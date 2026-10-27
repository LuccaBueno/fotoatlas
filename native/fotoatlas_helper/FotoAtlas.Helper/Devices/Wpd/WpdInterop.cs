using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace FotoAtlas.Helper.Devices.Wpd;

// Interop COM mínimo do Windows Portable Devices (ADR 0012), gerado em tempo de
// compilação (compatível com AOT). A ordem dos métodos segue a vtable dos headers
// do SDK (conferida com portabledeviceapi.idl / portabledevicetypes.idl).
//
// SÓ LEITURA: métodos que gravam, movem ou apagam no dispositivo não são
// declarados. Quando a vtable obriga a ocupar o slot, ele vira um "Reserved_*"
// sem parâmetros, que nunca é chamado (um teste confere os nomes permitidos).

[StructLayout(LayoutKind.Sequential)]
internal struct PropertyKey(Guid fmtId, uint pid)
{
    public Guid FmtId = fmtId;
    public uint Pid = pid;
}

/// <summary>PROPVARIANT: 16 bytes em x86, 24 em x64. Liberar com <see cref="Ole32.PropVariantClear"/>.</summary>
[StructLayout(LayoutKind.Sequential)]
internal struct PropVariant
{
    public ushort Vt;
    public ushort Reserved1;
    public ushort Reserved2;
    public ushort Reserved3;
    public nint A;
    public nint B;
}

[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("a1567595-4c2f-4574-a6fa-ecef917b9a40")]
internal unsafe partial interface IPortableDeviceManager
{
    void GetDevices(char** pnpDeviceIds, ref uint count);
    void RefreshDeviceList();
    void GetDeviceFriendlyName(string pnpDeviceId, char* name, ref uint length);
}

[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("625e2df8-6392-4cf0-9ad1-3cfa5f17775c")]
internal partial interface IPortableDevice
{
    void Open(string pnpDeviceId, IPortableDeviceValues clientInfo);
    void Reserved_SendCommand();
    void Content(out IPortableDeviceContent content);
    void Reserved_Capabilities();
    void Cancel();
    void Close();
}

[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("6a96ed84-7c73-4480-9938-bf5af477d426")]
internal partial interface IPortableDeviceContent
{
    void EnumObjects(uint flags, string parentObjectId, IPortableDeviceValues? filter, out IEnumPortableDeviceObjectIds enumerator);
    void Properties(out IPortableDeviceProperties properties);
    void Transfer(out IPortableDeviceResources resources);
    // Depois daqui: CreateObject*, Delete, Move, Copy — propositalmente ausentes.
}

[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("10ece955-cf41-4728-bfa0-41eedf1bbf19")]
internal unsafe partial interface IEnumPortableDeviceObjectIds
{
    [PreserveSig]
    int Next(uint count, char** objectIds, out uint fetched);
}

[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("7f6d695c-03df-4439-a809-59266beee3a6")]
internal partial interface IPortableDeviceProperties
{
    void Reserved_GetSupportedProperties();
    void Reserved_GetPropertyAttributes();
    void GetValues(string objectId, IPortableDeviceKeyCollection? keys, out IPortableDeviceValues values);
    // Depois daqui: SetValues, Delete — propositalmente ausentes.
}

[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("fd8878ac-d841-4d17-891c-e6829cdb6934")]
internal partial interface IPortableDeviceResources
{
    void Reserved_GetSupportedResources();
    void Reserved_GetResourceAttributes();

    /// <param name="mode">STGM_READ (0). Nenhum outro modo é usado.</param>
    void GetStream(string objectId, in PropertyKey key, uint mode, out uint optimalBufferSize, out ISequentialStreamRead stream);
    // Depois daqui: Delete, CreateResource — propositalmente ausentes.
}

/// <summary>IStream visto só pelo primeiro método (ISequentialStream::Read).</summary>
[GeneratedComInterface]
[Guid("0000000c-0000-0000-C000-000000000046")]
internal unsafe partial interface ISequentialStreamRead
{
    [PreserveSig]
    int Read(byte* buffer, uint count, out uint read);
}

/// <summary>
/// Saco de propriedades em memória (não é o dispositivo): os "Set" daqui só
/// montam parâmetros locais, como as informações do cliente no <c>Open</c>.
/// </summary>
[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("6848f6f2-3155-4f86-b6f5-263eeeab3143")]
internal unsafe partial interface IPortableDeviceValues
{
    void GetCount(out uint count);
    void Reserved_GetAt();
    void SetValue(in PropertyKey key, in PropVariant value);

    [PreserveSig]
    int GetValue(in PropertyKey key, out PropVariant value);
    void SetStringValue(in PropertyKey key, string value);

    [PreserveSig]
    int GetStringValue(in PropertyKey key, out char* value);
    void SetUnsignedIntegerValue(in PropertyKey key, uint value);

    [PreserveSig]
    int GetUnsignedIntegerValue(in PropertyKey key, out uint value);
    void Reserved_SetSignedIntegerValue();
    void Reserved_GetSignedIntegerValue();
    void SetUnsignedLargeIntegerValue(in PropertyKey key, ulong value);

    [PreserveSig]
    int GetUnsignedLargeIntegerValue(in PropertyKey key, out ulong value);
    void Reserved_SetSignedLargeIntegerValue();
    void Reserved_GetSignedLargeIntegerValue();
    void Reserved_SetFloatValue();
    void Reserved_GetFloatValue();
    void Reserved_SetErrorValue();

