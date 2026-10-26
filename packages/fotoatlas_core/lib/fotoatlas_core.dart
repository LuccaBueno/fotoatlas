/// Núcleo do FotoAtlas: catálogo, fontes, escaneamento e (nas próximas fases)
/// hash, cobertura e cópia segura. Dart puro, sem Flutter.
library;

export 'src/catalog/catalog.dart' show Catalog, CatalogTooNewException;
export 'src/catalog/catalog_database.dart' show CatalogDatabase, ScanRow, SourceRow;
export 'src/fotoatlas_core_base.dart';
export 'src/helper/helper_client.dart' show HelperClient, HelperException, HelperStatus, HelperVolumeProvider;
export 'src/scan/scan_engine.dart' show ScanProgress;
export 'src/scan/scan_service.dart' show ScanService;
export 'src/sources/identity.dart';
export 'src/sources/media_types.dart';
export 'src/sources/sources_service.dart';
export 'src/sources/volumes.dart';
export 'src/util/clock.dart' show fileTimeToDateTime;
export 'src/util/instance_lock.dart' show CatalogInUseException;
export 'src/util/paths.dart';
