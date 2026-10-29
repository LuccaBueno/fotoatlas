using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using FotoAtlas.Helper.Devices;
using FotoAtlas.Helper.Devices.Fake;
using FotoAtlas.Helper.Devices.Wpd;
using FotoAtlas.Helper.Protocol;

namespace FotoAtlas.Helper.Tests;

public sealed class FakeDeviceTests : IDisposable
{
    private readonly DirectoryInfo _dir = Directory.CreateTempSubdirectory("fotoatlas_fake_devices_");

    public void Dispose() => _dir.Delete(recursive: true);

    private string Write(string name, string json)
    {
        var path = Path.Combine(_dir.FullName, name);
        File.WriteAllText(path, json, new UTF8Encoding(false));
        return path;
    }

    private const string Pixel = """
        {
          "deviceId": "fake:pixel", "friendlyName": "Pixel de Teste", "manufacturer": "Google",
          "model": "Pixel 9", "serial": "FAKE-0001", "kind": "android",
          "storages": [{
            "name": "Armazenamento interno",
            "folders": ["Download"],
            "files": [
              {"path": "DCIM/Camera/IMG_0001.jpg", "text": "foto um", "modified": "2024-05-01T10:00:00Z"},
              {"path": "DCIM/Camera/IMG_0002.jpg", "text": "foto dois"},
              {"path": "WhatsApp/Media/IMG-WA0001.jpg", "text": "zap", "modified": null}
            ]
          }],
          "faults": {"changeDuringRead": ["DCIM/Camera/IMG_0002.jpg"]}
        }
        """;

    private static List<DeviceEntry> Children(IDeviceBackend b, string device, string objectId)
    {
        var all = new List<DeviceEntry>();
        b.ListChildren(device, objectId, all.AddRange, CancellationToken.None);
        return all;
    }

    [Fact]
    public void ListaENavega()
    {
        Write("pixel.json", Pixel);
        var backend = new FakeDeviceBackend(_dir.FullName);
        var device = Assert.Single(backend.List());
        Assert.Equal("android", device.Kind);
        Assert.Equal("ok", device.Status);
        Assert.True(device.Simulated);

        var storage = Assert.Single(Children(backend, "fake:pixel", ""));
        Assert.True(storage.IsFolder);
        Assert.Equal("Armazenamento interno", storage.Name);
        var top = Children(backend, "fake:pixel", storage.ObjectId).Select(e => e.Name).ToList();
        Assert.Equal(["DCIM", "Download", "WhatsApp"], top);
        var dcim = Children(backend, "fake:pixel", storage.ObjectId).Single(e => e.Name == "DCIM");
        var camera = Assert.Single(Children(backend, "fake:pixel", dcim.ObjectId));
        var files = Children(backend, "fake:pixel", camera.ObjectId);
        Assert.Equal(["IMG_0001.jpg", "IMG_0002.jpg"], files.Select(f => f.Name));
        Assert.Equal(7, files[0].Size);
        Assert.Equal(new DateTime(2024, 5, 1, 10, 0, 0, DateTimeKind.Utc).ToFileTimeUtc(), files[0].Modified);

        var zap = Children(backend, "fake:pixel", Children(backend, "fake:pixel", Children(backend, "fake:pixel", storage.ObjectId).Single(e => e.Name == "WhatsApp").ObjectId)[0].ObjectId);
        Assert.Null(Assert.Single(zap).Modified);
    }

    [Fact]
    public void HashConfereEDetectaMudanca()
    {
        Write("pixel.json", Pixel);
        var backend = new FakeDeviceBackend(_dir.FullName);
        var storage = Children(backend, "fake:pixel", "")[0];
        var camera = Children(backend, "fake:pixel", Children(backend, "fake:pixel", Children(backend, "fake:pixel", storage.ObjectId)[0].ObjectId)[0].ObjectId);
        var result = backend.Hash("fake:pixel", camera[0].ObjectId, 7, _ => { }, CancellationToken.None);
        Assert.Equal(Convert.ToHexStringLower(SHA256.HashData("foto um"u8.ToArray())), result.Sha256Hex);

        var changed = Assert.Throws<HelperException>(() => backend.Hash("fake:pixel", camera[1].ObjectId, null, _ => { }, CancellationToken.None));
        Assert.Equal("changed_during_read", changed.Code);
        var wrongSize = Assert.Throws<HelperException>(() => backend.Hash("fake:pixel", camera[0].ObjectId, 99, _ => { }, CancellationToken.None));
        Assert.Equal("changed_during_read", wrongSize.Code);
    }

