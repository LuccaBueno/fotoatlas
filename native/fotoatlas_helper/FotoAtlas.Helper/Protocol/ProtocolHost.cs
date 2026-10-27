using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;
using FotoAtlas.Helper.Devices;
using FotoAtlas.Helper.Volumes;

namespace FotoAtlas.Helper.Protocol;

/// <summary>Erro de protocolo com código estável (docs/protocolo-helper.md §4).</summary>
internal sealed class HelperException(string code, string message, bool retryable = false) : Exception(message)
{
    public string Code { get; } = code;
    public bool Retryable { get; } = retryable;
}

/// <summary>Host JSON-lines: lê pedidos de <c>input</c>, escreve respostas e eventos em <c>output</c>.</summary>
internal sealed class ProtocolHost(TextReader input, TextWriter output, IVolumeSource volumes, TextWriter? log = null, IDeviceBackend? devices = null)
{
    public const int ProtocolVersion = 1;
    public const int MaxLineLength = 1 << 20;
    public static readonly string HelperVersion =
        typeof(ProtocolHost).Assembly.GetName().Version?.ToString(3) ?? "0.0.0";

    private readonly Lock _writeLock = new();
    private readonly ConcurrentDictionary<string, CancellationTokenSource> _inflight = new();
    private readonly Stopwatch _uptime = Stopwatch.StartNew();
    private readonly TaskCompletionSource _shutdown = new(TaskCreationOptions.RunContinuationsAsynchronously);

    /// <summary>Completa quando chega <c>system.shutdown</c>.</summary>
    public Task ShutdownRequested => _shutdown.Task;

    public async Task RunAsync()
    {
        Emit(new JsonObject
        {
            ["v"] = ProtocolVersion,
            ["event"] = "hello",
            ["data"] = new JsonObject
            {
                ["protocol"] = ProtocolVersion,
                ["helperVersion"] = HelperVersion,
                ["pid"] = Environment.ProcessId,
            },
        });

        var running = new List<Task>();
        while (!_shutdown.Task.IsCompleted)
        {
            var line = await input.ReadLineAsync();
            if (line is null) break; // EOF: o processo pai fechou o stdin.
            if (line.Length == 0) continue;
            running.Add(HandleLineAsync(line));
            running.RemoveAll(t => t.IsCompleted);
        }
        await Task.WhenAll(running);
    }

    private async Task HandleLineAsync(string line)
    {
        string? id = null;
        try
        {
            if (line.Length > MaxLineLength) throw new HelperException("bad_request", "Linha excede 1 MiB.");
            JsonObject request;
            try
            {
                request = JsonNode.Parse(line) as JsonObject ?? throw new HelperException("bad_request", "Mensagem não é um objeto JSON.");
            }
            catch (JsonException e)
            {
                throw new HelperException("bad_request", $"JSON inválido: {e.Message}");
            }
            id = request["id"]?.GetValueKind() == JsonValueKind.String ? request["id"]!.GetValue<string>() : null;
            if (id is null) throw new HelperException("bad_request", "Campo 'id' (string) ausente.");
            if (request["v"]?.GetValueKind() != JsonValueKind.Number || request["v"]!.GetValue<int>() != ProtocolVersion)
            {
                throw new HelperException("bad_request", $"Versão de envelope não suportada (esperado v={ProtocolVersion}).");
            }
            var method = request["method"]?.GetValueKind() == JsonValueKind.String ? request["method"]!.GetValue<string>() : null;
            var parameters = request["params"] as JsonObject ?? [];

            using var cts = new CancellationTokenSource();
            if (!_inflight.TryAdd(id, cts)) throw new HelperException("bad_request", $"id '{id}' já está em uso.");
            try
            {
                var result = await DispatchAsync(id, method, parameters, cts.Token);
                Emit(new JsonObject { ["v"] = ProtocolVersion, ["id"] = id, ["ok"] = true, ["result"] = result });
            }
            finally
            {
                _inflight.TryRemove(id, out _);
            }
            if (method == "system.shutdown") _shutdown.TrySetResult();
        }
        catch (HelperException e)
        {
            EmitError(id, e.Code, e.Message, e.Retryable);
        }
        catch (OperationCanceledException)
        {
            EmitError(id, "cancelled", "Cancelado a pedido.", false);
        }
        catch (Exception e)
        {
            log?.WriteLine($"[helper] erro interno: {e}");
            EmitError(id, "internal", e.Message, true);
        }
    }

