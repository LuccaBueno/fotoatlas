using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;
using System.Security.Cryptography;
using FotoAtlas.Helper.Protocol;

namespace FotoAtlas.Helper.Devices.Wpd;

/// <summary>
/// Celulares e câmeras pelo Windows Portable Devices, só leitura (ADR 0012).
///
/// Cada dispositivo fica aberto (com <c>GENERIC_READ</c>) enquanto aparece na lista,
/// e todas as chamadas a ele passam por um portão próprio: o WPD é serializado por
/// dispositivo. Se o portão está ocupado (ex.: conferindo um vídeo grande),
/// <c>devices.list</c> devolve a última situação conhecida em vez de esperar.
/// </summary>
internal sealed unsafe class WpdBackend : IDeviceBackend
{
    private const string DeviceObjectId = "DEVICE";
    private const uint GenericRead = 0x80000000;
    private const uint FileShareRead = 0x1;
    private const uint FileShareWrite = 0x2;
    private const uint SecurityImpersonation = 0x20000;
    private const uint StgmRead = 0;
    private const int SFalse = 1;

    private readonly Lock _managerLock = new();
    private IPortableDeviceManager? _manager;
    private readonly ConcurrentDictionary<string, Slot> _slots = new(StringComparer.OrdinalIgnoreCase);

    private sealed class Slot
    {
        public readonly SemaphoreSlim Gate = new(1, 1);
        public IPortableDevice? Device;
        public IPortableDeviceContent? Content;
        public IPortableDeviceProperties? Properties;
        public DeviceInfo? Last;

        /// <summary>Pendrive/cartão visto pelo WpdFs: fora da lista.</summary>
        public bool Ignored;
    }

    public IReadOnlyList<DeviceInfo> List()
    {
        var ids = DeviceIds();
        foreach (var gone in _slots.Keys.Where(k => !ids.Contains(k, StringComparer.OrdinalIgnoreCase)).ToList())
        {
            if (_slots.TryRemove(gone, out var slot) && slot.Gate.Wait(0))
            {
                try { CloseSlot(slot); } finally { slot.Gate.Release(); }
            }
        }
        var result = new List<DeviceInfo>();
        foreach (var id in ids)
        {
            var slot = _slots.GetOrAdd(id, _ => new Slot());
            if (slot.Gate.Wait(0))
            {
                try
                {
                    slot.Last = Describe(id, slot);
                }
                catch (Exception e)
                {
                    Console.Error.WriteLine($"[wpd] falha ao descrever um dispositivo: 0x{e.HResult:X8}");
                    CloseSlot(slot);
                    slot.Last = null;
                }
                finally
                {
                    slot.Gate.Release();
                }
            }
            if (!slot.Ignored && slot.Last is not null) result.Add(slot.Last);
        }
        return result;
    }

    public void ListChildren(string deviceId, string objectId, Action<IReadOnlyList<DeviceEntry>> onBatch, CancellationToken ct)
    {
        WithDevice(deviceId, ct, slot =>
        {
            var parent = objectId.Length == 0 ? DeviceObjectId : objectId;
            var keys = KeyCollection(
                WpdKeys.ParentId, WpdKeys.Name, WpdKeys.OriginalFileName, WpdKeys.ContentType, WpdKeys.Size,
                WpdKeys.DateCreated, WpdKeys.DateModified, WpdKeys.PersistentUniqueId, WpdKeys.FunctionalCategory,
                WpdKeys.StorageDescription);
            var batch = new List<DeviceEntry>(200);
            foreach (var childId in EnumChildren(slot.Content!, parent, ct))
            {
                ct.ThrowIfCancellationRequested();
                // Falha ao ler um filho derruba a pasta inteira (vira "erro" no catálogo):
                // pular o filho faria o arquivo parecer ausente (regra 10).
                slot.Properties!.GetValues(childId, keys, out var values);
                try
                {
                    var contentType = GetGuid(values, WpdKeys.ContentType);
                    var isFunctional = contentType == WpdGuids.ContentTypeFunctionalObject;
                    if (parent == DeviceObjectId)
                    {
                        // Na raiz só interessam os armazenamentos.
                        if (GetGuid(values, WpdKeys.FunctionalCategory) != WpdGuids.FunctionalCategoryStorage) continue;
                    }
                    else if (isFunctional)
                    {
                        continue;
                    }
                    var isFolder = isFunctional || contentType == WpdGuids.ContentTypeFolder;
                    var name = parent == DeviceObjectId
                        ? GetString(values, WpdKeys.StorageDescription) ?? GetString(values, WpdKeys.Name) ?? childId
                        : GetString(values, WpdKeys.OriginalFileName) ?? GetString(values, WpdKeys.Name) ?? childId;
                    var size = isFolder ? null : (long?)GetUInt64(values, WpdKeys.Size);
                    batch.Add(new DeviceEntry(
                        childId,
                        objectId,
                        name,
                        isFolder,
                        size,
                        GetDate(values, WpdKeys.DateModified),
                        GetDate(values, WpdKeys.DateCreated),
                        GetString(values, WpdKeys.PersistentUniqueId)));
                }
                finally
                {
                    Release(values);
                }
                if (batch.Count >= 200)
                {
                    onBatch(batch);
                    batch = new List<DeviceEntry>(200);
                }
            }
            if (batch.Count > 0) onBatch(batch);
            Release(keys);
            return 0;
        });
    }