    [Fact]
    public void DesplugarApagandoOArquivo()
    {
        var file = Write("pixel.json", Pixel);
        var backend = new FakeDeviceBackend(_dir.FullName);
        var storage = Children(backend, "fake:pixel", "")[0];
        File.Delete(file);
        Assert.Empty(backend.List());
        var e = Assert.Throws<HelperException>(() => Children(backend, "fake:pixel", storage.ObjectId));
        Assert.Equal("device_disconnected", e.Code);
    }

    [Fact]
    public void DesconectaDepoisDeNListagens()
    {
        Write("pixel.json", Pixel.Replace("\"faults\": {", "\"faults\": {\"disconnectAfterListCalls\": 2, "));
        var backend = new FakeDeviceBackend(_dir.FullName);
        var storage = Children(backend, "fake:pixel", "")[0];
        Children(backend, "fake:pixel", storage.ObjectId);
        var e = Assert.Throws<HelperException>(() => Children(backend, "fake:pixel", storage.ObjectId));
        Assert.Equal("device_disconnected", e.Code);
        Assert.Empty(backend.List());
    }

    [Fact]
    public void IdsMudamEntreSessoes()
    {
        Write("pixel.json", Pixel);
        var first = new FakeDeviceBackend(_dir.FullName);
        var storage = Children(first, "fake:pixel", "")[0];
        var second = new FakeDeviceBackend(_dir.FullName);
        var e = Assert.Throws<HelperException>(() => Children(second, "fake:pixel", storage.ObjectId));
        Assert.Equal("not_found", e.Code);
        Assert.Single(Children(second, "fake:pixel", ""));
    }

    [Fact]
    public void BloqueadoNaoMostraArmazenamento()
    {
        Write("iphone.json", """{"deviceId":"fake:iphone","friendlyName":"iPhone","manufacturer":"Apple Inc.","kind":"iphone","status":"unauthorized","storages":[{"files":[{"path":"DCIM/a.jpg","text":"x"}]}]}""");
        var backend = new FakeDeviceBackend(_dir.FullName);
        var device = Assert.Single(backend.List());
        Assert.Equal("unauthorized", device.Status);
        Assert.Empty(device.Storages);
    }

    [Fact]
    public async Task ProtocoloDevices()
    {
        Write("pixel.json", Pixel);
        var input = new StringReader(string.Join('\n',
            """{"v":1,"id":"1","method":"devices.list"}""",
            """{"v":1,"id":"2","method":"devices.listChildren","params":{"deviceId":"fake:pixel","objectId":""}}""",
            """{"v":1,"id":"3","method":"devices.listChildren","params":{"deviceId":"fake:nada","objectId":""}}""",
            """{"v":1,"id":"4","method":"devices.hashObject","params":{"deviceId":"fake:pixel"}}""") + "\n");
        var output = new StringWriter();
        await new ProtocolHost(input, output, new NoVolumes(), null, new FakeDeviceBackend(_dir.FullName)).RunAsync();
        var messages = output.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries).Select(l => (JsonObject)JsonNode.Parse(l)!).ToList();
        JsonObject Response(string id) => messages.Single(m => m["id"]?.GetValue<string>() == id && m["event"] is null);

