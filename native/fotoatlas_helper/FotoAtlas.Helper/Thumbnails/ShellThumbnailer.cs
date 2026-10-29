using System.Runtime.InteropServices;
using FotoAtlas.Helper.Protocol;
using FotoAtlas.Helper.Volumes;

namespace FotoAtlas.Helper.Thumbnails;

/// <summary>
/// Miniatura pelo Shell do Windows (<c>IShellItemImageFactory</c>, a mesma do
/// Explorador, com os codecs instalados) codificada em JPEG pelo WIC, em memória.
/// O arquivo de origem só é lido; o JPEG volta em bytes e quem grava é o host,
/// dentro do cache e com <c>CreateNew</c> (docs/protocolo-helper.md §6).
/// Chamadas COM pela vtable (como <c>NativeReadStream</c>): poucos métodos, sem
/// declarar interfaces inteiras.
/// </summary>
internal static unsafe partial class ShellThumbnailer
{
    private static readonly Guid IidShellItemImageFactory = new("bcc18b79-ba16-442f-80c4-8a59c30c463b");
    private static readonly Guid ClsidWicImagingFactory = new("cacaf262-9370-4615-a13b-9f5539da4c0a");
    private static readonly Guid IidWicImagingFactory = new("ec5ec8a9-c395-4314-9c77-54d7a935ff70");
    private static readonly Guid ContainerFormatJpeg = new("19e4a5aa-5662-4fc5-a0c0-1758028e1057");
    private static readonly Guid PixelFormat24bppBgr = new("6fddc324-4e03-4bfe-b185-3d77768dc90c");

    private const int SiigbfThumbnailOnly = 0x08;
    private const int WicBitmapIgnoreAlpha = 2;
    private const int WicBitmapEncoderNoCache = 2;
    private const int StreamSeekCur = 1;
    private const int MaxJpegBytes = 4 * 1024 * 1024;

    [StructLayout(LayoutKind.Sequential)]
    private struct Size(int cx, int cy)
    {
        public int Cx = cx;
        public int Cy = cy;
    }

