using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using FotoAtlas.Helper.Protocol;
using FotoAtlas.Helper.Thumbnails;

namespace FotoAtlas.Helper.Files;

/// <summary>Resultado de <see cref="Recycler.Recycle"/>: o arquivo foi para a Lixeira.</summary>
internal sealed record RecycleResult(string? RecycledPath);

/// <summary>
/// "Limpar repetidos" (ADR 0027): manda **um** arquivo para a Lixeira do Windows pelo
/// <c>IFileOperation</c> do Shell, sem nenhuma janela. É a única remoção de arquivo do
/// helper, e ela **nunca é definitiva**:
/// <list type="bullet">
/// <item><c>FOF_ALLOWUNDO</c> + <c>FOFX_RECYCLEONDELETE</c> pedem a Lixeira;</item>
/// <item>quando o Windows avisa (no <c>PreDeleteItem</c>, sem <c>TSF_DELETE_RECYCLE_IF_POSSIBLE</c>)
/// que apagaria de vez — pendrive, cartão, rede, arquivo maior que a Lixeira, Lixeira
/// desligada —, o pedido é recusado antes (<c>no_recycle_bin</c>) e o arquivo fica;</item>
/// <item>depois, só conta como feito se o Windows devolver o item criado na Lixeira.</item>
/// </list>
/// Antes de chamar o Shell, confere que o arquivo ainda tem o tamanho e a data esperados.
/// Chamadas COM pela vtable (como <see cref="ShellThumbnailer"/>); o "ouvinte" do Shell é
/// um objeto COM mínimo montado à mão (só os métodos que o Shell chama).
/// </summary>
internal static unsafe partial class Recycler
{
    private static readonly Guid ClsidFileOperation = new("3ad05575-8857-4850-9277-11b85bdb8e09");
    private static readonly Guid IidFileOperation = new("947aab5f-0a5c-4c13-b4d6-4bf7836fc9f8");
    private static readonly Guid IidShellItem = new("43826d1e-e718-42ee-bc55-a1e261c37bfe");
    private static readonly Guid IidUnknown = new("00000000-0000-0000-c000-000000000046");
    private static readonly Guid IidProgressSink = new("04b0f1a7-9490-44bc-96e1-4296a31252e2");

    // FOF_NO_UI (SILENT | NOCONFIRMATION | NOERRORUI | NOCONFIRMMKDIR) + ALLOWUNDO + RECYCLEONDELETE + EARLYFAILURE.
    internal const uint OperationFlags = 0x0004 | 0x0010 | 0x0400 | 0x0200 | 0x0040 | 0x00080000 | 0x00100000;
    internal const uint TsfDeleteRecycleIfPossible = 0x80;
    private const int SigdnFileSysPath = unchecked((int)0x80058000);
    private const int EAbort = unchecked((int)0x80004004);
    private const int ENoInterface = unchecked((int)0x80004002);