        var device = Response("1")["result"]!["devices"]![0]!;
        Assert.Equal("Pixel de Teste", device["friendlyName"]!.GetValue<string>());
        Assert.Equal("FAKE-0001", device["serial"]!.GetValue<string>());
        var entries = messages.Single(m => m["id"]?.GetValue<string>() == "2" && m["event"]?.GetValue<string>() == "entries");
        Assert.Equal("Armazenamento interno", entries["data"]!["items"]![0]!["name"]!.GetValue<string>());
        Assert.Equal(1, Response("2")["result"]!["count"]!.GetValue<int>());
        Assert.Equal("device_disconnected", Response("3")["error"]!["code"]!.GetValue<string>());
        Assert.Equal("bad_request", Response("4")["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task PullToFileGravaOPartConfereENuncaSobrescreve()
    {
        Write("pixel.json", Pixel.Replace("\"faults\": {\"changeDuringRead\": [\"DCIM/Camera/IMG_0002.jpg\"]}",
            "\"faults\": {\"disconnectDuringPull\": [\"DCIM/Camera/IMG_0002.jpg\"]}"));
        var backend = new FakeDeviceBackend(_dir.FullName);
        var storage = Children(backend, "fake:pixel", "")[0];
        var dcim = Children(backend, "fake:pixel", storage.ObjectId).Single(e => e.Name == "DCIM");
        var camera = Children(backend, "fake:pixel", dcim.ObjectId).Single();
        var files = Children(backend, "fake:pixel", camera.ObjectId);
        var img1 = files.Single(f => f.Name == "IMG_0001.jpg").ObjectId;
        var img2 = files.Single(f => f.Name == "IMG_0002.jpg").ObjectId;

        var tmp = Directory.CreateDirectory(Path.Combine(_dir.FullName, "destino", ".fotoatlas-tmp")).FullName;
        var ok = Path.Combine(tmp, "a.part");
        var cut = Path.Combine(tmp, "b.part");
        var outside = Path.Combine(_dir.FullName, "destino", "IMG_0001.jpg");
        File.WriteAllText(Path.Combine(tmp, "existe.part"), "não mexer");
        string Req(string id, string objectId, string dest, int size = 7) => new JsonObject
        {
            ["v"] = 1, ["id"] = id, ["method"] = "devices.pullToFile",
            ["params"] = new JsonObject
            {
                ["deviceId"] = "fake:pixel", ["objectId"] = objectId, ["destPath"] = dest,
                ["expectedSize"] = size, ["modified"] = "133590528000000000",
            },
        }.ToJsonString();
        var input = new StringReader(string.Join("\n",
            Req("1", img1, ok),
            Req("2", img1, outside),
            Req("3", img1, Path.Combine(tmp, "existe.part")),
            Req("4", img2, cut, 9)) + "\n");
        var output = new StringWriter();
        await new ProtocolHost(input, output, new NoVolumes(), null, backend).RunAsync();
        var messages = output.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries).Select(l => (JsonObject)JsonNode.Parse(l)!).ToList();
        JsonObject Response(string id) => messages.Single(m => m["id"]?.GetValue<string>() == id && m["event"] is null);

        var result = Response("1")["result"]!;
        Assert.Equal(Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes("foto um"))), result["sha256"]!.GetValue<string>());
        Assert.Equal(7, result["bytesWritten"]!.GetValue<long>());
        Assert.Equal("foto um", File.ReadAllText(ok));
        Assert.Equal(DateTime.FromFileTimeUtc(133590528000000000), File.GetLastWriteTimeUtc(ok));
        Assert.Equal("write_refused", Response("2")["error"]!["code"]!.GetValue<string>());
        Assert.False(File.Exists(outside));
        Assert.Equal("already_exists", Response("3")["error"]!["code"]!.GetValue<string>());
        Assert.Equal("não mexer", File.ReadAllText(Path.Combine(tmp, "existe.part")));
        // Desplugado no meio: erro próprio e o .part parcial fica para o core decidir.
        Assert.Equal("device_disconnected", Response("4")["error"]!["code"]!.GetValue<string>());
        Assert.True(File.Exists(cut));
        Assert.True(new FileInfo(cut).Length < "foto dois".Length);
    }

    private sealed class NoVolumes : FotoAtlas.Helper.Volumes.IVolumeSource
    {
        public IReadOnlyList<FotoAtlas.Helper.Volumes.VolumeInfo> List() => [];
    }
}

public class DeviceKindsTests
{
    [Theory]
    [InlineData(@"\\?\swd#wpdbusenum#_??_usbstor#disk&ven_kingston#{6ac27878}", null, true)]
    [InlineData(@"\\?\usb#vid_18d1&pid_4ee1#abc123#{6ac27878}", "MTP: 1.00", false)]
    [InlineData(@"\\?\usb#vid_0000#x#{6ac27878}", "MSC:", true)]
    public void PendriveFicaFora(string pnp, string? protocol, bool expected) =>
        Assert.Equal(expected, DeviceKinds.IsMassStorage(pnp, protocol));

    [Fact]
    public void Classifica()
    {
        Assert.Equal("iphone", DeviceKinds.Classify("Apple Inc.", "iPhone", "iPhone de Ana", 3));
        Assert.Equal("android", DeviceKinds.Classify("samsung", "SM-S918B", "Galaxy S23", 3));
        Assert.Equal("camera", DeviceKinds.Classify("Canon", "EOS", "Canon", 1));
        Assert.Equal("other", DeviceKinds.Classify(null, null, null, null));
    }

    [Fact]
    public void SemArmazenamentoEhBloqueado()
    {
        Assert.Equal("locked", DeviceKinds.StatusFor("android", []));
        Assert.Equal("unauthorized", DeviceKinds.StatusFor("iphone", []));
        Assert.Equal("locked", DeviceKinds.StatusFor("android", [new StorageInfo("s", "Interno", 0, 0)]));
        Assert.Equal("ok", DeviceKinds.StatusFor("android", [new StorageInfo("s", "Interno", 100, 10)]));
    }
}