    [LibraryImport("shell32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int SHCreateItemFromParsingName(string path, nint bindContext, in Guid riid, out nint item);

    [LibraryImport("ole32.dll")]
    private static partial int CoCreateInstance(in Guid clsid, nint outer, uint context, in Guid iid, out nint instance);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DeleteObject(nint handle);

    /// <summary>
    /// JPEG com o lado maior até <paramref name="size"/>. Sem miniatura (formato sem
    /// codec, arquivo ilegível) → <c>not_found</c>.
    /// </summary>
    public static (byte[] Jpeg, int Width, int Height) Get(string path, int size)
    {
        (byte[], int, int)? result = null;
        Exception? error = null;
        // O Shell espera um apartamento STA.
        var thread = new Thread(() =>
        {
            try { result = GetOnThisThread(path, size); }
            catch (Exception e) { error = e; }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
        if (error is not null) throw error;
        return result!.Value;
    }

    private static (byte[], int, int) GetOnThisThread(string path, int size)
    {
        nint item = 0, hbitmap = 0, wic = 0, bitmap = 0, stream = 0, encoder = 0, frame = 0, bag = 0;
        try
        {
            var hr = SHCreateItemFromParsingName(ShellPath(path), 0, IidShellItemImageFactory, out item);
            if (hr < 0) throw new HelperException("not_found", $"Arquivo não encontrado para a miniatura (0x{hr:X8}).");
            // IShellItemImageFactory::GetImage(SIZE, SIIGBF, HBITMAP*) — slot 3.
            var getImage = (delegate* unmanaged[Stdcall]<nint, Size, int, nint*, int>)Slot(item, 3);
            hr = getImage(item, new Size(size, size), SiigbfThumbnailOnly, &hbitmap);
            if (hr < 0 || hbitmap == 0) throw new HelperException("not_found", $"Sem miniatura para este arquivo (0x{hr:X8}).");

            Check(CoCreateInstance(ClsidWicImagingFactory, 0, 1 /* CLSCTX_INPROC_SERVER */, IidWicImagingFactory, out wic));
            // IWICImagingFactory::CreateBitmapFromHBITMAP — slot 21.
            Check(((delegate* unmanaged[Stdcall]<nint, nint, nint, int, nint*, int>)Slot(wic, 21))(wic, hbitmap, 0, WicBitmapIgnoreAlpha, &bitmap));
            uint w, h;
            // IWICBitmapSource::GetSize — slot 3.
            Check(((delegate* unmanaged[Stdcall]<nint, uint*, uint*, int>)Slot(bitmap, 3))(bitmap, &w, &h));

            var buffer = new byte[MaxJpegBytes];
            fixed (byte* pBuffer = buffer)
            {
                // CreateStream (slot 14) + IWICStream::InitializeFromMemory (slot 16): nada vai para o disco.
                Check(((delegate* unmanaged[Stdcall]<nint, nint*, int>)Slot(wic, 14))(wic, &stream));
                Check(((delegate* unmanaged[Stdcall]<nint, byte*, uint, int>)Slot(stream, 16))(stream, pBuffer, (uint)buffer.Length));
                var jpeg = ContainerFormatJpeg;
                // CreateEncoder — slot 8.
                Check(((delegate* unmanaged[Stdcall]<nint, Guid*, Guid*, nint*, int>)Slot(wic, 8))(wic, &jpeg, null, &encoder));
                // IWICBitmapEncoder::Initialize (3), CreateNewFrame (10), Commit (11).
                Check(((delegate* unmanaged[Stdcall]<nint, nint, int, int>)Slot(encoder, 3))(encoder, stream, WicBitmapEncoderNoCache));
                Check(((delegate* unmanaged[Stdcall]<nint, nint*, nint*, int>)Slot(encoder, 10))(encoder, &frame, &bag));
                // IWICBitmapFrameEncode::Initialize (3), SetSize (4), SetPixelFormat (6), WriteSource (11), Commit (12).
                Check(((delegate* unmanaged[Stdcall]<nint, nint, int>)Slot(frame, 3))(frame, bag));
                Check(((delegate* unmanaged[Stdcall]<nint, uint, uint, int>)Slot(frame, 4))(frame, w, h));
                var format = PixelFormat24bppBgr;
                Check(((delegate* unmanaged[Stdcall]<nint, Guid*, int>)Slot(frame, 6))(frame, &format));
                Check(((delegate* unmanaged[Stdcall]<nint, nint, void*, int>)Slot(frame, 11))(frame, bitmap, null));
                Check(((delegate* unmanaged[Stdcall]<nint, int>)Slot(frame, 12))(frame));
                Check(((delegate* unmanaged[Stdcall]<nint, int>)Slot(encoder, 11))(encoder));
                // IStream::Seek(0, CUR) — slot 5: posição = bytes escritos.
                ulong written;
                Check(((delegate* unmanaged[Stdcall]<nint, long, int, ulong*, int>)Slot(stream, 5))(stream, 0, StreamSeekCur, &written));
                return (buffer.AsSpan(0, (int)written).ToArray(), (int)w, (int)h);
            }
        }
        finally
        {
            foreach (var p in new[] { bag, frame, encoder, stream, bitmap, wic, item })
            {
                if (p != 0) Marshal.Release(p);
            }
            if (hbitmap != 0) DeleteObject(hbitmap);
        }
    }

    private static nint Slot(nint obj, int index) => (*(nint**)obj)[index];

    /// <summary>
    /// O Shell não abre <c>\\?\Volume{GUID}\…</c> (o core acessa as fontes assim, sem
    /// depender da letra): troca pelo ponto de montagem atual do volume.
    /// </summary>
    internal static string ShellPath(string path)
    {
        const string prefix = @"\\?\Volume{";
        if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return Path.GetFullPath(path);
        var end = path.IndexOf(@"}\", StringComparison.Ordinal);
        if (end < 0) throw new HelperException("not_found", "Caminho de volume inválido.");
        var volume = path[..(end + 2)];
        var mount = VolumeEnumerator.GetMountPoints(volume).FirstOrDefault()
            ?? throw new HelperException("not_found", "O volume não tem letra nem pasta de montagem (miniatura indisponível).");
        return Path.Combine(mount, path[(end + 2)..]);
    }

    private static void Check(int hr)
    {
        if (hr < 0) throw new HelperException("io_error", $"Falha ao gerar a miniatura (0x{hr:X8}).");
    }
}