    public DeviceHashResult Hash(string deviceId, string objectId, long? expectedSize, Action<long> onProgress, CancellationToken ct) =>
        WithDevice(deviceId, ct, slot =>
        {
            var before = SizeAndDate(slot, objectId);
            if (expectedSize is not null && before.Size != expectedSize)
            {
                throw new HelperException("changed_during_read", "O arquivo mudou depois do escaneamento. Escaneie de novo.");
            }
            slot.Content!.Transfer(out var resources);
            try
            {
                resources.GetStream(objectId, WpdKeys.ResourceDefault, StgmRead, out var optimal, out var stream);
                using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                long total = 0, lastReport = 0;
                var buffer = new byte[Math.Clamp((int)optimal, 64 * 1024, 4 * 1024 * 1024)];
                try
                {
                    fixed (byte* p = buffer)
                    {
                        while (true)
                        {
                            ct.ThrowIfCancellationRequested();
                            var hr = stream.Read(p, (uint)buffer.Length, out var read);
                            if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                            if (read == 0) break;
                            sha.AppendData(buffer, 0, (int)read);
                            total += read;
                            if (total - lastReport >= 4 * 1024 * 1024)
                            {
                                lastReport = total;
                                onProgress(total);
                            }
                            if (hr == SFalse) break;
                        }
                    }
                }
                finally
                {
                    Release(stream);
                }
                var after = SizeAndDate(slot, objectId);
                if (total != before.Size || after.Size != before.Size || after.Modified != before.Modified)
                {
                    throw new HelperException("changed_during_read", "O arquivo mudou enquanto era lido. Escaneie de novo.");
                }
                return new DeviceHashResult(Convert.ToHexStringLower(sha.GetHashAndReset()), total, before.Modified);
            }
            finally
            {
                Release(resources);
            }
        });

    private (long? Size, long? Modified) SizeAndDate(Slot slot, string objectId)
    {
        var keys = KeyCollection(WpdKeys.Size, WpdKeys.DateModified);
        slot.Properties!.GetValues(objectId, keys, out var values);
        try
        {
            return ((long?)GetUInt64(values, WpdKeys.Size), GetDate(values, WpdKeys.DateModified));
        }
        finally
        {
            Release(values);
            Release(keys);
        }
    }

