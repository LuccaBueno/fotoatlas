import 'package:fotoatlas_core/fotoatlas_core.dart';

/// Zips do Google Takeout (Fase 9). Separado de [AppBackend] para os testes
/// antigos não precisarem implementar.
abstract interface class TakeoutBackend {
  Future<List<TakeoutZip>> find(String sourceId);
  Future<CopyPreview> preview(List<TakeoutZip> zips, {required String destSourceId, required String destFolder});
}

class CoreTakeoutBackend implements TakeoutBackend {
  CoreTakeoutBackend(this.core);
  final FotoAtlasCore core;

  @override
  Future<List<TakeoutZip>> find(String sourceId) => core.takeoutZips.find(sourceId: sourceId);

  @override
  Future<CopyPreview> preview(List<TakeoutZip> zips, {required String destSourceId, required String destFolder}) =>
      core.takeoutZips.preview(zips, destSourceId: destSourceId, destFolder: destFolder);
}