    [LibraryImport("shell32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int SHCreateItemFromParsingName(string path, nint bindContext, in Guid riid, out nint item);

    [LibraryImport("ole32.dll")]
    private static partial int CoCreateInstance(in Guid clsid, nint outer, uint context, in Guid iid, out nint instance);

    [LibraryImport("ole32.dll")]
    private static partial void CoTaskMemFree(nint pv);

    /// <summary>
    /// Manda <paramref name="path"/> para a Lixeira se ele ainda tiver
    /// <paramref name="expectedSize"/> bytes e a data de modificação <paramref name="expectedMtime"/>
    /// (FILETIME). Lança <see cref="HelperException"/> com o motivo quando não manda.
    /// </summary>
    public static RecycleResult Recycle(string path, long expectedSize, long? expectedMtime)
    {
        if (!Path.IsPathFullyQualified(path) || path.Split('\\', '/').Any(s => s == ".."))
        {
            throw new HelperException("bad_request", "Caminho precisa ser absoluto e sem '..'.");
        }
        var shellPath = ShellThumbnailer.ShellPath(path);
        FileInfo info;
        try
        {
            info = new FileInfo(shellPath);
            if (!info.Exists) throw new HelperException("not_found", "O arquivo não está mais lá.");
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            throw new HelperException("io_error", $"Não foi possível conferir o arquivo: {e.Message}", retryable: true);
        }
        if ((info.Attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint)) != 0)
        {
            throw new HelperException("bad_request", "Só arquivos comuns vão para a Lixeira (nunca pastas nem atalhos).");
        }
        if (info.Length != expectedSize || (expectedMtime is { } m && info.LastWriteTimeUtc.ToFileTimeUtc() != m))
        {
            throw new HelperException("changed", "O arquivo mudou (tamanho ou data diferente): não foi para a Lixeira.");
        }

        RecycleResult? result = null;
        Exception? error = null;
        // O Shell espera um apartamento STA.
        var thread = new Thread(() =>
        {
            try { result = RecycleOnThisThread(shellPath); }
            catch (Exception e) { error = e; }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
        if (error is not null) throw error;
        return result!;
    }

    private static RecycleResult RecycleOnThisThread(string path)
    {
        nint op = 0, item = 0;
        var state = new SinkState();
        var sink = Sink.Create(state);
        try
        {
            var hr = SHCreateItemFromParsingName(path, 0, IidShellItem, out item);
            if (hr < 0) throw new HelperException("not_found", $"O Windows não encontrou o arquivo (0x{hr:X8}).");
            Check(CoCreateInstance(ClsidFileOperation, 0, 1 /* CLSCTX_INPROC_SERVER */, IidFileOperation, out op), "abrir a operação");
            // IFileOperation::SetOperationFlags — slot 5.
            Check(((delegate* unmanaged[Stdcall]<nint, uint, int>)Slot(op, 5))(op, OperationFlags), "configurar a operação");
            // IFileOperation::DeleteItem(item, sink) — slot 18.
            Check(((delegate* unmanaged[Stdcall]<nint, nint, nint, int>)Slot(op, 18))(op, item, sink), "preparar a remoção");
            // IFileOperation::PerformOperations — slot 21.
            var performed = ((delegate* unmanaged[Stdcall]<nint, int>)Slot(op, 21))(op);
            if (state.RefusedPermanent)
            {
                throw new HelperException(
                    "no_recycle_bin",
                    "Neste disco o Windows apagaria o arquivo de vez (sem Lixeira): nada foi removido.");
            }
            if (performed < 0 || state.DeleteResult < 0)
            {
                var code = performed < 0 ? performed : state.DeleteResult;
                throw new HelperException(
                    code is unchecked((int)0x80070020) or unchecked((int)0x80070021) ? "in_use" : "io_error",
                    $"O Windows não conseguiu mandar o arquivo para a Lixeira (0x{code:X8}).",
                    retryable: true);
            }
            if (!state.Recycled)
            {
                // Sem item novo na Lixeira: só aceitamos se o arquivo continua lá (nada aconteceu).
                if (File.Exists(path)) throw new HelperException("io_error", "O arquivo não foi para a Lixeira.", retryable: true);
                throw new HelperException("not_recycled", "O Windows não confirmou que o arquivo foi para a Lixeira.");
            }
            return new RecycleResult(state.RecycledPath);
        }
        finally
        {
            if (op != 0) Marshal.Release(op);
            if (item != 0) Marshal.Release(item);
            Sink.Release(sink);
        }
    }

    private static nint Slot(nint obj, int index) => (*(nint**)obj)[index];

    private static void Check(int hr, string what)
    {
        if (hr < 0) throw new HelperException("io_error", $"Falha ao {what} da Lixeira (0x{hr:X8}).");
    }

    /// <summary>O que o Shell contou ao ouvinte.</summary>
    internal sealed class SinkState
    {
        public bool RefusedPermanent;
        public bool Recycled;
        public int DeleteResult;
        public string? RecycledPath;
    }

    /// <summary>
    /// <c>IFileOperationProgressSink</c> mínimo: um bloco nativo com a vtable e um
    /// <see cref="GCHandle"/> para o <see cref="SinkState"/>. Tudo devolve S_OK, menos o
    /// <c>PreDeleteItem</c> de uma remoção definitiva (E_ABORT: não remove).
    /// </summary>
    private static class Sink
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct Block
        {
            public nint Vtbl;
            public int Refs;
            public nint State;
        }

        private static readonly nint Vtbl = BuildVtbl();

        private static nint BuildVtbl()
        {
            var v = (nint*)NativeMemory.AllocZeroed(19, (nuint)sizeof(nint));
            v[0] = (nint)(delegate* unmanaged[Stdcall]<Block*, Guid*, nint*, int>)&QueryInterface;
            v[1] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint>)&AddRef;
            v[2] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint>)&ReleaseRefExport;
            v[3] = (nint)(delegate* unmanaged[Stdcall]<Block*, int>)&Ok0; // StartOperations
            v[4] = (nint)(delegate* unmanaged[Stdcall]<Block*, int, int>)&Ok1; // FinishOperations
            v[5] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, int>)&Ok3; // PreRenameItem
            v[6] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, int, nint, int>)&Ok5; // PostRenameItem
            v[7] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, nint, int>)&Ok4; // PreMoveItem
            v[8] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, nint, int, nint, int>)&Ok6; // PostMoveItem
            v[9] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, nint, int>)&Ok4; // PreCopyItem
            v[10] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, nint, int, nint, int>)&Ok6; // PostCopyItem
            v[11] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, int>)&PreDeleteItem;
            v[12] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, int, nint, int>)&PostDeleteItem;
            v[13] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, int>)&Ok3; // PreNewItem
            v[14] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, nint, nint, nint, uint, int, nint, int>)&Ok7; // PostNewItem
            v[15] = (nint)(delegate* unmanaged[Stdcall]<Block*, uint, uint, int>)&Ok2; // UpdateProgress
            v[16] = (nint)(delegate* unmanaged[Stdcall]<Block*, int>)&Ok0; // ResetTimer
            v[17] = (nint)(delegate* unmanaged[Stdcall]<Block*, int>)&Ok0; // PauseTimer
            v[18] = (nint)(delegate* unmanaged[Stdcall]<Block*, int>)&Ok0; // ResumeTimer
            return (nint)v;
        }

        public static nint Create(SinkState state)
        {
            var b = (Block*)NativeMemory.AllocZeroed((nuint)sizeof(Block));
            b->Vtbl = Vtbl;
            b->Refs = 1;
            b->State = GCHandle.ToIntPtr(GCHandle.Alloc(state));
            return (nint)b;
        }

        public static void Release(nint sink) => ReleaseRef((Block*)sink);

        private static SinkState StateOf(Block* b) => (SinkState)GCHandle.FromIntPtr(b->State).Target!;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int QueryInterface(Block* self, Guid* iid, nint* result)
        {
            if (*iid == IidUnknown || *iid == IidProgressSink)
            {
                Interlocked.Increment(ref self->Refs);
                *result = (nint)self;
                return 0;
            }
            *result = 0;
            return ENoInterface;
        }

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static uint AddRef(Block* self) => (uint)Interlocked.Increment(ref self->Refs);

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static uint ReleaseRefExport(Block* self) => ReleaseRef(self);

        private static uint ReleaseRef(Block* self)
        {
            var n = Interlocked.Decrement(ref self->Refs);
            if (n == 0)
            {
                GCHandle.FromIntPtr(self->State).Free();
                NativeMemory.Free(self);
            }
            return (uint)n;
        }

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int PreDeleteItem(Block* self, uint flags, nint item)
        {
            if ((flags & TsfDeleteRecycleIfPossible) != 0) return 0;
            // O Windows apagaria de vez: recusa (o arquivo fica).
            StateOf(self).RefusedPermanent = true;
            return EAbort;
        }

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int PostDeleteItem(Block* self, uint flags, nint item, int hr, nint newlyCreated)
        {
            var state = StateOf(self);
            state.DeleteResult = hr;
            if (hr >= 0 && newlyCreated != 0)
            {
                state.Recycled = true;
                nint name = 0;
                // IShellItem::GetDisplayName(SIGDN_FILESYSPATH) — slot 5.
                if (((delegate* unmanaged[Stdcall]<nint, int, nint*, int>)Slot(newlyCreated, 5))(newlyCreated, SigdnFileSysPath, &name) >= 0 && name != 0)
                {
                    state.RecycledPath = Marshal.PtrToStringUni(name);
                    CoTaskMemFree(name);
                }
            }
            return 0;
        }

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok0(Block* self) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok1(Block* self, int a) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok2(Block* self, uint a, uint b) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok3(Block* self, uint a, nint b, nint c) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok4(Block* self, uint a, nint b, nint c, nint d) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok5(Block* self, uint a, nint b, nint c, int d, nint e) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok6(Block* self, uint a, nint b, nint c, nint d, int e, nint f) => 0;

        [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
        private static int Ok7(Block* self, uint a, nint b, nint c, nint d, uint e, int f, nint g) => 0;
    }
}