/// <summary>
/// Interop WPD sem tocar em nenhum dispositivo: só objetos em memória do próprio
/// Windows (saco de propriedades, coleção de chaves, gerenciador).
/// </summary>
public class WpdInteropTests
{
    [Fact]
    public void SacoDePropriedadesIdaEVolta()
    {
        var values = Ole32.Create<IPortableDeviceValues>(WpdGuids.PortableDeviceValues);
        values.SetStringValue(WpdKeys.Name, "IMG_0001.HEIC");
        values.SetUnsignedIntegerValue(WpdKeys.DeviceType, 3);
        values.SetUnsignedLargeIntegerValue(WpdKeys.Size, 5_000_000_000UL);
        values.SetGuidValue(WpdKeys.ContentType, WpdGuids.ContentTypeFolder);
        values.SetBoolValue(WpdKeys.ObjectId, 1);
        var date = new PropVariant { Vt = 7 };
        var oa = new DateTime(2024, 5, 1, 10, 30, 0).ToOADate();
        unsafe
        {
            *(double*)((byte*)&date + 8) = oa;
        }
        values.SetValue(WpdKeys.DateModified, date);

        Assert.Equal("IMG_0001.HEIC", WpdBackend.GetString(values, WpdKeys.Name));
        Assert.Equal(3u, WpdBackend.GetUInt32(values, WpdKeys.DeviceType));
        Assert.Equal(5_000_000_000UL, WpdBackend.GetUInt64(values, WpdKeys.Size));
        Assert.Equal(WpdGuids.ContentTypeFolder, WpdBackend.GetGuid(values, WpdKeys.ContentType));
        Assert.Equal(0, values.GetBoolValue(WpdKeys.ObjectId, out var b));
        Assert.Equal(1, b);
        Assert.Equal(DateTime.SpecifyKind(new DateTime(2024, 5, 1, 10, 30, 0), DateTimeKind.Local).ToFileTime(), WpdBackend.GetDate(values, WpdKeys.DateModified));
        Assert.Null(WpdBackend.GetString(values, WpdKeys.DeviceModel));
        values.GetCount(out var count);
        Assert.Equal(6u, count);
    }

    [Fact]
    public void ColecaoDeChaves()
    {
        var keys = WpdBackend.KeyCollection(WpdKeys.Name, WpdKeys.Size);
        keys.GetCount(out var count);
        Assert.Equal(2u, count);
        keys.GetAt(1, out var key);
        Assert.Equal(WpdKeys.Size.FmtId, key.FmtId);
        Assert.Equal(11u, key.Pid);
    }

    [Fact]
    public void GerenciadorEDispositivoInstanciam()
    {
        // Só a contagem: não abre nenhum dispositivo conectado (CLAUDE.md).
        var manager = Ole32.Create<IPortableDeviceManager>(WpdGuids.PortableDeviceManager);
        manager.RefreshDeviceList();
        uint n = 0;
        unsafe
        {
            manager.GetDevices(null, ref n);
        }
        Assert.True(n >= 0);
        Assert.NotNull(Ole32.Create<IPortableDevice>(WpdGuids.PortableDeviceFtm));
    }

    /// <summary>
    /// Regra 2/4 no código: nenhuma interface do interop expõe método que grave,
    /// mova ou apague no dispositivo. Slots obrigatórios da vtable são "Reserved_*" sem parâmetros.
    /// </summary>
    [Fact]
    public void InteropSoTemMetodosDeLeitura()
    {
        var allowed = new HashSet<string>
        {
            "GetDevices", "RefreshDeviceList", "GetDeviceFriendlyName",
            "Open", "Content", "Cancel", "Close",
            "EnumObjects", "Properties", "Transfer", "Next", "GetValues", "GetStream", "Read",
            "GetCount", "GetAt", "Add",
            // Saco de propriedades em memória (parâmetros locais, não o aparelho).
            "SetValue", "GetValue", "SetStringValue", "GetStringValue", "SetUnsignedIntegerValue", "GetUnsignedIntegerValue",
            "SetUnsignedLargeIntegerValue", "GetUnsignedLargeIntegerValue", "GetErrorValue", "SetBoolValue", "GetBoolValue",
            "SetGuidValue", "GetGuidValue",
        };
        var interfaces = typeof(WpdBackend).Assembly.GetTypes()
            .Where(t => t.IsInterface && t.Namespace == typeof(WpdBackend).Namespace)
            .ToList();
        Assert.Contains(typeof(IPortableDeviceContent), interfaces);
        foreach (var type in interfaces)
        {
            foreach (var m in type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
            {
                if (m.Name.StartsWith("Reserved_", StringComparison.Ordinal))
                {
                    Assert.Empty(m.GetParameters());
                    continue;
                }
                Assert.True(allowed.Contains(m.Name), $"{type.Name}.{m.Name} não está na lista de métodos de leitura");
                if (m.Name.StartsWith("Set", StringComparison.Ordinal) || m.Name == "Add")
                {
                    Assert.True(type == typeof(IPortableDeviceValues) || type == typeof(IPortableDeviceKeyCollection), $"{type.Name}.{m.Name}");
                }
            }
        }
    }
}
