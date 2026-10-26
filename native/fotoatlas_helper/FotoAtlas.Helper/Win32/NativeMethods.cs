using System.Runtime.InteropServices;

namespace FotoAtlas.Helper.Win32;

/// <summary>P/Invoke mínimo para volumes e discos. Nenhuma função aqui grava em disco.</summary>
internal static unsafe partial class NativeMethods
{
    public const uint OpenExisting = 3;
    public const uint FileShareRead = 0x1;
    public const uint FileShareWrite = 0x2;
    public const uint IoctlVolumeGetVolumeDiskExtents = 0x00560000;
    public const uint IoctlStorageQueryProperty = 0x002D1400;
    public const uint IoctlDiskGetDriveGeometryEx = 0x000700A0;
    public const int ErrorMoreData = 234;
    public const int ErrorNoMoreFiles = 18;

    public static readonly nint InvalidHandle = -1;

    [LibraryImport("kernel32.dll", EntryPoint = "FindFirstVolumeW", SetLastError = true)]
    public static partial nint FindFirstVolume(char* volumeName, uint bufferLength);

    [LibraryImport("kernel32.dll", EntryPoint = "FindNextVolumeW", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool FindNextVolume(nint findVolume, char* volumeName, uint bufferLength);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool FindVolumeClose(nint findVolume);

    [LibraryImport("kernel32.dll", EntryPoint = "GetVolumePathNamesForVolumeNameW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetVolumePathNamesForVolumeName(string volumeName, char* volumePathNames, uint bufferLength, out uint returnLength);

    [LibraryImport("kernel32.dll", EntryPoint = "GetVolumeInformationW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetVolumeInformation(
        string rootPathName,
        char* volumeNameBuffer,
        uint volumeNameSize,
        out uint volumeSerialNumber,
        out uint maximumComponentLength,
        out uint fileSystemFlags,
        char* fileSystemNameBuffer,
        uint fileSystemNameSize);

    [LibraryImport("kernel32.dll", EntryPoint = "GetDiskFreeSpaceExW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetDiskFreeSpaceEx(string directoryName, out ulong freeBytesAvailable, out ulong totalBytes, out ulong totalFreeBytes);

    [LibraryImport("kernel32.dll", EntryPoint = "GetDriveTypeW", StringMarshalling = StringMarshalling.Utf16)]
    public static partial uint GetDriveType(string rootPathName);

    [LibraryImport("kernel32.dll", EntryPoint = "CreateFileW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint CreateFile(string fileName, uint desiredAccess, uint shareMode, nint securityAttributes, uint creationDisposition, uint flagsAndAttributes, nint templateFile);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool CloseHandle(nint handle);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool DeviceIoControl(nint device, uint ioControlCode, void* inBuffer, uint inBufferSize, void* outBuffer, uint outBufferSize, out uint bytesReturned, nint overlapped);
}