    private async Task<JsonNode> DispatchAsync(string id, string? method, JsonObject parameters, CancellationToken ct)
    {
        switch (method)
        {
            case "system.ping":
                return new JsonObject { ["uptimeMs"] = _uptime.ElapsedMilliseconds };
            case "system.info":
                return new JsonObject
                {
                    ["helperVersion"] = HelperVersion,
                    ["protocol"] = ProtocolVersion,
                    ["os"] = Environment.OSVersion.Version.ToString(),
                };
            case "system.cancel":
                var target = parameters["target"]?.GetValueKind() == JsonValueKind.String ? parameters["target"]!.GetValue<string>() : null;
                if (target is null) throw new HelperException("bad_request", "Parâmetro 'target' ausente.");
                if (_inflight.TryGetValue(target, out var other)) await other.CancelAsync();
                return new JsonObject();
            case "system.shutdown":
                return new JsonObject();
            case "volumes.list":
                var list = await Task.Run(volumes.List, ct);
                ct.ThrowIfCancellationRequested();
                return new JsonObject { ["volumes"] = VolumeJson.ToJson(list) };
            case "devices.list":
                var found = await Task.Run(Devices.List, ct);
                ct.ThrowIfCancellationRequested();
                return new JsonObject { ["devices"] = DeviceJson.ToJson(found) };
            case "devices.listChildren":
                return await ListChildrenAsync(id, parameters, ct);
            case "devices.hashObject":
                return await HashObjectAsync(id, parameters, ct);
            default:
                throw new HelperException("bad_request", $"Método desconhecido: '{method}'.");
        }
    }

    private IDeviceBackend Devices =>
        devices ?? throw new HelperException("not_found", "Leitura de celulares indisponível neste helper.");

    private static string RequiredString(JsonObject parameters, string name, bool allowEmpty = false)
    {
        var node = parameters[name];
        if (node?.GetValueKind() != JsonValueKind.String) throw new HelperException("bad_request", $"Parâmetro '{name}' (string) ausente.");
        var value = node.GetValue<string>();
        if (!allowEmpty && value.Length == 0) throw new HelperException("bad_request", $"Parâmetro '{name}' vazio.");
        return value;
    }

    private async Task<JsonNode> ListChildrenAsync(string id, JsonObject parameters, CancellationToken ct)
    {
        var deviceId = RequiredString(parameters, "deviceId");
        var objectId = RequiredString(parameters, "objectId", allowEmpty: true);
        var count = 0;
        await Task.Run(() => Devices.ListChildren(deviceId, objectId, batch =>
        {
            count += batch.Count;
            Emit(new JsonObject
            {
                ["v"] = ProtocolVersion,
                ["id"] = id,
                ["event"] = "entries",
                ["data"] = new JsonObject { ["items"] = DeviceJson.ToJson(batch) },
            });
        }, ct), ct);
        return new JsonObject { ["count"] = count };
    }

    private async Task<JsonNode> HashObjectAsync(string id, JsonObject parameters, CancellationToken ct)
    {
        var deviceId = RequiredString(parameters, "deviceId");
        var objectId = RequiredString(parameters, "objectId");
        long? expected = parameters["expectedSize"]?.GetValueKind() == JsonValueKind.Number ? parameters["expectedSize"]!.GetValue<long>() : null;
        var result = await Task.Run(() => Devices.Hash(deviceId, objectId, expected, bytes => Emit(new JsonObject
        {
            ["v"] = ProtocolVersion,
            ["id"] = id,
            ["event"] = "progress",
            ["data"] = new JsonObject { ["bytes"] = bytes },
        }), ct), ct);
        return new JsonObject
        {
            ["sha256"] = result.Sha256Hex,
            ["size"] = result.Size,
            ["modified"] = result.Modified?.ToString(System.Globalization.CultureInfo.InvariantCulture),
        };
    }

