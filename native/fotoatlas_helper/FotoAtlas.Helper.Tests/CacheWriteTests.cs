using System.Text;
using System.Text.Json.Nodes;
using FotoAtlas.Helper.Devices.Fake;
using FotoAtlas.Helper.Protocol;

namespace FotoAtlas.Helper.Tests;

/// <summary>
/// <c>thumbnails.get</c> e <c>devices.readHead</c>: as únicas gravações do helper
/// nesta fase, sempre num arquivo novo dentro do <c>--cache-dir</c> (§6).
/// </summary>
public sealed class CacheWriteTests : IDisposable
{
    private readonly DirectoryInfo _dir = Directory.CreateTempSubdirectory("fotoatlas_helper_cache_");

    public void Dispose() => _dir.Delete(recursive: true);

    // JPEG 32×24 sem metadados (o mesmo dos fixtures).
    private static readonly byte[] Jpeg = Convert.FromBase64String(
        "/9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAgQEBMQExYWFhYWFhoYGhsbGxoaGhobGxsdHR0iIiIdHR0bGx0dICAiIiUmJSMjIiMmJigoKDAwLi44ODpFRVP/xABMAAEBAAAAAAAAAAAAAAAAAAAABAEBAQAAAAAAAAAAAAAAAAAAAAYQAQAAAAAAAAAAAAAAAAAAAAARAQAAAAAAAAAAAAAAAAAAAAD/wAARCAAYACADASIAAhEAAxEA/9oADAMBAAIRAxEAPwCEBbpcAAAAAB//2Q==");

    private string Cache => Directory.CreateDirectory(Path.Combine(_dir.FullName, "cache")).FullName;

    private static string Json(string path) => JsonValue.Create(path)!.ToJsonString();

    private async Task<Func<string, JsonObject>> Run(params string[] lines)
    {
        var output = new StringWriter();
        await new ProtocolHost(
            new StringReader(string.Join('\n', lines) + "\n"),
            output,
            new NoVolumes(),
            null,
            new FakeDeviceBackend(Path.Combine(_dir.FullName, "celulares")),
            Cache).RunAsync();
        var messages = output.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries).Select(l => (JsonObject)JsonNode.Parse(l)!).ToList();
        return id => messages.Single(m => m["id"]?.GetValue<string>() == id && m["event"] is null);
    }

    [Fact]
    public async Task MiniaturaDoShellViraJpegNoCache()
    {
        var foto = Path.Combine(_dir.FullName, "foto ção.jpg");
        File.WriteAllBytes(foto, Jpeg);
        var before = File.ReadAllBytes(foto);
        var outPath = Path.Combine(Cache, "ab", "x.jpg.tmp");
        Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
        var response = await Run(
            $$$"""{"v":1,"id":"1","method":"thumbnails.get","params":{"path":{{{Json(foto)}}},"size":256,"outPath":{{{Json(outPath)}}}}}""");
        Assert.Null(response("1")["error"]?.ToJsonString());
        var result = response("1")["result"]!;
        Assert.True(result["width"]!.GetValue<int>() > 0);
        var thumb = File.ReadAllBytes(outPath);
        Assert.Equal([0xFF, 0xD8], thumb[..2]);
        Assert.Equal(before, File.ReadAllBytes(foto)); // origem intacta
    }

    [Fact]
    public async Task MiniaturaRecusaForaDoCacheArquivoExistenteEOrigemQueNaoExiste()
    {
        var foto = Path.Combine(_dir.FullName, "a.jpg");
        File.WriteAllBytes(foto, Jpeg);
        var fora = Path.Combine(_dir.FullName, "fora.jpg");
        var existente = Path.Combine(Cache, "existe.jpg");
        File.WriteAllBytes(existente, [1, 2, 3]);
        var response = await Run(
            $$$"""{"v":1,"id":"1","method":"thumbnails.get","params":{"path":{{{Json(foto)}}},"outPath":{{{Json(fora)}}}}}""",
            $$$"""{"v":1,"id":"2","method":"thumbnails.get","params":{"path":{{{Json(foto)}}},"outPath":{{{Json(existente)}}}}}""",
            $$$"""{"v":1,"id":"3","method":"thumbnails.get","params":{"path":{{{Json(Path.Combine(_dir.FullName, "sumiu.jpg"))}}},"outPath":{{{Json(Path.Combine(Cache, "n.jpg"))}}}}}""",
            $$$"""{"v":1,"id":"4","method":"thumbnails.get","params":{"path":{{{Json(foto)}}},"outPath":{{{Json(Path.Combine(Cache, "..", "fora2.jpg"))}}}}}""");
        Assert.Equal("write_refused", response("1")["error"]!["code"]!.GetValue<string>());
        Assert.False(File.Exists(fora));
        Assert.Equal("already_exists", response("2")["error"]!["code"]!.GetValue<string>());
        Assert.Equal([1, 2, 3], File.ReadAllBytes(existente)); // nunca sobrescreve
        Assert.Equal("not_found", response("3")["error"]!["code"]!.GetValue<string>());
        Assert.False(File.Exists(Path.Combine(Cache, "n.jpg")));
        Assert.Equal("write_refused", response("4")["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task ReadHeadCopiaSoOComecoParaOCache()
    {
        var celulares = Directory.CreateDirectory(Path.Combine(_dir.FullName, "celulares")).FullName;
        var content = new string('x', 1000);
        File.WriteAllText(Path.Combine(celulares, "pixel.json"), $$"""
            {"deviceId": "fake:pixel", "friendlyName": "Pixel", "kind": "android", "stableIds": true,
             "storages": [{"name": "Interno", "files": [{"path": "DCIM/a.jpg", "text": "{{content}}"}]}]}
            """, new UTF8Encoding(false));
        var outPath = Path.Combine(Cache, "head.bin");
        var fora = Path.Combine(_dir.FullName, "head.bin");
        var response = await Run(
            $$$"""{"v":1,"id":"1","method":"devices.readHead","params":{"deviceId":"fake:pixel","objectId":"s|0|DCIM/a.jpg","maxBytes":100,"outPath":{{{Json(outPath)}}}}}""",
            $$$"""{"v":1,"id":"2","method":"devices.readHead","params":{"deviceId":"fake:pixel","objectId":"s|0|DCIM/a.jpg","outPath":{{{Json(fora)}}}}}""",
            $$$"""{"v":1,"id":"3","method":"devices.readHead","params":{"deviceId":"fake:pixel","objectId":"s|0|DCIM/a.jpg","outPath":{{{Json(outPath)}}}}}""");
        Assert.Equal(100, response("1")["result"]!["bytes"]!.GetValue<long>());
        Assert.Equal(Encoding.UTF8.GetBytes(content[..100]), File.ReadAllBytes(outPath));
        Assert.Equal("write_refused", response("2")["error"]!["code"]!.GetValue<string>());
        Assert.False(File.Exists(fora));
        Assert.Equal("already_exists", response("3")["error"]!["code"]!.GetValue<string>());
    }

    private sealed class NoVolumes : FotoAtlas.Helper.Volumes.IVolumeSource
    {
        public IReadOnlyList<FotoAtlas.Helper.Volumes.VolumeInfo> List() => [];
    }
}
