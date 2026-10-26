using System.Runtime.InteropServices;
using System.Text;
using FotoAtlas.Helper.Win32;

namespace FotoAtlas.Helper.Volumes;

internal sealed record PhysicalDiskInfo(
    int DiskNumber,
    string? Serial,
    string? Model,
    long? SizeBytes,
    string BusType,
    bool RemovableMedia,
    string IdentityConfidence);

internal sealed record VolumeInfo(
    string GuidPath,
    IReadOnlyList<string> MountPoints,
    string? Label,
    string? FileSystem,
    uint? Serial,
    ulong? TotalBytes,
    ulong? FreeBytes,
    string DriveType,
    bool IsSystem,
    bool IsBoot,
    IReadOnlyList<PhysicalDiskInfo> PhysicalDisks);

internal interface IVolumeSource
{
    IReadOnlyList<VolumeInfo> List();
}

/// <summary>Lista volumes e discos físicos via Win32 (somente leitura, sem exigir admin).</summary>
internal sealed unsafe class VolumeEnumerator : IVolumeSource
{
    public IReadOnlyList<VolumeInfo> List()
    {
        var guids = EnumerateVolumeGuids();
        var diskCache = new Dictionary<int, RawDisk>();
        var bootRoot = Path.GetPathRoot(Environment.SystemDirectory) ?? "C:\\";
        var raw = new List<(string Guid, List<string> Mounts, VolumeBasics Basics, List<int> Disks)>();

        foreach (var guid in guids)
        {
            var mounts = GetMountPoints(guid);
            var basics = GetBasics(guid);
            var disks = GetDiskNumbers(guid);
            foreach (var n in disks)
            {
                if (!diskCache.ContainsKey(n)) diskCache[n] = QueryDisk(n);
            }
            raw.Add((guid, mounts, basics, disks));
        }

        var serialCounts = diskCache.Values
            .Where(d => !string.IsNullOrEmpty(d.Serial))
            .GroupBy(d => d.Serial!)
            .ToDictionary(g => g.Key, g => g.Count());

        var result = new List<VolumeInfo>();
        foreach (var (guid, mounts, basics, disks) in raw)
        {
            var physical = disks
                .Select(n => diskCache[n])
                .Select(d => new PhysicalDiskInfo(
                    d.Number,
                    d.Serial,
                    d.Model,
                    d.SizeBytes,
                    d.BusType,
                    d.Removable,
                    DiskIdentity.Classify(d.Serial, d.Model, d.SizeBytes, d.Serial is null ? 0 : serialCounts.GetValueOrDefault(d.Serial))))
                .ToList();
            var isBoot = mounts.Any(m => string.Equals(m, bootRoot, StringComparison.OrdinalIgnoreCase));
            // Heurística: volume sem ponto de montagem e pequeno = EFI/Recuperação.
            var isSystem = mounts.Count == 0 && (basics.Total ?? 0) < 2UL * 1024 * 1024 * 1024;
            result.Add(new VolumeInfo(
                guid, mounts, basics.Label, basics.FileSystem, basics.Serial,
                basics.Total, basics.Free, basics.DriveType, isSystem, isBoot, physical));
        }
        return result;
    }

    private static List<string> EnumerateVolumeGuids()
    {
        var list = new List<string>();
        var buffer = stackalloc char[1024];
        var handle = NativeMethods.FindFirstVolume(buffer, 1024);
        if (handle == NativeMethods.InvalidHandle) return list;
        try
        {
            do
            {
                list.Add(new string(buffer));
            } while (NativeMethods.FindNextVolume(handle, buffer, 1024));
        }
        finally
        {
            NativeMethods.FindVolumeClose(handle);
        }
        return list;
    }

    private static List<string> GetMountPoints(string guid)
    {
        uint size = 512;
        while (true)
        {
            var buffer = new char[size];
            fixed (char* p = buffer)
            {
                if (NativeMethods.GetVolumePathNamesForVolumeName(guid, p, size, out var needed))
                {
                    return ParseMultiSz(buffer);
                }
                if (Marshal.GetLastPInvokeError() != NativeMethods.ErrorMoreData || needed <= size) return [];
                size = needed;
            }
        }
    }

    internal static List<string> ParseMultiSz(ReadOnlySpan<char> buffer)
    {
        var list = new List<string>();
        var start = 0;
        for (var i = 0; i < buffer.Length; i++)
        {
            if (buffer[i] != '\0') continue;
            if (i == start) break;
            list.Add(new string(buffer[start..i]));
            start = i + 1;
        }
        return list;
    }

    private readonly record struct VolumeBasics(string? Label, string? FileSystem, uint? Serial, ulong? Total, ulong? Free, string DriveType);

    private static VolumeBasics GetBasics(string guid)
    {
        string? label = null, fs = null;
        uint? serial = null;
        ulong? total = null, free = null;
        var labelBuf = stackalloc char[261];
        var fsBuf = stackalloc char[261];
        if (NativeMethods.GetVolumeInformation(guid, labelBuf, 261, out var s, out _, out _, fsBuf, 261))
        {
            label = new string(labelBuf);
            fs = new string(fsBuf);
            serial = s;
        }
        if (NativeMethods.GetDiskFreeSpaceEx(guid, out var avail, out var tot, out _))
        {
            total = tot;
            free = avail;
        }
        var driveType = NativeMethods.GetDriveType(guid) switch
        {
            2 => "removable",
            3 => "fixed",
            4 => "network",
            5 => "cdrom",
            6 => "ram",
            _ => "unknown",
        };
        return new VolumeBasics(label, fs, serial, total, free, driveType);
    }