    private T WithDevice<T>(string deviceId, CancellationToken ct, Func<Slot, T> action)
    {
        if (!_slots.TryGetValue(deviceId, out var slot))
        {
            // Pode ter acabado de conectar: atualiza a lista uma vez.
            if (!DeviceIds().Contains(deviceId, StringComparer.OrdinalIgnoreCase))
            {
                throw new HelperException("device_disconnected", "O dispositivo não está conectado.", retryable: true);
            }
            slot = _slots.GetOrAdd(deviceId, _ => new Slot());
        }
        slot.Gate.Wait(ct);
        try
        {
            EnsureOpen(deviceId, slot);
            if (slot.Ignored) throw new HelperException("not_found", "Este dispositivo não é um celular.");
            return action(slot);
        }
        catch (HelperException)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception e)
        {
            throw Translate(e, deviceId, slot);
        }
        finally
        {
            slot.Gate.Release();
        }
    }

    private HelperException Translate(Exception e, string deviceId, Slot slot)
    {
        var hr = e.HResult;
        // Saiu da lista do Windows? Então foi desconectado, não é erro do arquivo.
        if (!DeviceIds().Contains(deviceId, StringComparer.OrdinalIgnoreCase))
        {
            CloseSlot(slot);
            _slots.TryRemove(deviceId, out _);
            return new HelperException("device_disconnected", "O dispositivo foi desconectado.", retryable: true);
        }
        return (uint)hr switch
        {
            0x80070005 => new HelperException("device_unauthorized", "O dispositivo não autorizou o acesso. Desbloqueie e permita o acesso.", retryable: true),
            0x80070002 or 0x80070003 or 0x80070490 or 0x80070057 => new HelperException("not_found", $"Objeto não encontrado (0x{hr:X8})."),
            0x8007048F or 0x80070015 or 0x8007001F or 0x80010108 or 0x802A0003 => Disconnected(slot, deviceId),
            _ => new HelperException("io_error", $"Erro de leitura no dispositivo (0x{hr:X8}).", retryable: true),
        };
    }

    private HelperException Disconnected(Slot slot, string deviceId)
    {
        CloseSlot(slot);
        _slots.TryRemove(deviceId, out _);
        return new HelperException("device_disconnected", "O dispositivo foi desconectado.", retryable: true);
    }

    private DeviceInfo? Describe(string id, Slot slot)
    {
        try
        {
            EnsureOpen(id, slot);
        }
        catch (Exception e) when ((uint)e.HResult == 0x80070005)
        {
            CloseSlot(slot);
            return new DeviceInfo(id, FriendlyName(id) ?? "Dispositivo", null, null, null, "other", "unauthorized", []);
        }
        if (slot.Ignored) return null;

        var keys = KeyCollection(
            WpdKeys.DeviceFriendlyName, WpdKeys.DeviceManufacturer, WpdKeys.DeviceModel, WpdKeys.DeviceSerial,
            WpdKeys.DeviceType, WpdKeys.DeviceProtocol);
        slot.Properties!.GetValues(DeviceObjectId, keys, out var values);
        string? manufacturer, model, serial, friendly, protocol;
        uint? type;
        try
        {
            manufacturer = GetString(values, WpdKeys.DeviceManufacturer);
            model = GetString(values, WpdKeys.DeviceModel);
            serial = GetString(values, WpdKeys.DeviceSerial);
            friendly = GetString(values, WpdKeys.DeviceFriendlyName);
            protocol = GetString(values, WpdKeys.DeviceProtocol);
            type = GetUInt32(values, WpdKeys.DeviceType);
        }
        finally
        {
            Release(values);
            Release(keys);
        }
        if (DeviceKinds.IsMassStorage(id, protocol))
        {
            slot.Ignored = true;
            CloseSlot(slot);
            return null;
        }

        var storages = new List<StorageInfo>();
        var storageKeys = KeyCollection(WpdKeys.FunctionalCategory, WpdKeys.StorageDescription, WpdKeys.Name, WpdKeys.StorageCapacity, WpdKeys.StorageFree);
        foreach (var childId in EnumChildren(slot.Content!, DeviceObjectId, CancellationToken.None))
        {
            slot.Properties!.GetValues(childId, storageKeys, out var sv);
            try
            {
                if (GetGuid(sv, WpdKeys.FunctionalCategory) != WpdGuids.FunctionalCategoryStorage) continue;
                storages.Add(new StorageInfo(
                    childId,
                    GetString(sv, WpdKeys.StorageDescription) ?? GetString(sv, WpdKeys.Name) ?? childId,
                    GetUInt64(sv, WpdKeys.StorageCapacity),
                    GetUInt64(sv, WpdKeys.StorageFree)));
            }
            finally
            {
                Release(sv);
            }
        }
        Release(storageKeys);
        var name = friendly ?? FriendlyName(id) ?? model ?? "Dispositivo";
        var kind = DeviceKinds.Classify(manufacturer, model, name, type);
        return new DeviceInfo(id, name, manufacturer, model, serial, kind, DeviceKinds.StatusFor(kind, storages), storages);
    }

    private static void EnsureOpen(string id, Slot slot)
    {
        if (slot.Device is not null || slot.Ignored) return;
        var device = Ole32.Create<IPortableDevice>(WpdGuids.PortableDeviceFtm);
        var client = Ole32.Create<IPortableDeviceValues>(WpdGuids.PortableDeviceValues);
        client.SetStringValue(WpdKeys.ClientName, "FotoAtlas");
        client.SetUnsignedIntegerValue(WpdKeys.ClientMajor, 0);
        client.SetUnsignedIntegerValue(WpdKeys.ClientMinor, 3);
        client.SetUnsignedIntegerValue(WpdKeys.ClientRevision, 0);
        client.SetUnsignedIntegerValue(WpdKeys.ClientSecurityQos, SecurityImpersonation);
        // Só leitura (regra 2): o driver recusa qualquer gravação nesta sessão.
        client.SetUnsignedIntegerValue(WpdKeys.ClientDesiredAccess, GenericRead);
        client.SetUnsignedIntegerValue(WpdKeys.ClientShareMode, FileShareRead | FileShareWrite);
        try
        {
            device.Open(id, client);
        }
        catch
        {
            Release(device);
            throw;
        }
        finally
        {
            Release(client);
        }
        device.Content(out var content);
        content.Properties(out var properties);
        slot.Device = device;
        slot.Content = content;
        slot.Properties = properties;
    }

    private static void CloseSlot(Slot slot)
    {
        try { slot.Device?.Close(); } catch { /* já desconectado */ }
        Release(slot.Properties);
        Release(slot.Content);
        Release(slot.Device);
        slot.Device = null;
        slot.Content = null;
        slot.Properties = null;
    }

    private static List<string> EnumChildren(IPortableDeviceContent content, string parent, CancellationToken ct)
    {
        content.EnumObjects(0, parent, null, out var enumerator);
        var result = new List<string>();
        try
        {
            const int chunk = 64;
            var ids = new nint[chunk];
            while (true)
            {
                ct.ThrowIfCancellationRequested();
                uint fetched;
                int hr;
                fixed (nint* p = ids)
                {
                    hr = enumerator.Next(chunk, (char**)p, out fetched);
                }
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                for (var i = 0; i < fetched; i++)
                {
                    result.Add(Marshal.PtrToStringUni(ids[i])!);
                    Ole32.CoTaskMemFree(ids[i]);
                }
                if (hr == SFalse || fetched == 0) break;
            }
        }
        finally
        {
            Release(enumerator);
        }
        return result;
    }

    private List<string> DeviceIds()
    {
        lock (_managerLock)
        {
            _manager ??= Ole32.Create<IPortableDeviceManager>(WpdGuids.PortableDeviceManager);
            _manager.RefreshDeviceList();
            uint count = 0;
            _manager.GetDevices(null, ref count);
            if (count == 0) return [];
            var ptrs = new nint[count];
            fixed (nint* p = ptrs)
            {
                _manager.GetDevices((char**)p, ref count);
            }
            var list = new List<string>((int)count);
            for (var i = 0; i < count; i++)
            {
                list.Add(Marshal.PtrToStringUni(ptrs[i])!);
                Ole32.CoTaskMemFree(ptrs[i]);
            }
            return list;
        }
    }

    private string? FriendlyName(string id)
    {
        lock (_managerLock)
        {
            try
            {
                uint length = 0;
                _manager!.GetDeviceFriendlyName(id, null, ref length);
                if (length == 0) return null;
                var buffer = new char[length];
                fixed (char* p = buffer)
                {
                    _manager.GetDeviceFriendlyName(id, p, ref length);
                }
                var text = new string(buffer).TrimEnd('\0');
                return text.Length == 0 ? null : text;
            }
            catch
            {
                return null;
            }
        }
    }

    internal static IPortableDeviceKeyCollection KeyCollection(params PropertyKey[] keys)
    {
        var collection = Ole32.Create<IPortableDeviceKeyCollection>(WpdGuids.PortableDeviceKeyCollection);
        foreach (var k in keys) collection.Add(k);
        return collection;
    }

    internal static string? GetString(IPortableDeviceValues values, PropertyKey key)
    {
        if (values.GetStringValue(key, out var p) < 0 || p == null) return null;
        try
        {
            var s = new string(p);
            return string.IsNullOrWhiteSpace(s) ? null : s;
        }
        finally
        {
            Ole32.CoTaskMemFree((nint)p);
        }
    }

    internal static ulong? GetUInt64(IPortableDeviceValues values, PropertyKey key) =>
        values.GetUnsignedLargeIntegerValue(key, out var v) < 0 ? null : v;

    internal static uint? GetUInt32(IPortableDeviceValues values, PropertyKey key) =>
        values.GetUnsignedIntegerValue(key, out var v) < 0 ? null : v;

    internal static Guid? GetGuid(IPortableDeviceValues values, PropertyKey key) =>
        values.GetGuidValue(key, out var v) < 0 ? null : v;

    /// <summary>Data do WPD (VT_DATE em hora local do aparelho, ou VT_FILETIME) como FILETIME UTC.</summary>
    internal static long? GetDate(IPortableDeviceValues values, PropertyKey key)
    {
        if (values.GetValue(key, out var pv) < 0) return null;
        try
        {
            var payload = (byte*)&pv + 8;
            switch (pv.Vt)
            {
                case 7: // VT_DATE
                    var oa = *(double*)payload;
                    if (oa is < -657434 or > 2958465 || double.IsNaN(oa)) return null;
                    var local = DateTime.SpecifyKind(DateTime.FromOADate(oa), DateTimeKind.Local);
                    return local.Year < 1601 ? null : local.ToFileTime();
                case 64: // VT_FILETIME
                    return *(long*)payload;
                default:
                    return null;
            }
        }
        finally
        {
            Ole32.PropVariantClear(ref pv);
        }
    }

    /// <summary>Libera já o objeto COM (o MTP aceita uma transferência por vez).</summary>
    internal static void Release(object? com)
    {
        if (com is ComObject c) c.FinalRelease();
    }
}
