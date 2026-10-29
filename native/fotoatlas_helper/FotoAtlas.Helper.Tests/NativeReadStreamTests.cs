using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using FotoAtlas.Helper.Devices.Wpd;

namespace FotoAtlas.Helper.Tests;

/// <summary>
/// O stream do WPD precisa ser liberado na hora: com o wrapper gerado, o MTP do
/// celular real ficava "ocupado" (0x800700AA) no arquivo seguinte até o GC rodar.
/// Aqui um objeto COM falso (vtable em memória) conta as chamadas.
/// </summary>
public sealed unsafe class NativeReadStreamTests
{
    private static int _refs;
    private static int _reads;
    private static int _otherCalls;
    private static int _remaining;

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static uint AddRef(nint self) => (uint)Interlocked.Increment(ref _refs);

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static uint Release(nint self) => (uint)Interlocked.Decrement(ref _refs);

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int Read(nint self, byte* buffer, uint count, uint* read)
    {
        _reads++;
        var n = (uint)Math.Min(count, _remaining);
        for (var i = 0; i < n; i++) buffer[i] = 7;
        _remaining -= (int)n;
        *read = n;
        return n < count ? 1 : 0; // S_FALSE na leitura curta, como o WPD
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int Other(nint self)
    {
        Interlocked.Increment(ref _otherCalls);
        return unchecked((int)0x80004001); // E_NOTIMPL
    }

    [Fact]
    public void LeSoPeloReadEDevolveAReferenciaNaHora()
    {
        // IStream: QueryInterface, AddRef, Release, Read, Write, ... (Write e os demais = "Other").
        var vtable = (nint*)NativeMemory.AllocZeroed(14, (nuint)sizeof(nint));
        var obj = (nint*)NativeMemory.AllocZeroed(1, (nuint)sizeof(nint));
        try
        {
            for (var i = 0; i < 14; i++) vtable[i] = (nint)(delegate* unmanaged[Stdcall]<nint, int>)&Other;
            vtable[1] = (nint)(delegate* unmanaged[Stdcall]<nint, uint>)&AddRef;
            vtable[2] = (nint)(delegate* unmanaged[Stdcall]<nint, uint>)&Release;
            vtable[3] = (nint)(delegate* unmanaged[Stdcall]<nint, byte*, uint, uint*, int>)&Read;
            *obj = (nint)vtable;
            _refs = 1;
            _reads = 0;
            _otherCalls = 0;
            _remaining = 100_000;

            var stream = new NativeReadStream((nint)obj);
            var buffer = new byte[64 * 1024];
            long total = 0;
            fixed (byte* p = buffer)
            {
                while (true)
                {
                    Assert.True(stream.Read(p, (uint)buffer.Length, out var read) >= 0);
                    if (read == 0) break;
                    total += read;
                }
            }
            Assert.Equal(100_000, total);
            Assert.Equal(3, _reads); // 64 KiB, o resto (S_FALSE) e a leitura vazia do fim
            Assert.Equal(0, stream.Release());
            Assert.Equal(0, _refs);
            stream.Dispose(); // não libera de novo
            Assert.Equal(0, _refs);
            Assert.Equal(0, _otherCalls); // nunca Write nem outro método
            Assert.Throws<ObjectDisposedException>(() =>
            {
                fixed (byte* p = buffer) stream.Read(p, 1, out _);
            });
        }
        finally
        {
            NativeMemory.Free(obj);
            NativeMemory.Free(vtable);
        }
    }
}