    [PreserveSig]
    int GetErrorValue(in PropertyKey key, out int hresult);
    void Reserved_SetKeyValue();
    void Reserved_GetKeyValue();
    void SetBoolValue(in PropertyKey key, int value);

    [PreserveSig]
    int GetBoolValue(in PropertyKey key, out int value);
    void Reserved_SetIUnknownValue();
    void Reserved_GetIUnknownValue();
    void SetGuidValue(in PropertyKey key, in Guid value);

    [PreserveSig]
    int GetGuidValue(in PropertyKey key, out Guid value);
}

[GeneratedComInterface]
[Guid("dada2357-e0ad-492e-98db-dd61c53ba353")]
internal partial interface IPortableDeviceKeyCollection
{
    void GetCount(out uint count);
    void GetAt(uint index, out PropertyKey key);
    void Add(in PropertyKey key);
}

internal static partial class Ole32
{
    public const uint ClsctxInprocServer = 0x1;

    [LibraryImport("ole32.dll")]
    public static partial int CoCreateInstance(in Guid clsid, nint outer, uint context, in Guid iid, out nint instance);

    [LibraryImport("ole32.dll")]
    public static partial int PropVariantClear(ref PropVariant value);

    [LibraryImport("ole32.dll")]
    public static partial void CoTaskMemFree(nint pointer);

    private static readonly StrategyBasedComWrappers Wrappers = new();

    /// <summary>Cria um objeto COM em processo e devolve a interface pedida.</summary>
    public static T Create<T>(Guid clsid)
        where T : class
    {
        var iid = typeof(T).GUID;
        var hr = CoCreateInstance(clsid, 0, ClsctxInprocServer, iid, out var pointer);
        if (hr < 0) Marshal.ThrowExceptionForHR(hr);
        try
        {
            return (T)Wrappers.GetOrCreateObjectForComInstance(pointer, CreateObjectFlags.None);
        }
        finally
        {
            Marshal.Release(pointer);
        }
    }
}

internal static class WpdGuids
{
    public static readonly Guid PortableDeviceManager = new("0af10cec-2ecd-4b92-9581-34f6ae0637f3");
    public static readonly Guid PortableDeviceFtm = new("f7c0039a-4762-488a-b4b3-760ef9a1ba9b");
    public static readonly Guid PortableDeviceValues = new("0c15d503-d017-47ce-9016-7b3f978721cc");
    public static readonly Guid PortableDeviceKeyCollection = new("de2d022d-2480-43be-97f0-d1fa2cf98f4f");

    public static readonly Guid ContentTypeFolder = new("27e2e392-a111-48e0-ab0c-e17705a05f85");
    public static readonly Guid ContentTypeFunctionalObject = new("99ed0160-17ff-4c44-9d98-1d7a6f941921");
    public static readonly Guid FunctionalCategoryStorage = new("23f05bbc-15de-4c2a-a55b-a9af5ce412ef");
}

internal static class WpdKeys
{
    private static readonly Guid Object = new("ef6b490d-5cd8-437a-affc-da8b60ee4a3c");
    private static readonly Guid Device = new("26d4979a-e643-4626-9e2b-736dc0c92fdc");
    private static readonly Guid Storage = new("01a3057a-74d6-4e80-bea7-dc4c212ce50a");
    private static readonly Guid Client = new("204d9f0c-2292-4080-9f42-40664e70f859");

    public static readonly PropertyKey ObjectId = new(Object, 2);
    public static readonly PropertyKey ParentId = new(Object, 3);
    public static readonly PropertyKey Name = new(Object, 4);
    public static readonly PropertyKey PersistentUniqueId = new(Object, 5);
    public static readonly PropertyKey ContentType = new(Object, 7);
    public static readonly PropertyKey Size = new(Object, 11);
    public static readonly PropertyKey OriginalFileName = new(Object, 12);
    public static readonly PropertyKey DateCreated = new(Object, 18);
    public static readonly PropertyKey DateModified = new(Object, 19);

    public static readonly PropertyKey DeviceProtocol = new(Device, 6);
    public static readonly PropertyKey DeviceManufacturer = new(Device, 7);
    public static readonly PropertyKey DeviceModel = new(Device, 8);
    public static readonly PropertyKey DeviceSerial = new(Device, 9);
    public static readonly PropertyKey DeviceFriendlyName = new(Device, 12);
    public static readonly PropertyKey DeviceType = new(Device, 15);

    public static readonly PropertyKey StorageCapacity = new(Storage, 4);
    public static readonly PropertyKey StorageFree = new(Storage, 5);
    public static readonly PropertyKey StorageDescription = new(Storage, 7);

    public static readonly PropertyKey FunctionalCategory = new(new Guid("8f052d93-abca-4fc5-a5ac-b01df4dbe598"), 2);
    public static readonly PropertyKey ResourceDefault = new(new Guid("e81e79be-34f0-41bf-b53f-f1a06ae87842"), 0);

    public static readonly PropertyKey ClientName = new(Client, 2);
    public static readonly PropertyKey ClientMajor = new(Client, 3);
    public static readonly PropertyKey ClientMinor = new(Client, 4);
    public static readonly PropertyKey ClientRevision = new(Client, 5);
    public static readonly PropertyKey ClientSecurityQos = new(Client, 8);
    public static readonly PropertyKey ClientDesiredAccess = new(Client, 9);
    public static readonly PropertyKey ClientShareMode = new(Client, 10);
}
