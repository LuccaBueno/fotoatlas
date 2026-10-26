using System.Text.Json.Nodes;
using FotoAtlas.Helper.Protocol;
using FotoAtlas.Helper.Volumes;

namespace FotoAtlas.Helper.Tests;

public class ProtocolHostTests
{
    private sealed class FakeVolumes : IVolumeSource
    {
        public IReadOnlyList<VolumeInfo> List() =>
        [
            new VolumeInfo(
                "\\\\?\\Volume{00000000-0000-0000-0000-000000000001}\\",
                ["E:\\"], "Backup1", "NTFS", 1234u, 1000UL, 400UL, "fixed", false, false,
                [new PhysicalDiskInfo(2, "WD-ABC123", "WDC X", 1000, "usb", false, "reliable")]),
        ];
    }

    private static async Task<List<JsonObject>> RunAsync(params string[] lines)
    {
        var input = new StringReader(string.Join('\n', lines) + "\n");
        var output = new StringWriter();
        var host = new ProtocolHost(input, output, new FakeVolumes());
        await host.RunAsync();
        return output.ToString()
            .Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(l => (JsonObject)JsonNode.Parse(l)!)
            .ToList();
    }

    private static JsonObject ById(List<JsonObject> messages, string id) =>
        messages.Single(m => m["id"]?.GetValue<string>() == id);

    [Fact]
    public async Task EmiteHelloPrimeiro()
    {
        var messages = await RunAsync();
        var hello = messages[0];
        Assert.Equal("hello", hello["event"]!.GetValue<string>());
        Assert.Equal(1, hello["data"]!["protocol"]!.GetValue<int>());
    }

    [Fact]
    public async Task PingResponde()
    {
        var messages = await RunAsync("""{"v":1,"id":"1","method":"system.ping"}""");
        var response = ById(messages, "1");
        Assert.True(response["ok"]!.GetValue<bool>());
        Assert.NotNull(response["result"]!["uptimeMs"]);
    }

    [Fact]
    public async Task VolumesListSerializaCampos()
    {
        var messages = await RunAsync("""{"v":1,"id":"7","method":"volumes.list","params":{}}""");
        var volume = ById(messages, "7")["result"]!["volumes"]![0]!;
        Assert.Equal("E:\\", volume["mountPoints"]![0]!.GetValue<string>());
        Assert.Equal(1234u, volume["serial"]!.GetValue<uint>());
        Assert.Equal("reliable", volume["physicalDisks"]![0]!["identityConfidence"]!.GetValue<string>());
    }

    [Theory]
    [InlineData("isto não é json")]
    [InlineData("""{"v":1,"method":"system.ping"}""")]
    [InlineData("""{"v":2,"id":"1","method":"system.ping"}""")]
    [InlineData("""{"v":1,"id":"1","method":"nao.existe"}""")]
    public async Task PedidoInvalidoViraBadRequest(string line)
    {
        var messages = await RunAsync(line);
        var error = messages.Single(m => m["ok"] is not null);
        Assert.False(error["ok"]!.GetValue<bool>());
        Assert.Equal("bad_request", error["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task ShutdownRespondeEEncerra()
    {
        var input = new StringReader("""{"v":1,"id":"9","method":"system.shutdown"}""" + "\n");
        var output = new StringWriter();
        var host = new ProtocolHost(input, output, new FakeVolumes());
        await host.RunAsync();
        Assert.True(host.ShutdownRequested.IsCompleted);
        Assert.Contains("\"id\":\"9\",\"ok\":true", output.ToString());
    }
}
