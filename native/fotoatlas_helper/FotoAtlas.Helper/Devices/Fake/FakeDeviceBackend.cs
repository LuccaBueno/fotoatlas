using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using FotoAtlas.Helper.Protocol;

namespace FotoAtlas.Helper.Devices.Fake;

/// <summary>
/// Celulares simulados para testes e demonstração sem aparelho (<c>--fake-devices PASTA</c>).
///
/// Cada <c>*.json</c> da pasta é um dispositivo; ele está "conectado" enquanto o arquivo
/// existir (apagar ou renomear = desplugar). O formato está em docs/protocolo-helper.md §5.3.1.
/// Só lê: nada é gravado na pasta.
/// </summary>
internal sealed class FakeDeviceBackend(string directory) : IDeviceBackend
{
    /// <summary>
    /// IDs de objeto mudam a cada processo (como no Android), salvo com <c>"stableIds": true</c>.
    /// </summary>
    private readonly string _salt = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(3));
    private readonly ConcurrentDictionary<string, int> _listCalls = new();
    private readonly ConcurrentDictionary<string, (DateTime Stamp, FakeDevice Device)> _cache = new();

    private sealed record FakeFile(string Path, Func<byte[]> Content, long? Modified);

    private sealed record FakeStorage(string Name, ulong? Total, ulong? Free, IReadOnlyList<string> Folders, IReadOnlyList<FakeFile> Files);

    private sealed record FakeDevice(
        string File,
        DeviceInfo Info,
        bool StableIds,
        IReadOnlyList<FakeStorage> Storages,
        int? DisconnectAfterListCalls,
        IReadOnlySet<string> ChangeDuringRead,
        IReadOnlySet<string> FolderErrors,
        int ReadDelayMs);

    public IReadOnlyList<DeviceInfo> List() =>
        [.. LoadAll().Where(d => !Unplugged(d)).Select(d => d.Info with { Storages = StoragesOf(d) })];

    public void ListChildren(string deviceId, string objectId, Action<IReadOnlyList<DeviceEntry>> onBatch, CancellationToken ct)
    {
        var device = Connected(deviceId);
        var count = _listCalls.AddOrUpdate(deviceId, 1, (_, n) => n + 1);
        if (device.DisconnectAfterListCalls is { } limit && count > limit)
        {
            throw new HelperException("device_disconnected", "O dispositivo foi desconectado (simulado).", retryable: true);
        }
        if (device.Info.Status != "ok") throw new HelperException("device_locked", "Dispositivo bloqueado (simulado).", retryable: true);

        var entries = new List<DeviceEntry>();
        if (objectId.Length == 0)
        {
            for (var i = 0; i < device.Storages.Count; i++)
            {
                entries.Add(new DeviceEntry(Id(device, i, ""), "", device.Storages[i].Name, true, null, null, null, $"storage-{i}"));
            }
        }
        else
        {
            var (index, folder) = Parse(device, objectId);
            var storage = device.Storages[index];
            if (device.FolderErrors.Contains(folder)) throw new HelperException("io_error", "Erro de leitura simulado.", retryable: true);
            var prefix = folder.Length == 0 ? "" : folder + "/";
            var allFolders = AllFolders(storage);
            if (folder.Length > 0 && !allFolders.Contains(folder)) throw new HelperException("not_found", "Pasta não existe (simulado).");
            foreach (var f in allFolders.Where(f => f.StartsWith(prefix, StringComparison.Ordinal) && f.Length > prefix.Length && !f[prefix.Length..].Contains('/')).Order(StringComparer.Ordinal))
            {
                entries.Add(new DeviceEntry(Id(device, index, f), objectId, f[prefix.Length..], true, null, null, null, $"{index}:{f}"));
            }
            foreach (var file in storage.Files.Where(f => Parent(f.Path) == folder).OrderBy(f => f.Path, StringComparer.Ordinal))
            {
                var name = file.Path[prefix.Length..];
                entries.Add(new DeviceEntry(Id(device, index, file.Path), objectId, name, false, file.Content().LongLength, file.Modified, file.Modified, $"{index}:{file.Path}"));
            }
        }
        foreach (var chunk in entries.Chunk(200))
        {
            ct.ThrowIfCancellationRequested();
            onBatch(chunk);
        }
    }

    public DeviceHashResult Hash(string deviceId, string objectId, long? expectedSize, Action<long> onProgress, CancellationToken ct)
    {
        var device = Connected(deviceId);
        if (device.Info.Status != "ok") throw new HelperException("device_locked", "Dispositivo bloqueado (simulado).", retryable: true);
        var (index, path) = Parse(device, objectId);
        var file = device.Storages[index].Files.FirstOrDefault(f => f.Path == path)
            ?? throw new HelperException("not_found", "Arquivo não existe (simulado).");
        var bytes = file.Content();
        if (expectedSize is not null && bytes.LongLength != expectedSize)
        {
            throw new HelperException("changed_during_read", "O arquivo mudou depois do escaneamento. Escaneie de novo.");
        }
        if (device.ReadDelayMs > 0)
        {
            Task.Delay(device.ReadDelayMs, ct).Wait(ct);
            Connected(deviceId); // desplugado durante a leitura?
        }
        onProgress(bytes.LongLength);
        if (device.ChangeDuringRead.Contains(path))
        {
            throw new HelperException("changed_during_read", "O arquivo mudou enquanto era lido. Escaneie de novo.");
        }
        return new DeviceHashResult(Convert.ToHexStringLower(SHA256.HashData(bytes)), bytes.LongLength, file.Modified);
    }

    private FakeDevice Connected(string deviceId)
    {
        var device = LoadAll().FirstOrDefault(d => d.Info.DeviceId == deviceId);
        if (device is null || Unplugged(device))
        {
            throw new HelperException("device_disconnected", "O dispositivo não está conectado (simulado).", retryable: true);
        }
        return device;
    }

    private bool Unplugged(FakeDevice d) =>
        d.DisconnectAfterListCalls is { } limit && _listCalls.TryGetValue(d.Info.DeviceId, out var n) && n > limit;

    private string Id(FakeDevice d, int storage, string path) => $"{(d.StableIds ? "s" : _salt)}|{storage}|{path}";

    private (int Storage, string Path) Parse(FakeDevice d, string objectId)
    {
        var parts = objectId.Split('|', 3);
        if (parts.Length != 3 || parts[0] != (d.StableIds ? "s" : _salt) || !int.TryParse(parts[1], out var i) || i < 0 || i >= d.Storages.Count)
        {
            throw new HelperException("not_found", "Objeto não encontrado (ID de outra sessão?).");
        }
        return (i, parts[2]);
    }

    private static string Parent(string path)
    {
        var slash = path.LastIndexOf('/');
        return slash < 0 ? "" : path[..slash];
    }

    private static HashSet<string> AllFolders(FakeStorage s)
    {
        var set = new HashSet<string>(StringComparer.Ordinal);
        foreach (var path in s.Folders.Concat(s.Files.Select(f => Parent(f.Path))))
        {
            var p = path;
            while (p.Length > 0 && set.Add(p)) p = Parent(p);
        }
        return set;
    }

    private List<StorageInfo> StoragesOf(FakeDevice d) =>
        [.. d.Storages.Select((s, i) => new StorageInfo(Id(d, i, ""), s.Name, s.Total, s.Free))];

    private List<FakeDevice> LoadAll()
    {
        var list = new List<FakeDevice>();
        if (!Directory.Exists(directory)) return list;
        foreach (var file in Directory.EnumerateFiles(directory, "*.json").Order(StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                var stamp = File.GetLastWriteTimeUtc(file);
                if (_cache.TryGetValue(file, out var cached) && cached.Stamp == stamp)
                {
                    list.Add(cached.Device);
                    continue;
                }
                var device = Parse(file);
                _cache[file] = (stamp, device);
                list.Add(device);
            }
            catch (Exception e) when (e is IOException or System.Text.Json.JsonException or FormatException or InvalidOperationException)
            {
                Console.Error.WriteLine($"[fake-devices] ignorado {Path.GetFileName(file)}: {e.Message}");
            }
        }
        return list;
    }

    private static FakeDevice Parse(string file)
    {
        var root = JsonNode.Parse(File.ReadAllText(file, Encoding.UTF8))!.AsObject();
        var baseDir = Path.GetDirectoryName(file)!;
        string? Str(JsonNode? n, string key) => n?[key]?.GetValue<string>();
        var storages = new List<FakeStorage>();
        foreach (var s in root["storages"]?.AsArray() ?? [])
        {
            var files = new List<FakeFile>();
            foreach (var f in s!["files"]?.AsArray() ?? [])
            {
                var path = Str(f, "path") ?? throw new FormatException("arquivo sem 'path'");
                Func<byte[]> content;
                if (Str(f, "text") is { } text)
                {
                    var bytes = Encoding.UTF8.GetBytes(text);
                    content = () => bytes;
                }
                else if (Str(f, "base64") is { } b64)
                {
                    var bytes = Convert.FromBase64String(b64);
                    content = () => bytes;
                }
                else if (Str(f, "contentFile") is { } cf)
                {
                    var full = Path.IsPathFullyQualified(cf) ? cf : Path.Combine(baseDir, cf);
                    content = () => File.ReadAllBytes(full);
                }
                else
                {
                    throw new FormatException($"'{path}' sem conteúdo (text, base64 ou contentFile)");
                }
                long? modified = Str(f, "modified") is { } m
                    ? DateTimeOffset.Parse(m, System.Globalization.CultureInfo.InvariantCulture).UtcDateTime.ToFileTimeUtc()
                    : new DateTime(2024, 1, 1, 12, 0, 0, DateTimeKind.Utc).ToFileTimeUtc();
                // "modified": null = o aparelho não informa a data.
                if (f!.AsObject().ContainsKey("modified") && f["modified"] is null) modified = null;
                files.Add(new FakeFile(path.Trim('/'), content, modified));
            }
            storages.Add(new FakeStorage(
                Str(s, "name") ?? "Armazenamento interno",
                s["totalBytes"]?.GetValue<ulong>() ?? 64_000_000_000UL,
                s["freeBytes"]?.GetValue<ulong>() ?? 10_000_000_000UL,
                [.. (s["folders"]?.AsArray() ?? []).Select(x => x!.GetValue<string>().Trim('/'))],
                files));
        }
        var faults = root["faults"];
        HashSet<string> Set(string key) => [.. (faults?[key]?.AsArray() ?? []).Select(x => x!.GetValue<string>().Trim('/'))];
        var kind = Str(root, "kind") ?? "android";
        var status = Str(root, "status") ?? "ok";
        var info = new DeviceInfo(
            Str(root, "deviceId") ?? "fake:" + Path.GetFileNameWithoutExtension(file),
            Str(root, "friendlyName") ?? Path.GetFileNameWithoutExtension(file),
            Str(root, "manufacturer"),
            Str(root, "model"),
            Str(root, "serial"),
            kind,
            status,
            [],
            Simulated: true);
        return new FakeDevice(
            file,
            info,
            root["stableIds"]?.GetValue<bool>() ?? false,
            status == "ok" ? storages : [],
            faults?["disconnectAfterListCalls"]?.GetValue<int>(),
            Set("changeDuringRead"),
            Set("folderErrors"),
            faults?["readDelayMs"]?.GetValue<int>() ?? 0);
    }
}
