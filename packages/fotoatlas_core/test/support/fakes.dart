import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;

/// Volumes simulados: cada "volume" é uma pasta real no temp do teste, usada
/// como raiz de acesso (guidPath). A letra (mountPoints) é só informativa.
class FakeVolumeProvider implements VolumeProvider {
  List<VolumeInfo> volumes = [];
  int calls = 0;

  @override
  Future<List<VolumeInfo>> list() async {
    calls++;
    return List.of(volumes);
  }
}

VolumeInfo fakeVolume(
  String rootDir, {
  String mount = r'E:\',
  int serial = 0x1234ABCD,
  String label = 'Backup1',
  String fs = 'NTFS',
  int total = 1000000000,
  String? diskSerial = 'WD-TESTE-0001',
  String diskConfidence = 'reliable',
  String driveType = 'fixed',
  String busType = 'usb',
}) {
  final guid = rootDir.endsWith(r'\') ? rootDir : '$rootDir\\';
  return VolumeInfo(
    guidPath: guid,
    mountPoints: [mount],
    label: label,
    fileSystem: fs,
    serial: serial,
    totalBytes: total,
    freeBytes: total ~/ 2,
    driveType: driveType,
    physicalDisks: [
      PhysicalDiskInfo(
        diskNumber: 2,
        serial: diskSerial,
        model: 'Disco Teste',
        sizeBytes: total,
        busType: busType,
        identityConfidence: diskConfidence,
      ),
    ],
  );
}

/// Resolve caminhos dentro das pastas-volume simuladas.
class FakePathResolver implements PathResolver {
  FakePathResolver(this.provider);
  final FakeVolumeProvider provider;

  @override
  ({String mountRoot, String volumeGuid}) resolve(String path) {
    for (final v in provider.volumes) {
      final root = v.guidPath.substring(0, v.guidPath.length - 1);
      if (p.equals(root, path) || p.isWithin(root, path)) {
        return (mountRoot: v.guidPath, volumeGuid: v.guidPath);
      }
    }
    throw SourceException('fora dos volumes simulados: $path');
  }
}
