import 'package:fotoatlas_core/fotoatlas_core.dart';

/// O que a Biblioteca, os momentos e as datas precisam do core (Fase 4).
/// Separado de [AppBackend] para os testes antigos não precisarem implementar.
abstract interface class LibraryBackend {
  /// Algo que muda a Biblioteca foi gravado (o app recarrega com atraso).
  Stream<void> changes();

  Future<LibraryIndex> index(LibraryFilter filter, {bool ascending = false});
  Future<List<LibraryItem>> items(List<int> ids);
  Future<LibraryItemDetail?> detail(int contentId);
  Future<LibraryFacets> facets();
  Future<SelectionSummary> summarize(Iterable<int> ids);

  Future<List<SavedFilter>> savedFilters();
  Future<void> saveFilter(String name, LibraryFilter filter);
  Future<void> deleteFilter(int id);

  /// Caminho da miniatura (gera se preciso); `null` se não deu.
  Future<String?> thumbnail(int contentId);

  // Momentos.
  Future<List<MomentView>> moments();
  Duration get momentGap;
  Future<MomentsRecalc> setMomentGap(Duration gap);
  Future<void> renameMoment(int id, String? name);
  Future<int> mergeMoments(List<int> ids);
  Future<int> splitMoment(int id, int atContentId);
  Future<void> resetMoment(int id);

  // Datas.
  Future<List<CaptureDevice>> captureDevices();
  Future<CorrectionPreview> previewCorrection(ClockCorrectionDraft draft);
  Future<int> applyCorrection(ClockCorrectionDraft draft);
  Future<void> undoCorrection(int id);
  Future<List<ClockCorrection>> corrections();
  Future<Duration> offsetBetween(int contentId, int referenceContentId);
  Future<int> confirmDates(Iterable<int> ids);
  Future<void> setManualDate(Iterable<int> ids, WallTime wall);
  Future<void> clearManualDate(Iterable<int> ids);

  // Leitura de metadados.
  MetadataStatus get metadataStatus;
  Stream<MetadataStatus> watchMetadataStatus();
  Future<void> startMetadata();
  Future<void> pauseMetadata();
  Future<int> retryMetadataErrors();
  ExternalTools get tools;
  String get timezone;
  Future<void> setTimezone(String zone);
  List<DateSource> get datePriority;
  Future<void> setDatePriority(List<DateSource> order);
}

class CoreLibraryBackend implements LibraryBackend {
  CoreLibraryBackend(this.core);
  final FotoAtlasCore core;

  @override
  Stream<void> changes() => core.library.changes;

  @override
  Future<LibraryIndex> index(LibraryFilter filter, {bool ascending = false}) =>
      core.library.index(filter, ascending: ascending);

  @override
  Future<List<LibraryItem>> items(List<int> ids) => core.library.items(ids);

  @override
  Future<LibraryItemDetail?> detail(int contentId) => core.library.detail(contentId);

  @override
  Future<LibraryFacets> facets() => core.library.facets();

  @override
  Future<SelectionSummary> summarize(Iterable<int> ids) => core.library.summarize(ids);

  @override
  Future<List<SavedFilter>> savedFilters() => core.library.savedFilters();

  @override
  Future<void> saveFilter(String name, LibraryFilter filter) => core.library.saveFilter(name, filter);

  @override
  Future<void> deleteFilter(int id) => core.library.deleteFilter(id);

  @override
  Future<String?> thumbnail(int contentId) => core.thumbnails.thumbnail(contentId);

  @override
  Future<List<MomentView>> moments() => core.moments.list();

  @override
  Duration get momentGap => core.moments.gap;

  @override
  Future<MomentsRecalc> setMomentGap(Duration gap) => core.moments.setGap(gap);

  @override
  Future<void> renameMoment(int id, String? name) => core.moments.rename(id, name);

  @override
  Future<int> mergeMoments(List<int> ids) => core.moments.merge(ids);

  @override
  Future<int> splitMoment(int id, int atContentId) => core.moments.split(id, atContentId);

  @override
  Future<void> resetMoment(int id) => core.moments.reset(id);

  @override
  Future<List<CaptureDevice>> captureDevices() => core.dates.captureDevices();

  @override
  Future<CorrectionPreview> previewCorrection(ClockCorrectionDraft draft) => core.dates.preview(draft);

  @override
  Future<int> applyCorrection(ClockCorrectionDraft draft) => core.dates.applyCorrection(draft);

  @override
  Future<void> undoCorrection(int id) => core.dates.undoCorrection(id);

  @override
  Future<List<ClockCorrection>> corrections() => core.dates.corrections();

  @override
  Future<Duration> offsetBetween(int contentId, int referenceContentId) =>
      core.dates.offsetBetween(contentId, referenceContentId);

  @override
  Future<int> confirmDates(Iterable<int> ids) => core.dates.confirm(ids);

  @override
  Future<void> setManualDate(Iterable<int> ids, WallTime wall) => core.dates.setManual(ids, wall);

  @override
  Future<void> clearManualDate(Iterable<int> ids) => core.dates.clearManual(ids);

  @override
  MetadataStatus get metadataStatus => core.metadata.current;

  @override
  Stream<MetadataStatus> watchMetadataStatus() => core.metadata.status;

  @override
  Future<void> startMetadata() => core.metadata.start();

  @override
  Future<void> pauseMetadata() => core.metadata.pause();

  @override
  Future<int> retryMetadataErrors() => core.metadata.retryErrors();

  @override
  ExternalTools get tools => core.metadata.tools;

  @override
  String get timezone => core.metadata.zone;

  @override
  Future<void> setTimezone(String zone) async {
    await core.metadata.setZone(zone);
    await core.settleDates();
  }

  @override
  List<DateSource> get datePriority => core.metadata.priority;

  @override
  Future<void> setDatePriority(List<DateSource> order) async {
    await core.metadata.setPriority(order);
    await core.settleDates();
  }
}