    private void EmitError(string? id, string code, string message, bool retryable) =>
        Emit(new JsonObject
        {
            ["v"] = ProtocolVersion,
            ["id"] = id,
            ["ok"] = false,
            ["error"] = new JsonObject { ["code"] = code, ["message"] = message, ["retryable"] = retryable },
        });

    private void Emit(JsonObject message)
    {
        var text = message.ToJsonString();
        lock (_writeLock)
        {
            output.Write(text);
            output.Write('\n');
            output.Flush();
        }
    }
}

internal static class VolumeJson
{
    public static JsonArray ToJson(IReadOnlyList<VolumeInfo> volumes)
    {
        var array = new JsonArray();
        foreach (var v in volumes)
        {
            var mounts = new JsonArray();
            foreach (var m in v.MountPoints) mounts.Add((JsonNode?)JsonValue.Create(m));
            var disks = new JsonArray();
            foreach (var d in v.PhysicalDisks)
            {
                disks.Add((JsonNode)new JsonObject
                {
                    ["diskNumber"] = d.DiskNumber,
                    ["serial"] = d.Serial,
                    ["model"] = d.Model,
                    ["sizeBytes"] = d.SizeBytes,
                    ["busType"] = d.BusType,
                    ["removableMedia"] = d.RemovableMedia,
                    ["identityConfidence"] = d.IdentityConfidence,
                });
            }
            array.Add((JsonNode)new JsonObject
            {
                ["guidPath"] = v.GuidPath,
                ["mountPoints"] = mounts,
                ["label"] = v.Label,
                ["fileSystem"] = v.FileSystem,
                ["serial"] = v.Serial,
                ["totalBytes"] = v.TotalBytes,
                ["freeBytes"] = v.FreeBytes,
                ["driveType"] = v.DriveType,
                ["isSystem"] = v.IsSystem,
                ["isBoot"] = v.IsBoot,
                ["physicalDisks"] = disks,
            });
        }
        return array;
    }
}

internal static class DeviceJson
{
    private static string? FileTime(long? value) => value?.ToString(System.Globalization.CultureInfo.InvariantCulture);

    public static JsonArray ToJson(IReadOnlyList<DeviceInfo> devices)
    {
        var array = new JsonArray();
        foreach (var d in devices)
        {
            var storages = new JsonArray();
            foreach (var s in d.Storages)
            {
                storages.Add((JsonNode)new JsonObject
                {
                    ["storageId"] = s.StorageId,
                    ["name"] = s.Name,
                    ["totalBytes"] = s.TotalBytes,
                    ["freeBytes"] = s.FreeBytes,
                });
            }
            array.Add((JsonNode)new JsonObject
            {
                ["deviceId"] = d.DeviceId,
                ["friendlyName"] = d.FriendlyName,
                ["manufacturer"] = d.Manufacturer,
                ["model"] = d.Model,
                ["serial"] = d.Serial,
                ["kind"] = d.Kind,
                ["status"] = d.Status,
                ["simulated"] = d.Simulated,
                ["storages"] = storages,
            });
        }
        return array;
    }

    public static JsonArray ToJson(IReadOnlyList<DeviceEntry> entries)
    {
        var array = new JsonArray();
        foreach (var e in entries)
        {
            array.Add((JsonNode)new JsonObject
            {
                ["objectId"] = e.ObjectId,
                ["parentObjectId"] = e.ParentObjectId,
                ["name"] = e.Name,
                ["isFolder"] = e.IsFolder,
                ["size"] = e.Size,
                ["modified"] = FileTime(e.Modified),
                ["created"] = FileTime(e.Created),
                ["persistentId"] = e.PersistentId,
            });
        }
        return array;
    }
}
