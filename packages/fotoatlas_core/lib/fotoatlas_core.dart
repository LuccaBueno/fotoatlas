/// Núcleo do FotoAtlas: catálogo, fontes, escaneamento, conferência de
/// conteúdo (hash), cobertura, comparação, metadados, momentos, Biblioteca e
/// (nas próximas fases) cópia segura. Dart puro, sem Flutter.
library;

export 'src/catalog/catalog.dart' show Catalog, CatalogTooNewException;
export 'src/catalog/catalog_backup.dart' show CatalogBackupException, CatalogBackupInfo, CatalogBackupService;
export 'src/catalog/catalog_database.dart' show CatalogDatabase, ScanRow, SourceRow;
export 'src/compare/compare_service.dart';
export 'src/compare/scope.dart';
export 'src/coverage/coverage_service.dart';
export 'src/devices/devices.dart';
export 'src/fotoatlas_core_base.dart';
export 'src/hash/hash_engine.dart' show HashPriority;
export 'src/hash/hash_service.dart' show HashService, HashStatus;
export 'src/helper/helper_client.dart' show HelperClient, HelperException, HelperStatus, HelperVolumeProvider;
export 'src/library/library_filter.dart';
export 'src/library/library_service.dart';
export 'src/metadata/capture_date.dart'
    show
        DateConfidence,
        DateSource,
        DateCandidate,
        TimeZones,
        WallTime,
        formatWall,
        looksLikeClockReset,
        parseWall,
        wallTime;
export 'src/metadata/dates_service.dart';
export 'src/metadata/effective_dates.dart' show ClockCorrection;
export 'src/metadata/external_tools.dart';
export 'src/metadata/metadata_service.dart' show MetadataService, MetadataStatus;
export 'src/metadata/moments_service.dart' show MomentView, MomentsRecalc, MomentsService;
export 'src/scan/scan_engine.dart' show ScanProgress;
export 'src/scan/scan_listers.dart' show lockedMessage, phoneStatusMessage, unauthorizedMessage;
export 'src/scan/scan_service.dart' show ScanService;
export 'src/sources/identity.dart';
export 'src/sources/media_types.dart';
export 'src/sources/sources_service.dart';
export 'src/settings/settings_store.dart';
export 'src/sources/volumes.dart';
export 'src/thumbs/thumbnail_service.dart' show ThumbnailService, exifThumbnail;
export 'src/util/clock.dart' show fileTimeToDateTime;
export 'src/util/instance_lock.dart' show CatalogInUseException;
export 'src/util/paths.dart';
export 'src/ops/copy_models.dart';
export 'src/ops/copy_planner.dart' show FreeSpaceProbe, defaultReserveBytes, fat32MaxFileSize, isFat;
export 'src/ops/copy_service.dart' show CopyService;
export 'src/ops/names.dart'
    show
        FolderTemplate,
        TemplateVars,
        cleanFolder,
        renderFolder,
        sanitizeName,
        templateUsesDate,
        templateUsesMoment,
        undatedFolder,
        withSuffix;
export 'src/ops/reorg_models.dart';
export 'src/ops/reorg_service.dart' show ReorgService;
