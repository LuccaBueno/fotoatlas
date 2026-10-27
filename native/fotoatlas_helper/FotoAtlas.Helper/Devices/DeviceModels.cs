namespace FotoAtlas.Helper.Devices;

/// <summary>Armazenamento de um celular (interno, cartão SD…).</summary>
internal sealed record StorageInfo(string StorageId, string Name, ulong? TotalBytes, ulong? FreeBytes);

/// <summary>Dispositivo portátil visto agora (docs/protocolo-helper.md §5.3).</summary>
/// <param name="Kind"><c>android</c>, <c>iphone</c>, <c>camera</c> ou <c>other</c>.</param>
/// <param name="Status"><c>ok</c>, <c>locked</c> ou <c>unauthorized</c>.</param>
internal sealed record DeviceInfo(
    string DeviceId,
    string FriendlyName,
    string? Manufacturer,
    string? Model,
    string? Serial,
    string Kind,
    string Status,
    IReadOnlyList<StorageInfo> Storages,
    bool Simulated = false);

/// <summary>Objeto filho de uma pasta (ou armazenamento) do dispositivo.</summary>
/// <param name="Modified">FILETIME UTC (100 ns desde 1601), ou nulo se o dispositivo não informa.</param>
internal sealed record DeviceEntry(
    string ObjectId,
    string ParentObjectId,
    string Name,
    bool IsFolder,
    long? Size,
    long? Modified,
    long? Created,
    string? PersistentId);

/// <summary>Resultado de <c>devices.hashObject</c>.</summary>
internal sealed record DeviceHashResult(string Sha256Hex, long Size, long? Modified);

/// <summary>
/// Acesso de leitura a dispositivos portáteis. Não há nenhum método que grave,
/// renomeie ou apague no dispositivo (regras 2 e 4).
/// </summary>
internal interface IDeviceBackend
{
    IReadOnlyList<DeviceInfo> List();

    /// <summary>
    /// Filhos diretos de <paramref name="objectId"/>; <c>""</c> = raiz do dispositivo,
    /// cujos filhos são os armazenamentos (como pastas).
    /// </summary>
    void ListChildren(string deviceId, string objectId, Action<IReadOnlyList<DeviceEntry>> onBatch, CancellationToken ct);

    /// <summary>
    /// SHA-256 do conteúdo lido em streaming. Lança <c>changed_during_read</c> se o
    /// tamanho ou a data mudarem durante a leitura, ou se o tamanho não for o esperado.
    /// </summary>
    DeviceHashResult Hash(string deviceId, string objectId, long? expectedSize, Action<long> onProgress, CancellationToken ct);
}

internal static class DeviceKinds
{
    /// <summary>
    /// Pendrives e cartões também aparecem como dispositivos WPD (driver WpdFs).
    /// Eles já são tratados como unidades: ficam fora da lista de celulares.
    /// </summary>
    public static bool IsMassStorage(string pnpId, string? protocol) =>
        (protocol?.StartsWith("MSC", StringComparison.OrdinalIgnoreCase) ?? false) ||
        pnpId.Contains("usbstor", StringComparison.OrdinalIgnoreCase) ||
        pnpId.Contains("storage#volume", StringComparison.OrdinalIgnoreCase) ||
        pnpId.Contains("_??_", StringComparison.OrdinalIgnoreCase);

    /// <summary>Tipo para a interface (o iPhone precisa do aviso "Manter originais").</summary>
    /// <param name="wpdType">WPD_DEVICE_TYPE: 1 câmera, 3 telefone.</param>
    public static string Classify(string? manufacturer, string? model, string? friendlyName, uint? wpdType)
    {
        static bool Has(string? s, string what) => s?.Contains(what, StringComparison.OrdinalIgnoreCase) ?? false;
        if (Has(manufacturer, "Apple") || Has(model, "iPhone") || Has(friendlyName, "iPhone") || Has(model, "iPad")) return "iphone";
        return wpdType switch
        {
            3 => "android",
            1 => "camera",
            _ => "other",
        };
    }

    /// <summary>
    /// Sem armazenamento visível (ou todos com capacidade zero) o celular está
    /// bloqueado ou ainda não autorizou o computador.
    /// </summary>
    public static string StatusFor(string kind, IReadOnlyList<StorageInfo> storages)
    {
        var usable = storages.Any(s => s.TotalBytes is null or > 0);
        if (usable) return "ok";
        return kind == "iphone" ? "unauthorized" : "locked";
    }
}
