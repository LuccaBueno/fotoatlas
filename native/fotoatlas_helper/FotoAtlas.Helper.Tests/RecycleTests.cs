using System.Text.Json.Nodes;
using FotoAtlas.Helper.Files;
using FotoAtlas.Helper.Protocol;

namespace FotoAtlas.Helper.Tests;

/// <summary>
/// <c>files.recycle</c> (ADR 0027): a única remoção do helper, sempre para a Lixeira.
/// Usa só arquivos sintéticos numa pasta temporária do próprio teste; o que o teste
/// manda para a Lixeira é tirado de lá no fim (os dois arquivos <c>$R</c>/<c>$I</c>).
/// </summary>
public sealed class RecycleTests : IDisposable
{
    private readonly DirectoryInfo _dir = Directory.CreateTempSubdirectory("fotoatlas_helper_lixeira_");
    private readonly List<string> _recycled = [];

    public void Dispose()
    {
        foreach (var r in _recycled) RemoveFromRecycleBin(r);
        _dir.Delete(recursive: true);
    }

    /// <summary>Limpa o que o teste pôs na Lixeira: o conteúdo (<c>$R…</c>) e a ficha (<c>$I…</c>).</summary>
    private static void RemoveFromRecycleBin(string recycledPath)
    {
        var name = Path.GetFileName(recycledPath);
        Assert.StartsWith("$R", name);
        Assert.Contains(@"\$Recycle.Bin\", recycledPath, StringComparison.OrdinalIgnoreCase);
        File.Delete(recycledPath);
        File.Delete(Path.Combine(Path.GetDirectoryName(recycledPath)!, "$I" + name[2..]));
    }

    private string Write(string name, int size)
    {
        var path = Path.Combine(_dir.FullName, name);
        File.WriteAllBytes(path, [.. Enumerable.Range(0, size).Select(i => (byte)(i * 7))]);
        return path;
    }

    private static string Json(string path) => JsonValue.Create(path)!.ToJsonString();

    private static async Task<JsonObject> Call(string line)
    {
        var output = new StringWriter();
        await new ProtocolHost(new StringReader(line + "\n"), output, new NoVolumes()).RunAsync();
        return output.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(l => (JsonObject)JsonNode.Parse(l)!)
            .Single(m => m["id"]?.GetValue<string>() == "1");
    }

    [Fact]
    public async Task ArquivoVaiParaALixeiraENaoEApagadoDeVez()
    {
        var path = Write("repetida ção.jpg", 4096);
        var mtime = File.GetLastWriteTimeUtc(path).ToFileTimeUtc();
        var response = await Call(
            $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(path)}}},"expectedSize":4096,"expectedMtime":"{{{mtime}}}"}}""");
        Assert.Null(response["error"]?.ToJsonString());
        var recycledPath = response["result"]!["recycledPath"]!.GetValue<string>();
        _recycled.Add(recycledPath);
        Assert.False(File.Exists(path));
        // O conteúdo está inteiro na Lixeira (dá para restaurar pelo Explorador).
        Assert.Equal(4096, new FileInfo(recycledPath).Length);
        Assert.Contains(@"\$Recycle.Bin\", recycledPath, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ArquivoQueMudouNaoSai()
    {
        var path = Write("mudou.jpg", 1000);
        var response = await Call(
            $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(path)}}},"expectedSize":999}}""");
        Assert.Equal("changed", response["error"]!["code"]!.GetValue<string>());
        Assert.True(File.Exists(path));

        var mtime = File.GetLastWriteTimeUtc(path).ToFileTimeUtc() + 10_000_000;
        response = await Call(
            $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(path)}}},"expectedSize":1000,"expectedMtime":"{{{mtime}}}"}}""");
        Assert.Equal("changed", response["error"]!["code"]!.GetValue<string>());
        Assert.True(File.Exists(path));
    }

    [Fact]
    public async Task PastaCaminhoRelativoEArquivoQueSumiuSaoRecusados()
    {
        var folder = Directory.CreateDirectory(Path.Combine(_dir.FullName, "pasta")).FullName;
        var response = await Call(
            $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(folder)}}},"expectedSize":0}}""");
        Assert.Equal("not_found", response["error"]!["code"]!.GetValue<string>());
        Assert.True(Directory.Exists(folder));

        response = await Call("""{"v":1,"id":"1","method":"files.recycle","params":{"path":"foto.jpg","expectedSize":1}}""");
        Assert.Equal("bad_request", response["error"]!["code"]!.GetValue<string>());

        var traversal = Path.Combine(_dir.FullName, "pasta", "..", "x.jpg");
        response = await Call(
            $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(traversal)}}},"expectedSize":1}}""");
        Assert.Equal("bad_request", response["error"]!["code"]!.GetValue<string>());

        response = await Call(
            $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(Path.Combine(_dir.FullName, "nao.jpg"))}}},"expectedSize":1}}""");
        Assert.Equal("not_found", response["error"]!["code"]!.GetValue<string>());
    }

    /// <summary>
    /// Numa unidade sem Lixeira o Windows apagaria de vez: o helper recusa e o arquivo
    /// fica. Uma unidade <c>subst</c> (letra livre, apontando para a pasta do teste) não
    /// tem Lixeira e não exige administrador.
    /// </summary>
    [Fact]
    public async Task UnidadeSemLixeiraNaoPerdeNada()
    {
        var letter = Enumerable.Range('M', 'Z' - 'M' + 1).Select(c => $"{(char)c}:")
            .FirstOrDefault(d => !Directory.Exists(d + "\\") && !DriveInfo.GetDrives().Any(x => x.Name.StartsWith(d, StringComparison.OrdinalIgnoreCase)));
        Assert.NotNull(letter);
        var path = Write("sem lixeira.jpg", 2048);
        Assert.Equal(0, Subst(letter, _dir.FullName));
        try
        {
            var substPath = Path.Combine(letter + "\\", Path.GetFileName(path));
            Assert.True(File.Exists(substPath));
            var response = await Call(
                $$$"""{"v":1,"id":"1","method":"files.recycle","params":{"path":{{{Json(substPath)}}},"expectedSize":2048}}""");
            Assert.Equal("no_recycle_bin", response["error"]!["code"]!.GetValue<string>());
            Assert.True(File.Exists(path));
            Assert.Equal(2048, new FileInfo(path).Length);
        }
        finally
        {
            Subst(letter, null);
        }
    }

    private static int Subst(string letter, string? target)
    {
        using var p = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("subst.exe")
        {
            ArgumentList = { letter, target ?? "/D" },
            UseShellExecute = false,
            CreateNoWindow = true,
        })!;
        p.WaitForExit();
        return p.ExitCode;
    }

    [Fact]
    public void FlagsPedemALixeiraSemNenhumaJanela()
    {
        // ALLOWUNDO (0x40) e RECYCLEONDELETE (0x80000); sem janelas (FOF_NO_UI = 0x614).
        Assert.Equal(0x40u, Recycler.OperationFlags & 0x40);
        Assert.Equal(0x80000u, Recycler.OperationFlags & 0x80000);
        Assert.Equal(0x614u, Recycler.OperationFlags & 0x614);
        Assert.Equal(0x80u, Recycler.TsfDeleteRecycleIfPossible);
    }

    private sealed class NoVolumes : FotoAtlas.Helper.Volumes.IVolumeSource
    {
        public IReadOnlyList<FotoAtlas.Helper.Volumes.VolumeInfo> List() => [];
    }
}
