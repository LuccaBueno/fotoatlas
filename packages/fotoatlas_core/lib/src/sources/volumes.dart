import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../platform/win32/kernel32.dart';

/// Disco físico de um volume (protocolo do helper §5.2).
class PhysicalDiskInfo {
  const PhysicalDiskInfo({
    required this.diskNumber,
    this.serial,
    this.model,
    this.sizeBytes,
    this.busType = 'unknown',
    this.removableMedia = false,
    this.identityConfidence = 'unknown',
  });

  factory PhysicalDiskInfo.fromJson(Map<String, Object?> json) => PhysicalDiskInfo(
    diskNumber: (json['diskNumber'] as num).toInt(),
    serial: json['serial'] as String?,
    model: json['model'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    busType: json['busType'] as String? ?? 'unknown',
    removableMedia: json['removableMedia'] as bool? ?? false,
    identityConfidence: json['identityConfidence'] as String? ?? 'unknown',
  );

  final int diskNumber;
  final String? serial;
  final String? model;
  final int? sizeBytes;
  final String busType;
  final bool removableMedia;

  /// `reliable`, `weak` ou `unknown` (ADR 0009, R1).
  final String identityConfidence;

  bool get isReliable => identityConfidence == 'reliable';
}

/// Volume do Windows visto agora.
class VolumeInfo {
  const VolumeInfo({
    required this.guidPath,
    this.mountPoints = const [],
    this.label,
    this.fileSystem,
    this.serial,
    this.totalBytes,
    this.freeBytes,
    this.driveType = 'unknown',
    this.isSystem = false,
    this.isBoot = false,
    this.physicalDisks = const [],
  });

  factory VolumeInfo.fromJson(Map<String, Object?> json) => VolumeInfo(
    guidPath: json['guidPath'] as String,
    mountPoints: [for (final m in json['mountPoints'] as List<Object?>? ?? const []) m as String],
    label: json['label'] as String?,
    fileSystem: json['fileSystem'] as String?,
    serial: (json['serial'] as num?)?.toInt(),
    totalBytes: (json['totalBytes'] as num?)?.toInt(),
    freeBytes: (json['freeBytes'] as num?)?.toInt(),
    driveType: json['driveType'] as String? ?? 'unknown',
    isSystem: json['isSystem'] as bool? ?? false,
    isBoot: json['isBoot'] as bool? ?? false,
    physicalDisks: [
      for (final d in json['physicalDisks'] as List<Object?>? ?? const [])
        PhysicalDiskInfo.fromJson((d as Map).cast<String, Object?>()),
    ],
  );

  /// `\\?\Volume{...}\` — também serve como raiz de acesso independente da letra.
  final String guidPath;
  final List<String> mountPoints;
  final String? label;
  final String? fileSystem;
  final int? serial;
  final int? totalBytes;
  final int? freeBytes;
  final String driveType;
  final bool isSystem;
  final bool isBoot;
  final List<PhysicalDiskInfo> physicalDisks;

  /// Ponto de montagem para exibição (`E:\`), se houver.
  String? get displayMount => mountPoints.isEmpty ? null : mountPoints.first;

  PhysicalDiskInfo? get primaryDisk => physicalDisks.isEmpty ? null : physicalDisks.first;
}

/// Fonte de informações de volumes (helper, FFI ou falso em testes).
abstract interface class VolumeProvider {
  Future<List<VolumeInfo>> list();
}

/// Lista volumes diretamente via Win32, sem discos físicos. Usado quando o
/// helper não está disponível (CLI sem helper, testes do core).
class Win32VolumeProvider implements VolumeProvider {
  @override
  Future<List<VolumeInfo>> list() async => listVolumesWin32();
}

List<VolumeInfo> listVolumesWin32() => using((arena) {
  final result = <VolumeInfo>[];
  const nameSize = 64;
  final name = arena<Uint16>(nameSize).cast<Utf16>();
  final handle = findFirstVolume(name, nameSize);
  if (handle == invalidHandleValue) return result;
  final bootRoot = '${_systemDrive()}\\'.toUpperCase();
  try {
    do {
      final guid = name.toDartString();
      final mounts = _mountPoints(guid, arena);
      final guidPtr = guid.toNativeUtf16(allocator: arena);
      final label = arena<Uint16>(261).cast<Utf16>();
      final fs = arena<Uint16>(261).cast<Utf16>();
      final serial = arena<Uint32>();
      final ok = getVolumeInformation(guidPtr, label, 261, serial, arena<Uint32>(), arena<Uint32>(), fs, 261);
      final free = arena<Uint64>();
      final total = arena<Uint64>();
      final hasSpace = getDiskFreeSpaceEx(guidPtr, free, total, arena<Uint64>()) != 0;
      final totalBytes = hasSpace ? total.value : null;
      result.add(
        VolumeInfo(
          guidPath: guid,
          mountPoints: mounts,
          label: ok != 0 ? label.toDartString() : null,
          fileSystem: ok != 0 ? fs.toDartString() : null,
          serial: ok != 0 ? serial.value : null,
          totalBytes: totalBytes,
          freeBytes: hasSpace ? free.value : null,
          driveType: _driveTypeName(getDriveType(guidPtr)),
          isBoot: mounts.any((m) => m.toUpperCase() == bootRoot),
          isSystem: mounts.isEmpty && (totalBytes ?? 0) < 2 * 1024 * 1024 * 1024,
        ),
      );
    } while (findNextVolume(handle, name, nameSize) != 0);
  } finally {
    findVolumeClose(handle);
  }
  return result;
});

List<String> _mountPoints(String guid, Arena arena) {
  const size = 1024;
  final buffer = arena<Uint16>(size);
  final needed = arena<Uint32>();
  if (getVolumePathNamesForVolumeName(guid.toNativeUtf16(allocator: arena), buffer.cast(), size, needed) == 0) {
    return const [];
  }
  final chars = buffer.asTypedList(size);
  final list = <String>[];
  var start = 0;
  for (var i = 0; i < size; i++) {
    if (chars[i] != 0) continue;
    if (i == start) break;
    list.add(String.fromCharCodes(chars, start, i));
    start = i + 1;
  }
  return list;
}

String _systemDrive() => Platform.environment['SystemDrive'] ?? 'C:';

String _driveTypeName(int type) => switch (type) {
  2 => 'removable',
  3 => 'fixed',
  4 => 'network',
  5 => 'cdrom',
  6 => 'ram',
  _ => 'unknown',
};
