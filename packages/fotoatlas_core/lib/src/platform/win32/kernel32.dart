// Bindings FFI mínimos do kernel32 (ADR 0008). Somente o necessário, revisável
// em um só lugar. Nenhuma função de escrita é exposta nesta fase.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

const int invalidHandleValue = -1;

// Erros Win32 usados pelo core.
const int errorFileNotFound = 2;
const int errorPathNotFound = 3;
const int errorAccessDenied = 5;
const int errorInvalidDrive = 15;
const int errorNoMoreFiles = 18;
const int errorNotReady = 21;
const int errorDevNotExist = 55;
const int errorBadNetPath = 53;
const int errorMoreData = 234;
const int errorFilenameExcedRange = 206;

// Atributos de arquivo.
const int fileAttributeHidden = 0x2;
const int fileAttributeSystem = 0x4;
const int fileAttributeDirectory = 0x10;
const int fileAttributeReparsePoint = 0x400;
const int fileAttributeOffline = 0x1000;
const int fileAttributeRecallOnOpen = 0x40000;
const int fileAttributeRecallOnDataAccess = 0x400000;

// Tags de reparse point.
const int ioReparseTagMountPoint = 0xA0000003; // junction / ponto de montagem
const int ioReparseTagSymlink = 0xA000000C;
const int ioReparseTagCloudMask = 0xFFFF0FFF;
const int ioReparseTagCloud = 0x9000001A; // CLOUD, CLOUD_1..CLOUD_F

const int findExInfoBasic = 1;
const int findExSearchNameMatch = 0;
const int findFirstExLargeFetch = 2;

/// Tamanho de WIN32_FIND_DATAW.
const int win32FindDataSize = 592;

typedef _FindFirstFileExNative = IntPtr Function(Pointer<Utf16>, Int32, Pointer<Uint8>, Int32, Pointer<Void>, Uint32);
typedef _FindFirstFileExDart = int Function(Pointer<Utf16>, int, Pointer<Uint8>, int, Pointer<Void>, int);

final findFirstFileEx = _kernel32.lookupFunction<_FindFirstFileExNative, _FindFirstFileExDart>(
  'FindFirstFileExW',
  isLeaf: true,
);

final findNextFile = _kernel32
    .lookupFunction<Int32 Function(IntPtr, Pointer<Uint8>), int Function(int, Pointer<Uint8>)>(
      'FindNextFileW',
      isLeaf: true,
    );

final findClose = _kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('FindClose', isLeaf: true);

final getLastError = _kernel32.lookupFunction<Uint32 Function(), int Function()>('GetLastError', isLeaf: true);

final getVolumePathName = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
      int Function(Pointer<Utf16>, Pointer<Utf16>, int)
    >('GetVolumePathNameW', isLeaf: true);

final getVolumeNameForVolumeMountPoint = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
      int Function(Pointer<Utf16>, Pointer<Utf16>, int)
    >('GetVolumeNameForVolumeMountPointW', isLeaf: true);

final getVolumePathNamesForVolumeName = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32, Pointer<Uint32>),
      int Function(Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Uint32>)
    >('GetVolumePathNamesForVolumeNameW', isLeaf: true);

final findFirstVolume = _kernel32
    .lookupFunction<IntPtr Function(Pointer<Utf16>, Uint32), int Function(Pointer<Utf16>, int)>(
      'FindFirstVolumeW',
      isLeaf: true,
    );

final findNextVolume = _kernel32
    .lookupFunction<Int32 Function(IntPtr, Pointer<Utf16>, Uint32), int Function(int, Pointer<Utf16>, int)>(
      'FindNextVolumeW',
      isLeaf: true,
    );

final findVolumeClose = _kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
  'FindVolumeClose',
  isLeaf: true,
);

final getVolumeInformation = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Pointer<Utf16>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Utf16>,
        Uint32,
      ),
      int Function(
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Utf16>,
        int,
      )
    >('GetVolumeInformationW', isLeaf: true);

final getDiskFreeSpaceEx = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
      int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>)
    >('GetDiskFreeSpaceExW', isLeaf: true);

final getDriveType = _kernel32.lookupFunction<Uint32 Function(Pointer<Utf16>), int Function(Pointer<Utf16>)>(
  'GetDriveTypeW',
  isLeaf: true,
);

/// Lê uma string UTF-16 terminada em zero de um buffer de tamanho fixo.
String readFixedUtf16(Pointer<Uint8> base, int offsetBytes, int maxChars) {
  final chars = (base + offsetBytes).cast<Uint16>().asTypedList(maxChars);
  var len = 0;
  while (len < maxChars && chars[len] != 0) {
    len++;
  }
  return String.fromCharCodes(chars, 0, len);
}

/// Executa [body] com um arena de alocação liberado ao final.
R withArena<R>(R Function(Arena arena) body) => using(body);