    private static List<int> GetDiskNumbers(string guid)
    {
        // CreateFile exige o caminho do volume sem a barra final.
        var handle = NativeMethods.CreateFile(guid.TrimEnd('\\'), 0, NativeMethods.FileShareRead | NativeMethods.FileShareWrite, 0, NativeMethods.OpenExisting, 0, 0);
        if (handle == NativeMethods.InvalidHandle) return [];
        try
        {
            const int size = 8 + 24 * 32;
            var buffer = stackalloc byte[size];
            if (!NativeMethods.DeviceIoControl(handle, NativeMethods.IoctlVolumeGetVolumeDiskExtents, null, 0, buffer, size, out _, 0))
            {
                return [];
            }
            var count = *(uint*)buffer;
            var list = new List<int>();
            for (var i = 0; i < count && i < 32; i++)
            {
                list.Add((int)*(uint*)(buffer + 8 + 24 * i));
            }
            return list.Distinct().ToList();
        }
        finally
        {
            NativeMethods.CloseHandle(handle);
        }
    }

    private sealed record RawDisk(int Number, string? Serial, string? Model, long? SizeBytes, string BusType, bool Removable);

    private static RawDisk QueryDisk(int number)
    {
        var handle = NativeMethods.CreateFile($"\\\\.\\PhysicalDrive{number}", 0, NativeMethods.FileShareRead | NativeMethods.FileShareWrite, 0, NativeMethods.OpenExisting, 0, 0);
        if (handle == NativeMethods.InvalidHandle) return new RawDisk(number, null, null, null, "unknown", false);
        try
        {
            string? serial = null, model = null;
            var bus = "unknown";
            var removable = false;
            long? sizeBytes = null;

            var query = stackalloc byte[12]; // STORAGE_PROPERTY_QUERY: PropertyId=0, QueryType=0
            const int outSize = 4096;
            var desc = stackalloc byte[outSize];
            if (NativeMethods.DeviceIoControl(handle, NativeMethods.IoctlStorageQueryProperty, query, 12, desc, outSize, out var got, 0) && got >= 32)
            {
                removable = desc[10] != 0;
                // STORAGE_DEVICE_DESCRIPTOR: VendorIdOffset @12, ProductIdOffset @16,
                // SerialNumberOffset @24, BusType @28.
                var vendor = ReadAnsi(desc, got, *(uint*)(desc + 12));
                var product = ReadAnsi(desc, got, *(uint*)(desc + 16));
                serial = ReadAnsi(desc, got, *(uint*)(desc + 24));
                model = string.Join(' ', new[] { vendor, product }.Where(s => !string.IsNullOrWhiteSpace(s)));
                if (model.Length == 0) model = null;
                bus = BusTypeName(*(uint*)(desc + 28));
            }

            const int geoSize = 256;
            var geo = stackalloc byte[geoSize];
            if (NativeMethods.DeviceIoControl(handle, NativeMethods.IoctlDiskGetDriveGeometryEx, null, 0, geo, geoSize, out var geoGot, 0) && geoGot >= 32)
            {
                sizeBytes = *(long*)(geo + 24);
            }
            return new RawDisk(number, serial, model, sizeBytes, bus, removable);
        }
        finally
        {
            NativeMethods.CloseHandle(handle);
        }
    }

    private static string? ReadAnsi(byte* buffer, uint length, uint offset)
    {
        if (offset == 0 || offset >= length) return null;
        var end = offset;
        while (end < length && buffer[end] != 0) end++;
        var text = Encoding.ASCII.GetString(buffer + offset, (int)(end - offset)).Trim();
        return text.Length == 0 ? null : text;
    }

    internal static string BusTypeName(uint value) => value switch
    {
        1 => "scsi",
        2 => "atapi",
        3 => "ata",
        4 => "1394",
        7 => "usb",
        8 => "raid",
        9 => "iscsi",
        10 => "sas",
        11 => "sata",
        12 => "sd",
        13 => "mmc",
        14 => "virtual",
        15 => "file_backed_virtual",
        16 => "spaces",
        17 => "nvme",
        18 => "scm",
        19 => "ufs",
        _ => "unknown",
    };
}

internal static class DiskIdentity
{
    /// <summary>
    /// reliable = serial presente, sem cara de placeholder e único entre os discos conectados;
    /// weak = sem serial confiável, mas com modelo e tamanho; unknown = nada útil (R1, ADR 0009).
    /// </summary>
    public static string Classify(string? serial, string? model, long? sizeBytes, int sameSerialCount)
    {
        if (IsPlausibleSerial(serial) && sameSerialCount <= 1) return "reliable";
        if (!string.IsNullOrWhiteSpace(model) && sizeBytes is > 0) return "weak";
        return "unknown";
    }

    public static bool IsPlausibleSerial(string? serial)
    {
        if (string.IsNullOrWhiteSpace(serial)) return false;
        var s = serial.Trim();
        if (s.Length < 4) return false;
        // Só zeros, espaços, sublinhados, pontos ou "F" repetidos são placeholders comuns de pontes USB.
        if (s.All(c => c is '0' or ' ' or '_' or '.' or '-')) return false;
        if (s.All(c => c is 'F' or 'f')) return false;
        if (s.Distinct().Count() == 1) return false;
        // Seriais quase todos zero (ex.: EUI-64 de alguns NVMe: "0000_0000_..._0100_...") não identificam o disco.
        var alnum = s.Where(char.IsLetterOrDigit).ToList();
        if (alnum.Count == 0 || alnum.Count(c => c == '0') * 10 >= alnum.Count * 8) return false;
        return true;
    }
}
