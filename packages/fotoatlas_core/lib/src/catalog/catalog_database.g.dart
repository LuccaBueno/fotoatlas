// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_database.dart';

// ignore_for_file: type=lint
class AppMeta extends Table with TableInfo<AppMeta, AppMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppMeta(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(Insertable<AppMetaRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  AppMeta createAlias(String alias) {
    return AppMeta(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  bool get dontWriteConstraints => true;
}

class AppMetaRow extends DataClass implements Insertable<AppMetaRow> {
  final String key;
  final String value;
  const AppMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetaRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaRow(key: serializer.fromJson<String>(json['key']), value: serializer.fromJson<String>(json['value']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
  }

  AppMetaRow copyWith({String? key, String? value}) => AppMetaRow(key: key ?? this.key, value: value ?? this.value);
  AppMetaRow copyWithCompanion(AppMetaCompanion data) {
    return AppMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppMetaRow && other.key == this.key && other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaRow> {
  final Value<String> key;
  final Value<String> value;
  const AppMetaCompanion({this.key = const Value.absent(), this.value = const Value.absent()});
  AppMetaCompanion.insert({required String key, required String value}) : key = Value(key), value = Value(value);
  static Insertable<AppMetaRow> custom({Expression<String>? key, Expression<String>? value}) {
    return RawValuesInsertable({if (key != null) 'key': key, if (value != null) 'value': value});
  }

  AppMetaCompanion copyWith({Value<String>? key, Value<String>? value}) {
    return AppMetaCompanion(key: key ?? this.key, value: value ?? this.value);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class Settings extends Table with TableInfo<Settings, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta('valueJson');
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(_valueJsonMeta, valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta));
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      valueJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value_json'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  bool get dontWriteConstraints => true;
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String valueJson;
  final int updatedAt;
  const SettingRow({required this.key, required this.valueJson, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), valueJson: Value(valueJson), updatedAt: Value(updatedAt));
  }

  factory SettingRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['value_json']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value_json': serializer.toJson<String>(valueJson),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  SettingRow copyWith({String? key, String? valueJson, int? updatedAt}) =>
      SettingRow(key: key ?? this.key, valueJson: valueJson ?? this.valueJson, updatedAt: updatedAt ?? this.updatedAt);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<int> updatedAt;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SettingsCompanion.insert({required String key, required String valueJson, required int updatedAt})
    : key = Value(key),
      valueJson = Value(valueJson),
      updatedAt = Value(updatedAt);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SettingsCompanion copyWith({Value<String>? key, Value<String>? valueJson, Value<int>? updatedAt}) {
    return SettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class PhysicalDisks extends Table with TableInfo<PhysicalDisks, PhysicalDiskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PhysicalDisks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
    'serial',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta('sizeBytes');
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _busTypeMeta = const VerificationMeta('busType');
  late final GeneratedColumn<String> busType = GeneratedColumn<String>(
    'bus_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _identityConfidenceMeta = const VerificationMeta('identityConfidence');
  late final GeneratedColumn<String> identityConfidence = GeneratedColumn<String>(
    'identity_confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (identity_confidence IN (\'reliable\', \'weak\', \'unknown\'))',
  );
  static const VerificationMeta _userConfirmedMeta = const VerificationMeta('userConfirmed');
  late final GeneratedColumn<bool> userConfirmed = GeneratedColumn<bool>(
    'user_confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta('firstSeenAt');
  late final GeneratedColumn<int> firstSeenAt = GeneratedColumn<int>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta('lastSeenAt');
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serial,
    model,
    sizeBytes,
    busType,
    identityConfidence,
    userConfirmed,
    firstSeenAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'physical_disks';
  @override
  VerificationContext validateIntegrity(Insertable<PhysicalDiskRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('serial')) {
      context.handle(_serialMeta, serial.isAcceptableOrUnknown(data['serial']!, _serialMeta));
    }
    if (data.containsKey('model')) {
      context.handle(_modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta, sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('bus_type')) {
      context.handle(_busTypeMeta, busType.isAcceptableOrUnknown(data['bus_type']!, _busTypeMeta));
    }
    if (data.containsKey('identity_confidence')) {
      context.handle(
        _identityConfidenceMeta,
        identityConfidence.isAcceptableOrUnknown(data['identity_confidence']!, _identityConfidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_identityConfidenceMeta);
    }
    if (data.containsKey('user_confirmed')) {
      context.handle(
        _userConfirmedMeta,
        userConfirmed.isAcceptableOrUnknown(data['user_confirmed']!, _userConfirmedMeta),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(_firstSeenAtMeta, firstSeenAt.isAcceptableOrUnknown(data['first_seen_at']!, _firstSeenAtMeta));
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(_lastSeenAtMeta, lastSeenAt.isAcceptableOrUnknown(data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhysicalDiskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhysicalDiskRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      serial: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}serial']),
      model: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}model']),
      sizeBytes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size_bytes']),
      busType: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}bus_type']),
      identityConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_confidence'],
      )!,
      userConfirmed: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}user_confirmed'])!,
      firstSeenAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}first_seen_at'])!,
      lastSeenAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}last_seen_at'])!,
    );
  }

  @override
  PhysicalDisks createAlias(String alias) {
    return PhysicalDisks(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class PhysicalDiskRow extends DataClass implements Insertable<PhysicalDiskRow> {
  final int id;
  final String? serial;
  final String? model;
  final int? sizeBytes;
  final String? busType;
  final String identityConfidence;
  final bool userConfirmed;
  final int firstSeenAt;
  final int lastSeenAt;
  const PhysicalDiskRow({
    required this.id,
    this.serial,
    this.model,
    this.sizeBytes,
    this.busType,
    required this.identityConfidence,
    required this.userConfirmed,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serial != null) {
      map['serial'] = Variable<String>(serial);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || busType != null) {
      map['bus_type'] = Variable<String>(busType);
    }
    map['identity_confidence'] = Variable<String>(identityConfidence);
    map['user_confirmed'] = Variable<bool>(userConfirmed);
    map['first_seen_at'] = Variable<int>(firstSeenAt);
    map['last_seen_at'] = Variable<int>(lastSeenAt);
    return map;
  }

  PhysicalDisksCompanion toCompanion(bool nullToAbsent) {
    return PhysicalDisksCompanion(
      id: Value(id),
      serial: serial == null && nullToAbsent ? const Value.absent() : Value(serial),
      model: model == null && nullToAbsent ? const Value.absent() : Value(model),
      sizeBytes: sizeBytes == null && nullToAbsent ? const Value.absent() : Value(sizeBytes),
      busType: busType == null && nullToAbsent ? const Value.absent() : Value(busType),
      identityConfidence: Value(identityConfidence),
      userConfirmed: Value(userConfirmed),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory PhysicalDiskRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhysicalDiskRow(
      id: serializer.fromJson<int>(json['id']),
      serial: serializer.fromJson<String?>(json['serial']),
      model: serializer.fromJson<String?>(json['model']),
      sizeBytes: serializer.fromJson<int?>(json['size_bytes']),
      busType: serializer.fromJson<String?>(json['bus_type']),
      identityConfidence: serializer.fromJson<String>(json['identity_confidence']),
      userConfirmed: serializer.fromJson<bool>(json['user_confirmed']),
      firstSeenAt: serializer.fromJson<int>(json['first_seen_at']),
      lastSeenAt: serializer.fromJson<int>(json['last_seen_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serial': serializer.toJson<String?>(serial),
      'model': serializer.toJson<String?>(model),
      'size_bytes': serializer.toJson<int?>(sizeBytes),
      'bus_type': serializer.toJson<String?>(busType),
      'identity_confidence': serializer.toJson<String>(identityConfidence),
      'user_confirmed': serializer.toJson<bool>(userConfirmed),
      'first_seen_at': serializer.toJson<int>(firstSeenAt),
      'last_seen_at': serializer.toJson<int>(lastSeenAt),
    };
  }

  PhysicalDiskRow copyWith({
    int? id,
    Value<String?> serial = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> busType = const Value.absent(),
    String? identityConfidence,
    bool? userConfirmed,
    int? firstSeenAt,
    int? lastSeenAt,
  }) => PhysicalDiskRow(
    id: id ?? this.id,
    serial: serial.present ? serial.value : this.serial,
    model: model.present ? model.value : this.model,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    busType: busType.present ? busType.value : this.busType,
    identityConfidence: identityConfidence ?? this.identityConfidence,
    userConfirmed: userConfirmed ?? this.userConfirmed,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  PhysicalDiskRow copyWithCompanion(PhysicalDisksCompanion data) {
    return PhysicalDiskRow(
      id: data.id.present ? data.id.value : this.id,
      serial: data.serial.present ? data.serial.value : this.serial,
      model: data.model.present ? data.model.value : this.model,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      busType: data.busType.present ? data.busType.value : this.busType,
      identityConfidence: data.identityConfidence.present ? data.identityConfidence.value : this.identityConfidence,
      userConfirmed: data.userConfirmed.present ? data.userConfirmed.value : this.userConfirmed,
      firstSeenAt: data.firstSeenAt.present ? data.firstSeenAt.value : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhysicalDiskRow(')
          ..write('id: $id, ')
          ..write('serial: $serial, ')
          ..write('model: $model, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('busType: $busType, ')
          ..write('identityConfidence: $identityConfidence, ')
          ..write('userConfirmed: $userConfirmed, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serial, model, sizeBytes, busType, identityConfidence, userConfirmed, firstSeenAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhysicalDiskRow &&
          other.id == this.id &&
          other.serial == this.serial &&
          other.model == this.model &&
          other.sizeBytes == this.sizeBytes &&
          other.busType == this.busType &&
          other.identityConfidence == this.identityConfidence &&
          other.userConfirmed == this.userConfirmed &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class PhysicalDisksCompanion extends UpdateCompanion<PhysicalDiskRow> {
  final Value<int> id;
  final Value<String?> serial;
  final Value<String?> model;
  final Value<int?> sizeBytes;
  final Value<String?> busType;
  final Value<String> identityConfidence;
  final Value<bool> userConfirmed;
  final Value<int> firstSeenAt;
  final Value<int> lastSeenAt;
  const PhysicalDisksCompanion({
    this.id = const Value.absent(),
    this.serial = const Value.absent(),
    this.model = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.busType = const Value.absent(),
    this.identityConfidence = const Value.absent(),
    this.userConfirmed = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
  });
  PhysicalDisksCompanion.insert({
    this.id = const Value.absent(),
    this.serial = const Value.absent(),
    this.model = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.busType = const Value.absent(),
    required String identityConfidence,
    this.userConfirmed = const Value.absent(),
    required int firstSeenAt,
    required int lastSeenAt,
  }) : identityConfidence = Value(identityConfidence),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<PhysicalDiskRow> custom({
    Expression<int>? id,
    Expression<String>? serial,
    Expression<String>? model,
    Expression<int>? sizeBytes,
    Expression<String>? busType,
    Expression<String>? identityConfidence,
    Expression<bool>? userConfirmed,
    Expression<int>? firstSeenAt,
    Expression<int>? lastSeenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serial != null) 'serial': serial,
      if (model != null) 'model': model,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (busType != null) 'bus_type': busType,
      if (identityConfidence != null) 'identity_confidence': identityConfidence,
      if (userConfirmed != null) 'user_confirmed': userConfirmed,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    });
  }

  PhysicalDisksCompanion copyWith({
    Value<int>? id,
    Value<String?>? serial,
    Value<String?>? model,
    Value<int?>? sizeBytes,
    Value<String?>? busType,
    Value<String>? identityConfidence,
    Value<bool>? userConfirmed,
    Value<int>? firstSeenAt,
    Value<int>? lastSeenAt,
  }) {
    return PhysicalDisksCompanion(
      id: id ?? this.id,
      serial: serial ?? this.serial,
      model: model ?? this.model,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      busType: busType ?? this.busType,
      identityConfidence: identityConfidence ?? this.identityConfidence,
      userConfirmed: userConfirmed ?? this.userConfirmed,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (busType.present) {
      map['bus_type'] = Variable<String>(busType.value);
    }
    if (identityConfidence.present) {
      map['identity_confidence'] = Variable<String>(identityConfidence.value);
    }
    if (userConfirmed.present) {
      map['user_confirmed'] = Variable<bool>(userConfirmed.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhysicalDisksCompanion(')
          ..write('id: $id, ')
          ..write('serial: $serial, ')
          ..write('model: $model, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('busType: $busType, ')
          ..write('identityConfidence: $identityConfidence, ')
          ..write('userConfirmed: $userConfirmed, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }
}

class Sources extends Table with TableInfo<Sources, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Sources(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'external_hd\', \'internal\', \'usb_stick\', \'memory_card\', \'phone\', \'folder\'))',
  );
  static const VerificationMeta _volumeGuidMeta = const VerificationMeta('volumeGuid');
  late final GeneratedColumn<String> volumeGuid = GeneratedColumn<String>(
    'volume_guid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _volumeSerialMeta = const VerificationMeta('volumeSerial');
  late final GeneratedColumn<int> volumeSerial = GeneratedColumn<int>(
    'volume_serial',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _volumeLabelMeta = const VerificationMeta('volumeLabel');
  late final GeneratedColumn<String> volumeLabel = GeneratedColumn<String>(
    'volume_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _filesystemMeta = const VerificationMeta('filesystem');
  late final GeneratedColumn<String> filesystem = GeneratedColumn<String>(
    'filesystem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _volumeSizeBytesMeta = const VerificationMeta('volumeSizeBytes');
  late final GeneratedColumn<int> volumeSizeBytes = GeneratedColumn<int>(
    'volume_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _physicalDiskIdMeta = const VerificationMeta('physicalDiskId');
  late final GeneratedColumn<int> physicalDiskId = GeneratedColumn<int>(
    'physical_disk_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES physical_disks(id)',
  );
  static const VerificationMeta _markerIdMeta = const VerificationMeta('markerId');
  late final GeneratedColumn<String> markerId = GeneratedColumn<String>(
    'marker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta('deviceId');
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceModelMeta = const VerificationMeta('deviceModel');
  late final GeneratedColumn<String> deviceModel = GeneratedColumn<String>(
    'device_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _rootRelPathMeta = const VerificationMeta('rootRelPath');
  late final GeneratedColumn<String> rootRelPath = GeneratedColumn<String>(
    'root_rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _lastMountPathMeta = const VerificationMeta('lastMountPath');
  late final GeneratedColumn<String> lastMountPath = GeneratedColumn<String>(
    'last_mount_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _connectedMeta = const VerificationMeta('connected');
  late final GeneratedColumn<bool> connected = GeneratedColumn<bool>(
    'connected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta('lastConnectedAt');
  late final GeneratedColumn<int> lastConnectedAt = GeneratedColumn<int>(
    'last_connected_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _totalBytesLastMeta = const VerificationMeta('totalBytesLast');
  late final GeneratedColumn<int> totalBytesLast = GeneratedColumn<int>(
    'total_bytes_last',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _freeBytesLastMeta = const VerificationMeta('freeBytesLast');
  late final GeneratedColumn<int> freeBytesLast = GeneratedColumn<int>(
    'free_bytes_last',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _forgottenAtMeta = const VerificationMeta('forgottenAt');
  late final GeneratedColumn<int> forgottenAt = GeneratedColumn<int>(
    'forgotten_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceSerialMeta = const VerificationMeta('deviceSerial');
  late final GeneratedColumn<String> deviceSerial = GeneratedColumn<String>(
    'device_serial',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _devicePlatformMeta = const VerificationMeta('devicePlatform');
  late final GeneratedColumn<String> devicePlatform = GeneratedColumn<String>(
    'device_platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    volumeGuid,
    volumeSerial,
    volumeLabel,
    filesystem,
    volumeSizeBytes,
    physicalDiskId,
    markerId,
    deviceId,
    deviceModel,
    rootRelPath,
    lastMountPath,
    connected,
    lastConnectedAt,
    totalBytesLast,
    freeBytesLast,
    createdAt,
    updatedAt,
    forgottenAt,
    deviceSerial,
    devicePlatform,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(Insertable<SourceRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('volume_guid')) {
      context.handle(_volumeGuidMeta, volumeGuid.isAcceptableOrUnknown(data['volume_guid']!, _volumeGuidMeta));
    }
    if (data.containsKey('volume_serial')) {
      context.handle(_volumeSerialMeta, volumeSerial.isAcceptableOrUnknown(data['volume_serial']!, _volumeSerialMeta));
    }
    if (data.containsKey('volume_label')) {
      context.handle(_volumeLabelMeta, volumeLabel.isAcceptableOrUnknown(data['volume_label']!, _volumeLabelMeta));
    }
    if (data.containsKey('filesystem')) {
      context.handle(_filesystemMeta, filesystem.isAcceptableOrUnknown(data['filesystem']!, _filesystemMeta));
    }
    if (data.containsKey('volume_size_bytes')) {
      context.handle(
        _volumeSizeBytesMeta,
        volumeSizeBytes.isAcceptableOrUnknown(data['volume_size_bytes']!, _volumeSizeBytesMeta),
      );
    }
    if (data.containsKey('physical_disk_id')) {
      context.handle(
        _physicalDiskIdMeta,
        physicalDiskId.isAcceptableOrUnknown(data['physical_disk_id']!, _physicalDiskIdMeta),
      );
    }
    if (data.containsKey('marker_id')) {
      context.handle(_markerIdMeta, markerId.isAcceptableOrUnknown(data['marker_id']!, _markerIdMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta, deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('device_model')) {
      context.handle(_deviceModelMeta, deviceModel.isAcceptableOrUnknown(data['device_model']!, _deviceModelMeta));
    }
    if (data.containsKey('root_rel_path')) {
      context.handle(_rootRelPathMeta, rootRelPath.isAcceptableOrUnknown(data['root_rel_path']!, _rootRelPathMeta));
    }
    if (data.containsKey('last_mount_path')) {
      context.handle(
        _lastMountPathMeta,
        lastMountPath.isAcceptableOrUnknown(data['last_mount_path']!, _lastMountPathMeta),
      );
    }
    if (data.containsKey('connected')) {
      context.handle(_connectedMeta, connected.isAcceptableOrUnknown(data['connected']!, _connectedMeta));
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(data['last_connected_at']!, _lastConnectedAtMeta),
      );
    }
    if (data.containsKey('total_bytes_last')) {
      context.handle(
        _totalBytesLastMeta,
        totalBytesLast.isAcceptableOrUnknown(data['total_bytes_last']!, _totalBytesLastMeta),
      );
    }
    if (data.containsKey('free_bytes_last')) {
      context.handle(
        _freeBytesLastMeta,
        freeBytesLast.isAcceptableOrUnknown(data['free_bytes_last']!, _freeBytesLastMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('forgotten_at')) {
      context.handle(_forgottenAtMeta, forgottenAt.isAcceptableOrUnknown(data['forgotten_at']!, _forgottenAtMeta));
    }
    if (data.containsKey('device_serial')) {
      context.handle(_deviceSerialMeta, deviceSerial.isAcceptableOrUnknown(data['device_serial']!, _deviceSerialMeta));
    }
    if (data.containsKey('device_platform')) {
      context.handle(
        _devicePlatformMeta,
        devicePlatform.isAcceptableOrUnknown(data['device_platform']!, _devicePlatformMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      volumeGuid: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}volume_guid']),
      volumeSerial: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}volume_serial']),
      volumeLabel: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}volume_label']),
      filesystem: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}filesystem']),
      volumeSizeBytes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}volume_size_bytes']),
      physicalDiskId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}physical_disk_id']),
      markerId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}marker_id']),
      deviceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_id']),
      deviceModel: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_model']),
      rootRelPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}root_rel_path'])!,
      lastMountPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}last_mount_path']),
      connected: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}connected'])!,
      lastConnectedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}last_connected_at']),
      totalBytesLast: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}total_bytes_last']),
      freeBytesLast: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}free_bytes_last']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      forgottenAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}forgotten_at']),
      deviceSerial: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_serial']),
      devicePlatform: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_platform']),
    );
  }

  @override
  Sources createAlias(String alias) {
    return Sources(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final String id;
  final String name;
  final String kind;
  final String? volumeGuid;
  final int? volumeSerial;
  final String? volumeLabel;
  final String? filesystem;
  final int? volumeSizeBytes;
  final int? physicalDiskId;
  final String? markerId;
  final String? deviceId;
  final String? deviceModel;
  final String rootRelPath;
  final String? lastMountPath;
  final bool connected;
  final int? lastConnectedAt;
  final int? totalBytesLast;
  final int? freeBytesLast;
  final int createdAt;
  final int updatedAt;
  final int? forgottenAt;
  final String? deviceSerial;

  /// v3: serial do celular (identidade)
  final String? devicePlatform;
  const SourceRow({
    required this.id,
    required this.name,
    required this.kind,
    this.volumeGuid,
    this.volumeSerial,
    this.volumeLabel,
    this.filesystem,
    this.volumeSizeBytes,
    this.physicalDiskId,
    this.markerId,
    this.deviceId,
    this.deviceModel,
    required this.rootRelPath,
    this.lastMountPath,
    required this.connected,
    this.lastConnectedAt,
    this.totalBytesLast,
    this.freeBytesLast,
    required this.createdAt,
    required this.updatedAt,
    this.forgottenAt,
    this.deviceSerial,
    this.devicePlatform,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || volumeGuid != null) {
      map['volume_guid'] = Variable<String>(volumeGuid);
    }
    if (!nullToAbsent || volumeSerial != null) {
      map['volume_serial'] = Variable<int>(volumeSerial);
    }
    if (!nullToAbsent || volumeLabel != null) {
      map['volume_label'] = Variable<String>(volumeLabel);
    }
    if (!nullToAbsent || filesystem != null) {
      map['filesystem'] = Variable<String>(filesystem);
    }
    if (!nullToAbsent || volumeSizeBytes != null) {
      map['volume_size_bytes'] = Variable<int>(volumeSizeBytes);
    }
    if (!nullToAbsent || physicalDiskId != null) {
      map['physical_disk_id'] = Variable<int>(physicalDiskId);
    }
    if (!nullToAbsent || markerId != null) {
      map['marker_id'] = Variable<String>(markerId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || deviceModel != null) {
      map['device_model'] = Variable<String>(deviceModel);
    }
    map['root_rel_path'] = Variable<String>(rootRelPath);
    if (!nullToAbsent || lastMountPath != null) {
      map['last_mount_path'] = Variable<String>(lastMountPath);
    }
    map['connected'] = Variable<bool>(connected);
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<int>(lastConnectedAt);
    }
    if (!nullToAbsent || totalBytesLast != null) {
      map['total_bytes_last'] = Variable<int>(totalBytesLast);
    }
    if (!nullToAbsent || freeBytesLast != null) {
      map['free_bytes_last'] = Variable<int>(freeBytesLast);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || forgottenAt != null) {
      map['forgotten_at'] = Variable<int>(forgottenAt);
    }
    if (!nullToAbsent || deviceSerial != null) {
      map['device_serial'] = Variable<String>(deviceSerial);
    }
    if (!nullToAbsent || devicePlatform != null) {
      map['device_platform'] = Variable<String>(devicePlatform);
    }
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      volumeGuid: volumeGuid == null && nullToAbsent ? const Value.absent() : Value(volumeGuid),
      volumeSerial: volumeSerial == null && nullToAbsent ? const Value.absent() : Value(volumeSerial),
      volumeLabel: volumeLabel == null && nullToAbsent ? const Value.absent() : Value(volumeLabel),
      filesystem: filesystem == null && nullToAbsent ? const Value.absent() : Value(filesystem),
      volumeSizeBytes: volumeSizeBytes == null && nullToAbsent ? const Value.absent() : Value(volumeSizeBytes),
      physicalDiskId: physicalDiskId == null && nullToAbsent ? const Value.absent() : Value(physicalDiskId),
      markerId: markerId == null && nullToAbsent ? const Value.absent() : Value(markerId),
      deviceId: deviceId == null && nullToAbsent ? const Value.absent() : Value(deviceId),
      deviceModel: deviceModel == null && nullToAbsent ? const Value.absent() : Value(deviceModel),
      rootRelPath: Value(rootRelPath),
      lastMountPath: lastMountPath == null && nullToAbsent ? const Value.absent() : Value(lastMountPath),
      connected: Value(connected),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent ? const Value.absent() : Value(lastConnectedAt),
      totalBytesLast: totalBytesLast == null && nullToAbsent ? const Value.absent() : Value(totalBytesLast),
      freeBytesLast: freeBytesLast == null && nullToAbsent ? const Value.absent() : Value(freeBytesLast),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      forgottenAt: forgottenAt == null && nullToAbsent ? const Value.absent() : Value(forgottenAt),
      deviceSerial: deviceSerial == null && nullToAbsent ? const Value.absent() : Value(deviceSerial),
      devicePlatform: devicePlatform == null && nullToAbsent ? const Value.absent() : Value(devicePlatform),
    );
  }

  factory SourceRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      volumeGuid: serializer.fromJson<String?>(json['volume_guid']),
      volumeSerial: serializer.fromJson<int?>(json['volume_serial']),
      volumeLabel: serializer.fromJson<String?>(json['volume_label']),
      filesystem: serializer.fromJson<String?>(json['filesystem']),
      volumeSizeBytes: serializer.fromJson<int?>(json['volume_size_bytes']),
      physicalDiskId: serializer.fromJson<int?>(json['physical_disk_id']),
      markerId: serializer.fromJson<String?>(json['marker_id']),
      deviceId: serializer.fromJson<String?>(json['device_id']),
      deviceModel: serializer.fromJson<String?>(json['device_model']),
      rootRelPath: serializer.fromJson<String>(json['root_rel_path']),
      lastMountPath: serializer.fromJson<String?>(json['last_mount_path']),
      connected: serializer.fromJson<bool>(json['connected']),
      lastConnectedAt: serializer.fromJson<int?>(json['last_connected_at']),
      totalBytesLast: serializer.fromJson<int?>(json['total_bytes_last']),
      freeBytesLast: serializer.fromJson<int?>(json['free_bytes_last']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      forgottenAt: serializer.fromJson<int?>(json['forgotten_at']),
      deviceSerial: serializer.fromJson<String?>(json['device_serial']),
      devicePlatform: serializer.fromJson<String?>(json['device_platform']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'volume_guid': serializer.toJson<String?>(volumeGuid),
      'volume_serial': serializer.toJson<int?>(volumeSerial),
      'volume_label': serializer.toJson<String?>(volumeLabel),
      'filesystem': serializer.toJson<String?>(filesystem),
      'volume_size_bytes': serializer.toJson<int?>(volumeSizeBytes),
      'physical_disk_id': serializer.toJson<int?>(physicalDiskId),
      'marker_id': serializer.toJson<String?>(markerId),
      'device_id': serializer.toJson<String?>(deviceId),
      'device_model': serializer.toJson<String?>(deviceModel),
      'root_rel_path': serializer.toJson<String>(rootRelPath),
      'last_mount_path': serializer.toJson<String?>(lastMountPath),
      'connected': serializer.toJson<bool>(connected),
      'last_connected_at': serializer.toJson<int?>(lastConnectedAt),
      'total_bytes_last': serializer.toJson<int?>(totalBytesLast),
      'free_bytes_last': serializer.toJson<int?>(freeBytesLast),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'forgotten_at': serializer.toJson<int?>(forgottenAt),
      'device_serial': serializer.toJson<String?>(deviceSerial),
      'device_platform': serializer.toJson<String?>(devicePlatform),
    };
  }

  SourceRow copyWith({
    String? id,
    String? name,
    String? kind,
    Value<String?> volumeGuid = const Value.absent(),
    Value<int?> volumeSerial = const Value.absent(),
    Value<String?> volumeLabel = const Value.absent(),
    Value<String?> filesystem = const Value.absent(),
    Value<int?> volumeSizeBytes = const Value.absent(),
    Value<int?> physicalDiskId = const Value.absent(),
    Value<String?> markerId = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<String?> deviceModel = const Value.absent(),
    String? rootRelPath,
    Value<String?> lastMountPath = const Value.absent(),
    bool? connected,
    Value<int?> lastConnectedAt = const Value.absent(),
    Value<int?> totalBytesLast = const Value.absent(),
    Value<int?> freeBytesLast = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> forgottenAt = const Value.absent(),
    Value<String?> deviceSerial = const Value.absent(),
    Value<String?> devicePlatform = const Value.absent(),
  }) => SourceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    volumeGuid: volumeGuid.present ? volumeGuid.value : this.volumeGuid,
    volumeSerial: volumeSerial.present ? volumeSerial.value : this.volumeSerial,
    volumeLabel: volumeLabel.present ? volumeLabel.value : this.volumeLabel,
    filesystem: filesystem.present ? filesystem.value : this.filesystem,
    volumeSizeBytes: volumeSizeBytes.present ? volumeSizeBytes.value : this.volumeSizeBytes,
    physicalDiskId: physicalDiskId.present ? physicalDiskId.value : this.physicalDiskId,
    markerId: markerId.present ? markerId.value : this.markerId,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deviceModel: deviceModel.present ? deviceModel.value : this.deviceModel,
    rootRelPath: rootRelPath ?? this.rootRelPath,
    lastMountPath: lastMountPath.present ? lastMountPath.value : this.lastMountPath,
    connected: connected ?? this.connected,
    lastConnectedAt: lastConnectedAt.present ? lastConnectedAt.value : this.lastConnectedAt,
    totalBytesLast: totalBytesLast.present ? totalBytesLast.value : this.totalBytesLast,
    freeBytesLast: freeBytesLast.present ? freeBytesLast.value : this.freeBytesLast,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    forgottenAt: forgottenAt.present ? forgottenAt.value : this.forgottenAt,
    deviceSerial: deviceSerial.present ? deviceSerial.value : this.deviceSerial,
    devicePlatform: devicePlatform.present ? devicePlatform.value : this.devicePlatform,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      volumeGuid: data.volumeGuid.present ? data.volumeGuid.value : this.volumeGuid,
      volumeSerial: data.volumeSerial.present ? data.volumeSerial.value : this.volumeSerial,
      volumeLabel: data.volumeLabel.present ? data.volumeLabel.value : this.volumeLabel,
      filesystem: data.filesystem.present ? data.filesystem.value : this.filesystem,
      volumeSizeBytes: data.volumeSizeBytes.present ? data.volumeSizeBytes.value : this.volumeSizeBytes,
      physicalDiskId: data.physicalDiskId.present ? data.physicalDiskId.value : this.physicalDiskId,
      markerId: data.markerId.present ? data.markerId.value : this.markerId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deviceModel: data.deviceModel.present ? data.deviceModel.value : this.deviceModel,
      rootRelPath: data.rootRelPath.present ? data.rootRelPath.value : this.rootRelPath,
      lastMountPath: data.lastMountPath.present ? data.lastMountPath.value : this.lastMountPath,
      connected: data.connected.present ? data.connected.value : this.connected,
      lastConnectedAt: data.lastConnectedAt.present ? data.lastConnectedAt.value : this.lastConnectedAt,
      totalBytesLast: data.totalBytesLast.present ? data.totalBytesLast.value : this.totalBytesLast,
      freeBytesLast: data.freeBytesLast.present ? data.freeBytesLast.value : this.freeBytesLast,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      forgottenAt: data.forgottenAt.present ? data.forgottenAt.value : this.forgottenAt,
      deviceSerial: data.deviceSerial.present ? data.deviceSerial.value : this.deviceSerial,
      devicePlatform: data.devicePlatform.present ? data.devicePlatform.value : this.devicePlatform,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('volumeGuid: $volumeGuid, ')
          ..write('volumeSerial: $volumeSerial, ')
          ..write('volumeLabel: $volumeLabel, ')
          ..write('filesystem: $filesystem, ')
          ..write('volumeSizeBytes: $volumeSizeBytes, ')
          ..write('physicalDiskId: $physicalDiskId, ')
          ..write('markerId: $markerId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceModel: $deviceModel, ')
          ..write('rootRelPath: $rootRelPath, ')
          ..write('lastMountPath: $lastMountPath, ')
          ..write('connected: $connected, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('totalBytesLast: $totalBytesLast, ')
          ..write('freeBytesLast: $freeBytesLast, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('forgottenAt: $forgottenAt, ')
          ..write('deviceSerial: $deviceSerial, ')
          ..write('devicePlatform: $devicePlatform')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    kind,
    volumeGuid,
    volumeSerial,
    volumeLabel,
    filesystem,
    volumeSizeBytes,
    physicalDiskId,
    markerId,
    deviceId,
    deviceModel,
    rootRelPath,
    lastMountPath,
    connected,
    lastConnectedAt,
    totalBytesLast,
    freeBytesLast,
    createdAt,
    updatedAt,
    forgottenAt,
    deviceSerial,
    devicePlatform,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.volumeGuid == this.volumeGuid &&
          other.volumeSerial == this.volumeSerial &&
          other.volumeLabel == this.volumeLabel &&
          other.filesystem == this.filesystem &&
          other.volumeSizeBytes == this.volumeSizeBytes &&
          other.physicalDiskId == this.physicalDiskId &&
          other.markerId == this.markerId &&
          other.deviceId == this.deviceId &&
          other.deviceModel == this.deviceModel &&
          other.rootRelPath == this.rootRelPath &&
          other.lastMountPath == this.lastMountPath &&
          other.connected == this.connected &&
          other.lastConnectedAt == this.lastConnectedAt &&
          other.totalBytesLast == this.totalBytesLast &&
          other.freeBytesLast == this.freeBytesLast &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.forgottenAt == this.forgottenAt &&
          other.deviceSerial == this.deviceSerial &&
          other.devicePlatform == this.devicePlatform);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> volumeGuid;
  final Value<int?> volumeSerial;
  final Value<String?> volumeLabel;
  final Value<String?> filesystem;
  final Value<int?> volumeSizeBytes;
  final Value<int?> physicalDiskId;
  final Value<String?> markerId;
  final Value<String?> deviceId;
  final Value<String?> deviceModel;
  final Value<String> rootRelPath;
  final Value<String?> lastMountPath;
  final Value<bool> connected;
  final Value<int?> lastConnectedAt;
  final Value<int?> totalBytesLast;
  final Value<int?> freeBytesLast;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> forgottenAt;
  final Value<String?> deviceSerial;
  final Value<String?> devicePlatform;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.volumeGuid = const Value.absent(),
    this.volumeSerial = const Value.absent(),
    this.volumeLabel = const Value.absent(),
    this.filesystem = const Value.absent(),
    this.volumeSizeBytes = const Value.absent(),
    this.physicalDiskId = const Value.absent(),
    this.markerId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceModel = const Value.absent(),
    this.rootRelPath = const Value.absent(),
    this.lastMountPath = const Value.absent(),
    this.connected = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.totalBytesLast = const Value.absent(),
    this.freeBytesLast = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.forgottenAt = const Value.absent(),
    this.deviceSerial = const Value.absent(),
    this.devicePlatform = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.volumeGuid = const Value.absent(),
    this.volumeSerial = const Value.absent(),
    this.volumeLabel = const Value.absent(),
    this.filesystem = const Value.absent(),
    this.volumeSizeBytes = const Value.absent(),
    this.physicalDiskId = const Value.absent(),
    this.markerId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceModel = const Value.absent(),
    this.rootRelPath = const Value.absent(),
    this.lastMountPath = const Value.absent(),
    this.connected = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.totalBytesLast = const Value.absent(),
    this.freeBytesLast = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.forgottenAt = const Value.absent(),
    this.deviceSerial = const Value.absent(),
    this.devicePlatform = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SourceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? volumeGuid,
    Expression<int>? volumeSerial,
    Expression<String>? volumeLabel,
    Expression<String>? filesystem,
    Expression<int>? volumeSizeBytes,
    Expression<int>? physicalDiskId,
    Expression<String>? markerId,
    Expression<String>? deviceId,
    Expression<String>? deviceModel,
    Expression<String>? rootRelPath,
    Expression<String>? lastMountPath,
    Expression<bool>? connected,
    Expression<int>? lastConnectedAt,
    Expression<int>? totalBytesLast,
    Expression<int>? freeBytesLast,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? forgottenAt,
    Expression<String>? deviceSerial,
    Expression<String>? devicePlatform,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (volumeGuid != null) 'volume_guid': volumeGuid,
      if (volumeSerial != null) 'volume_serial': volumeSerial,
      if (volumeLabel != null) 'volume_label': volumeLabel,
      if (filesystem != null) 'filesystem': filesystem,
      if (volumeSizeBytes != null) 'volume_size_bytes': volumeSizeBytes,
      if (physicalDiskId != null) 'physical_disk_id': physicalDiskId,
      if (markerId != null) 'marker_id': markerId,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceModel != null) 'device_model': deviceModel,
      if (rootRelPath != null) 'root_rel_path': rootRelPath,
      if (lastMountPath != null) 'last_mount_path': lastMountPath,
      if (connected != null) 'connected': connected,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (totalBytesLast != null) 'total_bytes_last': totalBytesLast,
      if (freeBytesLast != null) 'free_bytes_last': freeBytesLast,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (forgottenAt != null) 'forgotten_at': forgottenAt,
      if (deviceSerial != null) 'device_serial': deviceSerial,
      if (devicePlatform != null) 'device_platform': devicePlatform,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? volumeGuid,
    Value<int?>? volumeSerial,
    Value<String?>? volumeLabel,
    Value<String?>? filesystem,
    Value<int?>? volumeSizeBytes,
    Value<int?>? physicalDiskId,
    Value<String?>? markerId,
    Value<String?>? deviceId,
    Value<String?>? deviceModel,
    Value<String>? rootRelPath,
    Value<String?>? lastMountPath,
    Value<bool>? connected,
    Value<int?>? lastConnectedAt,
    Value<int?>? totalBytesLast,
    Value<int?>? freeBytesLast,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? forgottenAt,
    Value<String?>? deviceSerial,
    Value<String?>? devicePlatform,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      volumeGuid: volumeGuid ?? this.volumeGuid,
      volumeSerial: volumeSerial ?? this.volumeSerial,
      volumeLabel: volumeLabel ?? this.volumeLabel,
      filesystem: filesystem ?? this.filesystem,
      volumeSizeBytes: volumeSizeBytes ?? this.volumeSizeBytes,
      physicalDiskId: physicalDiskId ?? this.physicalDiskId,
      markerId: markerId ?? this.markerId,
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      rootRelPath: rootRelPath ?? this.rootRelPath,
      lastMountPath: lastMountPath ?? this.lastMountPath,
      connected: connected ?? this.connected,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      totalBytesLast: totalBytesLast ?? this.totalBytesLast,
      freeBytesLast: freeBytesLast ?? this.freeBytesLast,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      forgottenAt: forgottenAt ?? this.forgottenAt,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      devicePlatform: devicePlatform ?? this.devicePlatform,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (volumeGuid.present) {
      map['volume_guid'] = Variable<String>(volumeGuid.value);
    }
    if (volumeSerial.present) {
      map['volume_serial'] = Variable<int>(volumeSerial.value);
    }
    if (volumeLabel.present) {
      map['volume_label'] = Variable<String>(volumeLabel.value);
    }
    if (filesystem.present) {
      map['filesystem'] = Variable<String>(filesystem.value);
    }
    if (volumeSizeBytes.present) {
      map['volume_size_bytes'] = Variable<int>(volumeSizeBytes.value);
    }
    if (physicalDiskId.present) {
      map['physical_disk_id'] = Variable<int>(physicalDiskId.value);
    }
    if (markerId.present) {
      map['marker_id'] = Variable<String>(markerId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deviceModel.present) {
      map['device_model'] = Variable<String>(deviceModel.value);
    }
    if (rootRelPath.present) {
      map['root_rel_path'] = Variable<String>(rootRelPath.value);
    }
    if (lastMountPath.present) {
      map['last_mount_path'] = Variable<String>(lastMountPath.value);
    }
    if (connected.present) {
      map['connected'] = Variable<bool>(connected.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<int>(lastConnectedAt.value);
    }
    if (totalBytesLast.present) {
      map['total_bytes_last'] = Variable<int>(totalBytesLast.value);
    }
    if (freeBytesLast.present) {
      map['free_bytes_last'] = Variable<int>(freeBytesLast.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (forgottenAt.present) {
      map['forgotten_at'] = Variable<int>(forgottenAt.value);
    }
    if (deviceSerial.present) {
      map['device_serial'] = Variable<String>(deviceSerial.value);
    }
    if (devicePlatform.present) {
      map['device_platform'] = Variable<String>(devicePlatform.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('volumeGuid: $volumeGuid, ')
          ..write('volumeSerial: $volumeSerial, ')
          ..write('volumeLabel: $volumeLabel, ')
          ..write('filesystem: $filesystem, ')
          ..write('volumeSizeBytes: $volumeSizeBytes, ')
          ..write('physicalDiskId: $physicalDiskId, ')
          ..write('markerId: $markerId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceModel: $deviceModel, ')
          ..write('rootRelPath: $rootRelPath, ')
          ..write('lastMountPath: $lastMountPath, ')
          ..write('connected: $connected, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('totalBytesLast: $totalBytesLast, ')
          ..write('freeBytesLast: $freeBytesLast, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('forgottenAt: $forgottenAt, ')
          ..write('deviceSerial: $deviceSerial, ')
          ..write('devicePlatform: $devicePlatform, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Scans extends Table with TableInfo<Scans, ScanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Scans(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta('sourceId');
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES sources(id)',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'full\', \'incremental\'))',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (status IN (\'running\', \'paused\', \'interrupted\', \'completed\', \'cancelled\', \'failed\'))',
  );
  static const VerificationMeta _coverageMeta = const VerificationMeta('coverage');
  late final GeneratedColumn<String> coverage = GeneratedColumn<String>(
    'coverage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (coverage IN (\'complete\', \'partial\'))',
  );
  static const VerificationMeta _mountPathUsedMeta = const VerificationMeta('mountPathUsed');
  late final GeneratedColumn<String> mountPathUsed = GeneratedColumn<String>(
    'mount_path_used',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta('finishedAt');
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dirsDoneMeta = const VerificationMeta('dirsDone');
  late final GeneratedColumn<int> dirsDone = GeneratedColumn<int>(
    'dirs_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _filesSeenMeta = const VerificationMeta('filesSeen');
  late final GeneratedColumn<int> filesSeen = GeneratedColumn<int>(
    'files_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _bytesSeenMeta = const VerificationMeta('bytesSeen');
  late final GeneratedColumn<int> bytesSeen = GeneratedColumn<int>(
    'bytes_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _errorCountMeta = const VerificationMeta('errorCount');
  late final GeneratedColumn<int> errorCount = GeneratedColumn<int>(
    'error_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    kind,
    status,
    coverage,
    mountPathUsed,
    startedAt,
    finishedAt,
    dirsDone,
    filesSeen,
    bytesSeen,
    errorCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scans';
  @override
  VerificationContext validateIntegrity(Insertable<ScanRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta, sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('coverage')) {
      context.handle(_coverageMeta, coverage.isAcceptableOrUnknown(data['coverage']!, _coverageMeta));
    }
    if (data.containsKey('mount_path_used')) {
      context.handle(
        _mountPathUsedMeta,
        mountPathUsed.isAcceptableOrUnknown(data['mount_path_used']!, _mountPathUsedMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(_finishedAtMeta, finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta));
    }
    if (data.containsKey('dirs_done')) {
      context.handle(_dirsDoneMeta, dirsDone.isAcceptableOrUnknown(data['dirs_done']!, _dirsDoneMeta));
    }
    if (data.containsKey('files_seen')) {
      context.handle(_filesSeenMeta, filesSeen.isAcceptableOrUnknown(data['files_seen']!, _filesSeenMeta));
    }
    if (data.containsKey('bytes_seen')) {
      context.handle(_bytesSeenMeta, bytesSeen.isAcceptableOrUnknown(data['bytes_seen']!, _bytesSeenMeta));
    }
    if (data.containsKey('error_count')) {
      context.handle(_errorCountMeta, errorCount.isAcceptableOrUnknown(data['error_count']!, _errorCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      coverage: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}coverage']),
      mountPathUsed: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mount_path_used']),
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      finishedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}finished_at']),
      dirsDone: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}dirs_done'])!,
      filesSeen: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}files_seen'])!,
      bytesSeen: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}bytes_seen'])!,
      errorCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}error_count'])!,
    );
  }

  @override
  Scans createAlias(String alias) {
    return Scans(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ScanRow extends DataClass implements Insertable<ScanRow> {
  final int id;
  final String sourceId;
  final String kind;
  final String status;
  final String? coverage;
  final String? mountPathUsed;
  final int startedAt;
  final int? finishedAt;
  final int dirsDone;
  final int filesSeen;
  final int bytesSeen;
  final int errorCount;
  const ScanRow({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.status,
    this.coverage,
    this.mountPathUsed,
    required this.startedAt,
    this.finishedAt,
    required this.dirsDone,
    required this.filesSeen,
    required this.bytesSeen,
    required this.errorCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || coverage != null) {
      map['coverage'] = Variable<String>(coverage);
    }
    if (!nullToAbsent || mountPathUsed != null) {
      map['mount_path_used'] = Variable<String>(mountPathUsed);
    }
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    map['dirs_done'] = Variable<int>(dirsDone);
    map['files_seen'] = Variable<int>(filesSeen);
    map['bytes_seen'] = Variable<int>(bytesSeen);
    map['error_count'] = Variable<int>(errorCount);
    return map;
  }

  ScansCompanion toCompanion(bool nullToAbsent) {
    return ScansCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      kind: Value(kind),
      status: Value(status),
      coverage: coverage == null && nullToAbsent ? const Value.absent() : Value(coverage),
      mountPathUsed: mountPathUsed == null && nullToAbsent ? const Value.absent() : Value(mountPathUsed),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent ? const Value.absent() : Value(finishedAt),
      dirsDone: Value(dirsDone),
      filesSeen: Value(filesSeen),
      bytesSeen: Value(bytesSeen),
      errorCount: Value(errorCount),
    );
  }

  factory ScanRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['source_id']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      coverage: serializer.fromJson<String?>(json['coverage']),
      mountPathUsed: serializer.fromJson<String?>(json['mount_path_used']),
      startedAt: serializer.fromJson<int>(json['started_at']),
      finishedAt: serializer.fromJson<int?>(json['finished_at']),
      dirsDone: serializer.fromJson<int>(json['dirs_done']),
      filesSeen: serializer.fromJson<int>(json['files_seen']),
      bytesSeen: serializer.fromJson<int>(json['bytes_seen']),
      errorCount: serializer.fromJson<int>(json['error_count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source_id': serializer.toJson<String>(sourceId),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'coverage': serializer.toJson<String?>(coverage),
      'mount_path_used': serializer.toJson<String?>(mountPathUsed),
      'started_at': serializer.toJson<int>(startedAt),
      'finished_at': serializer.toJson<int?>(finishedAt),
      'dirs_done': serializer.toJson<int>(dirsDone),
      'files_seen': serializer.toJson<int>(filesSeen),
      'bytes_seen': serializer.toJson<int>(bytesSeen),
      'error_count': serializer.toJson<int>(errorCount),
    };
  }

  ScanRow copyWith({
    int? id,
    String? sourceId,
    String? kind,
    String? status,
    Value<String?> coverage = const Value.absent(),
    Value<String?> mountPathUsed = const Value.absent(),
    int? startedAt,
    Value<int?> finishedAt = const Value.absent(),
    int? dirsDone,
    int? filesSeen,
    int? bytesSeen,
    int? errorCount,
  }) => ScanRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    coverage: coverage.present ? coverage.value : this.coverage,
    mountPathUsed: mountPathUsed.present ? mountPathUsed.value : this.mountPathUsed,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    dirsDone: dirsDone ?? this.dirsDone,
    filesSeen: filesSeen ?? this.filesSeen,
    bytesSeen: bytesSeen ?? this.bytesSeen,
    errorCount: errorCount ?? this.errorCount,
  );
  ScanRow copyWithCompanion(ScansCompanion data) {
    return ScanRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      coverage: data.coverage.present ? data.coverage.value : this.coverage,
      mountPathUsed: data.mountPathUsed.present ? data.mountPathUsed.value : this.mountPathUsed,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
      dirsDone: data.dirsDone.present ? data.dirsDone.value : this.dirsDone,
      filesSeen: data.filesSeen.present ? data.filesSeen.value : this.filesSeen,
      bytesSeen: data.bytesSeen.present ? data.bytesSeen.value : this.bytesSeen,
      errorCount: data.errorCount.present ? data.errorCount.value : this.errorCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('coverage: $coverage, ')
          ..write('mountPathUsed: $mountPathUsed, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('dirsDone: $dirsDone, ')
          ..write('filesSeen: $filesSeen, ')
          ..write('bytesSeen: $bytesSeen, ')
          ..write('errorCount: $errorCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    kind,
    status,
    coverage,
    mountPathUsed,
    startedAt,
    finishedAt,
    dirsDone,
    filesSeen,
    bytesSeen,
    errorCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.coverage == this.coverage &&
          other.mountPathUsed == this.mountPathUsed &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.dirsDone == this.dirsDone &&
          other.filesSeen == this.filesSeen &&
          other.bytesSeen == this.bytesSeen &&
          other.errorCount == this.errorCount);
}

class ScansCompanion extends UpdateCompanion<ScanRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<String> kind;
  final Value<String> status;
  final Value<String?> coverage;
  final Value<String?> mountPathUsed;
  final Value<int> startedAt;
  final Value<int?> finishedAt;
  final Value<int> dirsDone;
  final Value<int> filesSeen;
  final Value<int> bytesSeen;
  final Value<int> errorCount;
  const ScansCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.coverage = const Value.absent(),
    this.mountPathUsed = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.dirsDone = const Value.absent(),
    this.filesSeen = const Value.absent(),
    this.bytesSeen = const Value.absent(),
    this.errorCount = const Value.absent(),
  });
  ScansCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required String kind,
    required String status,
    this.coverage = const Value.absent(),
    this.mountPathUsed = const Value.absent(),
    required int startedAt,
    this.finishedAt = const Value.absent(),
    this.dirsDone = const Value.absent(),
    this.filesSeen = const Value.absent(),
    this.bytesSeen = const Value.absent(),
    this.errorCount = const Value.absent(),
  }) : sourceId = Value(sourceId),
       kind = Value(kind),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<ScanRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? coverage,
    Expression<String>? mountPathUsed,
    Expression<int>? startedAt,
    Expression<int>? finishedAt,
    Expression<int>? dirsDone,
    Expression<int>? filesSeen,
    Expression<int>? bytesSeen,
    Expression<int>? errorCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (coverage != null) 'coverage': coverage,
      if (mountPathUsed != null) 'mount_path_used': mountPathUsed,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (dirsDone != null) 'dirs_done': dirsDone,
      if (filesSeen != null) 'files_seen': filesSeen,
      if (bytesSeen != null) 'bytes_seen': bytesSeen,
      if (errorCount != null) 'error_count': errorCount,
    });
  }

  ScansCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<String>? kind,
    Value<String>? status,
    Value<String?>? coverage,
    Value<String?>? mountPathUsed,
    Value<int>? startedAt,
    Value<int?>? finishedAt,
    Value<int>? dirsDone,
    Value<int>? filesSeen,
    Value<int>? bytesSeen,
    Value<int>? errorCount,
  }) {
    return ScansCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      coverage: coverage ?? this.coverage,
      mountPathUsed: mountPathUsed ?? this.mountPathUsed,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      dirsDone: dirsDone ?? this.dirsDone,
      filesSeen: filesSeen ?? this.filesSeen,
      bytesSeen: bytesSeen ?? this.bytesSeen,
      errorCount: errorCount ?? this.errorCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (coverage.present) {
      map['coverage'] = Variable<String>(coverage.value);
    }
    if (mountPathUsed.present) {
      map['mount_path_used'] = Variable<String>(mountPathUsed.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (dirsDone.present) {
      map['dirs_done'] = Variable<int>(dirsDone.value);
    }
    if (filesSeen.present) {
      map['files_seen'] = Variable<int>(filesSeen.value);
    }
    if (bytesSeen.present) {
      map['bytes_seen'] = Variable<int>(bytesSeen.value);
    }
    if (errorCount.present) {
      map['error_count'] = Variable<int>(errorCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScansCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('coverage: $coverage, ')
          ..write('mountPathUsed: $mountPathUsed, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('dirsDone: $dirsDone, ')
          ..write('filesSeen: $filesSeen, ')
          ..write('bytesSeen: $bytesSeen, ')
          ..write('errorCount: $errorCount')
          ..write(')'))
        .toString();
  }
}

class ScanDirs extends Table with TableInfo<ScanDirs, ScanDirRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ScanDirs(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  late final GeneratedColumn<int> scanId = GeneratedColumn<int>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES scans(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta('relPath');
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (status IN (\'pending\', \'done\', \'error\', \'excluded\'))',
  );
  @override
  List<GeneratedColumn> get $columns => [scanId, relPath, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_dirs';
  @override
  VerificationContext validateIntegrity(Insertable<ScanDirRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scan_id')) {
      context.handle(_scanIdMeta, scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta));
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(_relPathMeta, relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta));
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scanId, relPath};
  @override
  ScanDirRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanDirRow(
      scanId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}scan_id'])!,
      relPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}rel_path'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  ScanDirs createAlias(String alias) {
    return ScanDirs(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  List<String> get customConstraints => const ['PRIMARY KEY(scan_id, rel_path)'];
  @override
  bool get dontWriteConstraints => true;
}

class ScanDirRow extends DataClass implements Insertable<ScanDirRow> {
  final int scanId;
  final String relPath;
  final String status;
  const ScanDirRow({required this.scanId, required this.relPath, required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scan_id'] = Variable<int>(scanId);
    map['rel_path'] = Variable<String>(relPath);
    map['status'] = Variable<String>(status);
    return map;
  }

  ScanDirsCompanion toCompanion(bool nullToAbsent) {
    return ScanDirsCompanion(scanId: Value(scanId), relPath: Value(relPath), status: Value(status));
  }

  factory ScanDirRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanDirRow(
      scanId: serializer.fromJson<int>(json['scan_id']),
      relPath: serializer.fromJson<String>(json['rel_path']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scan_id': serializer.toJson<int>(scanId),
      'rel_path': serializer.toJson<String>(relPath),
      'status': serializer.toJson<String>(status),
    };
  }

  ScanDirRow copyWith({int? scanId, String? relPath, String? status}) =>
      ScanDirRow(scanId: scanId ?? this.scanId, relPath: relPath ?? this.relPath, status: status ?? this.status);
  ScanDirRow copyWithCompanion(ScanDirsCompanion data) {
    return ScanDirRow(
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanDirRow(')
          ..write('scanId: $scanId, ')
          ..write('relPath: $relPath, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scanId, relPath, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanDirRow &&
          other.scanId == this.scanId &&
          other.relPath == this.relPath &&
          other.status == this.status);
}

class ScanDirsCompanion extends UpdateCompanion<ScanDirRow> {
  final Value<int> scanId;
  final Value<String> relPath;
  final Value<String> status;
  const ScanDirsCompanion({
    this.scanId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.status = const Value.absent(),
  });
  ScanDirsCompanion.insert({required int scanId, required String relPath, required String status})
    : scanId = Value(scanId),
      relPath = Value(relPath),
      status = Value(status);
  static Insertable<ScanDirRow> custom({
    Expression<int>? scanId,
    Expression<String>? relPath,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (scanId != null) 'scan_id': scanId,
      if (relPath != null) 'rel_path': relPath,
      if (status != null) 'status': status,
    });
  }

  ScanDirsCompanion copyWith({Value<int>? scanId, Value<String>? relPath, Value<String>? status}) {
    return ScanDirsCompanion(
      scanId: scanId ?? this.scanId,
      relPath: relPath ?? this.relPath,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scanId.present) {
      map['scan_id'] = Variable<int>(scanId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanDirsCompanion(')
          ..write('scanId: $scanId, ')
          ..write('relPath: $relPath, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class ScanErrors extends Table with TableInfo<ScanErrors, ScanErrorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ScanErrors(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  late final GeneratedColumn<int> scanId = GeneratedColumn<int>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES scans(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta('relPath');
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'access_denied\', \'path_too_long\', \'io_error\', \'reparse_point_skipped\', \'device_disconnected\', \'other\'))',
  );
  static const VerificationMeta _win32CodeMeta = const VerificationMeta('win32Code');
  late final GeneratedColumn<int> win32Code = GeneratedColumn<int>(
    'win32_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _messageMeta = const VerificationMeta('message');
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, scanId, relPath, kind, win32Code, message, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_errors';
  @override
  VerificationContext validateIntegrity(Insertable<ScanErrorRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scan_id')) {
      context.handle(_scanIdMeta, scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta));
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(_relPathMeta, relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta));
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('win32_code')) {
      context.handle(_win32CodeMeta, win32Code.isAcceptableOrUnknown(data['win32_code']!, _win32CodeMeta));
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta, message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanErrorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanErrorRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      scanId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}scan_id'])!,
      relPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}rel_path'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      win32Code: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}win32_code']),
      message: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}message']),
      at: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}at'])!,
    );
  }

  @override
  ScanErrors createAlias(String alias) {
    return ScanErrors(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ScanErrorRow extends DataClass implements Insertable<ScanErrorRow> {
  final int id;
  final int scanId;
  final String relPath;
  final String kind;
  final int? win32Code;
  final String? message;
  final int at;
  const ScanErrorRow({
    required this.id,
    required this.scanId,
    required this.relPath,
    required this.kind,
    this.win32Code,
    this.message,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scan_id'] = Variable<int>(scanId);
    map['rel_path'] = Variable<String>(relPath);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || win32Code != null) {
      map['win32_code'] = Variable<int>(win32Code);
    }
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    map['at'] = Variable<int>(at);
    return map;
  }

  ScanErrorsCompanion toCompanion(bool nullToAbsent) {
    return ScanErrorsCompanion(
      id: Value(id),
      scanId: Value(scanId),
      relPath: Value(relPath),
      kind: Value(kind),
      win32Code: win32Code == null && nullToAbsent ? const Value.absent() : Value(win32Code),
      message: message == null && nullToAbsent ? const Value.absent() : Value(message),
      at: Value(at),
    );
  }

  factory ScanErrorRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanErrorRow(
      id: serializer.fromJson<int>(json['id']),
      scanId: serializer.fromJson<int>(json['scan_id']),
      relPath: serializer.fromJson<String>(json['rel_path']),
      kind: serializer.fromJson<String>(json['kind']),
      win32Code: serializer.fromJson<int?>(json['win32_code']),
      message: serializer.fromJson<String?>(json['message']),
      at: serializer.fromJson<int>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scan_id': serializer.toJson<int>(scanId),
      'rel_path': serializer.toJson<String>(relPath),
      'kind': serializer.toJson<String>(kind),
      'win32_code': serializer.toJson<int?>(win32Code),
      'message': serializer.toJson<String?>(message),
      'at': serializer.toJson<int>(at),
    };
  }

  ScanErrorRow copyWith({
    int? id,
    int? scanId,
    String? relPath,
    String? kind,
    Value<int?> win32Code = const Value.absent(),
    Value<String?> message = const Value.absent(),
    int? at,
  }) => ScanErrorRow(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    relPath: relPath ?? this.relPath,
    kind: kind ?? this.kind,
    win32Code: win32Code.present ? win32Code.value : this.win32Code,
    message: message.present ? message.value : this.message,
    at: at ?? this.at,
  );
  ScanErrorRow copyWithCompanion(ScanErrorsCompanion data) {
    return ScanErrorRow(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      kind: data.kind.present ? data.kind.value : this.kind,
      win32Code: data.win32Code.present ? data.win32Code.value : this.win32Code,
      message: data.message.present ? data.message.value : this.message,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanErrorRow(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('relPath: $relPath, ')
          ..write('kind: $kind, ')
          ..write('win32Code: $win32Code, ')
          ..write('message: $message, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scanId, relPath, kind, win32Code, message, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanErrorRow &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.relPath == this.relPath &&
          other.kind == this.kind &&
          other.win32Code == this.win32Code &&
          other.message == this.message &&
          other.at == this.at);
}

class ScanErrorsCompanion extends UpdateCompanion<ScanErrorRow> {
  final Value<int> id;
  final Value<int> scanId;
  final Value<String> relPath;
  final Value<String> kind;
  final Value<int?> win32Code;
  final Value<String?> message;
  final Value<int> at;
  const ScanErrorsCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.kind = const Value.absent(),
    this.win32Code = const Value.absent(),
    this.message = const Value.absent(),
    this.at = const Value.absent(),
  });
  ScanErrorsCompanion.insert({
    this.id = const Value.absent(),
    required int scanId,
    required String relPath,
    required String kind,
    this.win32Code = const Value.absent(),
    this.message = const Value.absent(),
    required int at,
  }) : scanId = Value(scanId),
       relPath = Value(relPath),
       kind = Value(kind),
       at = Value(at);
  static Insertable<ScanErrorRow> custom({
    Expression<int>? id,
    Expression<int>? scanId,
    Expression<String>? relPath,
    Expression<String>? kind,
    Expression<int>? win32Code,
    Expression<String>? message,
    Expression<int>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (relPath != null) 'rel_path': relPath,
      if (kind != null) 'kind': kind,
      if (win32Code != null) 'win32_code': win32Code,
      if (message != null) 'message': message,
      if (at != null) 'at': at,
    });
  }

  ScanErrorsCompanion copyWith({
    Value<int>? id,
    Value<int>? scanId,
    Value<String>? relPath,
    Value<String>? kind,
    Value<int?>? win32Code,
    Value<String?>? message,
    Value<int>? at,
  }) {
    return ScanErrorsCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      relPath: relPath ?? this.relPath,
      kind: kind ?? this.kind,
      win32Code: win32Code ?? this.win32Code,
      message: message ?? this.message,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<int>(scanId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (win32Code.present) {
      map['win32_code'] = Variable<int>(win32Code.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanErrorsCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('relPath: $relPath, ')
          ..write('kind: $kind, ')
          ..write('win32Code: $win32Code, ')
          ..write('message: $message, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class Contents extends Table with TableInfo<Contents, ContentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Contents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  late final GeneratedColumn<Uint8List> sha256 = GeneratedColumn<Uint8List>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(sha256) = 32)',
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta('sizeBytes');
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta('mediaType');
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'unknown\' CHECK (media_type IN (\'photo\', \'video\', \'raw\', \'sidecar\', \'other\', \'unknown\'))',
    defaultValue: const CustomExpression('\'unknown\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, sha256, sizeBytes, mediaType, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contents';
  @override
  VerificationContext validateIntegrity(Insertable<ContentRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta, sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta, sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta, mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sha256, sizeBytes},
  ];
  @override
  ContentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sha256: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}sha256'])!,
      sizeBytes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      mediaType: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  Contents createAlias(String alias) {
    return Contents(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(sha256, size_bytes)'];
  @override
  bool get dontWriteConstraints => true;
}

class ContentRow extends DataClass implements Insertable<ContentRow> {
  final int id;
  final Uint8List sha256;
  final int sizeBytes;
  final String mediaType;
  final int createdAt;
  const ContentRow({
    required this.id,
    required this.sha256,
    required this.sizeBytes,
    required this.mediaType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sha256'] = Variable<Uint8List>(sha256);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['media_type'] = Variable<String>(mediaType);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ContentsCompanion toCompanion(bool nullToAbsent) {
    return ContentsCompanion(
      id: Value(id),
      sha256: Value(sha256),
      sizeBytes: Value(sizeBytes),
      mediaType: Value(mediaType),
      createdAt: Value(createdAt),
    );
  }

  factory ContentRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentRow(
      id: serializer.fromJson<int>(json['id']),
      sha256: serializer.fromJson<Uint8List>(json['sha256']),
      sizeBytes: serializer.fromJson<int>(json['size_bytes']),
      mediaType: serializer.fromJson<String>(json['media_type']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sha256': serializer.toJson<Uint8List>(sha256),
      'size_bytes': serializer.toJson<int>(sizeBytes),
      'media_type': serializer.toJson<String>(mediaType),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  ContentRow copyWith({int? id, Uint8List? sha256, int? sizeBytes, String? mediaType, int? createdAt}) => ContentRow(
    id: id ?? this.id,
    sha256: sha256 ?? this.sha256,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mediaType: mediaType ?? this.mediaType,
    createdAt: createdAt ?? this.createdAt,
  );
  ContentRow copyWithCompanion(ContentsCompanion data) {
    return ContentRow(
      id: data.id.present ? data.id.value : this.id,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentRow(')
          ..write('id: $id, ')
          ..write('sha256: $sha256, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mediaType: $mediaType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(sha256), sizeBytes, mediaType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentRow &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.sha256, this.sha256) &&
          other.sizeBytes == this.sizeBytes &&
          other.mediaType == this.mediaType &&
          other.createdAt == this.createdAt);
}

class ContentsCompanion extends UpdateCompanion<ContentRow> {
  final Value<int> id;
  final Value<Uint8List> sha256;
  final Value<int> sizeBytes;
  final Value<String> mediaType;
  final Value<int> createdAt;
  const ContentsCompanion({
    this.id = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ContentsCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List sha256,
    required int sizeBytes,
    this.mediaType = const Value.absent(),
    required int createdAt,
  }) : sha256 = Value(sha256),
       sizeBytes = Value(sizeBytes),
       createdAt = Value(createdAt);
  static Insertable<ContentRow> custom({
    Expression<int>? id,
    Expression<Uint8List>? sha256,
    Expression<int>? sizeBytes,
    Expression<String>? mediaType,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sha256 != null) 'sha256': sha256,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mediaType != null) 'media_type': mediaType,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ContentsCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? sha256,
    Value<int>? sizeBytes,
    Value<String>? mediaType,
    Value<int>? createdAt,
  }) {
    return ContentsCompanion(
      id: id ?? this.id,
      sha256: sha256 ?? this.sha256,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<Uint8List>(sha256.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentsCompanion(')
          ..write('id: $id, ')
          ..write('sha256: $sha256, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mediaType: $mediaType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class FileInstances extends Table with TableInfo<FileInstances, FileInstanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  FileInstances(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta('sourceId');
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES sources(id)',
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta('relPath');
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dirRelPathMeta = const VerificationMeta('dirRelPath');
  late final GeneratedColumn<String> dirRelPath = GeneratedColumn<String>(
    'dir_rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta('sizeBytes');
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _ctimeMeta = const VerificationMeta('ctime');
  late final GeneratedColumn<int> ctime = GeneratedColumn<int>(
    'ctime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _attributesMeta = const VerificationMeta('attributes');
  late final GeneratedColumn<int> attributes = GeneratedColumn<int>(
    'attributes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta('contentId');
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
    'content_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES contents(id)',
  );
  static const VerificationMeta _hashStatusMeta = const VerificationMeta('hashStatus');
  late final GeneratedColumn<String> hashStatus = GeneratedColumn<String>(
    'hash_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'pending\' CHECK (hash_status IN (\'pending\', \'done\', \'changed_during_read\', \'error\', \'not_applicable\'))',
    defaultValue: const CustomExpression('\'pending\''),
  );
  static const VerificationMeta _hashedSizeMeta = const VerificationMeta('hashedSize');
  late final GeneratedColumn<int> hashedSize = GeneratedColumn<int>(
    'hashed_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _hashedMtimeMeta = const VerificationMeta('hashedMtime');
  late final GeneratedColumn<int> hashedMtime = GeneratedColumn<int>(
    'hashed_mtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _hashedAtMeta = const VerificationMeta('hashedAt');
  late final GeneratedColumn<int> hashedAt = GeneratedColumn<int>(
    'hashed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastVerifiedAtMeta = const VerificationMeta('lastVerifiedAt');
  late final GeneratedColumn<int> lastVerifiedAt = GeneratedColumn<int>(
    'last_verified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta('availability');
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'present\' CHECK (availability IN (\'present\', \'cloud_only\', \'unreadable\', \'missing\'))',
    defaultValue: const CustomExpression('\'present\''),
  );
  static const VerificationMeta _integrityMeta = const VerificationMeta('integrity');
  late final GeneratedColumn<String> integrity = GeneratedColumn<String>(
    'integrity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'unknown\' CHECK (integrity IN (\'unknown\', \'ok\', \'changed\', \'possibly_corrupt\'))',
    defaultValue: const CustomExpression('\'unknown\''),
  );
  static const VerificationMeta _firstSeenScanIdMeta = const VerificationMeta('firstSeenScanId');
  late final GeneratedColumn<int> firstSeenScanId = GeneratedColumn<int>(
    'first_seen_scan_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES scans(id)',
  );
  static const VerificationMeta _lastSeenScanIdMeta = const VerificationMeta('lastSeenScanId');
  late final GeneratedColumn<int> lastSeenScanId = GeneratedColumn<int>(
    'last_seen_scan_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES scans(id)',
  );
  static const VerificationMeta _missingConfirmedAtMeta = const VerificationMeta('missingConfirmedAt');
  late final GeneratedColumn<int> missingConfirmedAt = GeneratedColumn<int>(
    'missing_confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _hashErrorMeta = const VerificationMeta('hashError');
  late final GeneratedColumn<String> hashError = GeneratedColumn<String>(
    'hash_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceObjectIdMeta = const VerificationMeta('deviceObjectId');
  late final GeneratedColumn<String> deviceObjectId = GeneratedColumn<String>(
    'device_object_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    relPath,
    dirRelPath,
    name,
    ext,
    sizeBytes,
    mtime,
    ctime,
    attributes,
    contentId,
    hashStatus,
    hashedSize,
    hashedMtime,
    hashedAt,
    lastVerifiedAt,
    availability,
    integrity,
    firstSeenScanId,
    lastSeenScanId,
    missingConfirmedAt,
    hashError,
    deviceObjectId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_instances';
  @override
  VerificationContext validateIntegrity(Insertable<FileInstanceRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta, sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(_relPathMeta, relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta));
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('dir_rel_path')) {
      context.handle(_dirRelPathMeta, dirRelPath.isAcceptableOrUnknown(data['dir_rel_path']!, _dirRelPathMeta));
    } else if (isInserting) {
      context.missing(_dirRelPathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ext')) {
      context.handle(_extMeta, ext.isAcceptableOrUnknown(data['ext']!, _extMeta));
    } else if (isInserting) {
      context.missing(_extMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta, sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(_mtimeMeta, mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta));
    }
    if (data.containsKey('ctime')) {
      context.handle(_ctimeMeta, ctime.isAcceptableOrUnknown(data['ctime']!, _ctimeMeta));
    }
    if (data.containsKey('attributes')) {
      context.handle(_attributesMeta, attributes.isAcceptableOrUnknown(data['attributes']!, _attributesMeta));
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta, contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    }
    if (data.containsKey('hash_status')) {
      context.handle(_hashStatusMeta, hashStatus.isAcceptableOrUnknown(data['hash_status']!, _hashStatusMeta));
    }
    if (data.containsKey('hashed_size')) {
      context.handle(_hashedSizeMeta, hashedSize.isAcceptableOrUnknown(data['hashed_size']!, _hashedSizeMeta));
    }
    if (data.containsKey('hashed_mtime')) {
      context.handle(_hashedMtimeMeta, hashedMtime.isAcceptableOrUnknown(data['hashed_mtime']!, _hashedMtimeMeta));
    }
    if (data.containsKey('hashed_at')) {
      context.handle(_hashedAtMeta, hashedAt.isAcceptableOrUnknown(data['hashed_at']!, _hashedAtMeta));
    }
    if (data.containsKey('last_verified_at')) {
      context.handle(
        _lastVerifiedAtMeta,
        lastVerifiedAt.isAcceptableOrUnknown(data['last_verified_at']!, _lastVerifiedAtMeta),
      );
    }
    if (data.containsKey('availability')) {
      context.handle(_availabilityMeta, availability.isAcceptableOrUnknown(data['availability']!, _availabilityMeta));
    }
    if (data.containsKey('integrity')) {
      context.handle(_integrityMeta, integrity.isAcceptableOrUnknown(data['integrity']!, _integrityMeta));
    }
    if (data.containsKey('first_seen_scan_id')) {
      context.handle(
        _firstSeenScanIdMeta,
        firstSeenScanId.isAcceptableOrUnknown(data['first_seen_scan_id']!, _firstSeenScanIdMeta),
      );
    }
    if (data.containsKey('last_seen_scan_id')) {
      context.handle(
        _lastSeenScanIdMeta,
        lastSeenScanId.isAcceptableOrUnknown(data['last_seen_scan_id']!, _lastSeenScanIdMeta),
      );
    }
    if (data.containsKey('missing_confirmed_at')) {
      context.handle(
        _missingConfirmedAtMeta,
        missingConfirmedAt.isAcceptableOrUnknown(data['missing_confirmed_at']!, _missingConfirmedAtMeta),
      );
    }
    if (data.containsKey('hash_error')) {
      context.handle(_hashErrorMeta, hashError.isAcceptableOrUnknown(data['hash_error']!, _hashErrorMeta));
    }
    if (data.containsKey('device_object_id')) {
      context.handle(
        _deviceObjectIdMeta,
        deviceObjectId.isAcceptableOrUnknown(data['device_object_id']!, _deviceObjectIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, relPath},
  ];
  @override
  FileInstanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileInstanceRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      relPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}rel_path'])!,
      dirRelPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}dir_rel_path'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      ext: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}ext'])!,
      sizeBytes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      mtime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}mtime']),
      ctime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}ctime']),
      attributes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}attributes']),
      contentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}content_id']),
      hashStatus: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hash_status'])!,
      hashedSize: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}hashed_size']),
      hashedMtime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}hashed_mtime']),
      hashedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}hashed_at']),
      lastVerifiedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}last_verified_at']),
      availability: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}availability'])!,
      integrity: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}integrity'])!,
      firstSeenScanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_scan_id'],
      ),
      lastSeenScanId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}last_seen_scan_id']),
      missingConfirmedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}missing_confirmed_at'],
      ),
      hashError: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hash_error']),
      deviceObjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_object_id'],
      ),
    );
  }

  @override
  FileInstances createAlias(String alias) {
    return FileInstances(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(source_id, rel_path)'];
  @override
  bool get dontWriteConstraints => true;
}

class FileInstanceRow extends DataClass implements Insertable<FileInstanceRow> {
  final int id;
  final String sourceId;
  final String relPath;
  final String dirRelPath;
  final String name;
  final String ext;
  final int sizeBytes;
  final int? mtime;
  final int? ctime;
  final int? attributes;
  final int? contentId;
  final String hashStatus;
  final int? hashedSize;
  final int? hashedMtime;
  final int? hashedAt;
  final int? lastVerifiedAt;
  final String availability;
  final String integrity;
  final int? firstSeenScanId;
  final int? lastSeenScanId;
  final int? missingConfirmedAt;
  final String? hashError;

  /// v2: motivo legível de hash_status error/changed_during_read
  final String? deviceObjectId;
  const FileInstanceRow({
    required this.id,
    required this.sourceId,
    required this.relPath,
    required this.dirRelPath,
    required this.name,
    required this.ext,
    required this.sizeBytes,
    this.mtime,
    this.ctime,
    this.attributes,
    this.contentId,
    required this.hashStatus,
    this.hashedSize,
    this.hashedMtime,
    this.hashedAt,
    this.lastVerifiedAt,
    required this.availability,
    required this.integrity,
    this.firstSeenScanId,
    this.lastSeenScanId,
    this.missingConfirmedAt,
    this.hashError,
    this.deviceObjectId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['rel_path'] = Variable<String>(relPath);
    map['dir_rel_path'] = Variable<String>(dirRelPath);
    map['name'] = Variable<String>(name);
    map['ext'] = Variable<String>(ext);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || mtime != null) {
      map['mtime'] = Variable<int>(mtime);
    }
    if (!nullToAbsent || ctime != null) {
      map['ctime'] = Variable<int>(ctime);
    }
    if (!nullToAbsent || attributes != null) {
      map['attributes'] = Variable<int>(attributes);
    }
    if (!nullToAbsent || contentId != null) {
      map['content_id'] = Variable<int>(contentId);
    }
    map['hash_status'] = Variable<String>(hashStatus);
    if (!nullToAbsent || hashedSize != null) {
      map['hashed_size'] = Variable<int>(hashedSize);
    }
    if (!nullToAbsent || hashedMtime != null) {
      map['hashed_mtime'] = Variable<int>(hashedMtime);
    }
    if (!nullToAbsent || hashedAt != null) {
      map['hashed_at'] = Variable<int>(hashedAt);
    }
    if (!nullToAbsent || lastVerifiedAt != null) {
      map['last_verified_at'] = Variable<int>(lastVerifiedAt);
    }
    map['availability'] = Variable<String>(availability);
    map['integrity'] = Variable<String>(integrity);
    if (!nullToAbsent || firstSeenScanId != null) {
      map['first_seen_scan_id'] = Variable<int>(firstSeenScanId);
    }
    if (!nullToAbsent || lastSeenScanId != null) {
      map['last_seen_scan_id'] = Variable<int>(lastSeenScanId);
    }
    if (!nullToAbsent || missingConfirmedAt != null) {
      map['missing_confirmed_at'] = Variable<int>(missingConfirmedAt);
    }
    if (!nullToAbsent || hashError != null) {
      map['hash_error'] = Variable<String>(hashError);
    }
    if (!nullToAbsent || deviceObjectId != null) {
      map['device_object_id'] = Variable<String>(deviceObjectId);
    }
    return map;
  }

  FileInstancesCompanion toCompanion(bool nullToAbsent) {
    return FileInstancesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      relPath: Value(relPath),
      dirRelPath: Value(dirRelPath),
      name: Value(name),
      ext: Value(ext),
      sizeBytes: Value(sizeBytes),
      mtime: mtime == null && nullToAbsent ? const Value.absent() : Value(mtime),
      ctime: ctime == null && nullToAbsent ? const Value.absent() : Value(ctime),
      attributes: attributes == null && nullToAbsent ? const Value.absent() : Value(attributes),
      contentId: contentId == null && nullToAbsent ? const Value.absent() : Value(contentId),
      hashStatus: Value(hashStatus),
      hashedSize: hashedSize == null && nullToAbsent ? const Value.absent() : Value(hashedSize),
      hashedMtime: hashedMtime == null && nullToAbsent ? const Value.absent() : Value(hashedMtime),
      hashedAt: hashedAt == null && nullToAbsent ? const Value.absent() : Value(hashedAt),
      lastVerifiedAt: lastVerifiedAt == null && nullToAbsent ? const Value.absent() : Value(lastVerifiedAt),
      availability: Value(availability),
      integrity: Value(integrity),
      firstSeenScanId: firstSeenScanId == null && nullToAbsent ? const Value.absent() : Value(firstSeenScanId),
      lastSeenScanId: lastSeenScanId == null && nullToAbsent ? const Value.absent() : Value(lastSeenScanId),
      missingConfirmedAt: missingConfirmedAt == null && nullToAbsent ? const Value.absent() : Value(missingConfirmedAt),
      hashError: hashError == null && nullToAbsent ? const Value.absent() : Value(hashError),
      deviceObjectId: deviceObjectId == null && nullToAbsent ? const Value.absent() : Value(deviceObjectId),
    );
  }

  factory FileInstanceRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileInstanceRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['source_id']),
      relPath: serializer.fromJson<String>(json['rel_path']),
      dirRelPath: serializer.fromJson<String>(json['dir_rel_path']),
      name: serializer.fromJson<String>(json['name']),
      ext: serializer.fromJson<String>(json['ext']),
      sizeBytes: serializer.fromJson<int>(json['size_bytes']),
      mtime: serializer.fromJson<int?>(json['mtime']),
      ctime: serializer.fromJson<int?>(json['ctime']),
      attributes: serializer.fromJson<int?>(json['attributes']),
      contentId: serializer.fromJson<int?>(json['content_id']),
      hashStatus: serializer.fromJson<String>(json['hash_status']),
      hashedSize: serializer.fromJson<int?>(json['hashed_size']),
      hashedMtime: serializer.fromJson<int?>(json['hashed_mtime']),
      hashedAt: serializer.fromJson<int?>(json['hashed_at']),
      lastVerifiedAt: serializer.fromJson<int?>(json['last_verified_at']),
      availability: serializer.fromJson<String>(json['availability']),
      integrity: serializer.fromJson<String>(json['integrity']),
      firstSeenScanId: serializer.fromJson<int?>(json['first_seen_scan_id']),
      lastSeenScanId: serializer.fromJson<int?>(json['last_seen_scan_id']),
      missingConfirmedAt: serializer.fromJson<int?>(json['missing_confirmed_at']),
      hashError: serializer.fromJson<String?>(json['hash_error']),
      deviceObjectId: serializer.fromJson<String?>(json['device_object_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source_id': serializer.toJson<String>(sourceId),
      'rel_path': serializer.toJson<String>(relPath),
      'dir_rel_path': serializer.toJson<String>(dirRelPath),
      'name': serializer.toJson<String>(name),
      'ext': serializer.toJson<String>(ext),
      'size_bytes': serializer.toJson<int>(sizeBytes),
      'mtime': serializer.toJson<int?>(mtime),
      'ctime': serializer.toJson<int?>(ctime),
      'attributes': serializer.toJson<int?>(attributes),
      'content_id': serializer.toJson<int?>(contentId),
      'hash_status': serializer.toJson<String>(hashStatus),
      'hashed_size': serializer.toJson<int?>(hashedSize),
      'hashed_mtime': serializer.toJson<int?>(hashedMtime),
      'hashed_at': serializer.toJson<int?>(hashedAt),
      'last_verified_at': serializer.toJson<int?>(lastVerifiedAt),
      'availability': serializer.toJson<String>(availability),
      'integrity': serializer.toJson<String>(integrity),
      'first_seen_scan_id': serializer.toJson<int?>(firstSeenScanId),
      'last_seen_scan_id': serializer.toJson<int?>(lastSeenScanId),
      'missing_confirmed_at': serializer.toJson<int?>(missingConfirmedAt),
      'hash_error': serializer.toJson<String?>(hashError),
      'device_object_id': serializer.toJson<String?>(deviceObjectId),
    };
  }

  FileInstanceRow copyWith({
    int? id,
    String? sourceId,
    String? relPath,
    String? dirRelPath,
    String? name,
    String? ext,
    int? sizeBytes,
    Value<int?> mtime = const Value.absent(),
    Value<int?> ctime = const Value.absent(),
    Value<int?> attributes = const Value.absent(),
    Value<int?> contentId = const Value.absent(),
    String? hashStatus,
    Value<int?> hashedSize = const Value.absent(),
    Value<int?> hashedMtime = const Value.absent(),
    Value<int?> hashedAt = const Value.absent(),
    Value<int?> lastVerifiedAt = const Value.absent(),
    String? availability,
    String? integrity,
    Value<int?> firstSeenScanId = const Value.absent(),
    Value<int?> lastSeenScanId = const Value.absent(),
    Value<int?> missingConfirmedAt = const Value.absent(),
    Value<String?> hashError = const Value.absent(),
    Value<String?> deviceObjectId = const Value.absent(),
  }) => FileInstanceRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    relPath: relPath ?? this.relPath,
    dirRelPath: dirRelPath ?? this.dirRelPath,
    name: name ?? this.name,
    ext: ext ?? this.ext,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mtime: mtime.present ? mtime.value : this.mtime,
    ctime: ctime.present ? ctime.value : this.ctime,
    attributes: attributes.present ? attributes.value : this.attributes,
    contentId: contentId.present ? contentId.value : this.contentId,
    hashStatus: hashStatus ?? this.hashStatus,
    hashedSize: hashedSize.present ? hashedSize.value : this.hashedSize,
    hashedMtime: hashedMtime.present ? hashedMtime.value : this.hashedMtime,
    hashedAt: hashedAt.present ? hashedAt.value : this.hashedAt,
    lastVerifiedAt: lastVerifiedAt.present ? lastVerifiedAt.value : this.lastVerifiedAt,
    availability: availability ?? this.availability,
    integrity: integrity ?? this.integrity,
    firstSeenScanId: firstSeenScanId.present ? firstSeenScanId.value : this.firstSeenScanId,
    lastSeenScanId: lastSeenScanId.present ? lastSeenScanId.value : this.lastSeenScanId,
    missingConfirmedAt: missingConfirmedAt.present ? missingConfirmedAt.value : this.missingConfirmedAt,
    hashError: hashError.present ? hashError.value : this.hashError,
    deviceObjectId: deviceObjectId.present ? deviceObjectId.value : this.deviceObjectId,
  );
  FileInstanceRow copyWithCompanion(FileInstancesCompanion data) {
    return FileInstanceRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      dirRelPath: data.dirRelPath.present ? data.dirRelPath.value : this.dirRelPath,
      name: data.name.present ? data.name.value : this.name,
      ext: data.ext.present ? data.ext.value : this.ext,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      ctime: data.ctime.present ? data.ctime.value : this.ctime,
      attributes: data.attributes.present ? data.attributes.value : this.attributes,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      hashStatus: data.hashStatus.present ? data.hashStatus.value : this.hashStatus,
      hashedSize: data.hashedSize.present ? data.hashedSize.value : this.hashedSize,
      hashedMtime: data.hashedMtime.present ? data.hashedMtime.value : this.hashedMtime,
      hashedAt: data.hashedAt.present ? data.hashedAt.value : this.hashedAt,
      lastVerifiedAt: data.lastVerifiedAt.present ? data.lastVerifiedAt.value : this.lastVerifiedAt,
      availability: data.availability.present ? data.availability.value : this.availability,
      integrity: data.integrity.present ? data.integrity.value : this.integrity,
      firstSeenScanId: data.firstSeenScanId.present ? data.firstSeenScanId.value : this.firstSeenScanId,
      lastSeenScanId: data.lastSeenScanId.present ? data.lastSeenScanId.value : this.lastSeenScanId,
      missingConfirmedAt: data.missingConfirmedAt.present ? data.missingConfirmedAt.value : this.missingConfirmedAt,
      hashError: data.hashError.present ? data.hashError.value : this.hashError,
      deviceObjectId: data.deviceObjectId.present ? data.deviceObjectId.value : this.deviceObjectId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileInstanceRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('relPath: $relPath, ')
          ..write('dirRelPath: $dirRelPath, ')
          ..write('name: $name, ')
          ..write('ext: $ext, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtime: $mtime, ')
          ..write('ctime: $ctime, ')
          ..write('attributes: $attributes, ')
          ..write('contentId: $contentId, ')
          ..write('hashStatus: $hashStatus, ')
          ..write('hashedSize: $hashedSize, ')
          ..write('hashedMtime: $hashedMtime, ')
          ..write('hashedAt: $hashedAt, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('availability: $availability, ')
          ..write('integrity: $integrity, ')
          ..write('firstSeenScanId: $firstSeenScanId, ')
          ..write('lastSeenScanId: $lastSeenScanId, ')
          ..write('missingConfirmedAt: $missingConfirmedAt, ')
          ..write('hashError: $hashError, ')
          ..write('deviceObjectId: $deviceObjectId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sourceId,
    relPath,
    dirRelPath,
    name,
    ext,
    sizeBytes,
    mtime,
    ctime,
    attributes,
    contentId,
    hashStatus,
    hashedSize,
    hashedMtime,
    hashedAt,
    lastVerifiedAt,
    availability,
    integrity,
    firstSeenScanId,
    lastSeenScanId,
    missingConfirmedAt,
    hashError,
    deviceObjectId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileInstanceRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.relPath == this.relPath &&
          other.dirRelPath == this.dirRelPath &&
          other.name == this.name &&
          other.ext == this.ext &&
          other.sizeBytes == this.sizeBytes &&
          other.mtime == this.mtime &&
          other.ctime == this.ctime &&
          other.attributes == this.attributes &&
          other.contentId == this.contentId &&
          other.hashStatus == this.hashStatus &&
          other.hashedSize == this.hashedSize &&
          other.hashedMtime == this.hashedMtime &&
          other.hashedAt == this.hashedAt &&
          other.lastVerifiedAt == this.lastVerifiedAt &&
          other.availability == this.availability &&
          other.integrity == this.integrity &&
          other.firstSeenScanId == this.firstSeenScanId &&
          other.lastSeenScanId == this.lastSeenScanId &&
          other.missingConfirmedAt == this.missingConfirmedAt &&
          other.hashError == this.hashError &&
          other.deviceObjectId == this.deviceObjectId);
}

class FileInstancesCompanion extends UpdateCompanion<FileInstanceRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<String> relPath;
  final Value<String> dirRelPath;
  final Value<String> name;
  final Value<String> ext;
  final Value<int> sizeBytes;
  final Value<int?> mtime;
  final Value<int?> ctime;
  final Value<int?> attributes;
  final Value<int?> contentId;
  final Value<String> hashStatus;
  final Value<int?> hashedSize;
  final Value<int?> hashedMtime;
  final Value<int?> hashedAt;
  final Value<int?> lastVerifiedAt;
  final Value<String> availability;
  final Value<String> integrity;
  final Value<int?> firstSeenScanId;
  final Value<int?> lastSeenScanId;
  final Value<int?> missingConfirmedAt;
  final Value<String?> hashError;
  final Value<String?> deviceObjectId;
  const FileInstancesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.dirRelPath = const Value.absent(),
    this.name = const Value.absent(),
    this.ext = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtime = const Value.absent(),
    this.ctime = const Value.absent(),
    this.attributes = const Value.absent(),
    this.contentId = const Value.absent(),
    this.hashStatus = const Value.absent(),
    this.hashedSize = const Value.absent(),
    this.hashedMtime = const Value.absent(),
    this.hashedAt = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.availability = const Value.absent(),
    this.integrity = const Value.absent(),
    this.firstSeenScanId = const Value.absent(),
    this.lastSeenScanId = const Value.absent(),
    this.missingConfirmedAt = const Value.absent(),
    this.hashError = const Value.absent(),
    this.deviceObjectId = const Value.absent(),
  });
  FileInstancesCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required String relPath,
    required String dirRelPath,
    required String name,
    required String ext,
    required int sizeBytes,
    this.mtime = const Value.absent(),
    this.ctime = const Value.absent(),
    this.attributes = const Value.absent(),
    this.contentId = const Value.absent(),
    this.hashStatus = const Value.absent(),
    this.hashedSize = const Value.absent(),
    this.hashedMtime = const Value.absent(),
    this.hashedAt = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.availability = const Value.absent(),
    this.integrity = const Value.absent(),
    this.firstSeenScanId = const Value.absent(),
    this.lastSeenScanId = const Value.absent(),
    this.missingConfirmedAt = const Value.absent(),
    this.hashError = const Value.absent(),
    this.deviceObjectId = const Value.absent(),
  }) : sourceId = Value(sourceId),
       relPath = Value(relPath),
       dirRelPath = Value(dirRelPath),
       name = Value(name),
       ext = Value(ext),
       sizeBytes = Value(sizeBytes);
  static Insertable<FileInstanceRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? relPath,
    Expression<String>? dirRelPath,
    Expression<String>? name,
    Expression<String>? ext,
    Expression<int>? sizeBytes,
    Expression<int>? mtime,
    Expression<int>? ctime,
    Expression<int>? attributes,
    Expression<int>? contentId,
    Expression<String>? hashStatus,
    Expression<int>? hashedSize,
    Expression<int>? hashedMtime,
    Expression<int>? hashedAt,
    Expression<int>? lastVerifiedAt,
    Expression<String>? availability,
    Expression<String>? integrity,
    Expression<int>? firstSeenScanId,
    Expression<int>? lastSeenScanId,
    Expression<int>? missingConfirmedAt,
    Expression<String>? hashError,
    Expression<String>? deviceObjectId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (relPath != null) 'rel_path': relPath,
      if (dirRelPath != null) 'dir_rel_path': dirRelPath,
      if (name != null) 'name': name,
      if (ext != null) 'ext': ext,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mtime != null) 'mtime': mtime,
      if (ctime != null) 'ctime': ctime,
      if (attributes != null) 'attributes': attributes,
      if (contentId != null) 'content_id': contentId,
      if (hashStatus != null) 'hash_status': hashStatus,
      if (hashedSize != null) 'hashed_size': hashedSize,
      if (hashedMtime != null) 'hashed_mtime': hashedMtime,
      if (hashedAt != null) 'hashed_at': hashedAt,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt,
      if (availability != null) 'availability': availability,
      if (integrity != null) 'integrity': integrity,
      if (firstSeenScanId != null) 'first_seen_scan_id': firstSeenScanId,
      if (lastSeenScanId != null) 'last_seen_scan_id': lastSeenScanId,
      if (missingConfirmedAt != null) 'missing_confirmed_at': missingConfirmedAt,
      if (hashError != null) 'hash_error': hashError,
      if (deviceObjectId != null) 'device_object_id': deviceObjectId,
    });
  }

  FileInstancesCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<String>? relPath,
    Value<String>? dirRelPath,
    Value<String>? name,
    Value<String>? ext,
    Value<int>? sizeBytes,
    Value<int?>? mtime,
    Value<int?>? ctime,
    Value<int?>? attributes,
    Value<int?>? contentId,
    Value<String>? hashStatus,
    Value<int?>? hashedSize,
    Value<int?>? hashedMtime,
    Value<int?>? hashedAt,
    Value<int?>? lastVerifiedAt,
    Value<String>? availability,
    Value<String>? integrity,
    Value<int?>? firstSeenScanId,
    Value<int?>? lastSeenScanId,
    Value<int?>? missingConfirmedAt,
    Value<String?>? hashError,
    Value<String?>? deviceObjectId,
  }) {
    return FileInstancesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      relPath: relPath ?? this.relPath,
      dirRelPath: dirRelPath ?? this.dirRelPath,
      name: name ?? this.name,
      ext: ext ?? this.ext,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mtime: mtime ?? this.mtime,
      ctime: ctime ?? this.ctime,
      attributes: attributes ?? this.attributes,
      contentId: contentId ?? this.contentId,
      hashStatus: hashStatus ?? this.hashStatus,
      hashedSize: hashedSize ?? this.hashedSize,
      hashedMtime: hashedMtime ?? this.hashedMtime,
      hashedAt: hashedAt ?? this.hashedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      availability: availability ?? this.availability,
      integrity: integrity ?? this.integrity,
      firstSeenScanId: firstSeenScanId ?? this.firstSeenScanId,
      lastSeenScanId: lastSeenScanId ?? this.lastSeenScanId,
      missingConfirmedAt: missingConfirmedAt ?? this.missingConfirmedAt,
      hashError: hashError ?? this.hashError,
      deviceObjectId: deviceObjectId ?? this.deviceObjectId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (dirRelPath.present) {
      map['dir_rel_path'] = Variable<String>(dirRelPath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (ctime.present) {
      map['ctime'] = Variable<int>(ctime.value);
    }
    if (attributes.present) {
      map['attributes'] = Variable<int>(attributes.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (hashStatus.present) {
      map['hash_status'] = Variable<String>(hashStatus.value);
    }
    if (hashedSize.present) {
      map['hashed_size'] = Variable<int>(hashedSize.value);
    }
    if (hashedMtime.present) {
      map['hashed_mtime'] = Variable<int>(hashedMtime.value);
    }
    if (hashedAt.present) {
      map['hashed_at'] = Variable<int>(hashedAt.value);
    }
    if (lastVerifiedAt.present) {
      map['last_verified_at'] = Variable<int>(lastVerifiedAt.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (integrity.present) {
      map['integrity'] = Variable<String>(integrity.value);
    }
    if (firstSeenScanId.present) {
      map['first_seen_scan_id'] = Variable<int>(firstSeenScanId.value);
    }
    if (lastSeenScanId.present) {
      map['last_seen_scan_id'] = Variable<int>(lastSeenScanId.value);
    }
    if (missingConfirmedAt.present) {
      map['missing_confirmed_at'] = Variable<int>(missingConfirmedAt.value);
    }
    if (hashError.present) {
      map['hash_error'] = Variable<String>(hashError.value);
    }
    if (deviceObjectId.present) {
      map['device_object_id'] = Variable<String>(deviceObjectId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileInstancesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('relPath: $relPath, ')
          ..write('dirRelPath: $dirRelPath, ')
          ..write('name: $name, ')
          ..write('ext: $ext, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtime: $mtime, ')
          ..write('ctime: $ctime, ')
          ..write('attributes: $attributes, ')
          ..write('contentId: $contentId, ')
          ..write('hashStatus: $hashStatus, ')
          ..write('hashedSize: $hashedSize, ')
          ..write('hashedMtime: $hashedMtime, ')
          ..write('hashedAt: $hashedAt, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('availability: $availability, ')
          ..write('integrity: $integrity, ')
          ..write('firstSeenScanId: $firstSeenScanId, ')
          ..write('lastSeenScanId: $lastSeenScanId, ')
          ..write('missingConfirmedAt: $missingConfirmedAt, ')
          ..write('hashError: $hashError, ')
          ..write('deviceObjectId: $deviceObjectId')
          ..write(')'))
        .toString();
  }
}

class ClockCorrections extends Table with TableInfo<ClockCorrections, ClockCorrectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ClockCorrections(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _bodySerialMeta = const VerificationMeta('bodySerial');
  late final GeneratedColumn<String> bodySerial = GeneratedColumn<String>(
    'body_serial',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _offsetMsMeta = const VerificationMeta('offsetMs');
  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
    'offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _yearsMeta = const VerificationMeta('years');
  late final GeneratedColumn<int> years = GeneratedColumn<int>(
    'years',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _periodStartUtcMsMeta = const VerificationMeta('periodStartUtcMs');
  late final GeneratedColumn<int> periodStartUtcMs = GeneratedColumn<int>(
    'period_start_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _periodEndUtcMsMeta = const VerificationMeta('periodEndUtcMs');
  late final GeneratedColumn<int> periodEndUtcMs = GeneratedColumn<int>(
    'period_end_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sourceIdsJsonMeta = const VerificationMeta('sourceIdsJson');
  late final GeneratedColumn<String> sourceIdsJson = GeneratedColumn<String>(
    'source_ids_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _undoneAtMeta = const VerificationMeta('undoneAt');
  late final GeneratedColumn<int> undoneAt = GeneratedColumn<int>(
    'undone_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    make,
    model,
    bodySerial,
    offsetMs,
    years,
    periodStartUtcMs,
    periodEndUtcMs,
    sourceIdsJson,
    note,
    createdAt,
    undoneAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clock_corrections';
  @override
  VerificationContext validateIntegrity(Insertable<ClockCorrectionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('make')) {
      context.handle(_makeMeta, make.isAcceptableOrUnknown(data['make']!, _makeMeta));
    }
    if (data.containsKey('model')) {
      context.handle(_modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('body_serial')) {
      context.handle(_bodySerialMeta, bodySerial.isAcceptableOrUnknown(data['body_serial']!, _bodySerialMeta));
    }
    if (data.containsKey('offset_ms')) {
      context.handle(_offsetMsMeta, offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta));
    }
    if (data.containsKey('years')) {
      context.handle(_yearsMeta, years.isAcceptableOrUnknown(data['years']!, _yearsMeta));
    }
    if (data.containsKey('period_start_utc_ms')) {
      context.handle(
        _periodStartUtcMsMeta,
        periodStartUtcMs.isAcceptableOrUnknown(data['period_start_utc_ms']!, _periodStartUtcMsMeta),
      );
    }
    if (data.containsKey('period_end_utc_ms')) {
      context.handle(
        _periodEndUtcMsMeta,
        periodEndUtcMs.isAcceptableOrUnknown(data['period_end_utc_ms']!, _periodEndUtcMsMeta),
      );
    }
    if (data.containsKey('source_ids_json')) {
      context.handle(
        _sourceIdsJsonMeta,
        sourceIdsJson.isAcceptableOrUnknown(data['source_ids_json']!, _sourceIdsJsonMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('undone_at')) {
      context.handle(_undoneAtMeta, undoneAt.isAcceptableOrUnknown(data['undone_at']!, _undoneAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClockCorrectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClockCorrectionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      make: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}make']),
      model: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}model']),
      bodySerial: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body_serial']),
      offsetMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}offset_ms'])!,
      years: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}years'])!,
      periodStartUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}period_start_utc_ms'],
      ),
      periodEndUtcMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}period_end_utc_ms']),
      sourceIdsJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_ids_json']),
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      undoneAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}undone_at']),
    );
  }

  @override
  ClockCorrections createAlias(String alias) {
    return ClockCorrections(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ClockCorrectionRow extends DataClass implements Insertable<ClockCorrectionRow> {
  final int id;
  final String? make;
  final String? model;
  final String? bodySerial;
  final int offsetMs;
  final int years;

  /// "ano errado": soma anos no calendário
  final int? periodStartUtcMs;

  /// opcional: só itens neste período (data extraída)
  final int? periodEndUtcMs;
  final String? sourceIdsJson;

  /// opcional: só itens com cópia nestas fontes
  final String? note;
  final int createdAt;
  final int? undoneAt;
  const ClockCorrectionRow({
    required this.id,
    this.make,
    this.model,
    this.bodySerial,
    required this.offsetMs,
    required this.years,
    this.periodStartUtcMs,
    this.periodEndUtcMs,
    this.sourceIdsJson,
    this.note,
    required this.createdAt,
    this.undoneAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || make != null) {
      map['make'] = Variable<String>(make);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || bodySerial != null) {
      map['body_serial'] = Variable<String>(bodySerial);
    }
    map['offset_ms'] = Variable<int>(offsetMs);
    map['years'] = Variable<int>(years);
    if (!nullToAbsent || periodStartUtcMs != null) {
      map['period_start_utc_ms'] = Variable<int>(periodStartUtcMs);
    }
    if (!nullToAbsent || periodEndUtcMs != null) {
      map['period_end_utc_ms'] = Variable<int>(periodEndUtcMs);
    }
    if (!nullToAbsent || sourceIdsJson != null) {
      map['source_ids_json'] = Variable<String>(sourceIdsJson);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || undoneAt != null) {
      map['undone_at'] = Variable<int>(undoneAt);
    }
    return map;
  }

  ClockCorrectionsCompanion toCompanion(bool nullToAbsent) {
    return ClockCorrectionsCompanion(
      id: Value(id),
      make: make == null && nullToAbsent ? const Value.absent() : Value(make),
      model: model == null && nullToAbsent ? const Value.absent() : Value(model),
      bodySerial: bodySerial == null && nullToAbsent ? const Value.absent() : Value(bodySerial),
      offsetMs: Value(offsetMs),
      years: Value(years),
      periodStartUtcMs: periodStartUtcMs == null && nullToAbsent ? const Value.absent() : Value(periodStartUtcMs),
      periodEndUtcMs: periodEndUtcMs == null && nullToAbsent ? const Value.absent() : Value(periodEndUtcMs),
      sourceIdsJson: sourceIdsJson == null && nullToAbsent ? const Value.absent() : Value(sourceIdsJson),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      undoneAt: undoneAt == null && nullToAbsent ? const Value.absent() : Value(undoneAt),
    );
  }

  factory ClockCorrectionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClockCorrectionRow(
      id: serializer.fromJson<int>(json['id']),
      make: serializer.fromJson<String?>(json['make']),
      model: serializer.fromJson<String?>(json['model']),
      bodySerial: serializer.fromJson<String?>(json['body_serial']),
      offsetMs: serializer.fromJson<int>(json['offset_ms']),
      years: serializer.fromJson<int>(json['years']),
      periodStartUtcMs: serializer.fromJson<int?>(json['period_start_utc_ms']),
      periodEndUtcMs: serializer.fromJson<int?>(json['period_end_utc_ms']),
      sourceIdsJson: serializer.fromJson<String?>(json['source_ids_json']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      undoneAt: serializer.fromJson<int?>(json['undone_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'make': serializer.toJson<String?>(make),
      'model': serializer.toJson<String?>(model),
      'body_serial': serializer.toJson<String?>(bodySerial),
      'offset_ms': serializer.toJson<int>(offsetMs),
      'years': serializer.toJson<int>(years),
      'period_start_utc_ms': serializer.toJson<int?>(periodStartUtcMs),
      'period_end_utc_ms': serializer.toJson<int?>(periodEndUtcMs),
      'source_ids_json': serializer.toJson<String?>(sourceIdsJson),
      'note': serializer.toJson<String?>(note),
      'created_at': serializer.toJson<int>(createdAt),
      'undone_at': serializer.toJson<int?>(undoneAt),
    };
  }

  ClockCorrectionRow copyWith({
    int? id,
    Value<String?> make = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> bodySerial = const Value.absent(),
    int? offsetMs,
    int? years,
    Value<int?> periodStartUtcMs = const Value.absent(),
    Value<int?> periodEndUtcMs = const Value.absent(),
    Value<String?> sourceIdsJson = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    Value<int?> undoneAt = const Value.absent(),
  }) => ClockCorrectionRow(
    id: id ?? this.id,
    make: make.present ? make.value : this.make,
    model: model.present ? model.value : this.model,
    bodySerial: bodySerial.present ? bodySerial.value : this.bodySerial,
    offsetMs: offsetMs ?? this.offsetMs,
    years: years ?? this.years,
    periodStartUtcMs: periodStartUtcMs.present ? periodStartUtcMs.value : this.periodStartUtcMs,
    periodEndUtcMs: periodEndUtcMs.present ? periodEndUtcMs.value : this.periodEndUtcMs,
    sourceIdsJson: sourceIdsJson.present ? sourceIdsJson.value : this.sourceIdsJson,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    undoneAt: undoneAt.present ? undoneAt.value : this.undoneAt,
  );
  ClockCorrectionRow copyWithCompanion(ClockCorrectionsCompanion data) {
    return ClockCorrectionRow(
      id: data.id.present ? data.id.value : this.id,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      bodySerial: data.bodySerial.present ? data.bodySerial.value : this.bodySerial,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      years: data.years.present ? data.years.value : this.years,
      periodStartUtcMs: data.periodStartUtcMs.present ? data.periodStartUtcMs.value : this.periodStartUtcMs,
      periodEndUtcMs: data.periodEndUtcMs.present ? data.periodEndUtcMs.value : this.periodEndUtcMs,
      sourceIdsJson: data.sourceIdsJson.present ? data.sourceIdsJson.value : this.sourceIdsJson,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      undoneAt: data.undoneAt.present ? data.undoneAt.value : this.undoneAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClockCorrectionRow(')
          ..write('id: $id, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('bodySerial: $bodySerial, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('years: $years, ')
          ..write('periodStartUtcMs: $periodStartUtcMs, ')
          ..write('periodEndUtcMs: $periodEndUtcMs, ')
          ..write('sourceIdsJson: $sourceIdsJson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('undoneAt: $undoneAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    make,
    model,
    bodySerial,
    offsetMs,
    years,
    periodStartUtcMs,
    periodEndUtcMs,
    sourceIdsJson,
    note,
    createdAt,
    undoneAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClockCorrectionRow &&
          other.id == this.id &&
          other.make == this.make &&
          other.model == this.model &&
          other.bodySerial == this.bodySerial &&
          other.offsetMs == this.offsetMs &&
          other.years == this.years &&
          other.periodStartUtcMs == this.periodStartUtcMs &&
          other.periodEndUtcMs == this.periodEndUtcMs &&
          other.sourceIdsJson == this.sourceIdsJson &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.undoneAt == this.undoneAt);
}

class ClockCorrectionsCompanion extends UpdateCompanion<ClockCorrectionRow> {
  final Value<int> id;
  final Value<String?> make;
  final Value<String?> model;
  final Value<String?> bodySerial;
  final Value<int> offsetMs;
  final Value<int> years;
  final Value<int?> periodStartUtcMs;
  final Value<int?> periodEndUtcMs;
  final Value<String?> sourceIdsJson;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int?> undoneAt;
  const ClockCorrectionsCompanion({
    this.id = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.bodySerial = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.years = const Value.absent(),
    this.periodStartUtcMs = const Value.absent(),
    this.periodEndUtcMs = const Value.absent(),
    this.sourceIdsJson = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.undoneAt = const Value.absent(),
  });
  ClockCorrectionsCompanion.insert({
    this.id = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.bodySerial = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.years = const Value.absent(),
    this.periodStartUtcMs = const Value.absent(),
    this.periodEndUtcMs = const Value.absent(),
    this.sourceIdsJson = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    this.undoneAt = const Value.absent(),
  }) : createdAt = Value(createdAt);
  static Insertable<ClockCorrectionRow> custom({
    Expression<int>? id,
    Expression<String>? make,
    Expression<String>? model,
    Expression<String>? bodySerial,
    Expression<int>? offsetMs,
    Expression<int>? years,
    Expression<int>? periodStartUtcMs,
    Expression<int>? periodEndUtcMs,
    Expression<String>? sourceIdsJson,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? undoneAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (bodySerial != null) 'body_serial': bodySerial,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (years != null) 'years': years,
      if (periodStartUtcMs != null) 'period_start_utc_ms': periodStartUtcMs,
      if (periodEndUtcMs != null) 'period_end_utc_ms': periodEndUtcMs,
      if (sourceIdsJson != null) 'source_ids_json': sourceIdsJson,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (undoneAt != null) 'undone_at': undoneAt,
    });
  }

  ClockCorrectionsCompanion copyWith({
    Value<int>? id,
    Value<String?>? make,
    Value<String?>? model,
    Value<String?>? bodySerial,
    Value<int>? offsetMs,
    Value<int>? years,
    Value<int?>? periodStartUtcMs,
    Value<int?>? periodEndUtcMs,
    Value<String?>? sourceIdsJson,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int?>? undoneAt,
  }) {
    return ClockCorrectionsCompanion(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      bodySerial: bodySerial ?? this.bodySerial,
      offsetMs: offsetMs ?? this.offsetMs,
      years: years ?? this.years,
      periodStartUtcMs: periodStartUtcMs ?? this.periodStartUtcMs,
      periodEndUtcMs: periodEndUtcMs ?? this.periodEndUtcMs,
      sourceIdsJson: sourceIdsJson ?? this.sourceIdsJson,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      undoneAt: undoneAt ?? this.undoneAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (bodySerial.present) {
      map['body_serial'] = Variable<String>(bodySerial.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (years.present) {
      map['years'] = Variable<int>(years.value);
    }
    if (periodStartUtcMs.present) {
      map['period_start_utc_ms'] = Variable<int>(periodStartUtcMs.value);
    }
    if (periodEndUtcMs.present) {
      map['period_end_utc_ms'] = Variable<int>(periodEndUtcMs.value);
    }
    if (sourceIdsJson.present) {
      map['source_ids_json'] = Variable<String>(sourceIdsJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (undoneAt.present) {
      map['undone_at'] = Variable<int>(undoneAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClockCorrectionsCompanion(')
          ..write('id: $id, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('bodySerial: $bodySerial, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('years: $years, ')
          ..write('periodStartUtcMs: $periodStartUtcMs, ')
          ..write('periodEndUtcMs: $periodEndUtcMs, ')
          ..write('sourceIdsJson: $sourceIdsJson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('undoneAt: $undoneAt')
          ..write(')'))
        .toString();
  }
}

class Moments extends Table with TableInfo<Moments, MomentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Moments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'auto\', \'edited\'))',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _startUtcMsMeta = const VerificationMeta('startUtcMs');
  late final GeneratedColumn<int> startUtcMs = GeneratedColumn<int>(
    'start_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _endUtcMsMeta = const VerificationMeta('endUtcMs');
  late final GeneratedColumn<int> endUtcMs = GeneratedColumn<int>(
    'end_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta('itemCount');
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, name, startUtcMs, endUtcMs, itemCount, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'moments';
  @override
  VerificationContext validateIntegrity(Insertable<MomentRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('start_utc_ms')) {
      context.handle(_startUtcMsMeta, startUtcMs.isAcceptableOrUnknown(data['start_utc_ms']!, _startUtcMsMeta));
    } else if (isInserting) {
      context.missing(_startUtcMsMeta);
    }
    if (data.containsKey('end_utc_ms')) {
      context.handle(_endUtcMsMeta, endUtcMs.isAcceptableOrUnknown(data['end_utc_ms']!, _endUtcMsMeta));
    } else if (isInserting) {
      context.missing(_endUtcMsMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(_itemCountMeta, itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MomentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MomentRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name']),
      startUtcMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}start_utc_ms'])!,
      endUtcMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}end_utc_ms'])!,
      itemCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}item_count'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  Moments createAlias(String alias) {
    return Moments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MomentRow extends DataClass implements Insertable<MomentRow> {
  final int id;
  final String kind;
  final String? name;
  final int startUtcMs;
  final int endUtcMs;
  final int itemCount;
  final int createdAt;
  final int updatedAt;
  const MomentRow({
    required this.id,
    required this.kind,
    this.name,
    required this.startUtcMs,
    required this.endUtcMs,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['start_utc_ms'] = Variable<int>(startUtcMs);
    map['end_utc_ms'] = Variable<int>(endUtcMs);
    map['item_count'] = Variable<int>(itemCount);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MomentsCompanion toCompanion(bool nullToAbsent) {
    return MomentsCompanion(
      id: Value(id),
      kind: Value(kind),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      startUtcMs: Value(startUtcMs),
      endUtcMs: Value(endUtcMs),
      itemCount: Value(itemCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MomentRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MomentRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String?>(json['name']),
      startUtcMs: serializer.fromJson<int>(json['start_utc_ms']),
      endUtcMs: serializer.fromJson<int>(json['end_utc_ms']),
      itemCount: serializer.fromJson<int>(json['item_count']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String?>(name),
      'start_utc_ms': serializer.toJson<int>(startUtcMs),
      'end_utc_ms': serializer.toJson<int>(endUtcMs),
      'item_count': serializer.toJson<int>(itemCount),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  MomentRow copyWith({
    int? id,
    String? kind,
    Value<String?> name = const Value.absent(),
    int? startUtcMs,
    int? endUtcMs,
    int? itemCount,
    int? createdAt,
    int? updatedAt,
  }) => MomentRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name.present ? name.value : this.name,
    startUtcMs: startUtcMs ?? this.startUtcMs,
    endUtcMs: endUtcMs ?? this.endUtcMs,
    itemCount: itemCount ?? this.itemCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MomentRow copyWithCompanion(MomentsCompanion data) {
    return MomentRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      startUtcMs: data.startUtcMs.present ? data.startUtcMs.value : this.startUtcMs,
      endUtcMs: data.endUtcMs.present ? data.endUtcMs.value : this.endUtcMs,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MomentRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('startUtcMs: $startUtcMs, ')
          ..write('endUtcMs: $endUtcMs, ')
          ..write('itemCount: $itemCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, name, startUtcMs, endUtcMs, itemCount, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MomentRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.startUtcMs == this.startUtcMs &&
          other.endUtcMs == this.endUtcMs &&
          other.itemCount == this.itemCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MomentsCompanion extends UpdateCompanion<MomentRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String?> name;
  final Value<int> startUtcMs;
  final Value<int> endUtcMs;
  final Value<int> itemCount;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const MomentsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.startUtcMs = const Value.absent(),
    this.endUtcMs = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MomentsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    this.name = const Value.absent(),
    required int startUtcMs,
    required int endUtcMs,
    this.itemCount = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : kind = Value(kind),
       startUtcMs = Value(startUtcMs),
       endUtcMs = Value(endUtcMs),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MomentRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? startUtcMs,
    Expression<int>? endUtcMs,
    Expression<int>? itemCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (startUtcMs != null) 'start_utc_ms': startUtcMs,
      if (endUtcMs != null) 'end_utc_ms': endUtcMs,
      if (itemCount != null) 'item_count': itemCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MomentsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String?>? name,
    Value<int>? startUtcMs,
    Value<int>? endUtcMs,
    Value<int>? itemCount,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return MomentsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      startUtcMs: startUtcMs ?? this.startUtcMs,
      endUtcMs: endUtcMs ?? this.endUtcMs,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startUtcMs.present) {
      map['start_utc_ms'] = Variable<int>(startUtcMs.value);
    }
    if (endUtcMs.present) {
      map['end_utc_ms'] = Variable<int>(endUtcMs.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MomentsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('startUtcMs: $startUtcMs, ')
          ..write('endUtcMs: $endUtcMs, ')
          ..write('itemCount: $itemCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class MediaMetadata extends Table with TableInfo<MediaMetadata, MediaMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MediaMetadata(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta('contentId');
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY REFERENCES contents(id)',
  );
  static const VerificationMeta _captureUtcMsMeta = const VerificationMeta('captureUtcMs');
  late final GeneratedColumn<int> captureUtcMs = GeneratedColumn<int>(
    'capture_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _captureLocalMeta = const VerificationMeta('captureLocal');
  late final GeneratedColumn<String> captureLocal = GeneratedColumn<String>(
    'capture_local',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _tzOffsetMinMeta = const VerificationMeta('tzOffsetMin');
  late final GeneratedColumn<int> tzOffsetMin = GeneratedColumn<int>(
    'tz_offset_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dateSourceMeta = const VerificationMeta('dateSource');
  late final GeneratedColumn<String> dateSource = GeneratedColumn<String>(
    'date_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (date_source IN (\'manual\', \'exif_original\', \'video_internal\', \'filename\', \'filesystem\', \'none\'))',
  );
  static const VerificationMeta _dateConfidenceMeta = const VerificationMeta('dateConfidence');
  late final GeneratedColumn<String> dateConfidence = GeneratedColumn<String>(
    'date_confidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (date_confidence IN (\'high\', \'medium\', \'low\', \'none\'))',
  );
  static const VerificationMeta _dateConflictMeta = const VerificationMeta('dateConflict');
  late final GeneratedColumn<bool> dateConflict = GeneratedColumn<bool>(
    'date_conflict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _candidatesJsonMeta = const VerificationMeta('candidatesJson');
  late final GeneratedColumn<String> candidatesJson = GeneratedColumn<String>(
    'candidates_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lensMeta = const VerificationMeta('lens');
  late final GeneratedColumn<String> lens = GeneratedColumn<String>(
    'lens',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isoMeta = const VerificationMeta('iso');
  late final GeneratedColumn<int> iso = GeneratedColumn<int>(
    'iso',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _apertureMeta = const VerificationMeta('aperture');
  late final GeneratedColumn<double> aperture = GeneratedColumn<double>(
    'aperture',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _exposureSMeta = const VerificationMeta('exposureS');
  late final GeneratedColumn<double> exposureS = GeneratedColumn<double>(
    'exposure_s',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _focalMmMeta = const VerificationMeta('focalMm');
  late final GeneratedColumn<double> focalMm = GeneratedColumn<double>(
    'focal_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _orientationMeta = const VerificationMeta('orientation');
  late final GeneratedColumn<int> orientation = GeneratedColumn<int>(
    'orientation',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta('durationMs');
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fpsMeta = const VerificationMeta('fps');
  late final GeneratedColumn<double> fps = GeneratedColumn<double>(
    'fps',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _videoCodecMeta = const VerificationMeta('videoCodec');
  late final GeneratedColumn<String> videoCodec = GeneratedColumn<String>(
    'video_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _audioCodecMeta = const VerificationMeta('audioCodec');
  late final GeneratedColumn<String> audioCodec = GeneratedColumn<String>(
    'audio_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta('bitrate');
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _softwareMeta = const VerificationMeta('software');
  late final GeneratedColumn<String> software = GeneratedColumn<String>(
    'software',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _extractorMeta = const VerificationMeta('extractor');
  late final GeneratedColumn<String> extractor = GeneratedColumn<String>(
    'extractor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _extractedAtMeta = const VerificationMeta('extractedAt');
  late final GeneratedColumn<int> extractedAt = GeneratedColumn<int>(
    'extracted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _bodySerialMeta = const VerificationMeta('bodySerial');
  late final GeneratedColumn<String> bodySerial = GeneratedColumn<String>(
    'body_serial',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _metaStatusMeta = const VerificationMeta('metaStatus');
  late final GeneratedColumn<String> metaStatus = GeneratedColumn<String>(
    'meta_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'full\' CHECK (meta_status IN (\'full\', \'partial\', \'error\'))',
    defaultValue: const CustomExpression('\'full\''),
  );
  static const VerificationMeta _metaErrorMeta = const VerificationMeta('metaError');
  late final GeneratedColumn<String> metaError = GeneratedColumn<String>(
    'meta_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effUtcMsMeta = const VerificationMeta('effUtcMs');
  late final GeneratedColumn<int> effUtcMs = GeneratedColumn<int>(
    'eff_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effLocalMeta = const VerificationMeta('effLocal');
  late final GeneratedColumn<String> effLocal = GeneratedColumn<String>(
    'eff_local',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effOffsetMinMeta = const VerificationMeta('effOffsetMin');
  late final GeneratedColumn<int> effOffsetMin = GeneratedColumn<int>(
    'eff_offset_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effSourceMeta = const VerificationMeta('effSource');
  late final GeneratedColumn<String> effSource = GeneratedColumn<String>(
    'eff_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effConfidenceMeta = const VerificationMeta('effConfidence');
  late final GeneratedColumn<String> effConfidence = GeneratedColumn<String>(
    'eff_confidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _clockCorrectionIdMeta = const VerificationMeta('clockCorrectionId');
  late final GeneratedColumn<int> clockCorrectionId = GeneratedColumn<int>(
    'clock_correction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES clock_corrections(id)',
  );
  static const VerificationMeta _effYearMeta = const VerificationMeta('effYear');
  late final GeneratedColumn<int> effYear = GeneratedColumn<int>(
    'eff_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effMonthMeta = const VerificationMeta('effMonth');
  late final GeneratedColumn<int> effMonth = GeneratedColumn<int>(
    'eff_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effDayMeta = const VerificationMeta('effDay');
  late final GeneratedColumn<String> effDay = GeneratedColumn<String>(
    'eff_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effMinuteMeta = const VerificationMeta('effMinute');
  late final GeneratedColumn<int> effMinute = GeneratedColumn<int>(
    'eff_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _effWeekdayMeta = const VerificationMeta('effWeekday');
  late final GeneratedColumn<int> effWeekday = GeneratedColumn<int>(
    'eff_weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _momentIdMeta = const VerificationMeta('momentId');
  late final GeneratedColumn<int> momentId = GeneratedColumn<int>(
    'moment_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES moments(id)ON DELETE SET NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentId,
    captureUtcMs,
    captureLocal,
    tzOffsetMin,
    dateSource,
    dateConfidence,
    dateConflict,
    candidatesJson,
    make,
    model,
    lens,
    iso,
    aperture,
    exposureS,
    focalMm,
    width,
    height,
    orientation,
    lat,
    lon,
    durationMs,
    fps,
    videoCodec,
    audioCodec,
    bitrate,
    software,
    extractor,
    extractedAt,
    bodySerial,
    metaStatus,
    metaError,
    effUtcMs,
    effLocal,
    effOffsetMin,
    effSource,
    effConfidence,
    clockCorrectionId,
    effYear,
    effMonth,
    effDay,
    effMinute,
    effWeekday,
    momentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<MediaMetadataRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta, contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    }
    if (data.containsKey('capture_utc_ms')) {
      context.handle(_captureUtcMsMeta, captureUtcMs.isAcceptableOrUnknown(data['capture_utc_ms']!, _captureUtcMsMeta));
    }
    if (data.containsKey('capture_local')) {
      context.handle(_captureLocalMeta, captureLocal.isAcceptableOrUnknown(data['capture_local']!, _captureLocalMeta));
    }
    if (data.containsKey('tz_offset_min')) {
      context.handle(_tzOffsetMinMeta, tzOffsetMin.isAcceptableOrUnknown(data['tz_offset_min']!, _tzOffsetMinMeta));
    }
    if (data.containsKey('date_source')) {
      context.handle(_dateSourceMeta, dateSource.isAcceptableOrUnknown(data['date_source']!, _dateSourceMeta));
    }
    if (data.containsKey('date_confidence')) {
      context.handle(
        _dateConfidenceMeta,
        dateConfidence.isAcceptableOrUnknown(data['date_confidence']!, _dateConfidenceMeta),
      );
    }
    if (data.containsKey('date_conflict')) {
      context.handle(_dateConflictMeta, dateConflict.isAcceptableOrUnknown(data['date_conflict']!, _dateConflictMeta));
    }
    if (data.containsKey('candidates_json')) {
      context.handle(
        _candidatesJsonMeta,
        candidatesJson.isAcceptableOrUnknown(data['candidates_json']!, _candidatesJsonMeta),
      );
    }
    if (data.containsKey('make')) {
      context.handle(_makeMeta, make.isAcceptableOrUnknown(data['make']!, _makeMeta));
    }
    if (data.containsKey('model')) {
      context.handle(_modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('lens')) {
      context.handle(_lensMeta, lens.isAcceptableOrUnknown(data['lens']!, _lensMeta));
    }
    if (data.containsKey('iso')) {
      context.handle(_isoMeta, iso.isAcceptableOrUnknown(data['iso']!, _isoMeta));
    }
    if (data.containsKey('aperture')) {
      context.handle(_apertureMeta, aperture.isAcceptableOrUnknown(data['aperture']!, _apertureMeta));
    }
    if (data.containsKey('exposure_s')) {
      context.handle(_exposureSMeta, exposureS.isAcceptableOrUnknown(data['exposure_s']!, _exposureSMeta));
    }
    if (data.containsKey('focal_mm')) {
      context.handle(_focalMmMeta, focalMm.isAcceptableOrUnknown(data['focal_mm']!, _focalMmMeta));
    }
    if (data.containsKey('width')) {
      context.handle(_widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta, height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('orientation')) {
      context.handle(_orientationMeta, orientation.isAcceptableOrUnknown(data['orientation']!, _orientationMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(_latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lon')) {
      context.handle(_lonMeta, lon.isAcceptableOrUnknown(data['lon']!, _lonMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(_durationMsMeta, durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('fps')) {
      context.handle(_fpsMeta, fps.isAcceptableOrUnknown(data['fps']!, _fpsMeta));
    }
    if (data.containsKey('video_codec')) {
      context.handle(_videoCodecMeta, videoCodec.isAcceptableOrUnknown(data['video_codec']!, _videoCodecMeta));
    }
    if (data.containsKey('audio_codec')) {
      context.handle(_audioCodecMeta, audioCodec.isAcceptableOrUnknown(data['audio_codec']!, _audioCodecMeta));
    }
    if (data.containsKey('bitrate')) {
      context.handle(_bitrateMeta, bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta));
    }
    if (data.containsKey('software')) {
      context.handle(_softwareMeta, software.isAcceptableOrUnknown(data['software']!, _softwareMeta));
    }
    if (data.containsKey('extractor')) {
      context.handle(_extractorMeta, extractor.isAcceptableOrUnknown(data['extractor']!, _extractorMeta));
    }
    if (data.containsKey('extracted_at')) {
      context.handle(_extractedAtMeta, extractedAt.isAcceptableOrUnknown(data['extracted_at']!, _extractedAtMeta));
    }
    if (data.containsKey('body_serial')) {
      context.handle(_bodySerialMeta, bodySerial.isAcceptableOrUnknown(data['body_serial']!, _bodySerialMeta));
    }
    if (data.containsKey('meta_status')) {
      context.handle(_metaStatusMeta, metaStatus.isAcceptableOrUnknown(data['meta_status']!, _metaStatusMeta));
    }
    if (data.containsKey('meta_error')) {
      context.handle(_metaErrorMeta, metaError.isAcceptableOrUnknown(data['meta_error']!, _metaErrorMeta));
    }
    if (data.containsKey('eff_utc_ms')) {
      context.handle(_effUtcMsMeta, effUtcMs.isAcceptableOrUnknown(data['eff_utc_ms']!, _effUtcMsMeta));
    }
    if (data.containsKey('eff_local')) {
      context.handle(_effLocalMeta, effLocal.isAcceptableOrUnknown(data['eff_local']!, _effLocalMeta));
    }
    if (data.containsKey('eff_offset_min')) {
      context.handle(_effOffsetMinMeta, effOffsetMin.isAcceptableOrUnknown(data['eff_offset_min']!, _effOffsetMinMeta));
    }
    if (data.containsKey('eff_source')) {
      context.handle(_effSourceMeta, effSource.isAcceptableOrUnknown(data['eff_source']!, _effSourceMeta));
    }
    if (data.containsKey('eff_confidence')) {
      context.handle(
        _effConfidenceMeta,
        effConfidence.isAcceptableOrUnknown(data['eff_confidence']!, _effConfidenceMeta),
      );
    }
    if (data.containsKey('clock_correction_id')) {
      context.handle(
        _clockCorrectionIdMeta,
        clockCorrectionId.isAcceptableOrUnknown(data['clock_correction_id']!, _clockCorrectionIdMeta),
      );
    }
    if (data.containsKey('eff_year')) {
      context.handle(_effYearMeta, effYear.isAcceptableOrUnknown(data['eff_year']!, _effYearMeta));
    }
    if (data.containsKey('eff_month')) {
      context.handle(_effMonthMeta, effMonth.isAcceptableOrUnknown(data['eff_month']!, _effMonthMeta));
    }
    if (data.containsKey('eff_day')) {
      context.handle(_effDayMeta, effDay.isAcceptableOrUnknown(data['eff_day']!, _effDayMeta));
    }
    if (data.containsKey('eff_minute')) {
      context.handle(_effMinuteMeta, effMinute.isAcceptableOrUnknown(data['eff_minute']!, _effMinuteMeta));
    }
    if (data.containsKey('eff_weekday')) {
      context.handle(_effWeekdayMeta, effWeekday.isAcceptableOrUnknown(data['eff_weekday']!, _effWeekdayMeta));
    }
    if (data.containsKey('moment_id')) {
      context.handle(_momentIdMeta, momentId.isAcceptableOrUnknown(data['moment_id']!, _momentIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId};
  @override
  MediaMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaMetadataRow(
      contentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}content_id'])!,
      captureUtcMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}capture_utc_ms']),
      captureLocal: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}capture_local']),
      tzOffsetMin: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tz_offset_min']),
      dateSource: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date_source']),
      dateConfidence: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date_confidence']),
      dateConflict: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}date_conflict'])!,
      candidatesJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}candidates_json']),
      make: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}make']),
      model: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}model']),
      lens: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}lens']),
      iso: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}iso']),
      aperture: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}aperture']),
      exposureS: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}exposure_s']),
      focalMm: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}focal_mm']),
      width: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}width']),
      height: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}height']),
      orientation: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}orientation']),
      lat: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lon: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}lon']),
      durationMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      fps: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}fps']),
      videoCodec: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}video_codec']),
      audioCodec: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}audio_codec']),
      bitrate: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}bitrate']),
      software: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}software']),
      extractor: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}extractor']),
      extractedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}extracted_at']),
      bodySerial: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body_serial']),
      metaStatus: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}meta_status'])!,
      metaError: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}meta_error']),
      effUtcMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}eff_utc_ms']),
      effLocal: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}eff_local']),
      effOffsetMin: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}eff_offset_min']),
      effSource: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}eff_source']),
      effConfidence: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}eff_confidence']),
      clockCorrectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clock_correction_id'],
      ),
      effYear: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}eff_year']),
      effMonth: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}eff_month']),
      effDay: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}eff_day']),
      effMinute: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}eff_minute']),
      effWeekday: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}eff_weekday']),
      momentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}moment_id']),
    );
  }

  @override
  MediaMetadata createAlias(String alias) {
    return MediaMetadata(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MediaMetadataRow extends DataClass implements Insertable<MediaMetadataRow> {
  final int contentId;
  final int? captureUtcMs;
  final String? captureLocal;
  final int? tzOffsetMin;
  final String? dateSource;
  final String? dateConfidence;
  final bool dateConflict;
  final String? candidatesJson;
  final String? make;
  final String? model;
  final String? lens;
  final int? iso;
  final double? aperture;
  final double? exposureS;
  final double? focalMm;
  final int? width;
  final int? height;
  final int? orientation;
  final double? lat;
  final double? lon;
  final int? durationMs;
  final double? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrate;
  final String? software;
  final String? extractor;
  final int? extractedAt;

  /// v4 (Fase 4): número de série do corpo da câmera (correção de relógio por dispositivo).
  final String? bodySerial;

  /// v4: 'full' = arquivo lido (EXIF/vídeo); 'partial' = só nome e data do arquivo
  /// (nenhuma cópia acessível ainda); 'error' = leitura falhou (meta_error diz o motivo).
  final String metaStatus;
  final String? metaError;

  /// v4: data EFETIVA = extraída (capture_*) + correção de relógio + correção manual.
  /// É a que a linha do tempo, os momentos e os filtros usam (eff_* derivadas, para índices).
  final int? effUtcMs;
  final String? effLocal;
  final int? effOffsetMin;
  final String? effSource;
  final String? effConfidence;
  final int? clockCorrectionId;
  final int? effYear;
  final int? effMonth;
  final String? effDay;

  /// 'AAAA-MM-DD' (hora local)
  final int? effMinute;

  /// minuto do dia (0..1439), hora local
  final int? effWeekday;

  /// 1 = segunda … 7 = domingo
  final int? momentId;
  const MediaMetadataRow({
    required this.contentId,
    this.captureUtcMs,
    this.captureLocal,
    this.tzOffsetMin,
    this.dateSource,
    this.dateConfidence,
    required this.dateConflict,
    this.candidatesJson,
    this.make,
    this.model,
    this.lens,
    this.iso,
    this.aperture,
    this.exposureS,
    this.focalMm,
    this.width,
    this.height,
    this.orientation,
    this.lat,
    this.lon,
    this.durationMs,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
    this.software,
    this.extractor,
    this.extractedAt,
    this.bodySerial,
    required this.metaStatus,
    this.metaError,
    this.effUtcMs,
    this.effLocal,
    this.effOffsetMin,
    this.effSource,
    this.effConfidence,
    this.clockCorrectionId,
    this.effYear,
    this.effMonth,
    this.effDay,
    this.effMinute,
    this.effWeekday,
    this.momentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<int>(contentId);
    if (!nullToAbsent || captureUtcMs != null) {
      map['capture_utc_ms'] = Variable<int>(captureUtcMs);
    }
    if (!nullToAbsent || captureLocal != null) {
      map['capture_local'] = Variable<String>(captureLocal);
    }
    if (!nullToAbsent || tzOffsetMin != null) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin);
    }
    if (!nullToAbsent || dateSource != null) {
      map['date_source'] = Variable<String>(dateSource);
    }
    if (!nullToAbsent || dateConfidence != null) {
      map['date_confidence'] = Variable<String>(dateConfidence);
    }
    map['date_conflict'] = Variable<bool>(dateConflict);
    if (!nullToAbsent || candidatesJson != null) {
      map['candidates_json'] = Variable<String>(candidatesJson);
    }
    if (!nullToAbsent || make != null) {
      map['make'] = Variable<String>(make);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || lens != null) {
      map['lens'] = Variable<String>(lens);
    }
    if (!nullToAbsent || iso != null) {
      map['iso'] = Variable<int>(iso);
    }
    if (!nullToAbsent || aperture != null) {
      map['aperture'] = Variable<double>(aperture);
    }
    if (!nullToAbsent || exposureS != null) {
      map['exposure_s'] = Variable<double>(exposureS);
    }
    if (!nullToAbsent || focalMm != null) {
      map['focal_mm'] = Variable<double>(focalMm);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || orientation != null) {
      map['orientation'] = Variable<int>(orientation);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || fps != null) {
      map['fps'] = Variable<double>(fps);
    }
    if (!nullToAbsent || videoCodec != null) {
      map['video_codec'] = Variable<String>(videoCodec);
    }
    if (!nullToAbsent || audioCodec != null) {
      map['audio_codec'] = Variable<String>(audioCodec);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || software != null) {
      map['software'] = Variable<String>(software);
    }
    if (!nullToAbsent || extractor != null) {
      map['extractor'] = Variable<String>(extractor);
    }
    if (!nullToAbsent || extractedAt != null) {
      map['extracted_at'] = Variable<int>(extractedAt);
    }
    if (!nullToAbsent || bodySerial != null) {
      map['body_serial'] = Variable<String>(bodySerial);
    }
    map['meta_status'] = Variable<String>(metaStatus);
    if (!nullToAbsent || metaError != null) {
      map['meta_error'] = Variable<String>(metaError);
    }
    if (!nullToAbsent || effUtcMs != null) {
      map['eff_utc_ms'] = Variable<int>(effUtcMs);
    }
    if (!nullToAbsent || effLocal != null) {
      map['eff_local'] = Variable<String>(effLocal);
    }
    if (!nullToAbsent || effOffsetMin != null) {
      map['eff_offset_min'] = Variable<int>(effOffsetMin);
    }
    if (!nullToAbsent || effSource != null) {
      map['eff_source'] = Variable<String>(effSource);
    }
    if (!nullToAbsent || effConfidence != null) {
      map['eff_confidence'] = Variable<String>(effConfidence);
    }
    if (!nullToAbsent || clockCorrectionId != null) {
      map['clock_correction_id'] = Variable<int>(clockCorrectionId);
    }
    if (!nullToAbsent || effYear != null) {
      map['eff_year'] = Variable<int>(effYear);
    }
    if (!nullToAbsent || effMonth != null) {
      map['eff_month'] = Variable<int>(effMonth);
    }
    if (!nullToAbsent || effDay != null) {
      map['eff_day'] = Variable<String>(effDay);
    }
    if (!nullToAbsent || effMinute != null) {
      map['eff_minute'] = Variable<int>(effMinute);
    }
    if (!nullToAbsent || effWeekday != null) {
      map['eff_weekday'] = Variable<int>(effWeekday);
    }
    if (!nullToAbsent || momentId != null) {
      map['moment_id'] = Variable<int>(momentId);
    }
    return map;
  }

  MediaMetadataCompanion toCompanion(bool nullToAbsent) {
    return MediaMetadataCompanion(
      contentId: Value(contentId),
      captureUtcMs: captureUtcMs == null && nullToAbsent ? const Value.absent() : Value(captureUtcMs),
      captureLocal: captureLocal == null && nullToAbsent ? const Value.absent() : Value(captureLocal),
      tzOffsetMin: tzOffsetMin == null && nullToAbsent ? const Value.absent() : Value(tzOffsetMin),
      dateSource: dateSource == null && nullToAbsent ? const Value.absent() : Value(dateSource),
      dateConfidence: dateConfidence == null && nullToAbsent ? const Value.absent() : Value(dateConfidence),
      dateConflict: Value(dateConflict),
      candidatesJson: candidatesJson == null && nullToAbsent ? const Value.absent() : Value(candidatesJson),
      make: make == null && nullToAbsent ? const Value.absent() : Value(make),
      model: model == null && nullToAbsent ? const Value.absent() : Value(model),
      lens: lens == null && nullToAbsent ? const Value.absent() : Value(lens),
      iso: iso == null && nullToAbsent ? const Value.absent() : Value(iso),
      aperture: aperture == null && nullToAbsent ? const Value.absent() : Value(aperture),
      exposureS: exposureS == null && nullToAbsent ? const Value.absent() : Value(exposureS),
      focalMm: focalMm == null && nullToAbsent ? const Value.absent() : Value(focalMm),
      width: width == null && nullToAbsent ? const Value.absent() : Value(width),
      height: height == null && nullToAbsent ? const Value.absent() : Value(height),
      orientation: orientation == null && nullToAbsent ? const Value.absent() : Value(orientation),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      durationMs: durationMs == null && nullToAbsent ? const Value.absent() : Value(durationMs),
      fps: fps == null && nullToAbsent ? const Value.absent() : Value(fps),
      videoCodec: videoCodec == null && nullToAbsent ? const Value.absent() : Value(videoCodec),
      audioCodec: audioCodec == null && nullToAbsent ? const Value.absent() : Value(audioCodec),
      bitrate: bitrate == null && nullToAbsent ? const Value.absent() : Value(bitrate),
      software: software == null && nullToAbsent ? const Value.absent() : Value(software),
      extractor: extractor == null && nullToAbsent ? const Value.absent() : Value(extractor),
      extractedAt: extractedAt == null && nullToAbsent ? const Value.absent() : Value(extractedAt),
      bodySerial: bodySerial == null && nullToAbsent ? const Value.absent() : Value(bodySerial),
      metaStatus: Value(metaStatus),
      metaError: metaError == null && nullToAbsent ? const Value.absent() : Value(metaError),
      effUtcMs: effUtcMs == null && nullToAbsent ? const Value.absent() : Value(effUtcMs),
      effLocal: effLocal == null && nullToAbsent ? const Value.absent() : Value(effLocal),
      effOffsetMin: effOffsetMin == null && nullToAbsent ? const Value.absent() : Value(effOffsetMin),
      effSource: effSource == null && nullToAbsent ? const Value.absent() : Value(effSource),
      effConfidence: effConfidence == null && nullToAbsent ? const Value.absent() : Value(effConfidence),
      clockCorrectionId: clockCorrectionId == null && nullToAbsent ? const Value.absent() : Value(clockCorrectionId),
      effYear: effYear == null && nullToAbsent ? const Value.absent() : Value(effYear),
      effMonth: effMonth == null && nullToAbsent ? const Value.absent() : Value(effMonth),
      effDay: effDay == null && nullToAbsent ? const Value.absent() : Value(effDay),
      effMinute: effMinute == null && nullToAbsent ? const Value.absent() : Value(effMinute),
      effWeekday: effWeekday == null && nullToAbsent ? const Value.absent() : Value(effWeekday),
      momentId: momentId == null && nullToAbsent ? const Value.absent() : Value(momentId),
    );
  }

  factory MediaMetadataRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaMetadataRow(
      contentId: serializer.fromJson<int>(json['content_id']),
      captureUtcMs: serializer.fromJson<int?>(json['capture_utc_ms']),
      captureLocal: serializer.fromJson<String?>(json['capture_local']),
      tzOffsetMin: serializer.fromJson<int?>(json['tz_offset_min']),
      dateSource: serializer.fromJson<String?>(json['date_source']),
      dateConfidence: serializer.fromJson<String?>(json['date_confidence']),
      dateConflict: serializer.fromJson<bool>(json['date_conflict']),
      candidatesJson: serializer.fromJson<String?>(json['candidates_json']),
      make: serializer.fromJson<String?>(json['make']),
      model: serializer.fromJson<String?>(json['model']),
      lens: serializer.fromJson<String?>(json['lens']),
      iso: serializer.fromJson<int?>(json['iso']),
      aperture: serializer.fromJson<double?>(json['aperture']),
      exposureS: serializer.fromJson<double?>(json['exposure_s']),
      focalMm: serializer.fromJson<double?>(json['focal_mm']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      orientation: serializer.fromJson<int?>(json['orientation']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      durationMs: serializer.fromJson<int?>(json['duration_ms']),
      fps: serializer.fromJson<double?>(json['fps']),
      videoCodec: serializer.fromJson<String?>(json['video_codec']),
      audioCodec: serializer.fromJson<String?>(json['audio_codec']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      software: serializer.fromJson<String?>(json['software']),
      extractor: serializer.fromJson<String?>(json['extractor']),
      extractedAt: serializer.fromJson<int?>(json['extracted_at']),
      bodySerial: serializer.fromJson<String?>(json['body_serial']),
      metaStatus: serializer.fromJson<String>(json['meta_status']),
      metaError: serializer.fromJson<String?>(json['meta_error']),
      effUtcMs: serializer.fromJson<int?>(json['eff_utc_ms']),
      effLocal: serializer.fromJson<String?>(json['eff_local']),
      effOffsetMin: serializer.fromJson<int?>(json['eff_offset_min']),
      effSource: serializer.fromJson<String?>(json['eff_source']),
      effConfidence: serializer.fromJson<String?>(json['eff_confidence']),
      clockCorrectionId: serializer.fromJson<int?>(json['clock_correction_id']),
      effYear: serializer.fromJson<int?>(json['eff_year']),
      effMonth: serializer.fromJson<int?>(json['eff_month']),
      effDay: serializer.fromJson<String?>(json['eff_day']),
      effMinute: serializer.fromJson<int?>(json['eff_minute']),
      effWeekday: serializer.fromJson<int?>(json['eff_weekday']),
      momentId: serializer.fromJson<int?>(json['moment_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'content_id': serializer.toJson<int>(contentId),
      'capture_utc_ms': serializer.toJson<int?>(captureUtcMs),
      'capture_local': serializer.toJson<String?>(captureLocal),
      'tz_offset_min': serializer.toJson<int?>(tzOffsetMin),
      'date_source': serializer.toJson<String?>(dateSource),
      'date_confidence': serializer.toJson<String?>(dateConfidence),
      'date_conflict': serializer.toJson<bool>(dateConflict),
      'candidates_json': serializer.toJson<String?>(candidatesJson),
      'make': serializer.toJson<String?>(make),
      'model': serializer.toJson<String?>(model),
      'lens': serializer.toJson<String?>(lens),
      'iso': serializer.toJson<int?>(iso),
      'aperture': serializer.toJson<double?>(aperture),
      'exposure_s': serializer.toJson<double?>(exposureS),
      'focal_mm': serializer.toJson<double?>(focalMm),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'orientation': serializer.toJson<int?>(orientation),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'duration_ms': serializer.toJson<int?>(durationMs),
      'fps': serializer.toJson<double?>(fps),
      'video_codec': serializer.toJson<String?>(videoCodec),
      'audio_codec': serializer.toJson<String?>(audioCodec),
      'bitrate': serializer.toJson<int?>(bitrate),
      'software': serializer.toJson<String?>(software),
      'extractor': serializer.toJson<String?>(extractor),
      'extracted_at': serializer.toJson<int?>(extractedAt),
      'body_serial': serializer.toJson<String?>(bodySerial),
      'meta_status': serializer.toJson<String>(metaStatus),
      'meta_error': serializer.toJson<String?>(metaError),
      'eff_utc_ms': serializer.toJson<int?>(effUtcMs),
      'eff_local': serializer.toJson<String?>(effLocal),
      'eff_offset_min': serializer.toJson<int?>(effOffsetMin),
      'eff_source': serializer.toJson<String?>(effSource),
      'eff_confidence': serializer.toJson<String?>(effConfidence),
      'clock_correction_id': serializer.toJson<int?>(clockCorrectionId),
      'eff_year': serializer.toJson<int?>(effYear),
      'eff_month': serializer.toJson<int?>(effMonth),
      'eff_day': serializer.toJson<String?>(effDay),
      'eff_minute': serializer.toJson<int?>(effMinute),
      'eff_weekday': serializer.toJson<int?>(effWeekday),
      'moment_id': serializer.toJson<int?>(momentId),
    };
  }

  MediaMetadataRow copyWith({
    int? contentId,
    Value<int?> captureUtcMs = const Value.absent(),
    Value<String?> captureLocal = const Value.absent(),
    Value<int?> tzOffsetMin = const Value.absent(),
    Value<String?> dateSource = const Value.absent(),
    Value<String?> dateConfidence = const Value.absent(),
    bool? dateConflict,
    Value<String?> candidatesJson = const Value.absent(),
    Value<String?> make = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> lens = const Value.absent(),
    Value<int?> iso = const Value.absent(),
    Value<double?> aperture = const Value.absent(),
    Value<double?> exposureS = const Value.absent(),
    Value<double?> focalMm = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> orientation = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<double?> fps = const Value.absent(),
    Value<String?> videoCodec = const Value.absent(),
    Value<String?> audioCodec = const Value.absent(),
    Value<int?> bitrate = const Value.absent(),
    Value<String?> software = const Value.absent(),
    Value<String?> extractor = const Value.absent(),
    Value<int?> extractedAt = const Value.absent(),
    Value<String?> bodySerial = const Value.absent(),
    String? metaStatus,
    Value<String?> metaError = const Value.absent(),
    Value<int?> effUtcMs = const Value.absent(),
    Value<String?> effLocal = const Value.absent(),
    Value<int?> effOffsetMin = const Value.absent(),
    Value<String?> effSource = const Value.absent(),
    Value<String?> effConfidence = const Value.absent(),
    Value<int?> clockCorrectionId = const Value.absent(),
    Value<int?> effYear = const Value.absent(),
    Value<int?> effMonth = const Value.absent(),
    Value<String?> effDay = const Value.absent(),
    Value<int?> effMinute = const Value.absent(),
    Value<int?> effWeekday = const Value.absent(),
    Value<int?> momentId = const Value.absent(),
  }) => MediaMetadataRow(
    contentId: contentId ?? this.contentId,
    captureUtcMs: captureUtcMs.present ? captureUtcMs.value : this.captureUtcMs,
    captureLocal: captureLocal.present ? captureLocal.value : this.captureLocal,
    tzOffsetMin: tzOffsetMin.present ? tzOffsetMin.value : this.tzOffsetMin,
    dateSource: dateSource.present ? dateSource.value : this.dateSource,
    dateConfidence: dateConfidence.present ? dateConfidence.value : this.dateConfidence,
    dateConflict: dateConflict ?? this.dateConflict,
    candidatesJson: candidatesJson.present ? candidatesJson.value : this.candidatesJson,
    make: make.present ? make.value : this.make,
    model: model.present ? model.value : this.model,
    lens: lens.present ? lens.value : this.lens,
    iso: iso.present ? iso.value : this.iso,
    aperture: aperture.present ? aperture.value : this.aperture,
    exposureS: exposureS.present ? exposureS.value : this.exposureS,
    focalMm: focalMm.present ? focalMm.value : this.focalMm,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    orientation: orientation.present ? orientation.value : this.orientation,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    fps: fps.present ? fps.value : this.fps,
    videoCodec: videoCodec.present ? videoCodec.value : this.videoCodec,
    audioCodec: audioCodec.present ? audioCodec.value : this.audioCodec,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    software: software.present ? software.value : this.software,
    extractor: extractor.present ? extractor.value : this.extractor,
    extractedAt: extractedAt.present ? extractedAt.value : this.extractedAt,
    bodySerial: bodySerial.present ? bodySerial.value : this.bodySerial,
    metaStatus: metaStatus ?? this.metaStatus,
    metaError: metaError.present ? metaError.value : this.metaError,
    effUtcMs: effUtcMs.present ? effUtcMs.value : this.effUtcMs,
    effLocal: effLocal.present ? effLocal.value : this.effLocal,
    effOffsetMin: effOffsetMin.present ? effOffsetMin.value : this.effOffsetMin,
    effSource: effSource.present ? effSource.value : this.effSource,
    effConfidence: effConfidence.present ? effConfidence.value : this.effConfidence,
    clockCorrectionId: clockCorrectionId.present ? clockCorrectionId.value : this.clockCorrectionId,
    effYear: effYear.present ? effYear.value : this.effYear,
    effMonth: effMonth.present ? effMonth.value : this.effMonth,
    effDay: effDay.present ? effDay.value : this.effDay,
    effMinute: effMinute.present ? effMinute.value : this.effMinute,
    effWeekday: effWeekday.present ? effWeekday.value : this.effWeekday,
    momentId: momentId.present ? momentId.value : this.momentId,
  );
  MediaMetadataRow copyWithCompanion(MediaMetadataCompanion data) {
    return MediaMetadataRow(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      captureUtcMs: data.captureUtcMs.present ? data.captureUtcMs.value : this.captureUtcMs,
      captureLocal: data.captureLocal.present ? data.captureLocal.value : this.captureLocal,
      tzOffsetMin: data.tzOffsetMin.present ? data.tzOffsetMin.value : this.tzOffsetMin,
      dateSource: data.dateSource.present ? data.dateSource.value : this.dateSource,
      dateConfidence: data.dateConfidence.present ? data.dateConfidence.value : this.dateConfidence,
      dateConflict: data.dateConflict.present ? data.dateConflict.value : this.dateConflict,
      candidatesJson: data.candidatesJson.present ? data.candidatesJson.value : this.candidatesJson,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      lens: data.lens.present ? data.lens.value : this.lens,
      iso: data.iso.present ? data.iso.value : this.iso,
      aperture: data.aperture.present ? data.aperture.value : this.aperture,
      exposureS: data.exposureS.present ? data.exposureS.value : this.exposureS,
      focalMm: data.focalMm.present ? data.focalMm.value : this.focalMm,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      orientation: data.orientation.present ? data.orientation.value : this.orientation,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      durationMs: data.durationMs.present ? data.durationMs.value : this.durationMs,
      fps: data.fps.present ? data.fps.value : this.fps,
      videoCodec: data.videoCodec.present ? data.videoCodec.value : this.videoCodec,
      audioCodec: data.audioCodec.present ? data.audioCodec.value : this.audioCodec,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      software: data.software.present ? data.software.value : this.software,
      extractor: data.extractor.present ? data.extractor.value : this.extractor,
      extractedAt: data.extractedAt.present ? data.extractedAt.value : this.extractedAt,
      bodySerial: data.bodySerial.present ? data.bodySerial.value : this.bodySerial,
      metaStatus: data.metaStatus.present ? data.metaStatus.value : this.metaStatus,
      metaError: data.metaError.present ? data.metaError.value : this.metaError,
      effUtcMs: data.effUtcMs.present ? data.effUtcMs.value : this.effUtcMs,
      effLocal: data.effLocal.present ? data.effLocal.value : this.effLocal,
      effOffsetMin: data.effOffsetMin.present ? data.effOffsetMin.value : this.effOffsetMin,
      effSource: data.effSource.present ? data.effSource.value : this.effSource,
      effConfidence: data.effConfidence.present ? data.effConfidence.value : this.effConfidence,
      clockCorrectionId: data.clockCorrectionId.present ? data.clockCorrectionId.value : this.clockCorrectionId,
      effYear: data.effYear.present ? data.effYear.value : this.effYear,
      effMonth: data.effMonth.present ? data.effMonth.value : this.effMonth,
      effDay: data.effDay.present ? data.effDay.value : this.effDay,
      effMinute: data.effMinute.present ? data.effMinute.value : this.effMinute,
      effWeekday: data.effWeekday.present ? data.effWeekday.value : this.effWeekday,
      momentId: data.momentId.present ? data.momentId.value : this.momentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaMetadataRow(')
          ..write('contentId: $contentId, ')
          ..write('captureUtcMs: $captureUtcMs, ')
          ..write('captureLocal: $captureLocal, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('dateSource: $dateSource, ')
          ..write('dateConfidence: $dateConfidence, ')
          ..write('dateConflict: $dateConflict, ')
          ..write('candidatesJson: $candidatesJson, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('lens: $lens, ')
          ..write('iso: $iso, ')
          ..write('aperture: $aperture, ')
          ..write('exposureS: $exposureS, ')
          ..write('focalMm: $focalMm, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('orientation: $orientation, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('durationMs: $durationMs, ')
          ..write('fps: $fps, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('bitrate: $bitrate, ')
          ..write('software: $software, ')
          ..write('extractor: $extractor, ')
          ..write('extractedAt: $extractedAt, ')
          ..write('bodySerial: $bodySerial, ')
          ..write('metaStatus: $metaStatus, ')
          ..write('metaError: $metaError, ')
          ..write('effUtcMs: $effUtcMs, ')
          ..write('effLocal: $effLocal, ')
          ..write('effOffsetMin: $effOffsetMin, ')
          ..write('effSource: $effSource, ')
          ..write('effConfidence: $effConfidence, ')
          ..write('clockCorrectionId: $clockCorrectionId, ')
          ..write('effYear: $effYear, ')
          ..write('effMonth: $effMonth, ')
          ..write('effDay: $effDay, ')
          ..write('effMinute: $effMinute, ')
          ..write('effWeekday: $effWeekday, ')
          ..write('momentId: $momentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    contentId,
    captureUtcMs,
    captureLocal,
    tzOffsetMin,
    dateSource,
    dateConfidence,
    dateConflict,
    candidatesJson,
    make,
    model,
    lens,
    iso,
    aperture,
    exposureS,
    focalMm,
    width,
    height,
    orientation,
    lat,
    lon,
    durationMs,
    fps,
    videoCodec,
    audioCodec,
    bitrate,
    software,
    extractor,
    extractedAt,
    bodySerial,
    metaStatus,
    metaError,
    effUtcMs,
    effLocal,
    effOffsetMin,
    effSource,
    effConfidence,
    clockCorrectionId,
    effYear,
    effMonth,
    effDay,
    effMinute,
    effWeekday,
    momentId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaMetadataRow &&
          other.contentId == this.contentId &&
          other.captureUtcMs == this.captureUtcMs &&
          other.captureLocal == this.captureLocal &&
          other.tzOffsetMin == this.tzOffsetMin &&
          other.dateSource == this.dateSource &&
          other.dateConfidence == this.dateConfidence &&
          other.dateConflict == this.dateConflict &&
          other.candidatesJson == this.candidatesJson &&
          other.make == this.make &&
          other.model == this.model &&
          other.lens == this.lens &&
          other.iso == this.iso &&
          other.aperture == this.aperture &&
          other.exposureS == this.exposureS &&
          other.focalMm == this.focalMm &&
          other.width == this.width &&
          other.height == this.height &&
          other.orientation == this.orientation &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.durationMs == this.durationMs &&
          other.fps == this.fps &&
          other.videoCodec == this.videoCodec &&
          other.audioCodec == this.audioCodec &&
          other.bitrate == this.bitrate &&
          other.software == this.software &&
          other.extractor == this.extractor &&
          other.extractedAt == this.extractedAt &&
          other.bodySerial == this.bodySerial &&
          other.metaStatus == this.metaStatus &&
          other.metaError == this.metaError &&
          other.effUtcMs == this.effUtcMs &&
          other.effLocal == this.effLocal &&
          other.effOffsetMin == this.effOffsetMin &&
          other.effSource == this.effSource &&
          other.effConfidence == this.effConfidence &&
          other.clockCorrectionId == this.clockCorrectionId &&
          other.effYear == this.effYear &&
          other.effMonth == this.effMonth &&
          other.effDay == this.effDay &&
          other.effMinute == this.effMinute &&
          other.effWeekday == this.effWeekday &&
          other.momentId == this.momentId);
}

class MediaMetadataCompanion extends UpdateCompanion<MediaMetadataRow> {
  final Value<int> contentId;
  final Value<int?> captureUtcMs;
  final Value<String?> captureLocal;
  final Value<int?> tzOffsetMin;
  final Value<String?> dateSource;
  final Value<String?> dateConfidence;
  final Value<bool> dateConflict;
  final Value<String?> candidatesJson;
  final Value<String?> make;
  final Value<String?> model;
  final Value<String?> lens;
  final Value<int?> iso;
  final Value<double?> aperture;
  final Value<double?> exposureS;
  final Value<double?> focalMm;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> orientation;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<int?> durationMs;
  final Value<double?> fps;
  final Value<String?> videoCodec;
  final Value<String?> audioCodec;
  final Value<int?> bitrate;
  final Value<String?> software;
  final Value<String?> extractor;
  final Value<int?> extractedAt;
  final Value<String?> bodySerial;
  final Value<String> metaStatus;
  final Value<String?> metaError;
  final Value<int?> effUtcMs;
  final Value<String?> effLocal;
  final Value<int?> effOffsetMin;
  final Value<String?> effSource;
  final Value<String?> effConfidence;
  final Value<int?> clockCorrectionId;
  final Value<int?> effYear;
  final Value<int?> effMonth;
  final Value<String?> effDay;
  final Value<int?> effMinute;
  final Value<int?> effWeekday;
  final Value<int?> momentId;
  const MediaMetadataCompanion({
    this.contentId = const Value.absent(),
    this.captureUtcMs = const Value.absent(),
    this.captureLocal = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.dateSource = const Value.absent(),
    this.dateConfidence = const Value.absent(),
    this.dateConflict = const Value.absent(),
    this.candidatesJson = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.lens = const Value.absent(),
    this.iso = const Value.absent(),
    this.aperture = const Value.absent(),
    this.exposureS = const Value.absent(),
    this.focalMm = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.orientation = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fps = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.software = const Value.absent(),
    this.extractor = const Value.absent(),
    this.extractedAt = const Value.absent(),
    this.bodySerial = const Value.absent(),
    this.metaStatus = const Value.absent(),
    this.metaError = const Value.absent(),
    this.effUtcMs = const Value.absent(),
    this.effLocal = const Value.absent(),
    this.effOffsetMin = const Value.absent(),
    this.effSource = const Value.absent(),
    this.effConfidence = const Value.absent(),
    this.clockCorrectionId = const Value.absent(),
    this.effYear = const Value.absent(),
    this.effMonth = const Value.absent(),
    this.effDay = const Value.absent(),
    this.effMinute = const Value.absent(),
    this.effWeekday = const Value.absent(),
    this.momentId = const Value.absent(),
  });
  MediaMetadataCompanion.insert({
    this.contentId = const Value.absent(),
    this.captureUtcMs = const Value.absent(),
    this.captureLocal = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.dateSource = const Value.absent(),
    this.dateConfidence = const Value.absent(),
    this.dateConflict = const Value.absent(),
    this.candidatesJson = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.lens = const Value.absent(),
    this.iso = const Value.absent(),
    this.aperture = const Value.absent(),
    this.exposureS = const Value.absent(),
    this.focalMm = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.orientation = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fps = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.software = const Value.absent(),
    this.extractor = const Value.absent(),
    this.extractedAt = const Value.absent(),
    this.bodySerial = const Value.absent(),
    this.metaStatus = const Value.absent(),
    this.metaError = const Value.absent(),
    this.effUtcMs = const Value.absent(),
    this.effLocal = const Value.absent(),
    this.effOffsetMin = const Value.absent(),
    this.effSource = const Value.absent(),
    this.effConfidence = const Value.absent(),
    this.clockCorrectionId = const Value.absent(),
    this.effYear = const Value.absent(),
    this.effMonth = const Value.absent(),
    this.effDay = const Value.absent(),
    this.effMinute = const Value.absent(),
    this.effWeekday = const Value.absent(),
    this.momentId = const Value.absent(),
  });
  static Insertable<MediaMetadataRow> custom({
    Expression<int>? contentId,
    Expression<int>? captureUtcMs,
    Expression<String>? captureLocal,
    Expression<int>? tzOffsetMin,
    Expression<String>? dateSource,
    Expression<String>? dateConfidence,
    Expression<bool>? dateConflict,
    Expression<String>? candidatesJson,
    Expression<String>? make,
    Expression<String>? model,
    Expression<String>? lens,
    Expression<int>? iso,
    Expression<double>? aperture,
    Expression<double>? exposureS,
    Expression<double>? focalMm,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? orientation,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<int>? durationMs,
    Expression<double>? fps,
    Expression<String>? videoCodec,
    Expression<String>? audioCodec,
    Expression<int>? bitrate,
    Expression<String>? software,
    Expression<String>? extractor,
    Expression<int>? extractedAt,
    Expression<String>? bodySerial,
    Expression<String>? metaStatus,
    Expression<String>? metaError,
    Expression<int>? effUtcMs,
    Expression<String>? effLocal,
    Expression<int>? effOffsetMin,
    Expression<String>? effSource,
    Expression<String>? effConfidence,
    Expression<int>? clockCorrectionId,
    Expression<int>? effYear,
    Expression<int>? effMonth,
    Expression<String>? effDay,
    Expression<int>? effMinute,
    Expression<int>? effWeekday,
    Expression<int>? momentId,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (captureUtcMs != null) 'capture_utc_ms': captureUtcMs,
      if (captureLocal != null) 'capture_local': captureLocal,
      if (tzOffsetMin != null) 'tz_offset_min': tzOffsetMin,
      if (dateSource != null) 'date_source': dateSource,
      if (dateConfidence != null) 'date_confidence': dateConfidence,
      if (dateConflict != null) 'date_conflict': dateConflict,
      if (candidatesJson != null) 'candidates_json': candidatesJson,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (lens != null) 'lens': lens,
      if (iso != null) 'iso': iso,
      if (aperture != null) 'aperture': aperture,
      if (exposureS != null) 'exposure_s': exposureS,
      if (focalMm != null) 'focal_mm': focalMm,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (orientation != null) 'orientation': orientation,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fps != null) 'fps': fps,
      if (videoCodec != null) 'video_codec': videoCodec,
      if (audioCodec != null) 'audio_codec': audioCodec,
      if (bitrate != null) 'bitrate': bitrate,
      if (software != null) 'software': software,
      if (extractor != null) 'extractor': extractor,
      if (extractedAt != null) 'extracted_at': extractedAt,
      if (bodySerial != null) 'body_serial': bodySerial,
      if (metaStatus != null) 'meta_status': metaStatus,
      if (metaError != null) 'meta_error': metaError,
      if (effUtcMs != null) 'eff_utc_ms': effUtcMs,
      if (effLocal != null) 'eff_local': effLocal,
      if (effOffsetMin != null) 'eff_offset_min': effOffsetMin,
      if (effSource != null) 'eff_source': effSource,
      if (effConfidence != null) 'eff_confidence': effConfidence,
      if (clockCorrectionId != null) 'clock_correction_id': clockCorrectionId,
      if (effYear != null) 'eff_year': effYear,
      if (effMonth != null) 'eff_month': effMonth,
      if (effDay != null) 'eff_day': effDay,
      if (effMinute != null) 'eff_minute': effMinute,
      if (effWeekday != null) 'eff_weekday': effWeekday,
      if (momentId != null) 'moment_id': momentId,
    });
  }

  MediaMetadataCompanion copyWith({
    Value<int>? contentId,
    Value<int?>? captureUtcMs,
    Value<String?>? captureLocal,
    Value<int?>? tzOffsetMin,
    Value<String?>? dateSource,
    Value<String?>? dateConfidence,
    Value<bool>? dateConflict,
    Value<String?>? candidatesJson,
    Value<String?>? make,
    Value<String?>? model,
    Value<String?>? lens,
    Value<int?>? iso,
    Value<double?>? aperture,
    Value<double?>? exposureS,
    Value<double?>? focalMm,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? orientation,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<int?>? durationMs,
    Value<double?>? fps,
    Value<String?>? videoCodec,
    Value<String?>? audioCodec,
    Value<int?>? bitrate,
    Value<String?>? software,
    Value<String?>? extractor,
    Value<int?>? extractedAt,
    Value<String?>? bodySerial,
    Value<String>? metaStatus,
    Value<String?>? metaError,
    Value<int?>? effUtcMs,
    Value<String?>? effLocal,
    Value<int?>? effOffsetMin,
    Value<String?>? effSource,
    Value<String?>? effConfidence,
    Value<int?>? clockCorrectionId,
    Value<int?>? effYear,
    Value<int?>? effMonth,
    Value<String?>? effDay,
    Value<int?>? effMinute,
    Value<int?>? effWeekday,
    Value<int?>? momentId,
  }) {
    return MediaMetadataCompanion(
      contentId: contentId ?? this.contentId,
      captureUtcMs: captureUtcMs ?? this.captureUtcMs,
      captureLocal: captureLocal ?? this.captureLocal,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      dateSource: dateSource ?? this.dateSource,
      dateConfidence: dateConfidence ?? this.dateConfidence,
      dateConflict: dateConflict ?? this.dateConflict,
      candidatesJson: candidatesJson ?? this.candidatesJson,
      make: make ?? this.make,
      model: model ?? this.model,
      lens: lens ?? this.lens,
      iso: iso ?? this.iso,
      aperture: aperture ?? this.aperture,
      exposureS: exposureS ?? this.exposureS,
      focalMm: focalMm ?? this.focalMm,
      width: width ?? this.width,
      height: height ?? this.height,
      orientation: orientation ?? this.orientation,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      durationMs: durationMs ?? this.durationMs,
      fps: fps ?? this.fps,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      bitrate: bitrate ?? this.bitrate,
      software: software ?? this.software,
      extractor: extractor ?? this.extractor,
      extractedAt: extractedAt ?? this.extractedAt,
      bodySerial: bodySerial ?? this.bodySerial,
      metaStatus: metaStatus ?? this.metaStatus,
      metaError: metaError ?? this.metaError,
      effUtcMs: effUtcMs ?? this.effUtcMs,
      effLocal: effLocal ?? this.effLocal,
      effOffsetMin: effOffsetMin ?? this.effOffsetMin,
      effSource: effSource ?? this.effSource,
      effConfidence: effConfidence ?? this.effConfidence,
      clockCorrectionId: clockCorrectionId ?? this.clockCorrectionId,
      effYear: effYear ?? this.effYear,
      effMonth: effMonth ?? this.effMonth,
      effDay: effDay ?? this.effDay,
      effMinute: effMinute ?? this.effMinute,
      effWeekday: effWeekday ?? this.effWeekday,
      momentId: momentId ?? this.momentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (captureUtcMs.present) {
      map['capture_utc_ms'] = Variable<int>(captureUtcMs.value);
    }
    if (captureLocal.present) {
      map['capture_local'] = Variable<String>(captureLocal.value);
    }
    if (tzOffsetMin.present) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin.value);
    }
    if (dateSource.present) {
      map['date_source'] = Variable<String>(dateSource.value);
    }
    if (dateConfidence.present) {
      map['date_confidence'] = Variable<String>(dateConfidence.value);
    }
    if (dateConflict.present) {
      map['date_conflict'] = Variable<bool>(dateConflict.value);
    }
    if (candidatesJson.present) {
      map['candidates_json'] = Variable<String>(candidatesJson.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (lens.present) {
      map['lens'] = Variable<String>(lens.value);
    }
    if (iso.present) {
      map['iso'] = Variable<int>(iso.value);
    }
    if (aperture.present) {
      map['aperture'] = Variable<double>(aperture.value);
    }
    if (exposureS.present) {
      map['exposure_s'] = Variable<double>(exposureS.value);
    }
    if (focalMm.present) {
      map['focal_mm'] = Variable<double>(focalMm.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<int>(orientation.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fps.present) {
      map['fps'] = Variable<double>(fps.value);
    }
    if (videoCodec.present) {
      map['video_codec'] = Variable<String>(videoCodec.value);
    }
    if (audioCodec.present) {
      map['audio_codec'] = Variable<String>(audioCodec.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (software.present) {
      map['software'] = Variable<String>(software.value);
    }
    if (extractor.present) {
      map['extractor'] = Variable<String>(extractor.value);
    }
    if (extractedAt.present) {
      map['extracted_at'] = Variable<int>(extractedAt.value);
    }
    if (bodySerial.present) {
      map['body_serial'] = Variable<String>(bodySerial.value);
    }
    if (metaStatus.present) {
      map['meta_status'] = Variable<String>(metaStatus.value);
    }
    if (metaError.present) {
      map['meta_error'] = Variable<String>(metaError.value);
    }
    if (effUtcMs.present) {
      map['eff_utc_ms'] = Variable<int>(effUtcMs.value);
    }
    if (effLocal.present) {
      map['eff_local'] = Variable<String>(effLocal.value);
    }
    if (effOffsetMin.present) {
      map['eff_offset_min'] = Variable<int>(effOffsetMin.value);
    }
    if (effSource.present) {
      map['eff_source'] = Variable<String>(effSource.value);
    }
    if (effConfidence.present) {
      map['eff_confidence'] = Variable<String>(effConfidence.value);
    }
    if (clockCorrectionId.present) {
      map['clock_correction_id'] = Variable<int>(clockCorrectionId.value);
    }
    if (effYear.present) {
      map['eff_year'] = Variable<int>(effYear.value);
    }
    if (effMonth.present) {
      map['eff_month'] = Variable<int>(effMonth.value);
    }
    if (effDay.present) {
      map['eff_day'] = Variable<String>(effDay.value);
    }
    if (effMinute.present) {
      map['eff_minute'] = Variable<int>(effMinute.value);
    }
    if (effWeekday.present) {
      map['eff_weekday'] = Variable<int>(effWeekday.value);
    }
    if (momentId.present) {
      map['moment_id'] = Variable<int>(momentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaMetadataCompanion(')
          ..write('contentId: $contentId, ')
          ..write('captureUtcMs: $captureUtcMs, ')
          ..write('captureLocal: $captureLocal, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('dateSource: $dateSource, ')
          ..write('dateConfidence: $dateConfidence, ')
          ..write('dateConflict: $dateConflict, ')
          ..write('candidatesJson: $candidatesJson, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('lens: $lens, ')
          ..write('iso: $iso, ')
          ..write('aperture: $aperture, ')
          ..write('exposureS: $exposureS, ')
          ..write('focalMm: $focalMm, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('orientation: $orientation, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('durationMs: $durationMs, ')
          ..write('fps: $fps, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('bitrate: $bitrate, ')
          ..write('software: $software, ')
          ..write('extractor: $extractor, ')
          ..write('extractedAt: $extractedAt, ')
          ..write('bodySerial: $bodySerial, ')
          ..write('metaStatus: $metaStatus, ')
          ..write('metaError: $metaError, ')
          ..write('effUtcMs: $effUtcMs, ')
          ..write('effLocal: $effLocal, ')
          ..write('effOffsetMin: $effOffsetMin, ')
          ..write('effSource: $effSource, ')
          ..write('effConfidence: $effConfidence, ')
          ..write('clockCorrectionId: $clockCorrectionId, ')
          ..write('effYear: $effYear, ')
          ..write('effMonth: $effMonth, ')
          ..write('effDay: $effDay, ')
          ..write('effMinute: $effMinute, ')
          ..write('effWeekday: $effWeekday, ')
          ..write('momentId: $momentId')
          ..write(')'))
        .toString();
  }
}

class DateCorrections extends Table with TableInfo<DateCorrections, DateCorrectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DateCorrections(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta('contentId');
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES contents(id)',
  );
  static const VerificationMeta _captureLocalMeta = const VerificationMeta('captureLocal');
  late final GeneratedColumn<String> captureLocal = GeneratedColumn<String>(
    'capture_local',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _tzOffsetMinMeta = const VerificationMeta('tzOffsetMin');
  late final GeneratedColumn<int> tzOffsetMin = GeneratedColumn<int>(
    'tz_offset_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _supersededAtMeta = const VerificationMeta('supersededAt');
  late final GeneratedColumn<int> supersededAt = GeneratedColumn<int>(
    'superseded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [id, contentId, captureLocal, tzOffsetMin, note, createdAt, supersededAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'date_corrections';
  @override
  VerificationContext validateIntegrity(Insertable<DateCorrectionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta, contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('capture_local')) {
      context.handle(_captureLocalMeta, captureLocal.isAcceptableOrUnknown(data['capture_local']!, _captureLocalMeta));
    } else if (isInserting) {
      context.missing(_captureLocalMeta);
    }
    if (data.containsKey('tz_offset_min')) {
      context.handle(_tzOffsetMinMeta, tzOffsetMin.isAcceptableOrUnknown(data['tz_offset_min']!, _tzOffsetMinMeta));
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('superseded_at')) {
      context.handle(_supersededAtMeta, supersededAt.isAcceptableOrUnknown(data['superseded_at']!, _supersededAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DateCorrectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DateCorrectionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      contentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}content_id'])!,
      captureLocal: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}capture_local'])!,
      tzOffsetMin: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tz_offset_min']),
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      supersededAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}superseded_at']),
    );
  }

  @override
  DateCorrections createAlias(String alias) {
    return DateCorrections(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DateCorrectionRow extends DataClass implements Insertable<DateCorrectionRow> {
  final int id;
  final int contentId;
  final String captureLocal;
  final int? tzOffsetMin;
  final String? note;
  final int createdAt;
  final int? supersededAt;
  const DateCorrectionRow({
    required this.id,
    required this.contentId,
    required this.captureLocal,
    this.tzOffsetMin,
    this.note,
    required this.createdAt,
    this.supersededAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_id'] = Variable<int>(contentId);
    map['capture_local'] = Variable<String>(captureLocal);
    if (!nullToAbsent || tzOffsetMin != null) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || supersededAt != null) {
      map['superseded_at'] = Variable<int>(supersededAt);
    }
    return map;
  }

  DateCorrectionsCompanion toCompanion(bool nullToAbsent) {
    return DateCorrectionsCompanion(
      id: Value(id),
      contentId: Value(contentId),
      captureLocal: Value(captureLocal),
      tzOffsetMin: tzOffsetMin == null && nullToAbsent ? const Value.absent() : Value(tzOffsetMin),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      supersededAt: supersededAt == null && nullToAbsent ? const Value.absent() : Value(supersededAt),
    );
  }

  factory DateCorrectionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DateCorrectionRow(
      id: serializer.fromJson<int>(json['id']),
      contentId: serializer.fromJson<int>(json['content_id']),
      captureLocal: serializer.fromJson<String>(json['capture_local']),
      tzOffsetMin: serializer.fromJson<int?>(json['tz_offset_min']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      supersededAt: serializer.fromJson<int?>(json['superseded_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content_id': serializer.toJson<int>(contentId),
      'capture_local': serializer.toJson<String>(captureLocal),
      'tz_offset_min': serializer.toJson<int?>(tzOffsetMin),
      'note': serializer.toJson<String?>(note),
      'created_at': serializer.toJson<int>(createdAt),
      'superseded_at': serializer.toJson<int?>(supersededAt),
    };
  }

  DateCorrectionRow copyWith({
    int? id,
    int? contentId,
    String? captureLocal,
    Value<int?> tzOffsetMin = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    Value<int?> supersededAt = const Value.absent(),
  }) => DateCorrectionRow(
    id: id ?? this.id,
    contentId: contentId ?? this.contentId,
    captureLocal: captureLocal ?? this.captureLocal,
    tzOffsetMin: tzOffsetMin.present ? tzOffsetMin.value : this.tzOffsetMin,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    supersededAt: supersededAt.present ? supersededAt.value : this.supersededAt,
  );
  DateCorrectionRow copyWithCompanion(DateCorrectionsCompanion data) {
    return DateCorrectionRow(
      id: data.id.present ? data.id.value : this.id,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      captureLocal: data.captureLocal.present ? data.captureLocal.value : this.captureLocal,
      tzOffsetMin: data.tzOffsetMin.present ? data.tzOffsetMin.value : this.tzOffsetMin,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      supersededAt: data.supersededAt.present ? data.supersededAt.value : this.supersededAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DateCorrectionRow(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('captureLocal: $captureLocal, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('supersededAt: $supersededAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, contentId, captureLocal, tzOffsetMin, note, createdAt, supersededAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DateCorrectionRow &&
          other.id == this.id &&
          other.contentId == this.contentId &&
          other.captureLocal == this.captureLocal &&
          other.tzOffsetMin == this.tzOffsetMin &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.supersededAt == this.supersededAt);
}

class DateCorrectionsCompanion extends UpdateCompanion<DateCorrectionRow> {
  final Value<int> id;
  final Value<int> contentId;
  final Value<String> captureLocal;
  final Value<int?> tzOffsetMin;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int?> supersededAt;
  const DateCorrectionsCompanion({
    this.id = const Value.absent(),
    this.contentId = const Value.absent(),
    this.captureLocal = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.supersededAt = const Value.absent(),
  });
  DateCorrectionsCompanion.insert({
    this.id = const Value.absent(),
    required int contentId,
    required String captureLocal,
    this.tzOffsetMin = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    this.supersededAt = const Value.absent(),
  }) : contentId = Value(contentId),
       captureLocal = Value(captureLocal),
       createdAt = Value(createdAt);
  static Insertable<DateCorrectionRow> custom({
    Expression<int>? id,
    Expression<int>? contentId,
    Expression<String>? captureLocal,
    Expression<int>? tzOffsetMin,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? supersededAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentId != null) 'content_id': contentId,
      if (captureLocal != null) 'capture_local': captureLocal,
      if (tzOffsetMin != null) 'tz_offset_min': tzOffsetMin,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (supersededAt != null) 'superseded_at': supersededAt,
    });
  }

  DateCorrectionsCompanion copyWith({
    Value<int>? id,
    Value<int>? contentId,
    Value<String>? captureLocal,
    Value<int?>? tzOffsetMin,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int?>? supersededAt,
  }) {
    return DateCorrectionsCompanion(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      captureLocal: captureLocal ?? this.captureLocal,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      supersededAt: supersededAt ?? this.supersededAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (captureLocal.present) {
      map['capture_local'] = Variable<String>(captureLocal.value);
    }
    if (tzOffsetMin.present) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (supersededAt.present) {
      map['superseded_at'] = Variable<int>(supersededAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DateCorrectionsCompanion(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('captureLocal: $captureLocal, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('supersededAt: $supersededAt')
          ..write(')'))
        .toString();
  }
}

class Operations extends Table with TableInfo<Operations, OperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Operations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (kind IN (\'copy\', \'reorganize_move\', \'undo\', \'restore\', \'catalog_backup_copy\'))',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (status IN (\'planned\', \'confirmed\', \'running\', \'paused\', \'completed\', \'completed_with_errors\', \'cancelled\', \'needs_attention\'))',
  );
  static const VerificationMeta _destSourceIdMeta = const VerificationMeta('destSourceId');
  late final GeneratedColumn<String> destSourceId = GeneratedColumn<String>(
    'dest_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES sources(id)',
  );
  static const VerificationMeta _destRootRelMeta = const VerificationMeta('destRootRel');
  late final GeneratedColumn<String> destRootRel = GeneratedColumn<String>(
    'dest_root_rel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _templateMeta = const VerificationMeta('template');
  late final GeneratedColumn<String> template = GeneratedColumn<String>(
    'template',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _conflictPolicyMeta = const VerificationMeta('conflictPolicy');
  late final GeneratedColumn<String> conflictPolicy = GeneratedColumn<String>(
    'conflict_policy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (conflict_policy IN (\'suffix\', \'ask\'))',
  );
  static const VerificationMeta _paramsJsonMeta = const VerificationMeta('paramsJson');
  late final GeneratedColumn<String> paramsJson = GeneratedColumn<String>(
    'params_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta('summaryJson');
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _undoOfMeta = const VerificationMeta('undoOf');
  late final GeneratedColumn<String> undoOf = GeneratedColumn<String>(
    'undo_of',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES operations(id)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _confirmedAtMeta = const VerificationMeta('confirmedAt');
  late final GeneratedColumn<int> confirmedAt = GeneratedColumn<int>(
    'confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta('finishedAt');
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    status,
    destSourceId,
    destRootRel,
    template,
    conflictPolicy,
    paramsJson,
    summaryJson,
    undoOf,
    createdAt,
    confirmedAt,
    startedAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operations';
  @override
  VerificationContext validateIntegrity(Insertable<OperationRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('dest_source_id')) {
      context.handle(_destSourceIdMeta, destSourceId.isAcceptableOrUnknown(data['dest_source_id']!, _destSourceIdMeta));
    }
    if (data.containsKey('dest_root_rel')) {
      context.handle(_destRootRelMeta, destRootRel.isAcceptableOrUnknown(data['dest_root_rel']!, _destRootRelMeta));
    }
    if (data.containsKey('template')) {
      context.handle(_templateMeta, template.isAcceptableOrUnknown(data['template']!, _templateMeta));
    }
    if (data.containsKey('conflict_policy')) {
      context.handle(
        _conflictPolicyMeta,
        conflictPolicy.isAcceptableOrUnknown(data['conflict_policy']!, _conflictPolicyMeta),
      );
    }
    if (data.containsKey('params_json')) {
      context.handle(_paramsJsonMeta, paramsJson.isAcceptableOrUnknown(data['params_json']!, _paramsJsonMeta));
    }
    if (data.containsKey('summary_json')) {
      context.handle(_summaryJsonMeta, summaryJson.isAcceptableOrUnknown(data['summary_json']!, _summaryJsonMeta));
    }
    if (data.containsKey('undo_of')) {
      context.handle(_undoOfMeta, undoOf.isAcceptableOrUnknown(data['undo_of']!, _undoOfMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('confirmed_at')) {
      context.handle(_confirmedAtMeta, confirmedAt.isAcceptableOrUnknown(data['confirmed_at']!, _confirmedAtMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('finished_at')) {
      context.handle(_finishedAtMeta, finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      destSourceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}dest_source_id']),
      destRootRel: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}dest_root_rel']),
      template: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}template']),
      conflictPolicy: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}conflict_policy']),
      paramsJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}params_json']),
      summaryJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}summary_json']),
      undoOf: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}undo_of']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      confirmedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}confirmed_at']),
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}started_at']),
      finishedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}finished_at']),
    );
  }

  @override
  Operations createAlias(String alias) {
    return Operations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class OperationRow extends DataClass implements Insertable<OperationRow> {
  final String id;
  final String kind;
  final String status;
  final String? destSourceId;
  final String? destRootRel;
  final String? template;
  final String? conflictPolicy;
  final String? paramsJson;
  final String? summaryJson;
  final String? undoOf;
  final int createdAt;
  final int? confirmedAt;
  final int? startedAt;
  final int? finishedAt;
  const OperationRow({
    required this.id,
    required this.kind,
    required this.status,
    this.destSourceId,
    this.destRootRel,
    this.template,
    this.conflictPolicy,
    this.paramsJson,
    this.summaryJson,
    this.undoOf,
    required this.createdAt,
    this.confirmedAt,
    this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || destSourceId != null) {
      map['dest_source_id'] = Variable<String>(destSourceId);
    }
    if (!nullToAbsent || destRootRel != null) {
      map['dest_root_rel'] = Variable<String>(destRootRel);
    }
    if (!nullToAbsent || template != null) {
      map['template'] = Variable<String>(template);
    }
    if (!nullToAbsent || conflictPolicy != null) {
      map['conflict_policy'] = Variable<String>(conflictPolicy);
    }
    if (!nullToAbsent || paramsJson != null) {
      map['params_json'] = Variable<String>(paramsJson);
    }
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    if (!nullToAbsent || undoOf != null) {
      map['undo_of'] = Variable<String>(undoOf);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || confirmedAt != null) {
      map['confirmed_at'] = Variable<int>(confirmedAt);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    return map;
  }

  OperationsCompanion toCompanion(bool nullToAbsent) {
    return OperationsCompanion(
      id: Value(id),
      kind: Value(kind),
      status: Value(status),
      destSourceId: destSourceId == null && nullToAbsent ? const Value.absent() : Value(destSourceId),
      destRootRel: destRootRel == null && nullToAbsent ? const Value.absent() : Value(destRootRel),
      template: template == null && nullToAbsent ? const Value.absent() : Value(template),
      conflictPolicy: conflictPolicy == null && nullToAbsent ? const Value.absent() : Value(conflictPolicy),
      paramsJson: paramsJson == null && nullToAbsent ? const Value.absent() : Value(paramsJson),
      summaryJson: summaryJson == null && nullToAbsent ? const Value.absent() : Value(summaryJson),
      undoOf: undoOf == null && nullToAbsent ? const Value.absent() : Value(undoOf),
      createdAt: Value(createdAt),
      confirmedAt: confirmedAt == null && nullToAbsent ? const Value.absent() : Value(confirmedAt),
      startedAt: startedAt == null && nullToAbsent ? const Value.absent() : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent ? const Value.absent() : Value(finishedAt),
    );
  }

  factory OperationRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      destSourceId: serializer.fromJson<String?>(json['dest_source_id']),
      destRootRel: serializer.fromJson<String?>(json['dest_root_rel']),
      template: serializer.fromJson<String?>(json['template']),
      conflictPolicy: serializer.fromJson<String?>(json['conflict_policy']),
      paramsJson: serializer.fromJson<String?>(json['params_json']),
      summaryJson: serializer.fromJson<String?>(json['summary_json']),
      undoOf: serializer.fromJson<String?>(json['undo_of']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      confirmedAt: serializer.fromJson<int?>(json['confirmed_at']),
      startedAt: serializer.fromJson<int?>(json['started_at']),
      finishedAt: serializer.fromJson<int?>(json['finished_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'dest_source_id': serializer.toJson<String?>(destSourceId),
      'dest_root_rel': serializer.toJson<String?>(destRootRel),
      'template': serializer.toJson<String?>(template),
      'conflict_policy': serializer.toJson<String?>(conflictPolicy),
      'params_json': serializer.toJson<String?>(paramsJson),
      'summary_json': serializer.toJson<String?>(summaryJson),
      'undo_of': serializer.toJson<String?>(undoOf),
      'created_at': serializer.toJson<int>(createdAt),
      'confirmed_at': serializer.toJson<int?>(confirmedAt),
      'started_at': serializer.toJson<int?>(startedAt),
      'finished_at': serializer.toJson<int?>(finishedAt),
    };
  }

  OperationRow copyWith({
    String? id,
    String? kind,
    String? status,
    Value<String?> destSourceId = const Value.absent(),
    Value<String?> destRootRel = const Value.absent(),
    Value<String?> template = const Value.absent(),
    Value<String?> conflictPolicy = const Value.absent(),
    Value<String?> paramsJson = const Value.absent(),
    Value<String?> summaryJson = const Value.absent(),
    Value<String?> undoOf = const Value.absent(),
    int? createdAt,
    Value<int?> confirmedAt = const Value.absent(),
    Value<int?> startedAt = const Value.absent(),
    Value<int?> finishedAt = const Value.absent(),
  }) => OperationRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    destSourceId: destSourceId.present ? destSourceId.value : this.destSourceId,
    destRootRel: destRootRel.present ? destRootRel.value : this.destRootRel,
    template: template.present ? template.value : this.template,
    conflictPolicy: conflictPolicy.present ? conflictPolicy.value : this.conflictPolicy,
    paramsJson: paramsJson.present ? paramsJson.value : this.paramsJson,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    undoOf: undoOf.present ? undoOf.value : this.undoOf,
    createdAt: createdAt ?? this.createdAt,
    confirmedAt: confirmedAt.present ? confirmedAt.value : this.confirmedAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  OperationRow copyWithCompanion(OperationsCompanion data) {
    return OperationRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      destSourceId: data.destSourceId.present ? data.destSourceId.value : this.destSourceId,
      destRootRel: data.destRootRel.present ? data.destRootRel.value : this.destRootRel,
      template: data.template.present ? data.template.value : this.template,
      conflictPolicy: data.conflictPolicy.present ? data.conflictPolicy.value : this.conflictPolicy,
      paramsJson: data.paramsJson.present ? data.paramsJson.value : this.paramsJson,
      summaryJson: data.summaryJson.present ? data.summaryJson.value : this.summaryJson,
      undoOf: data.undoOf.present ? data.undoOf.value : this.undoOf,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      confirmedAt: data.confirmedAt.present ? data.confirmedAt.value : this.confirmedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('destSourceId: $destSourceId, ')
          ..write('destRootRel: $destRootRel, ')
          ..write('template: $template, ')
          ..write('conflictPolicy: $conflictPolicy, ')
          ..write('paramsJson: $paramsJson, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('undoOf: $undoOf, ')
          ..write('createdAt: $createdAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    status,
    destSourceId,
    destRootRel,
    template,
    conflictPolicy,
    paramsJson,
    summaryJson,
    undoOf,
    createdAt,
    confirmedAt,
    startedAt,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.destSourceId == this.destSourceId &&
          other.destRootRel == this.destRootRel &&
          other.template == this.template &&
          other.conflictPolicy == this.conflictPolicy &&
          other.paramsJson == this.paramsJson &&
          other.summaryJson == this.summaryJson &&
          other.undoOf == this.undoOf &&
          other.createdAt == this.createdAt &&
          other.confirmedAt == this.confirmedAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class OperationsCompanion extends UpdateCompanion<OperationRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> status;
  final Value<String?> destSourceId;
  final Value<String?> destRootRel;
  final Value<String?> template;
  final Value<String?> conflictPolicy;
  final Value<String?> paramsJson;
  final Value<String?> summaryJson;
  final Value<String?> undoOf;
  final Value<int> createdAt;
  final Value<int?> confirmedAt;
  final Value<int?> startedAt;
  final Value<int?> finishedAt;
  final Value<int> rowid;
  const OperationsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.destSourceId = const Value.absent(),
    this.destRootRel = const Value.absent(),
    this.template = const Value.absent(),
    this.conflictPolicy = const Value.absent(),
    this.paramsJson = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.undoOf = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.confirmedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationsCompanion.insert({
    required String id,
    required String kind,
    required String status,
    this.destSourceId = const Value.absent(),
    this.destRootRel = const Value.absent(),
    this.template = const Value.absent(),
    this.conflictPolicy = const Value.absent(),
    this.paramsJson = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.undoOf = const Value.absent(),
    required int createdAt,
    this.confirmedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<OperationRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? destSourceId,
    Expression<String>? destRootRel,
    Expression<String>? template,
    Expression<String>? conflictPolicy,
    Expression<String>? paramsJson,
    Expression<String>? summaryJson,
    Expression<String>? undoOf,
    Expression<int>? createdAt,
    Expression<int>? confirmedAt,
    Expression<int>? startedAt,
    Expression<int>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (destSourceId != null) 'dest_source_id': destSourceId,
      if (destRootRel != null) 'dest_root_rel': destRootRel,
      if (template != null) 'template': template,
      if (conflictPolicy != null) 'conflict_policy': conflictPolicy,
      if (paramsJson != null) 'params_json': paramsJson,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (undoOf != null) 'undo_of': undoOf,
      if (createdAt != null) 'created_at': createdAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? status,
    Value<String?>? destSourceId,
    Value<String?>? destRootRel,
    Value<String?>? template,
    Value<String?>? conflictPolicy,
    Value<String?>? paramsJson,
    Value<String?>? summaryJson,
    Value<String?>? undoOf,
    Value<int>? createdAt,
    Value<int?>? confirmedAt,
    Value<int?>? startedAt,
    Value<int?>? finishedAt,
    Value<int>? rowid,
  }) {
    return OperationsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      destSourceId: destSourceId ?? this.destSourceId,
      destRootRel: destRootRel ?? this.destRootRel,
      template: template ?? this.template,
      conflictPolicy: conflictPolicy ?? this.conflictPolicy,
      paramsJson: paramsJson ?? this.paramsJson,
      summaryJson: summaryJson ?? this.summaryJson,
      undoOf: undoOf ?? this.undoOf,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (destSourceId.present) {
      map['dest_source_id'] = Variable<String>(destSourceId.value);
    }
    if (destRootRel.present) {
      map['dest_root_rel'] = Variable<String>(destRootRel.value);
    }
    if (template.present) {
      map['template'] = Variable<String>(template.value);
    }
    if (conflictPolicy.present) {
      map['conflict_policy'] = Variable<String>(conflictPolicy.value);
    }
    if (paramsJson.present) {
      map['params_json'] = Variable<String>(paramsJson.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (undoOf.present) {
      map['undo_of'] = Variable<String>(undoOf.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (confirmedAt.present) {
      map['confirmed_at'] = Variable<int>(confirmedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('destSourceId: $destSourceId, ')
          ..write('destRootRel: $destRootRel, ')
          ..write('template: $template, ')
          ..write('conflictPolicy: $conflictPolicy, ')
          ..write('paramsJson: $paramsJson, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('undoOf: $undoOf, ')
          ..write('createdAt: $createdAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class OperationItems extends Table with TableInfo<OperationItems, OperationItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  OperationItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta('operationId');
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES operations(id)',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _srcSourceIdMeta = const VerificationMeta('srcSourceId');
  late final GeneratedColumn<String> srcSourceId = GeneratedColumn<String>(
    'src_source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES sources(id)',
  );
  static const VerificationMeta _srcRelPathMeta = const VerificationMeta('srcRelPath');
  late final GeneratedColumn<String> srcRelPath = GeneratedColumn<String>(
    'src_rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _srcInstanceIdMeta = const VerificationMeta('srcInstanceId');
  late final GeneratedColumn<int> srcInstanceId = GeneratedColumn<int>(
    'src_instance_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES file_instances(id)',
  );
  static const VerificationMeta _expectedSizeMeta = const VerificationMeta('expectedSize');
  late final GeneratedColumn<int> expectedSize = GeneratedColumn<int>(
    'expected_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _expectedSha256Meta = const VerificationMeta('expectedSha256');
  late final GeneratedColumn<Uint8List> expectedSha256 = GeneratedColumn<Uint8List>(
    'expected_sha256',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dstSourceIdMeta = const VerificationMeta('dstSourceId');
  late final GeneratedColumn<String> dstSourceId = GeneratedColumn<String>(
    'dst_source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES sources(id)',
  );
  static const VerificationMeta _dstRelPathPlannedMeta = const VerificationMeta('dstRelPathPlanned');
  late final GeneratedColumn<String> dstRelPathPlanned = GeneratedColumn<String>(
    'dst_rel_path_planned',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dstRelPathFinalMeta = const VerificationMeta('dstRelPathFinal');
  late final GeneratedColumn<String> dstRelPathFinal = GeneratedColumn<String>(
    'dst_rel_path_final',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _tmpRelPathMeta = const VerificationMeta('tmpRelPath');
  late final GeneratedColumn<String> tmpRelPath = GeneratedColumn<String>(
    'tmp_rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _originalNameMeta = const VerificationMeta('originalName');
  late final GeneratedColumn<String> originalName = GeneratedColumn<String>(
    'original_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (state IN (\'pending\', \'copying\', \'copied\', \'verifying\', \'verified\', \'publishing\', \'published\', \'skipped_identical\', \'failed\', \'needs_attention\', \'undone\'))',
  );
  static const VerificationMeta _srcSha256Meta = const VerificationMeta('srcSha256');
  late final GeneratedColumn<Uint8List> srcSha256 = GeneratedColumn<Uint8List>(
    'src_sha256',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dstSha256Meta = const VerificationMeta('dstSha256');
  late final GeneratedColumn<Uint8List> dstSha256 = GeneratedColumn<Uint8List>(
    'dst_sha256',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _bytesCopiedMeta = const VerificationMeta('bytesCopied');
  late final GeneratedColumn<int> bytesCopied = GeneratedColumn<int>(
    'bytes_copied',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta('attempts');
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta('lastErrorCode');
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastErrorMessageMeta = const VerificationMeta('lastErrorMessage');
  late final GeneratedColumn<String> lastErrorMessage = GeneratedColumn<String>(
    'last_error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _expectedMtimeMeta = const VerificationMeta('expectedMtime');
  late final GeneratedColumn<int> expectedMtime = GeneratedColumn<int>(
    'expected_mtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _undoOfItemIdMeta = const VerificationMeta('undoOfItemId');
  late final GeneratedColumn<int> undoOfItemId = GeneratedColumn<int>(
    'undo_of_item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES operation_items(id)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    seq,
    srcSourceId,
    srcRelPath,
    srcInstanceId,
    expectedSize,
    expectedSha256,
    dstSourceId,
    dstRelPathPlanned,
    dstRelPathFinal,
    tmpRelPath,
    originalName,
    state,
    srcSha256,
    dstSha256,
    bytesCopied,
    attempts,
    lastErrorCode,
    lastErrorMessage,
    updatedAt,
    expectedMtime,
    undoOfItemId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_items';
  @override
  VerificationContext validateIntegrity(Insertable<OperationItemRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_id')) {
      context.handle(_operationIdMeta, operationId.isAcceptableOrUnknown(data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('src_source_id')) {
      context.handle(_srcSourceIdMeta, srcSourceId.isAcceptableOrUnknown(data['src_source_id']!, _srcSourceIdMeta));
    } else if (isInserting) {
      context.missing(_srcSourceIdMeta);
    }
    if (data.containsKey('src_rel_path')) {
      context.handle(_srcRelPathMeta, srcRelPath.isAcceptableOrUnknown(data['src_rel_path']!, _srcRelPathMeta));
    } else if (isInserting) {
      context.missing(_srcRelPathMeta);
    }
    if (data.containsKey('src_instance_id')) {
      context.handle(
        _srcInstanceIdMeta,
        srcInstanceId.isAcceptableOrUnknown(data['src_instance_id']!, _srcInstanceIdMeta),
      );
    }
    if (data.containsKey('expected_size')) {
      context.handle(_expectedSizeMeta, expectedSize.isAcceptableOrUnknown(data['expected_size']!, _expectedSizeMeta));
    } else if (isInserting) {
      context.missing(_expectedSizeMeta);
    }
    if (data.containsKey('expected_sha256')) {
      context.handle(
        _expectedSha256Meta,
        expectedSha256.isAcceptableOrUnknown(data['expected_sha256']!, _expectedSha256Meta),
      );
    }
    if (data.containsKey('dst_source_id')) {
      context.handle(_dstSourceIdMeta, dstSourceId.isAcceptableOrUnknown(data['dst_source_id']!, _dstSourceIdMeta));
    } else if (isInserting) {
      context.missing(_dstSourceIdMeta);
    }
    if (data.containsKey('dst_rel_path_planned')) {
      context.handle(
        _dstRelPathPlannedMeta,
        dstRelPathPlanned.isAcceptableOrUnknown(data['dst_rel_path_planned']!, _dstRelPathPlannedMeta),
      );
    } else if (isInserting) {
      context.missing(_dstRelPathPlannedMeta);
    }
    if (data.containsKey('dst_rel_path_final')) {
      context.handle(
        _dstRelPathFinalMeta,
        dstRelPathFinal.isAcceptableOrUnknown(data['dst_rel_path_final']!, _dstRelPathFinalMeta),
      );
    }
    if (data.containsKey('tmp_rel_path')) {
      context.handle(_tmpRelPathMeta, tmpRelPath.isAcceptableOrUnknown(data['tmp_rel_path']!, _tmpRelPathMeta));
    }
    if (data.containsKey('original_name')) {
      context.handle(_originalNameMeta, originalName.isAcceptableOrUnknown(data['original_name']!, _originalNameMeta));
    }
    if (data.containsKey('state')) {
      context.handle(_stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('src_sha256')) {
      context.handle(_srcSha256Meta, srcSha256.isAcceptableOrUnknown(data['src_sha256']!, _srcSha256Meta));
    }
    if (data.containsKey('dst_sha256')) {
      context.handle(_dstSha256Meta, dstSha256.isAcceptableOrUnknown(data['dst_sha256']!, _dstSha256Meta));
    }
    if (data.containsKey('bytes_copied')) {
      context.handle(_bytesCopiedMeta, bytesCopied.isAcceptableOrUnknown(data['bytes_copied']!, _bytesCopiedMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta, attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(data['last_error_code']!, _lastErrorCodeMeta),
      );
    }
    if (data.containsKey('last_error_message')) {
      context.handle(
        _lastErrorMessageMeta,
        lastErrorMessage.isAcceptableOrUnknown(data['last_error_message']!, _lastErrorMessageMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('expected_mtime')) {
      context.handle(
        _expectedMtimeMeta,
        expectedMtime.isAcceptableOrUnknown(data['expected_mtime']!, _expectedMtimeMeta),
      );
    }
    if (data.containsKey('undo_of_item_id')) {
      context.handle(
        _undoOfItemIdMeta,
        undoOfItemId.isAcceptableOrUnknown(data['undo_of_item_id']!, _undoOfItemIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {operationId, seq},
  ];
  @override
  OperationItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationItemRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      operationId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      srcSourceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}src_source_id'])!,
      srcRelPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}src_rel_path'])!,
      srcInstanceId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}src_instance_id']),
      expectedSize: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}expected_size'])!,
      expectedSha256: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}expected_sha256']),
      dstSourceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}dst_source_id'])!,
      dstRelPathPlanned: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dst_rel_path_planned'],
      )!,
      dstRelPathFinal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dst_rel_path_final'],
      ),
      tmpRelPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tmp_rel_path']),
      originalName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}original_name']),
      state: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      srcSha256: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}src_sha256']),
      dstSha256: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}dst_sha256']),
      bytesCopied: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}bytes_copied'])!,
      attempts: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastErrorCode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}last_error_code']),
      lastErrorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_message'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      expectedMtime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}expected_mtime']),
      undoOfItemId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}undo_of_item_id']),
    );
  }

  @override
  OperationItems createAlias(String alias) {
    return OperationItems(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(operation_id, seq)'];
  @override
  bool get dontWriteConstraints => true;
}

class OperationItemRow extends DataClass implements Insertable<OperationItemRow> {
  final int id;
  final String operationId;
  final int seq;
  final String srcSourceId;
  final String srcRelPath;
  final int? srcInstanceId;
  final int expectedSize;
  final Uint8List? expectedSha256;
  final String dstSourceId;
  final String dstRelPathPlanned;
  final String? dstRelPathFinal;
  final String? tmpRelPath;
  final String? originalName;
  final String state;
  final Uint8List? srcSha256;
  final Uint8List? dstSha256;
  final int bytesCopied;
  final int attempts;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final int updatedAt;

  /// v5 (Fase 6): data de modificação (FILETIME) do arquivo no momento do mover;
  /// o Desfazer compara com ela para saber se o arquivo mudou desde então.
  final int? expectedMtime;

  /// v5: no Desfazer, o item da reorganização que este item devolve.
  final int? undoOfItemId;
  const OperationItemRow({
    required this.id,
    required this.operationId,
    required this.seq,
    required this.srcSourceId,
    required this.srcRelPath,
    this.srcInstanceId,
    required this.expectedSize,
    this.expectedSha256,
    required this.dstSourceId,
    required this.dstRelPathPlanned,
    this.dstRelPathFinal,
    this.tmpRelPath,
    this.originalName,
    required this.state,
    this.srcSha256,
    this.dstSha256,
    required this.bytesCopied,
    required this.attempts,
    this.lastErrorCode,
    this.lastErrorMessage,
    required this.updatedAt,
    this.expectedMtime,
    this.undoOfItemId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_id'] = Variable<String>(operationId);
    map['seq'] = Variable<int>(seq);
    map['src_source_id'] = Variable<String>(srcSourceId);
    map['src_rel_path'] = Variable<String>(srcRelPath);
    if (!nullToAbsent || srcInstanceId != null) {
      map['src_instance_id'] = Variable<int>(srcInstanceId);
    }
    map['expected_size'] = Variable<int>(expectedSize);
    if (!nullToAbsent || expectedSha256 != null) {
      map['expected_sha256'] = Variable<Uint8List>(expectedSha256);
    }
    map['dst_source_id'] = Variable<String>(dstSourceId);
    map['dst_rel_path_planned'] = Variable<String>(dstRelPathPlanned);
    if (!nullToAbsent || dstRelPathFinal != null) {
      map['dst_rel_path_final'] = Variable<String>(dstRelPathFinal);
    }
    if (!nullToAbsent || tmpRelPath != null) {
      map['tmp_rel_path'] = Variable<String>(tmpRelPath);
    }
    if (!nullToAbsent || originalName != null) {
      map['original_name'] = Variable<String>(originalName);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || srcSha256 != null) {
      map['src_sha256'] = Variable<Uint8List>(srcSha256);
    }
    if (!nullToAbsent || dstSha256 != null) {
      map['dst_sha256'] = Variable<Uint8List>(dstSha256);
    }
    map['bytes_copied'] = Variable<int>(bytesCopied);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || lastErrorMessage != null) {
      map['last_error_message'] = Variable<String>(lastErrorMessage);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || expectedMtime != null) {
      map['expected_mtime'] = Variable<int>(expectedMtime);
    }
    if (!nullToAbsent || undoOfItemId != null) {
      map['undo_of_item_id'] = Variable<int>(undoOfItemId);
    }
    return map;
  }

  OperationItemsCompanion toCompanion(bool nullToAbsent) {
    return OperationItemsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      seq: Value(seq),
      srcSourceId: Value(srcSourceId),
      srcRelPath: Value(srcRelPath),
      srcInstanceId: srcInstanceId == null && nullToAbsent ? const Value.absent() : Value(srcInstanceId),
      expectedSize: Value(expectedSize),
      expectedSha256: expectedSha256 == null && nullToAbsent ? const Value.absent() : Value(expectedSha256),
      dstSourceId: Value(dstSourceId),
      dstRelPathPlanned: Value(dstRelPathPlanned),
      dstRelPathFinal: dstRelPathFinal == null && nullToAbsent ? const Value.absent() : Value(dstRelPathFinal),
      tmpRelPath: tmpRelPath == null && nullToAbsent ? const Value.absent() : Value(tmpRelPath),
      originalName: originalName == null && nullToAbsent ? const Value.absent() : Value(originalName),
      state: Value(state),
      srcSha256: srcSha256 == null && nullToAbsent ? const Value.absent() : Value(srcSha256),
      dstSha256: dstSha256 == null && nullToAbsent ? const Value.absent() : Value(dstSha256),
      bytesCopied: Value(bytesCopied),
      attempts: Value(attempts),
      lastErrorCode: lastErrorCode == null && nullToAbsent ? const Value.absent() : Value(lastErrorCode),
      lastErrorMessage: lastErrorMessage == null && nullToAbsent ? const Value.absent() : Value(lastErrorMessage),
      updatedAt: Value(updatedAt),
      expectedMtime: expectedMtime == null && nullToAbsent ? const Value.absent() : Value(expectedMtime),
      undoOfItemId: undoOfItemId == null && nullToAbsent ? const Value.absent() : Value(undoOfItemId),
    );
  }

  factory OperationItemRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationItemRow(
      id: serializer.fromJson<int>(json['id']),
      operationId: serializer.fromJson<String>(json['operation_id']),
      seq: serializer.fromJson<int>(json['seq']),
      srcSourceId: serializer.fromJson<String>(json['src_source_id']),
      srcRelPath: serializer.fromJson<String>(json['src_rel_path']),
      srcInstanceId: serializer.fromJson<int?>(json['src_instance_id']),
      expectedSize: serializer.fromJson<int>(json['expected_size']),
      expectedSha256: serializer.fromJson<Uint8List?>(json['expected_sha256']),
      dstSourceId: serializer.fromJson<String>(json['dst_source_id']),
      dstRelPathPlanned: serializer.fromJson<String>(json['dst_rel_path_planned']),
      dstRelPathFinal: serializer.fromJson<String?>(json['dst_rel_path_final']),
      tmpRelPath: serializer.fromJson<String?>(json['tmp_rel_path']),
      originalName: serializer.fromJson<String?>(json['original_name']),
      state: serializer.fromJson<String>(json['state']),
      srcSha256: serializer.fromJson<Uint8List?>(json['src_sha256']),
      dstSha256: serializer.fromJson<Uint8List?>(json['dst_sha256']),
      bytesCopied: serializer.fromJson<int>(json['bytes_copied']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastErrorCode: serializer.fromJson<String?>(json['last_error_code']),
      lastErrorMessage: serializer.fromJson<String?>(json['last_error_message']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      expectedMtime: serializer.fromJson<int?>(json['expected_mtime']),
      undoOfItemId: serializer.fromJson<int?>(json['undo_of_item_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation_id': serializer.toJson<String>(operationId),
      'seq': serializer.toJson<int>(seq),
      'src_source_id': serializer.toJson<String>(srcSourceId),
      'src_rel_path': serializer.toJson<String>(srcRelPath),
      'src_instance_id': serializer.toJson<int?>(srcInstanceId),
      'expected_size': serializer.toJson<int>(expectedSize),
      'expected_sha256': serializer.toJson<Uint8List?>(expectedSha256),
      'dst_source_id': serializer.toJson<String>(dstSourceId),
      'dst_rel_path_planned': serializer.toJson<String>(dstRelPathPlanned),
      'dst_rel_path_final': serializer.toJson<String?>(dstRelPathFinal),
      'tmp_rel_path': serializer.toJson<String?>(tmpRelPath),
      'original_name': serializer.toJson<String?>(originalName),
      'state': serializer.toJson<String>(state),
      'src_sha256': serializer.toJson<Uint8List?>(srcSha256),
      'dst_sha256': serializer.toJson<Uint8List?>(dstSha256),
      'bytes_copied': serializer.toJson<int>(bytesCopied),
      'attempts': serializer.toJson<int>(attempts),
      'last_error_code': serializer.toJson<String?>(lastErrorCode),
      'last_error_message': serializer.toJson<String?>(lastErrorMessage),
      'updated_at': serializer.toJson<int>(updatedAt),
      'expected_mtime': serializer.toJson<int?>(expectedMtime),
      'undo_of_item_id': serializer.toJson<int?>(undoOfItemId),
    };
  }

  OperationItemRow copyWith({
    int? id,
    String? operationId,
    int? seq,
    String? srcSourceId,
    String? srcRelPath,
    Value<int?> srcInstanceId = const Value.absent(),
    int? expectedSize,
    Value<Uint8List?> expectedSha256 = const Value.absent(),
    String? dstSourceId,
    String? dstRelPathPlanned,
    Value<String?> dstRelPathFinal = const Value.absent(),
    Value<String?> tmpRelPath = const Value.absent(),
    Value<String?> originalName = const Value.absent(),
    String? state,
    Value<Uint8List?> srcSha256 = const Value.absent(),
    Value<Uint8List?> dstSha256 = const Value.absent(),
    int? bytesCopied,
    int? attempts,
    Value<String?> lastErrorCode = const Value.absent(),
    Value<String?> lastErrorMessage = const Value.absent(),
    int? updatedAt,
    Value<int?> expectedMtime = const Value.absent(),
    Value<int?> undoOfItemId = const Value.absent(),
  }) => OperationItemRow(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    seq: seq ?? this.seq,
    srcSourceId: srcSourceId ?? this.srcSourceId,
    srcRelPath: srcRelPath ?? this.srcRelPath,
    srcInstanceId: srcInstanceId.present ? srcInstanceId.value : this.srcInstanceId,
    expectedSize: expectedSize ?? this.expectedSize,
    expectedSha256: expectedSha256.present ? expectedSha256.value : this.expectedSha256,
    dstSourceId: dstSourceId ?? this.dstSourceId,
    dstRelPathPlanned: dstRelPathPlanned ?? this.dstRelPathPlanned,
    dstRelPathFinal: dstRelPathFinal.present ? dstRelPathFinal.value : this.dstRelPathFinal,
    tmpRelPath: tmpRelPath.present ? tmpRelPath.value : this.tmpRelPath,
    originalName: originalName.present ? originalName.value : this.originalName,
    state: state ?? this.state,
    srcSha256: srcSha256.present ? srcSha256.value : this.srcSha256,
    dstSha256: dstSha256.present ? dstSha256.value : this.dstSha256,
    bytesCopied: bytesCopied ?? this.bytesCopied,
    attempts: attempts ?? this.attempts,
    lastErrorCode: lastErrorCode.present ? lastErrorCode.value : this.lastErrorCode,
    lastErrorMessage: lastErrorMessage.present ? lastErrorMessage.value : this.lastErrorMessage,
    updatedAt: updatedAt ?? this.updatedAt,
    expectedMtime: expectedMtime.present ? expectedMtime.value : this.expectedMtime,
    undoOfItemId: undoOfItemId.present ? undoOfItemId.value : this.undoOfItemId,
  );
  OperationItemRow copyWithCompanion(OperationItemsCompanion data) {
    return OperationItemRow(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present ? data.operationId.value : this.operationId,
      seq: data.seq.present ? data.seq.value : this.seq,
      srcSourceId: data.srcSourceId.present ? data.srcSourceId.value : this.srcSourceId,
      srcRelPath: data.srcRelPath.present ? data.srcRelPath.value : this.srcRelPath,
      srcInstanceId: data.srcInstanceId.present ? data.srcInstanceId.value : this.srcInstanceId,
      expectedSize: data.expectedSize.present ? data.expectedSize.value : this.expectedSize,
      expectedSha256: data.expectedSha256.present ? data.expectedSha256.value : this.expectedSha256,
      dstSourceId: data.dstSourceId.present ? data.dstSourceId.value : this.dstSourceId,
      dstRelPathPlanned: data.dstRelPathPlanned.present ? data.dstRelPathPlanned.value : this.dstRelPathPlanned,
      dstRelPathFinal: data.dstRelPathFinal.present ? data.dstRelPathFinal.value : this.dstRelPathFinal,
      tmpRelPath: data.tmpRelPath.present ? data.tmpRelPath.value : this.tmpRelPath,
      originalName: data.originalName.present ? data.originalName.value : this.originalName,
      state: data.state.present ? data.state.value : this.state,
      srcSha256: data.srcSha256.present ? data.srcSha256.value : this.srcSha256,
      dstSha256: data.dstSha256.present ? data.dstSha256.value : this.dstSha256,
      bytesCopied: data.bytesCopied.present ? data.bytesCopied.value : this.bytesCopied,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastErrorCode: data.lastErrorCode.present ? data.lastErrorCode.value : this.lastErrorCode,
      lastErrorMessage: data.lastErrorMessage.present ? data.lastErrorMessage.value : this.lastErrorMessage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      expectedMtime: data.expectedMtime.present ? data.expectedMtime.value : this.expectedMtime,
      undoOfItemId: data.undoOfItemId.present ? data.undoOfItemId.value : this.undoOfItemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationItemRow(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('seq: $seq, ')
          ..write('srcSourceId: $srcSourceId, ')
          ..write('srcRelPath: $srcRelPath, ')
          ..write('srcInstanceId: $srcInstanceId, ')
          ..write('expectedSize: $expectedSize, ')
          ..write('expectedSha256: $expectedSha256, ')
          ..write('dstSourceId: $dstSourceId, ')
          ..write('dstRelPathPlanned: $dstRelPathPlanned, ')
          ..write('dstRelPathFinal: $dstRelPathFinal, ')
          ..write('tmpRelPath: $tmpRelPath, ')
          ..write('originalName: $originalName, ')
          ..write('state: $state, ')
          ..write('srcSha256: $srcSha256, ')
          ..write('dstSha256: $dstSha256, ')
          ..write('bytesCopied: $bytesCopied, ')
          ..write('attempts: $attempts, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('expectedMtime: $expectedMtime, ')
          ..write('undoOfItemId: $undoOfItemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    operationId,
    seq,
    srcSourceId,
    srcRelPath,
    srcInstanceId,
    expectedSize,
    $driftBlobEquality.hash(expectedSha256),
    dstSourceId,
    dstRelPathPlanned,
    dstRelPathFinal,
    tmpRelPath,
    originalName,
    state,
    $driftBlobEquality.hash(srcSha256),
    $driftBlobEquality.hash(dstSha256),
    bytesCopied,
    attempts,
    lastErrorCode,
    lastErrorMessage,
    updatedAt,
    expectedMtime,
    undoOfItemId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationItemRow &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.seq == this.seq &&
          other.srcSourceId == this.srcSourceId &&
          other.srcRelPath == this.srcRelPath &&
          other.srcInstanceId == this.srcInstanceId &&
          other.expectedSize == this.expectedSize &&
          $driftBlobEquality.equals(other.expectedSha256, this.expectedSha256) &&
          other.dstSourceId == this.dstSourceId &&
          other.dstRelPathPlanned == this.dstRelPathPlanned &&
          other.dstRelPathFinal == this.dstRelPathFinal &&
          other.tmpRelPath == this.tmpRelPath &&
          other.originalName == this.originalName &&
          other.state == this.state &&
          $driftBlobEquality.equals(other.srcSha256, this.srcSha256) &&
          $driftBlobEquality.equals(other.dstSha256, this.dstSha256) &&
          other.bytesCopied == this.bytesCopied &&
          other.attempts == this.attempts &&
          other.lastErrorCode == this.lastErrorCode &&
          other.lastErrorMessage == this.lastErrorMessage &&
          other.updatedAt == this.updatedAt &&
          other.expectedMtime == this.expectedMtime &&
          other.undoOfItemId == this.undoOfItemId);
}

class OperationItemsCompanion extends UpdateCompanion<OperationItemRow> {
  final Value<int> id;
  final Value<String> operationId;
  final Value<int> seq;
  final Value<String> srcSourceId;
  final Value<String> srcRelPath;
  final Value<int?> srcInstanceId;
  final Value<int> expectedSize;
  final Value<Uint8List?> expectedSha256;
  final Value<String> dstSourceId;
  final Value<String> dstRelPathPlanned;
  final Value<String?> dstRelPathFinal;
  final Value<String?> tmpRelPath;
  final Value<String?> originalName;
  final Value<String> state;
  final Value<Uint8List?> srcSha256;
  final Value<Uint8List?> dstSha256;
  final Value<int> bytesCopied;
  final Value<int> attempts;
  final Value<String?> lastErrorCode;
  final Value<String?> lastErrorMessage;
  final Value<int> updatedAt;
  final Value<int?> expectedMtime;
  final Value<int?> undoOfItemId;
  const OperationItemsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.seq = const Value.absent(),
    this.srcSourceId = const Value.absent(),
    this.srcRelPath = const Value.absent(),
    this.srcInstanceId = const Value.absent(),
    this.expectedSize = const Value.absent(),
    this.expectedSha256 = const Value.absent(),
    this.dstSourceId = const Value.absent(),
    this.dstRelPathPlanned = const Value.absent(),
    this.dstRelPathFinal = const Value.absent(),
    this.tmpRelPath = const Value.absent(),
    this.originalName = const Value.absent(),
    this.state = const Value.absent(),
    this.srcSha256 = const Value.absent(),
    this.dstSha256 = const Value.absent(),
    this.bytesCopied = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.expectedMtime = const Value.absent(),
    this.undoOfItemId = const Value.absent(),
  });
  OperationItemsCompanion.insert({
    this.id = const Value.absent(),
    required String operationId,
    required int seq,
    required String srcSourceId,
    required String srcRelPath,
    this.srcInstanceId = const Value.absent(),
    required int expectedSize,
    this.expectedSha256 = const Value.absent(),
    required String dstSourceId,
    required String dstRelPathPlanned,
    this.dstRelPathFinal = const Value.absent(),
    this.tmpRelPath = const Value.absent(),
    this.originalName = const Value.absent(),
    required String state,
    this.srcSha256 = const Value.absent(),
    this.dstSha256 = const Value.absent(),
    this.bytesCopied = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    required int updatedAt,
    this.expectedMtime = const Value.absent(),
    this.undoOfItemId = const Value.absent(),
  }) : operationId = Value(operationId),
       seq = Value(seq),
       srcSourceId = Value(srcSourceId),
       srcRelPath = Value(srcRelPath),
       expectedSize = Value(expectedSize),
       dstSourceId = Value(dstSourceId),
       dstRelPathPlanned = Value(dstRelPathPlanned),
       state = Value(state),
       updatedAt = Value(updatedAt);
  static Insertable<OperationItemRow> custom({
    Expression<int>? id,
    Expression<String>? operationId,
    Expression<int>? seq,
    Expression<String>? srcSourceId,
    Expression<String>? srcRelPath,
    Expression<int>? srcInstanceId,
    Expression<int>? expectedSize,
    Expression<Uint8List>? expectedSha256,
    Expression<String>? dstSourceId,
    Expression<String>? dstRelPathPlanned,
    Expression<String>? dstRelPathFinal,
    Expression<String>? tmpRelPath,
    Expression<String>? originalName,
    Expression<String>? state,
    Expression<Uint8List>? srcSha256,
    Expression<Uint8List>? dstSha256,
    Expression<int>? bytesCopied,
    Expression<int>? attempts,
    Expression<String>? lastErrorCode,
    Expression<String>? lastErrorMessage,
    Expression<int>? updatedAt,
    Expression<int>? expectedMtime,
    Expression<int>? undoOfItemId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (seq != null) 'seq': seq,
      if (srcSourceId != null) 'src_source_id': srcSourceId,
      if (srcRelPath != null) 'src_rel_path': srcRelPath,
      if (srcInstanceId != null) 'src_instance_id': srcInstanceId,
      if (expectedSize != null) 'expected_size': expectedSize,
      if (expectedSha256 != null) 'expected_sha256': expectedSha256,
      if (dstSourceId != null) 'dst_source_id': dstSourceId,
      if (dstRelPathPlanned != null) 'dst_rel_path_planned': dstRelPathPlanned,
      if (dstRelPathFinal != null) 'dst_rel_path_final': dstRelPathFinal,
      if (tmpRelPath != null) 'tmp_rel_path': tmpRelPath,
      if (originalName != null) 'original_name': originalName,
      if (state != null) 'state': state,
      if (srcSha256 != null) 'src_sha256': srcSha256,
      if (dstSha256 != null) 'dst_sha256': dstSha256,
      if (bytesCopied != null) 'bytes_copied': bytesCopied,
      if (attempts != null) 'attempts': attempts,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (expectedMtime != null) 'expected_mtime': expectedMtime,
      if (undoOfItemId != null) 'undo_of_item_id': undoOfItemId,
    });
  }

  OperationItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? operationId,
    Value<int>? seq,
    Value<String>? srcSourceId,
    Value<String>? srcRelPath,
    Value<int?>? srcInstanceId,
    Value<int>? expectedSize,
    Value<Uint8List?>? expectedSha256,
    Value<String>? dstSourceId,
    Value<String>? dstRelPathPlanned,
    Value<String?>? dstRelPathFinal,
    Value<String?>? tmpRelPath,
    Value<String?>? originalName,
    Value<String>? state,
    Value<Uint8List?>? srcSha256,
    Value<Uint8List?>? dstSha256,
    Value<int>? bytesCopied,
    Value<int>? attempts,
    Value<String?>? lastErrorCode,
    Value<String?>? lastErrorMessage,
    Value<int>? updatedAt,
    Value<int?>? expectedMtime,
    Value<int?>? undoOfItemId,
  }) {
    return OperationItemsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      seq: seq ?? this.seq,
      srcSourceId: srcSourceId ?? this.srcSourceId,
      srcRelPath: srcRelPath ?? this.srcRelPath,
      srcInstanceId: srcInstanceId ?? this.srcInstanceId,
      expectedSize: expectedSize ?? this.expectedSize,
      expectedSha256: expectedSha256 ?? this.expectedSha256,
      dstSourceId: dstSourceId ?? this.dstSourceId,
      dstRelPathPlanned: dstRelPathPlanned ?? this.dstRelPathPlanned,
      dstRelPathFinal: dstRelPathFinal ?? this.dstRelPathFinal,
      tmpRelPath: tmpRelPath ?? this.tmpRelPath,
      originalName: originalName ?? this.originalName,
      state: state ?? this.state,
      srcSha256: srcSha256 ?? this.srcSha256,
      dstSha256: dstSha256 ?? this.dstSha256,
      bytesCopied: bytesCopied ?? this.bytesCopied,
      attempts: attempts ?? this.attempts,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      expectedMtime: expectedMtime ?? this.expectedMtime,
      undoOfItemId: undoOfItemId ?? this.undoOfItemId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (srcSourceId.present) {
      map['src_source_id'] = Variable<String>(srcSourceId.value);
    }
    if (srcRelPath.present) {
      map['src_rel_path'] = Variable<String>(srcRelPath.value);
    }
    if (srcInstanceId.present) {
      map['src_instance_id'] = Variable<int>(srcInstanceId.value);
    }
    if (expectedSize.present) {
      map['expected_size'] = Variable<int>(expectedSize.value);
    }
    if (expectedSha256.present) {
      map['expected_sha256'] = Variable<Uint8List>(expectedSha256.value);
    }
    if (dstSourceId.present) {
      map['dst_source_id'] = Variable<String>(dstSourceId.value);
    }
    if (dstRelPathPlanned.present) {
      map['dst_rel_path_planned'] = Variable<String>(dstRelPathPlanned.value);
    }
    if (dstRelPathFinal.present) {
      map['dst_rel_path_final'] = Variable<String>(dstRelPathFinal.value);
    }
    if (tmpRelPath.present) {
      map['tmp_rel_path'] = Variable<String>(tmpRelPath.value);
    }
    if (originalName.present) {
      map['original_name'] = Variable<String>(originalName.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (srcSha256.present) {
      map['src_sha256'] = Variable<Uint8List>(srcSha256.value);
    }
    if (dstSha256.present) {
      map['dst_sha256'] = Variable<Uint8List>(dstSha256.value);
    }
    if (bytesCopied.present) {
      map['bytes_copied'] = Variable<int>(bytesCopied.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (lastErrorMessage.present) {
      map['last_error_message'] = Variable<String>(lastErrorMessage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (expectedMtime.present) {
      map['expected_mtime'] = Variable<int>(expectedMtime.value);
    }
    if (undoOfItemId.present) {
      map['undo_of_item_id'] = Variable<int>(undoOfItemId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationItemsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('seq: $seq, ')
          ..write('srcSourceId: $srcSourceId, ')
          ..write('srcRelPath: $srcRelPath, ')
          ..write('srcInstanceId: $srcInstanceId, ')
          ..write('expectedSize: $expectedSize, ')
          ..write('expectedSha256: $expectedSha256, ')
          ..write('dstSourceId: $dstSourceId, ')
          ..write('dstRelPathPlanned: $dstRelPathPlanned, ')
          ..write('dstRelPathFinal: $dstRelPathFinal, ')
          ..write('tmpRelPath: $tmpRelPath, ')
          ..write('originalName: $originalName, ')
          ..write('state: $state, ')
          ..write('srcSha256: $srcSha256, ')
          ..write('dstSha256: $dstSha256, ')
          ..write('bytesCopied: $bytesCopied, ')
          ..write('attempts: $attempts, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('expectedMtime: $expectedMtime, ')
          ..write('undoOfItemId: $undoOfItemId')
          ..write(')'))
        .toString();
  }
}

class OperationEvents extends Table with TableInfo<OperationEvents, OperationEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  OperationEvents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta('operationId');
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES operations(id)',
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES operation_items(id)',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fromStateMeta = const VerificationMeta('fromState');
  late final GeneratedColumn<String> fromState = GeneratedColumn<String>(
    'from_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _toStateMeta = const VerificationMeta('toState');
  late final GeneratedColumn<String> toState = GeneratedColumn<String>(
    'to_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _messageMeta = const VerificationMeta('message');
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [id, operationId, itemId, at, fromState, toState, message];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_events';
  @override
  VerificationContext validateIntegrity(Insertable<OperationEventRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_id')) {
      context.handle(_operationIdMeta, operationId.isAcceptableOrUnknown(data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta, itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('from_state')) {
      context.handle(_fromStateMeta, fromState.isAcceptableOrUnknown(data['from_state']!, _fromStateMeta));
    }
    if (data.containsKey('to_state')) {
      context.handle(_toStateMeta, toState.isAcceptableOrUnknown(data['to_state']!, _toStateMeta));
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta, message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationEventRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      operationId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      itemId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}item_id']),
      at: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}at'])!,
      fromState: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}from_state']),
      toState: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}to_state']),
      message: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}message']),
    );
  }

  @override
  OperationEvents createAlias(String alias) {
    return OperationEvents(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class OperationEventRow extends DataClass implements Insertable<OperationEventRow> {
  final int id;
  final String operationId;
  final int? itemId;
  final int at;
  final String? fromState;
  final String? toState;
  final String? message;
  const OperationEventRow({
    required this.id,
    required this.operationId,
    this.itemId,
    required this.at,
    this.fromState,
    this.toState,
    this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<int>(itemId);
    }
    map['at'] = Variable<int>(at);
    if (!nullToAbsent || fromState != null) {
      map['from_state'] = Variable<String>(fromState);
    }
    if (!nullToAbsent || toState != null) {
      map['to_state'] = Variable<String>(toState);
    }
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    return map;
  }

  OperationEventsCompanion toCompanion(bool nullToAbsent) {
    return OperationEventsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      itemId: itemId == null && nullToAbsent ? const Value.absent() : Value(itemId),
      at: Value(at),
      fromState: fromState == null && nullToAbsent ? const Value.absent() : Value(fromState),
      toState: toState == null && nullToAbsent ? const Value.absent() : Value(toState),
      message: message == null && nullToAbsent ? const Value.absent() : Value(message),
    );
  }

  factory OperationEventRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationEventRow(
      id: serializer.fromJson<int>(json['id']),
      operationId: serializer.fromJson<String>(json['operation_id']),
      itemId: serializer.fromJson<int?>(json['item_id']),
      at: serializer.fromJson<int>(json['at']),
      fromState: serializer.fromJson<String?>(json['from_state']),
      toState: serializer.fromJson<String?>(json['to_state']),
      message: serializer.fromJson<String?>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation_id': serializer.toJson<String>(operationId),
      'item_id': serializer.toJson<int?>(itemId),
      'at': serializer.toJson<int>(at),
      'from_state': serializer.toJson<String?>(fromState),
      'to_state': serializer.toJson<String?>(toState),
      'message': serializer.toJson<String?>(message),
    };
  }

  OperationEventRow copyWith({
    int? id,
    String? operationId,
    Value<int?> itemId = const Value.absent(),
    int? at,
    Value<String?> fromState = const Value.absent(),
    Value<String?> toState = const Value.absent(),
    Value<String?> message = const Value.absent(),
  }) => OperationEventRow(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    itemId: itemId.present ? itemId.value : this.itemId,
    at: at ?? this.at,
    fromState: fromState.present ? fromState.value : this.fromState,
    toState: toState.present ? toState.value : this.toState,
    message: message.present ? message.value : this.message,
  );
  OperationEventRow copyWithCompanion(OperationEventsCompanion data) {
    return OperationEventRow(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present ? data.operationId.value : this.operationId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      at: data.at.present ? data.at.value : this.at,
      fromState: data.fromState.present ? data.fromState.value : this.fromState,
      toState: data.toState.present ? data.toState.value : this.toState,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationEventRow(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('itemId: $itemId, ')
          ..write('at: $at, ')
          ..write('fromState: $fromState, ')
          ..write('toState: $toState, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, operationId, itemId, at, fromState, toState, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationEventRow &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.itemId == this.itemId &&
          other.at == this.at &&
          other.fromState == this.fromState &&
          other.toState == this.toState &&
          other.message == this.message);
}

class OperationEventsCompanion extends UpdateCompanion<OperationEventRow> {
  final Value<int> id;
  final Value<String> operationId;
  final Value<int?> itemId;
  final Value<int> at;
  final Value<String?> fromState;
  final Value<String?> toState;
  final Value<String?> message;
  const OperationEventsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.at = const Value.absent(),
    this.fromState = const Value.absent(),
    this.toState = const Value.absent(),
    this.message = const Value.absent(),
  });
  OperationEventsCompanion.insert({
    this.id = const Value.absent(),
    required String operationId,
    this.itemId = const Value.absent(),
    required int at,
    this.fromState = const Value.absent(),
    this.toState = const Value.absent(),
    this.message = const Value.absent(),
  }) : operationId = Value(operationId),
       at = Value(at);
  static Insertable<OperationEventRow> custom({
    Expression<int>? id,
    Expression<String>? operationId,
    Expression<int>? itemId,
    Expression<int>? at,
    Expression<String>? fromState,
    Expression<String>? toState,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (itemId != null) 'item_id': itemId,
      if (at != null) 'at': at,
      if (fromState != null) 'from_state': fromState,
      if (toState != null) 'to_state': toState,
      if (message != null) 'message': message,
    });
  }

  OperationEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? operationId,
    Value<int?>? itemId,
    Value<int>? at,
    Value<String?>? fromState,
    Value<String?>? toState,
    Value<String?>? message,
  }) {
    return OperationEventsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      itemId: itemId ?? this.itemId,
      at: at ?? this.at,
      fromState: fromState ?? this.fromState,
      toState: toState ?? this.toState,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (fromState.present) {
      map['from_state'] = Variable<String>(fromState.value);
    }
    if (toState.present) {
      map['to_state'] = Variable<String>(toState.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationEventsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('itemId: $itemId, ')
          ..write('at: $at, ')
          ..write('fromState: $fromState, ')
          ..write('toState: $toState, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

class SavedFilters extends Table with TableInfo<SavedFilters, SavedFilterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SavedFilters(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _definitionJsonMeta = const VerificationMeta('definitionJson');
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
    'definition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, definitionJson, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_filters';
  @override
  VerificationContext validateIntegrity(Insertable<SavedFilterRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('definition_json')) {
      context.handle(
        _definitionJsonMeta,
        definitionJson.isAcceptableOrUnknown(data['definition_json']!, _definitionJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedFilterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedFilterRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      definitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  SavedFilters createAlias(String alias) {
    return SavedFilters(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SavedFilterRow extends DataClass implements Insertable<SavedFilterRow> {
  final int id;
  final String name;
  final String definitionJson;
  final int createdAt;
  final int updatedAt;
  const SavedFilterRow({
    required this.id,
    required this.name,
    required this.definitionJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['definition_json'] = Variable<String>(definitionJson);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SavedFiltersCompanion toCompanion(bool nullToAbsent) {
    return SavedFiltersCompanion(
      id: Value(id),
      name: Value(name),
      definitionJson: Value(definitionJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedFilterRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedFilterRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      definitionJson: serializer.fromJson<String>(json['definition_json']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'definition_json': serializer.toJson<String>(definitionJson),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  SavedFilterRow copyWith({int? id, String? name, String? definitionJson, int? createdAt, int? updatedAt}) =>
      SavedFilterRow(
        id: id ?? this.id,
        name: name ?? this.name,
        definitionJson: definitionJson ?? this.definitionJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SavedFilterRow copyWithCompanion(SavedFiltersCompanion data) {
    return SavedFilterRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      definitionJson: data.definitionJson.present ? data.definitionJson.value : this.definitionJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedFilterRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, definitionJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedFilterRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.definitionJson == this.definitionJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SavedFiltersCompanion extends UpdateCompanion<SavedFilterRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> definitionJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const SavedFiltersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SavedFiltersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String definitionJson,
    required int createdAt,
    required int updatedAt,
  }) : name = Value(name),
       definitionJson = Value(definitionJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedFilterRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? definitionJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SavedFiltersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? definitionJson,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return SavedFiltersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      definitionJson: definitionJson ?? this.definitionJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedFiltersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class SelectionSets extends Table with TableInfo<SelectionSets, SelectionSetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SelectionSets(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'selection_sets';
  @override
  VerificationContext validateIntegrity(Insertable<SelectionSetRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SelectionSetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SelectionSetRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  SelectionSets createAlias(String alias) {
    return SelectionSets(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SelectionSetRow extends DataClass implements Insertable<SelectionSetRow> {
  final int id;
  final String name;
  final int createdAt;
  const SelectionSetRow({required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SelectionSetsCompanion toCompanion(bool nullToAbsent) {
    return SelectionSetsCompanion(id: Value(id), name: Value(name), createdAt: Value(createdAt));
  }

  factory SelectionSetRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SelectionSetRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  SelectionSetRow copyWith({int? id, String? name, int? createdAt}) =>
      SelectionSetRow(id: id ?? this.id, name: name ?? this.name, createdAt: createdAt ?? this.createdAt);
  SelectionSetRow copyWithCompanion(SelectionSetsCompanion data) {
    return SelectionSetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SelectionSetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SelectionSetRow && other.id == this.id && other.name == this.name && other.createdAt == this.createdAt);
}

class SelectionSetsCompanion extends UpdateCompanion<SelectionSetRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> createdAt;
  const SelectionSetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SelectionSetsCompanion.insert({this.id = const Value.absent(), required String name, required int createdAt})
    : name = Value(name),
      createdAt = Value(createdAt);
  static Insertable<SelectionSetRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SelectionSetsCompanion copyWith({Value<int>? id, Value<String>? name, Value<int>? createdAt}) {
    return SelectionSetsCompanion(id: id ?? this.id, name: name ?? this.name, createdAt: createdAt ?? this.createdAt);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SelectionSetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class SelectionSetItems extends Table with TableInfo<SelectionSetItems, SelectionSetItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SelectionSetItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES selection_sets(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _instanceIdMeta = const VerificationMeta('instanceId');
  late final GeneratedColumn<int> instanceId = GeneratedColumn<int>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES file_instances(id)',
  );
  @override
  List<GeneratedColumn> get $columns => [setId, instanceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'selection_set_items';
  @override
  VerificationContext validateIntegrity(Insertable<SelectionSetItemRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('set_id')) {
      context.handle(_setIdMeta, setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta));
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('instance_id')) {
      context.handle(_instanceIdMeta, instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta));
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setId, instanceId};
  @override
  SelectionSetItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SelectionSetItemRow(
      setId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}set_id'])!,
      instanceId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}instance_id'])!,
    );
  }

  @override
  SelectionSetItems createAlias(String alias) {
    return SelectionSetItems(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  List<String> get customConstraints => const ['PRIMARY KEY(set_id, instance_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class SelectionSetItemRow extends DataClass implements Insertable<SelectionSetItemRow> {
  final int setId;
  final int instanceId;
  const SelectionSetItemRow({required this.setId, required this.instanceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['set_id'] = Variable<int>(setId);
    map['instance_id'] = Variable<int>(instanceId);
    return map;
  }

  SelectionSetItemsCompanion toCompanion(bool nullToAbsent) {
    return SelectionSetItemsCompanion(setId: Value(setId), instanceId: Value(instanceId));
  }

  factory SelectionSetItemRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SelectionSetItemRow(
      setId: serializer.fromJson<int>(json['set_id']),
      instanceId: serializer.fromJson<int>(json['instance_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'set_id': serializer.toJson<int>(setId),
      'instance_id': serializer.toJson<int>(instanceId),
    };
  }

  SelectionSetItemRow copyWith({int? setId, int? instanceId}) =>
      SelectionSetItemRow(setId: setId ?? this.setId, instanceId: instanceId ?? this.instanceId);
  SelectionSetItemRow copyWithCompanion(SelectionSetItemsCompanion data) {
    return SelectionSetItemRow(
      setId: data.setId.present ? data.setId.value : this.setId,
      instanceId: data.instanceId.present ? data.instanceId.value : this.instanceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SelectionSetItemRow(')
          ..write('setId: $setId, ')
          ..write('instanceId: $instanceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(setId, instanceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SelectionSetItemRow && other.setId == this.setId && other.instanceId == this.instanceId);
}

class SelectionSetItemsCompanion extends UpdateCompanion<SelectionSetItemRow> {
  final Value<int> setId;
  final Value<int> instanceId;
  const SelectionSetItemsCompanion({this.setId = const Value.absent(), this.instanceId = const Value.absent()});
  SelectionSetItemsCompanion.insert({required int setId, required int instanceId})
    : setId = Value(setId),
      instanceId = Value(instanceId);
  static Insertable<SelectionSetItemRow> custom({Expression<int>? setId, Expression<int>? instanceId}) {
    return RawValuesInsertable({if (setId != null) 'set_id': setId, if (instanceId != null) 'instance_id': instanceId});
  }

  SelectionSetItemsCompanion copyWith({Value<int>? setId, Value<int>? instanceId}) {
    return SelectionSetItemsCompanion(setId: setId ?? this.setId, instanceId: instanceId ?? this.instanceId);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<int>(instanceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SelectionSetItemsCompanion(')
          ..write('setId: $setId, ')
          ..write('instanceId: $instanceId')
          ..write(')'))
        .toString();
  }
}

class Tags extends Table with TableInfo<Tags, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE COLLATE NOCASE',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(Insertable<TagRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  Tags createAlias(String alias) {
    return Tags(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final int id;
  final String name;
  const TagRow({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(id: Value(id), name: Value(name));
  }

  factory TagRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(id: serializer.fromJson<int>(json['id']), name: serializer.fromJson<String>(json['name']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<int>(id), 'name': serializer.toJson<String>(name)};
  }

  TagRow copyWith({int? id, String? name}) => TagRow(id: id ?? this.id, name: name ?? this.name);
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(id: data.id.present ? data.id.value : this.id, name: data.name.present ? data.name.value : this.name);
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TagRow && other.id == this.id && other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<int> id;
  final Value<String> name;
  const TagsCompanion({this.id = const Value.absent(), this.name = const Value.absent()});
  TagsCompanion.insert({this.id = const Value.absent(), required String name}) : name = Value(name);
  static Insertable<TagRow> custom({Expression<int>? id, Expression<String>? name}) {
    return RawValuesInsertable({if (id != null) 'id': id, if (name != null) 'name': name});
  }

  TagsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return TagsCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class ContentTags extends Table with TableInfo<ContentTags, ContentTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ContentTags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta('contentId');
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES contents(id)',
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES tags(id)ON DELETE CASCADE',
  );
  @override
  List<GeneratedColumn> get $columns => [contentId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_tags';
  @override
  VerificationContext validateIntegrity(Insertable<ContentTagRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta, contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(_tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId, tagId};
  @override
  ContentTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentTagRow(
      contentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}content_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  ContentTags createAlias(String alias) {
    return ContentTags(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  List<String> get customConstraints => const ['PRIMARY KEY(content_id, tag_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class ContentTagRow extends DataClass implements Insertable<ContentTagRow> {
  final int contentId;
  final int tagId;
  const ContentTagRow({required this.contentId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<int>(contentId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  ContentTagsCompanion toCompanion(bool nullToAbsent) {
    return ContentTagsCompanion(contentId: Value(contentId), tagId: Value(tagId));
  }

  factory ContentTagRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentTagRow(
      contentId: serializer.fromJson<int>(json['content_id']),
      tagId: serializer.fromJson<int>(json['tag_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'content_id': serializer.toJson<int>(contentId), 'tag_id': serializer.toJson<int>(tagId)};
  }

  ContentTagRow copyWith({int? contentId, int? tagId}) =>
      ContentTagRow(contentId: contentId ?? this.contentId, tagId: tagId ?? this.tagId);
  ContentTagRow copyWithCompanion(ContentTagsCompanion data) {
    return ContentTagRow(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentTagRow(')
          ..write('contentId: $contentId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentTagRow && other.contentId == this.contentId && other.tagId == this.tagId);
}

class ContentTagsCompanion extends UpdateCompanion<ContentTagRow> {
  final Value<int> contentId;
  final Value<int> tagId;
  const ContentTagsCompanion({this.contentId = const Value.absent(), this.tagId = const Value.absent()});
  ContentTagsCompanion.insert({required int contentId, required int tagId})
    : contentId = Value(contentId),
      tagId = Value(tagId);
  static Insertable<ContentTagRow> custom({Expression<int>? contentId, Expression<int>? tagId}) {
    return RawValuesInsertable({if (contentId != null) 'content_id': contentId, if (tagId != null) 'tag_id': tagId});
  }

  ContentTagsCompanion copyWith({Value<int>? contentId, Value<int>? tagId}) {
    return ContentTagsCompanion(contentId: contentId ?? this.contentId, tagId: tagId ?? this.tagId);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentTagsCompanion(')
          ..write('contentId: $contentId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }
}

class IntegrityChecks extends Table with TableInfo<IntegrityChecks, IntegrityCheckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  IntegrityChecks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _instanceIdMeta = const VerificationMeta('instanceId');
  late final GeneratedColumn<int> instanceId = GeneratedColumn<int>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES file_instances(id)',
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta('operationId');
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES operations(id)',
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta('checkedAt');
  late final GeneratedColumn<int> checkedAt = GeneratedColumn<int>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (result IN (\'unchanged\', \'changed_legit\', \'possibly_corrupt\', \'unreadable\', \'missing\'))',
  );
  static const VerificationMeta _observedSha256Meta = const VerificationMeta('observedSha256');
  late final GeneratedColumn<Uint8List> observedSha256 = GeneratedColumn<Uint8List>(
    'observed_sha256',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _observedSizeMeta = const VerificationMeta('observedSize');
  late final GeneratedColumn<int> observedSize = GeneratedColumn<int>(
    'observed_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _observedMtimeMeta = const VerificationMeta('observedMtime');
  late final GeneratedColumn<int> observedMtime = GeneratedColumn<int>(
    'observed_mtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    instanceId,
    operationId,
    checkedAt,
    result,
    observedSha256,
    observedSize,
    observedMtime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'integrity_checks';
  @override
  VerificationContext validateIntegrity(Insertable<IntegrityCheckRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('instance_id')) {
      context.handle(_instanceIdMeta, instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta));
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(_operationIdMeta, operationId.isAcceptableOrUnknown(data['operation_id']!, _operationIdMeta));
    }
    if (data.containsKey('checked_at')) {
      context.handle(_checkedAtMeta, checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta));
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta, result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('observed_sha256')) {
      context.handle(
        _observedSha256Meta,
        observedSha256.isAcceptableOrUnknown(data['observed_sha256']!, _observedSha256Meta),
      );
    }
    if (data.containsKey('observed_size')) {
      context.handle(_observedSizeMeta, observedSize.isAcceptableOrUnknown(data['observed_size']!, _observedSizeMeta));
    }
    if (data.containsKey('observed_mtime')) {
      context.handle(
        _observedMtimeMeta,
        observedMtime.isAcceptableOrUnknown(data['observed_mtime']!, _observedMtimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IntegrityCheckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntegrityCheckRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      instanceId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}instance_id'])!,
      operationId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}operation_id']),
      checkedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}checked_at'])!,
      result: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}result'])!,
      observedSha256: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}observed_sha256']),
      observedSize: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}observed_size']),
      observedMtime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}observed_mtime']),
    );
  }

  @override
  IntegrityChecks createAlias(String alias) {
    return IntegrityChecks(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class IntegrityCheckRow extends DataClass implements Insertable<IntegrityCheckRow> {
  final int id;
  final int instanceId;
  final String? operationId;
  final int checkedAt;
  final String result;
  final Uint8List? observedSha256;
  final int? observedSize;
  final int? observedMtime;
  const IntegrityCheckRow({
    required this.id,
    required this.instanceId,
    this.operationId,
    required this.checkedAt,
    required this.result,
    this.observedSha256,
    this.observedSize,
    this.observedMtime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['instance_id'] = Variable<int>(instanceId);
    if (!nullToAbsent || operationId != null) {
      map['operation_id'] = Variable<String>(operationId);
    }
    map['checked_at'] = Variable<int>(checkedAt);
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || observedSha256 != null) {
      map['observed_sha256'] = Variable<Uint8List>(observedSha256);
    }
    if (!nullToAbsent || observedSize != null) {
      map['observed_size'] = Variable<int>(observedSize);
    }
    if (!nullToAbsent || observedMtime != null) {
      map['observed_mtime'] = Variable<int>(observedMtime);
    }
    return map;
  }

  IntegrityChecksCompanion toCompanion(bool nullToAbsent) {
    return IntegrityChecksCompanion(
      id: Value(id),
      instanceId: Value(instanceId),
      operationId: operationId == null && nullToAbsent ? const Value.absent() : Value(operationId),
      checkedAt: Value(checkedAt),
      result: Value(result),
      observedSha256: observedSha256 == null && nullToAbsent ? const Value.absent() : Value(observedSha256),
      observedSize: observedSize == null && nullToAbsent ? const Value.absent() : Value(observedSize),
      observedMtime: observedMtime == null && nullToAbsent ? const Value.absent() : Value(observedMtime),
    );
  }

  factory IntegrityCheckRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntegrityCheckRow(
      id: serializer.fromJson<int>(json['id']),
      instanceId: serializer.fromJson<int>(json['instance_id']),
      operationId: serializer.fromJson<String?>(json['operation_id']),
      checkedAt: serializer.fromJson<int>(json['checked_at']),
      result: serializer.fromJson<String>(json['result']),
      observedSha256: serializer.fromJson<Uint8List?>(json['observed_sha256']),
      observedSize: serializer.fromJson<int?>(json['observed_size']),
      observedMtime: serializer.fromJson<int?>(json['observed_mtime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'instance_id': serializer.toJson<int>(instanceId),
      'operation_id': serializer.toJson<String?>(operationId),
      'checked_at': serializer.toJson<int>(checkedAt),
      'result': serializer.toJson<String>(result),
      'observed_sha256': serializer.toJson<Uint8List?>(observedSha256),
      'observed_size': serializer.toJson<int?>(observedSize),
      'observed_mtime': serializer.toJson<int?>(observedMtime),
    };
  }

  IntegrityCheckRow copyWith({
    int? id,
    int? instanceId,
    Value<String?> operationId = const Value.absent(),
    int? checkedAt,
    String? result,
    Value<Uint8List?> observedSha256 = const Value.absent(),
    Value<int?> observedSize = const Value.absent(),
    Value<int?> observedMtime = const Value.absent(),
  }) => IntegrityCheckRow(
    id: id ?? this.id,
    instanceId: instanceId ?? this.instanceId,
    operationId: operationId.present ? operationId.value : this.operationId,
    checkedAt: checkedAt ?? this.checkedAt,
    result: result ?? this.result,
    observedSha256: observedSha256.present ? observedSha256.value : this.observedSha256,
    observedSize: observedSize.present ? observedSize.value : this.observedSize,
    observedMtime: observedMtime.present ? observedMtime.value : this.observedMtime,
  );
  IntegrityCheckRow copyWithCompanion(IntegrityChecksCompanion data) {
    return IntegrityCheckRow(
      id: data.id.present ? data.id.value : this.id,
      instanceId: data.instanceId.present ? data.instanceId.value : this.instanceId,
      operationId: data.operationId.present ? data.operationId.value : this.operationId,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      result: data.result.present ? data.result.value : this.result,
      observedSha256: data.observedSha256.present ? data.observedSha256.value : this.observedSha256,
      observedSize: data.observedSize.present ? data.observedSize.value : this.observedSize,
      observedMtime: data.observedMtime.present ? data.observedMtime.value : this.observedMtime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntegrityCheckRow(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('operationId: $operationId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('result: $result, ')
          ..write('observedSha256: $observedSha256, ')
          ..write('observedSize: $observedSize, ')
          ..write('observedMtime: $observedMtime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    instanceId,
    operationId,
    checkedAt,
    result,
    $driftBlobEquality.hash(observedSha256),
    observedSize,
    observedMtime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrityCheckRow &&
          other.id == this.id &&
          other.instanceId == this.instanceId &&
          other.operationId == this.operationId &&
          other.checkedAt == this.checkedAt &&
          other.result == this.result &&
          $driftBlobEquality.equals(other.observedSha256, this.observedSha256) &&
          other.observedSize == this.observedSize &&
          other.observedMtime == this.observedMtime);
}

class IntegrityChecksCompanion extends UpdateCompanion<IntegrityCheckRow> {
  final Value<int> id;
  final Value<int> instanceId;
  final Value<String?> operationId;
  final Value<int> checkedAt;
  final Value<String> result;
  final Value<Uint8List?> observedSha256;
  final Value<int?> observedSize;
  final Value<int?> observedMtime;
  const IntegrityChecksCompanion({
    this.id = const Value.absent(),
    this.instanceId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.observedSha256 = const Value.absent(),
    this.observedSize = const Value.absent(),
    this.observedMtime = const Value.absent(),
  });
  IntegrityChecksCompanion.insert({
    this.id = const Value.absent(),
    required int instanceId,
    this.operationId = const Value.absent(),
    required int checkedAt,
    required String result,
    this.observedSha256 = const Value.absent(),
    this.observedSize = const Value.absent(),
    this.observedMtime = const Value.absent(),
  }) : instanceId = Value(instanceId),
       checkedAt = Value(checkedAt),
       result = Value(result);
  static Insertable<IntegrityCheckRow> custom({
    Expression<int>? id,
    Expression<int>? instanceId,
    Expression<String>? operationId,
    Expression<int>? checkedAt,
    Expression<String>? result,
    Expression<Uint8List>? observedSha256,
    Expression<int>? observedSize,
    Expression<int>? observedMtime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (instanceId != null) 'instance_id': instanceId,
      if (operationId != null) 'operation_id': operationId,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (result != null) 'result': result,
      if (observedSha256 != null) 'observed_sha256': observedSha256,
      if (observedSize != null) 'observed_size': observedSize,
      if (observedMtime != null) 'observed_mtime': observedMtime,
    });
  }

  IntegrityChecksCompanion copyWith({
    Value<int>? id,
    Value<int>? instanceId,
    Value<String?>? operationId,
    Value<int>? checkedAt,
    Value<String>? result,
    Value<Uint8List?>? observedSha256,
    Value<int?>? observedSize,
    Value<int?>? observedMtime,
  }) {
    return IntegrityChecksCompanion(
      id: id ?? this.id,
      instanceId: instanceId ?? this.instanceId,
      operationId: operationId ?? this.operationId,
      checkedAt: checkedAt ?? this.checkedAt,
      result: result ?? this.result,
      observedSha256: observedSha256 ?? this.observedSha256,
      observedSize: observedSize ?? this.observedSize,
      observedMtime: observedMtime ?? this.observedMtime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<int>(instanceId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<int>(checkedAt.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (observedSha256.present) {
      map['observed_sha256'] = Variable<Uint8List>(observedSha256.value);
    }
    if (observedSize.present) {
      map['observed_size'] = Variable<int>(observedSize.value);
    }
    if (observedMtime.present) {
      map['observed_mtime'] = Variable<int>(observedMtime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntegrityChecksCompanion(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('operationId: $operationId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('result: $result, ')
          ..write('observedSha256: $observedSha256, ')
          ..write('observedSize: $observedSize, ')
          ..write('observedMtime: $observedMtime')
          ..write(')'))
        .toString();
  }
}

class SavedScopes extends Table with TableInfo<SavedScopes, SavedScopeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SavedScopes(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE COLLATE NOCASE',
  );
  static const VerificationMeta _definitionJsonMeta = const VerificationMeta('definitionJson');
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
    'definition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, definitionJson, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_scopes';
  @override
  VerificationContext validateIntegrity(Insertable<SavedScopeRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('definition_json')) {
      context.handle(
        _definitionJsonMeta,
        definitionJson.isAcceptableOrUnknown(data['definition_json']!, _definitionJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedScopeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedScopeRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      definitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  SavedScopes createAlias(String alias) {
    return SavedScopes(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SavedScopeRow extends DataClass implements Insertable<SavedScopeRow> {
  final int id;
  final String name;
  final String definitionJson;
  final int createdAt;
  final int updatedAt;
  const SavedScopeRow({
    required this.id,
    required this.name,
    required this.definitionJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['definition_json'] = Variable<String>(definitionJson);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SavedScopesCompanion toCompanion(bool nullToAbsent) {
    return SavedScopesCompanion(
      id: Value(id),
      name: Value(name),
      definitionJson: Value(definitionJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedScopeRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedScopeRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      definitionJson: serializer.fromJson<String>(json['definition_json']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'definition_json': serializer.toJson<String>(definitionJson),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  SavedScopeRow copyWith({int? id, String? name, String? definitionJson, int? createdAt, int? updatedAt}) =>
      SavedScopeRow(
        id: id ?? this.id,
        name: name ?? this.name,
        definitionJson: definitionJson ?? this.definitionJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SavedScopeRow copyWithCompanion(SavedScopesCompanion data) {
    return SavedScopeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      definitionJson: data.definitionJson.present ? data.definitionJson.value : this.definitionJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedScopeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, definitionJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedScopeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.definitionJson == this.definitionJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SavedScopesCompanion extends UpdateCompanion<SavedScopeRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> definitionJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const SavedScopesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SavedScopesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String definitionJson,
    required int createdAt,
    required int updatedAt,
  }) : name = Value(name),
       definitionJson = Value(definitionJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedScopeRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? definitionJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SavedScopesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? definitionJson,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return SavedScopesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      definitionJson: definitionJson ?? this.definitionJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedScopesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class MomentEdits extends Table with TableInfo<MomentEdits, MomentEditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MomentEdits(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _momentIdMeta = const VerificationMeta('momentId');
  late final GeneratedColumn<int> momentId = GeneratedColumn<int>(
    'moment_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (op IN (\'rename\', \'merge\', \'split\', \'reset\'))',
  );
  static const VerificationMeta _detailJsonMeta = const VerificationMeta('detailJson');
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, momentId, op, detailJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'moment_edits';
  @override
  VerificationContext validateIntegrity(Insertable<MomentEditRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('moment_id')) {
      context.handle(_momentIdMeta, momentId.isAcceptableOrUnknown(data['moment_id']!, _momentIdMeta));
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('detail_json')) {
      context.handle(_detailJsonMeta, detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MomentEditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MomentEditRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      momentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}moment_id']),
      op: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}op'])!,
      detailJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}detail_json']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  MomentEdits createAlias(String alias) {
    return MomentEdits(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MomentEditRow extends DataClass implements Insertable<MomentEditRow> {
  final int id;
  final int? momentId;
  final String op;
  final String? detailJson;
  final int createdAt;
  const MomentEditRow({required this.id, this.momentId, required this.op, this.detailJson, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || momentId != null) {
      map['moment_id'] = Variable<int>(momentId);
    }
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || detailJson != null) {
      map['detail_json'] = Variable<String>(detailJson);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MomentEditsCompanion toCompanion(bool nullToAbsent) {
    return MomentEditsCompanion(
      id: Value(id),
      momentId: momentId == null && nullToAbsent ? const Value.absent() : Value(momentId),
      op: Value(op),
      detailJson: detailJson == null && nullToAbsent ? const Value.absent() : Value(detailJson),
      createdAt: Value(createdAt),
    );
  }

  factory MomentEditRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MomentEditRow(
      id: serializer.fromJson<int>(json['id']),
      momentId: serializer.fromJson<int?>(json['moment_id']),
      op: serializer.fromJson<String>(json['op']),
      detailJson: serializer.fromJson<String?>(json['detail_json']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'moment_id': serializer.toJson<int?>(momentId),
      'op': serializer.toJson<String>(op),
      'detail_json': serializer.toJson<String?>(detailJson),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  MomentEditRow copyWith({
    int? id,
    Value<int?> momentId = const Value.absent(),
    String? op,
    Value<String?> detailJson = const Value.absent(),
    int? createdAt,
  }) => MomentEditRow(
    id: id ?? this.id,
    momentId: momentId.present ? momentId.value : this.momentId,
    op: op ?? this.op,
    detailJson: detailJson.present ? detailJson.value : this.detailJson,
    createdAt: createdAt ?? this.createdAt,
  );
  MomentEditRow copyWithCompanion(MomentEditsCompanion data) {
    return MomentEditRow(
      id: data.id.present ? data.id.value : this.id,
      momentId: data.momentId.present ? data.momentId.value : this.momentId,
      op: data.op.present ? data.op.value : this.op,
      detailJson: data.detailJson.present ? data.detailJson.value : this.detailJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MomentEditRow(')
          ..write('id: $id, ')
          ..write('momentId: $momentId, ')
          ..write('op: $op, ')
          ..write('detailJson: $detailJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, momentId, op, detailJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MomentEditRow &&
          other.id == this.id &&
          other.momentId == this.momentId &&
          other.op == this.op &&
          other.detailJson == this.detailJson &&
          other.createdAt == this.createdAt);
}

class MomentEditsCompanion extends UpdateCompanion<MomentEditRow> {
  final Value<int> id;
  final Value<int?> momentId;
  final Value<String> op;
  final Value<String?> detailJson;
  final Value<int> createdAt;
  const MomentEditsCompanion({
    this.id = const Value.absent(),
    this.momentId = const Value.absent(),
    this.op = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MomentEditsCompanion.insert({
    this.id = const Value.absent(),
    this.momentId = const Value.absent(),
    required String op,
    this.detailJson = const Value.absent(),
    required int createdAt,
  }) : op = Value(op),
       createdAt = Value(createdAt);
  static Insertable<MomentEditRow> custom({
    Expression<int>? id,
    Expression<int>? momentId,
    Expression<String>? op,
    Expression<String>? detailJson,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (momentId != null) 'moment_id': momentId,
      if (op != null) 'op': op,
      if (detailJson != null) 'detail_json': detailJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MomentEditsCompanion copyWith({
    Value<int>? id,
    Value<int?>? momentId,
    Value<String>? op,
    Value<String?>? detailJson,
    Value<int>? createdAt,
  }) {
    return MomentEditsCompanion(
      id: id ?? this.id,
      momentId: momentId ?? this.momentId,
      op: op ?? this.op,
      detailJson: detailJson ?? this.detailJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (momentId.present) {
      map['moment_id'] = Variable<int>(momentId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MomentEditsCompanion(')
          ..write('id: $id, ')
          ..write('momentId: $momentId, ')
          ..write('op: $op, ')
          ..write('detailJson: $detailJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDatabase extends GeneratedDatabase {
  _$CatalogDatabase(QueryExecutor e) : super(e);
  $CatalogDatabaseManager get managers => $CatalogDatabaseManager(this);
  late final AppMeta appMeta = AppMeta(this);
  late final Settings settings = Settings(this);
  late final PhysicalDisks physicalDisks = PhysicalDisks(this);
  late final Sources sources = Sources(this);
  late final Index ixSourcesVolumeGuid = Index(
    'ix_sources_volume_guid',
    'CREATE INDEX ix_sources_volume_guid ON sources (volume_guid)',
  );
  late final Index ixSourcesVolumeSerial = Index(
    'ix_sources_volume_serial',
    'CREATE INDEX ix_sources_volume_serial ON sources (volume_serial)',
  );
  late final Index ixSourcesDeviceId = Index(
    'ix_sources_device_id',
    'CREATE INDEX ix_sources_device_id ON sources (device_id)',
  );
  late final Scans scans = Scans(this);
  late final Index ixScansSource = Index(
    'ix_scans_source',
    'CREATE INDEX ix_scans_source ON scans (source_id, started_at DESC)',
  );
  late final ScanDirs scanDirs = ScanDirs(this);
  late final Index ixScanDirsPending = Index(
    'ix_scan_dirs_pending',
    'CREATE INDEX ix_scan_dirs_pending ON scan_dirs (scan_id) WHERE status = \'pending\'',
  );
  late final ScanErrors scanErrors = ScanErrors(this);
  late final Contents contents = Contents(this);
  late final FileInstances fileInstances = FileInstances(this);
  late final Index ixFiContent = Index('ix_fi_content', 'CREATE INDEX ix_fi_content ON file_instances (content_id)');
  late final Index ixFiSourceDir = Index(
    'ix_fi_source_dir',
    'CREATE INDEX ix_fi_source_dir ON file_instances (source_id, dir_rel_path)',
  );
  late final Index ixFiSize = Index('ix_fi_size', 'CREATE INDEX ix_fi_size ON file_instances (size_bytes)');
  late final Index ixFiHashPending = Index(
    'ix_fi_hash_pending',
    'CREATE INDEX ix_fi_hash_pending ON file_instances (source_id) WHERE hash_status = \'pending\'',
  );
  late final Index ixFiLastSeen = Index(
    'ix_fi_last_seen',
    'CREATE INDEX ix_fi_last_seen ON file_instances (source_id, last_seen_scan_id)',
  );
  late final Index ixFiExt = Index('ix_fi_ext', 'CREATE INDEX ix_fi_ext ON file_instances (ext)');
  late final ClockCorrections clockCorrections = ClockCorrections(this);
  late final Moments moments = Moments(this);
  late final MediaMetadata mediaMetadata = MediaMetadata(this);
  late final Index ixMmCapture = Index(
    'ix_mm_capture',
    'CREATE INDEX ix_mm_capture ON media_metadata (capture_utc_ms)',
  );
  late final Index ixMmCamera = Index('ix_mm_camera', 'CREATE INDEX ix_mm_camera ON media_metadata (make, model)');
  late final Index ixMmEff = Index('ix_mm_eff', 'CREATE INDEX ix_mm_eff ON media_metadata (eff_utc_ms)');
  late final Index ixMmYm = Index('ix_mm_ym', 'CREATE INDEX ix_mm_ym ON media_metadata (eff_year, eff_month)');
  late final Index ixMmMoment = Index('ix_mm_moment', 'CREATE INDEX ix_mm_moment ON media_metadata (moment_id)');
  late final DateCorrections dateCorrections = DateCorrections(this);
  late final Index ixDcContent = Index(
    'ix_dc_content',
    'CREATE INDEX ix_dc_content ON date_corrections (content_id) WHERE superseded_at IS NULL',
  );
  late final Operations operations = Operations(this);
  late final OperationItems operationItems = OperationItems(this);
  late final Index ixOiOpen = Index(
    'ix_oi_open',
    'CREATE INDEX ix_oi_open ON operation_items (operation_id, state) WHERE state NOT IN (\'published\', \'skipped_identical\', \'undone\')',
  );
  late final OperationEvents operationEvents = OperationEvents(this);
  late final Index ixOeOp = Index('ix_oe_op', 'CREATE INDEX ix_oe_op ON operation_events (operation_id, at)');
  late final SavedFilters savedFilters = SavedFilters(this);
  late final SelectionSets selectionSets = SelectionSets(this);
  late final SelectionSetItems selectionSetItems = SelectionSetItems(this);
  late final Tags tags = Tags(this);
  late final ContentTags contentTags = ContentTags(this);
  late final IntegrityChecks integrityChecks = IntegrityChecks(this);
  late final Index ixIcInstance = Index(
    'ix_ic_instance',
    'CREATE INDEX ix_ic_instance ON integrity_checks (instance_id, checked_at DESC)',
  );
  late final SavedScopes savedScopes = SavedScopes(this);
  late final Index ixMomentsStart = Index(
    'ix_moments_start',
    'CREATE INDEX ix_moments_start ON moments (start_utc_ms)',
  );
  late final MomentEdits momentEdits = MomentEdits(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appMeta,
    settings,
    physicalDisks,
    sources,
    ixSourcesVolumeGuid,
    ixSourcesVolumeSerial,
    ixSourcesDeviceId,
    scans,
    ixScansSource,
    scanDirs,
    ixScanDirsPending,
    scanErrors,
    contents,
    fileInstances,
    ixFiContent,
    ixFiSourceDir,
    ixFiSize,
    ixFiHashPending,
    ixFiLastSeen,
    ixFiExt,
    clockCorrections,
    moments,
    mediaMetadata,
    ixMmCapture,
    ixMmCamera,
    ixMmEff,
    ixMmYm,
    ixMmMoment,
    dateCorrections,
    ixDcContent,
    operations,
    operationItems,
    ixOiOpen,
    operationEvents,
    ixOeOp,
    savedFilters,
    selectionSets,
    selectionSetItems,
    tags,
    contentTags,
    integrityChecks,
    ixIcInstance,
    savedScopes,
    ixMomentsStart,
    momentEdits,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('scans', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('scan_dirs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('scans', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('scan_errors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('moments', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('media_metadata', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('selection_sets', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('selection_set_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('tags', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('content_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $AppMetaCreateCompanionBuilder = AppMetaCompanion Function({required String key, required String value});
typedef $AppMetaUpdateCompanionBuilder = AppMetaCompanion Function({Value<String> key, Value<String> value});

class $AppMetaFilterComposer extends Composer<_$CatalogDatabase, AppMeta> {
  $AppMetaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $AppMetaOrderingComposer extends Composer<_$CatalogDatabase, AppMeta> {
  $AppMetaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $AppMetaAnnotationComposer extends Composer<_$CatalogDatabase, AppMeta> {
  $AppMetaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $AppMetaTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          AppMeta,
          AppMetaRow,
          $AppMetaFilterComposer,
          $AppMetaOrderingComposer,
          $AppMetaAnnotationComposer,
          $AppMetaCreateCompanionBuilder,
          $AppMetaUpdateCompanionBuilder,
          (AppMetaRow, BaseReferences<_$CatalogDatabase, AppMeta, AppMetaRow>),
          AppMetaRow,
          PrefetchHooks Function()
        > {
  $AppMetaTableManager(_$CatalogDatabase db, AppMeta table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $AppMetaFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $AppMetaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $AppMetaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
          }) => AppMetaCompanion(key: key, value: value),
          createCompanionCallback: ({required String key, required String value}) =>
              AppMetaCompanion.insert(key: key, value: value),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<AppMeta, AppMetaRow>(table),
                  BaseReferences<_$CatalogDatabase, AppMeta, AppMetaRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AppMetaProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      AppMeta,
      AppMetaRow,
      $AppMetaFilterComposer,
      $AppMetaOrderingComposer,
      $AppMetaAnnotationComposer,
      $AppMetaCreateCompanionBuilder,
      $AppMetaUpdateCompanionBuilder,
      (AppMetaRow, BaseReferences<_$CatalogDatabase, AppMeta, AppMetaRow>),
      AppMetaRow,
      PrefetchHooks Function()
    >;
typedef $SettingsCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String valueJson,
  required int updatedAt,
});
typedef $SettingsUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> valueJson,
  Value<int> updatedAt,
});

class $SettingsFilterComposer extends Composer<_$CatalogDatabase, Settings> {
  $SettingsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $SettingsOrderingComposer extends Composer<_$CatalogDatabase, Settings> {
  $SettingsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $SettingsAnnotationComposer extends Composer<_$CatalogDatabase, Settings> {
  $SettingsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson => $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $SettingsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Settings,
          SettingRow,
          $SettingsFilterComposer,
          $SettingsOrderingComposer,
          $SettingsAnnotationComposer,
          $SettingsCreateCompanionBuilder,
          $SettingsUpdateCompanionBuilder,
          (SettingRow, BaseReferences<_$CatalogDatabase, Settings, SettingRow>),
          SettingRow,
          PrefetchHooks Function()
        > {
  $SettingsTableManager(_$CatalogDatabase db, Settings table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SettingsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SettingsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SettingsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> valueJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
          }) => SettingsCompanion(key: key, valueJson: valueJson, updatedAt: updatedAt),
          createCompanionCallback: ({required String key, required String valueJson, required int updatedAt}) =>
              SettingsCompanion.insert(key: key, valueJson: valueJson, updatedAt: updatedAt),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Settings, SettingRow>(table),
                  BaseReferences<_$CatalogDatabase, Settings, SettingRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SettingsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Settings,
      SettingRow,
      $SettingsFilterComposer,
      $SettingsOrderingComposer,
      $SettingsAnnotationComposer,
      $SettingsCreateCompanionBuilder,
      $SettingsUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$CatalogDatabase, Settings, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $PhysicalDisksCreateCompanionBuilder = PhysicalDisksCompanion Function({
  Value<int> id,
  Value<String?> serial,
  Value<String?> model,
  Value<int?> sizeBytes,
  Value<String?> busType,
  required String identityConfidence,
  Value<bool> userConfirmed,
  required int firstSeenAt,
  required int lastSeenAt,
});
typedef $PhysicalDisksUpdateCompanionBuilder = PhysicalDisksCompanion Function({
  Value<int> id,
  Value<String?> serial,
  Value<String?> model,
  Value<int?> sizeBytes,
  Value<String?> busType,
  Value<String> identityConfidence,
  Value<bool> userConfirmed,
  Value<int> firstSeenAt,
  Value<int> lastSeenAt,
});

final class $PhysicalDisksReferences extends BaseReferences<_$CatalogDatabase, PhysicalDisks, PhysicalDiskRow> {
  $PhysicalDisksReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Sources, List<SourceRow>> _sourcesRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.sources, aliasName: 'physical_disks__id__sources__physical_disk_id');

  $SourcesProcessedTableManager get sourcesRefs {
    final manager = $SourcesTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.physicalDiskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourcesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $PhysicalDisksFilterComposer extends Composer<_$CatalogDatabase, PhysicalDisks> {
  $PhysicalDisksFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get busType =>
      $composableBuilder(column: $table.busType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get identityConfidence =>
      $composableBuilder(column: $table.identityConfidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get userConfirmed =>
      $composableBuilder(column: $table.userConfirmed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get firstSeenAt =>
      $composableBuilder(column: $table.firstSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSeenAt =>
      $composableBuilder(column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  Expression<bool> sourcesRefs(Expression<bool> Function($SourcesFilterComposer f) f) {
    final $SourcesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.physicalDiskId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $PhysicalDisksOrderingComposer extends Composer<_$CatalogDatabase, PhysicalDisks> {
  $PhysicalDisksOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get busType =>
      $composableBuilder(column: $table.busType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get identityConfidence =>
      $composableBuilder(column: $table.identityConfidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get userConfirmed =>
      $composableBuilder(column: $table.userConfirmed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get firstSeenAt =>
      $composableBuilder(column: $table.firstSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSeenAt =>
      $composableBuilder(column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $PhysicalDisksAnnotationComposer extends Composer<_$CatalogDatabase, PhysicalDisks> {
  $PhysicalDisksAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serial => $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<String> get model => $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes => $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get busType => $composableBuilder(column: $table.busType, builder: (column) => column);

  GeneratedColumn<String> get identityConfidence =>
      $composableBuilder(column: $table.identityConfidence, builder: (column) => column);

  GeneratedColumn<bool> get userConfirmed =>
      $composableBuilder(column: $table.userConfirmed, builder: (column) => column);

  GeneratedColumn<int> get firstSeenAt => $composableBuilder(column: $table.firstSeenAt, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(column: $table.lastSeenAt, builder: (column) => column);

  Expression<T> sourcesRefs<T extends Object>(Expression<T> Function($SourcesAnnotationComposer a) f) {
    final $SourcesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.physicalDiskId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $PhysicalDisksTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          PhysicalDisks,
          PhysicalDiskRow,
          $PhysicalDisksFilterComposer,
          $PhysicalDisksOrderingComposer,
          $PhysicalDisksAnnotationComposer,
          $PhysicalDisksCreateCompanionBuilder,
          $PhysicalDisksUpdateCompanionBuilder,
          (PhysicalDiskRow, $PhysicalDisksReferences),
          PhysicalDiskRow,
          PrefetchHooks Function({bool sourcesRefs})
        > {
  $PhysicalDisksTableManager(_$CatalogDatabase db, PhysicalDisks table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $PhysicalDisksFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $PhysicalDisksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $PhysicalDisksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serial = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> busType = const Value.absent(),
                Value<String> identityConfidence = const Value.absent(),
                Value<bool> userConfirmed = const Value.absent(),
                Value<int> firstSeenAt = const Value.absent(),
                Value<int> lastSeenAt = const Value.absent(),
              }) => PhysicalDisksCompanion(
                id: id,
                serial: serial,
                model: model,
                sizeBytes: sizeBytes,
                busType: busType,
                identityConfidence: identityConfidence,
                userConfirmed: userConfirmed,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serial = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> busType = const Value.absent(),
                required String identityConfidence,
                Value<bool> userConfirmed = const Value.absent(),
                required int firstSeenAt,
                required int lastSeenAt,
              }) => PhysicalDisksCompanion.insert(
                id: id,
                serial: serial,
                model: model,
                sizeBytes: sizeBytes,
                busType: busType,
                identityConfidence: identityConfidence,
                userConfirmed: userConfirmed,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<PhysicalDisks, PhysicalDiskRow>(table), $PhysicalDisksReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({sourcesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sourcesRefs) db.sources],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sourcesRefs)
                    await $_getPrefetchedDataByColumns<PhysicalDiskRow, PhysicalDisks, SourceRow, Sources>(
                      currentTable: table,
                      referencedTable: $PhysicalDisksReferences._sourcesRefsTable(db),
                      managerFromTypedResult: (p0) => $PhysicalDisksReferences(db, table, p0).sourcesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'physical_disk_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $PhysicalDisksProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      PhysicalDisks,
      PhysicalDiskRow,
      $PhysicalDisksFilterComposer,
      $PhysicalDisksOrderingComposer,
      $PhysicalDisksAnnotationComposer,
      $PhysicalDisksCreateCompanionBuilder,
      $PhysicalDisksUpdateCompanionBuilder,
      (PhysicalDiskRow, $PhysicalDisksReferences),
      PhysicalDiskRow,
      PrefetchHooks Function({bool sourcesRefs})
    >;
typedef $SourcesCreateCompanionBuilder = SourcesCompanion Function({
  required String id,
  required String name,
  required String kind,
  Value<String?> volumeGuid,
  Value<int?> volumeSerial,
  Value<String?> volumeLabel,
  Value<String?> filesystem,
  Value<int?> volumeSizeBytes,
  Value<int?> physicalDiskId,
  Value<String?> markerId,
  Value<String?> deviceId,
  Value<String?> deviceModel,
  Value<String> rootRelPath,
  Value<String?> lastMountPath,
  Value<bool> connected,
  Value<int?> lastConnectedAt,
  Value<int?> totalBytesLast,
  Value<int?> freeBytesLast,
  required int createdAt,
  required int updatedAt,
  Value<int?> forgottenAt,
  Value<String?> deviceSerial,
  Value<String?> devicePlatform,
  Value<int> rowid,
});
typedef $SourcesUpdateCompanionBuilder = SourcesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> kind,
  Value<String?> volumeGuid,
  Value<int?> volumeSerial,
  Value<String?> volumeLabel,
  Value<String?> filesystem,
  Value<int?> volumeSizeBytes,
  Value<int?> physicalDiskId,
  Value<String?> markerId,
  Value<String?> deviceId,
  Value<String?> deviceModel,
  Value<String> rootRelPath,
  Value<String?> lastMountPath,
  Value<bool> connected,
  Value<int?> lastConnectedAt,
  Value<int?> totalBytesLast,
  Value<int?> freeBytesLast,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> forgottenAt,
  Value<String?> deviceSerial,
  Value<String?> devicePlatform,
  Value<int> rowid,
});

final class $SourcesReferences extends BaseReferences<_$CatalogDatabase, Sources, SourceRow> {
  $SourcesReferences(super.$_db, super.$_table, super.$_typedResult);

  static PhysicalDisks _physicalDiskIdTable(_$CatalogDatabase db) =>
      db.physicalDisks.createAlias('sources__physical_disk_id__physical_disks__id');

  $PhysicalDisksProcessedTableManager? get physicalDiskId {
    final $_column = $_itemColumn<int>('physical_disk_id');
    if ($_column == null) return null;
    final manager = $PhysicalDisksTableManager($_db, $_db.physicalDisks).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_physicalDiskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<Scans, List<ScanRow>> _scansRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.scans, aliasName: 'sources__id__scans__source_id');

  $ScansProcessedTableManager get scansRefs {
    final manager = $ScansTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scansRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<FileInstances, List<FileInstanceRow>> _fileInstancesRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.fileInstances, aliasName: 'sources__id__file_instances__source_id');

  $FileInstancesProcessedTableManager get fileInstancesRefs {
    final manager = $FileInstancesTableManager(
      $_db,
      $_db.fileInstances,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fileInstancesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<Operations, List<OperationRow>> _operationsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.operations, aliasName: 'sources__id__operations__dest_source_id');

  $OperationsProcessedTableManager get operationsRefs {
    final manager = $OperationsTableManager(
      $_db,
      $_db.operations,
    ).filter((f) => f.destSourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $SourcesFilterComposer extends Composer<_$CatalogDatabase, Sources> {
  $SourcesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get volumeGuid =>
      $composableBuilder(column: $table.volumeGuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get volumeSerial =>
      $composableBuilder(column: $table.volumeSerial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get volumeLabel =>
      $composableBuilder(column: $table.volumeLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filesystem =>
      $composableBuilder(column: $table.filesystem, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get volumeSizeBytes =>
      $composableBuilder(column: $table.volumeSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get markerId =>
      $composableBuilder(column: $table.markerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceModel =>
      $composableBuilder(column: $table.deviceModel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rootRelPath =>
      $composableBuilder(column: $table.rootRelPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMountPath =>
      $composableBuilder(column: $table.lastMountPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get connected =>
      $composableBuilder(column: $table.connected, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastConnectedAt =>
      $composableBuilder(column: $table.lastConnectedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalBytesLast =>
      $composableBuilder(column: $table.totalBytesLast, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get freeBytesLast =>
      $composableBuilder(column: $table.freeBytesLast, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get forgottenAt =>
      $composableBuilder(column: $table.forgottenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceSerial =>
      $composableBuilder(column: $table.deviceSerial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get devicePlatform =>
      $composableBuilder(column: $table.devicePlatform, builder: (column) => ColumnFilters(column));

  $PhysicalDisksFilterComposer get physicalDiskId {
    final $PhysicalDisksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.physicalDiskId,
      referencedTable: $db.physicalDisks,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $PhysicalDisksFilterComposer(
            $db: $db,
            $table: $db.physicalDisks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scansRefs(Expression<bool> Function($ScansFilterComposer f) f) {
    final $ScansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.sourceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fileInstancesRefs(Expression<bool> Function($FileInstancesFilterComposer f) f) {
    final $FileInstancesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.sourceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesFilterComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> operationsRefs(Expression<bool> Function($OperationsFilterComposer f) f) {
    final $OperationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.destSourceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SourcesOrderingComposer extends Composer<_$CatalogDatabase, Sources> {
  $SourcesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get volumeGuid =>
      $composableBuilder(column: $table.volumeGuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get volumeSerial =>
      $composableBuilder(column: $table.volumeSerial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get volumeLabel =>
      $composableBuilder(column: $table.volumeLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filesystem =>
      $composableBuilder(column: $table.filesystem, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get volumeSizeBytes =>
      $composableBuilder(column: $table.volumeSizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get markerId =>
      $composableBuilder(column: $table.markerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceModel =>
      $composableBuilder(column: $table.deviceModel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rootRelPath =>
      $composableBuilder(column: $table.rootRelPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMountPath =>
      $composableBuilder(column: $table.lastMountPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get connected =>
      $composableBuilder(column: $table.connected, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastConnectedAt =>
      $composableBuilder(column: $table.lastConnectedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalBytesLast =>
      $composableBuilder(column: $table.totalBytesLast, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get freeBytesLast =>
      $composableBuilder(column: $table.freeBytesLast, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get forgottenAt =>
      $composableBuilder(column: $table.forgottenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceSerial =>
      $composableBuilder(column: $table.deviceSerial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get devicePlatform =>
      $composableBuilder(column: $table.devicePlatform, builder: (column) => ColumnOrderings(column));

  $PhysicalDisksOrderingComposer get physicalDiskId {
    final $PhysicalDisksOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.physicalDiskId,
      referencedTable: $db.physicalDisks,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $PhysicalDisksOrderingComposer(
            $db: $db,
            $table: $db.physicalDisks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SourcesAnnotationComposer extends Composer<_$CatalogDatabase, Sources> {
  $SourcesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get volumeGuid => $composableBuilder(column: $table.volumeGuid, builder: (column) => column);

  GeneratedColumn<int> get volumeSerial => $composableBuilder(column: $table.volumeSerial, builder: (column) => column);

  GeneratedColumn<String> get volumeLabel =>
      $composableBuilder(column: $table.volumeLabel, builder: (column) => column);

  GeneratedColumn<String> get filesystem => $composableBuilder(column: $table.filesystem, builder: (column) => column);

  GeneratedColumn<int> get volumeSizeBytes =>
      $composableBuilder(column: $table.volumeSizeBytes, builder: (column) => column);

  GeneratedColumn<String> get markerId => $composableBuilder(column: $table.markerId, builder: (column) => column);

  GeneratedColumn<String> get deviceId => $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get deviceModel =>
      $composableBuilder(column: $table.deviceModel, builder: (column) => column);

  GeneratedColumn<String> get rootRelPath =>
      $composableBuilder(column: $table.rootRelPath, builder: (column) => column);

  GeneratedColumn<String> get lastMountPath =>
      $composableBuilder(column: $table.lastMountPath, builder: (column) => column);

  GeneratedColumn<bool> get connected => $composableBuilder(column: $table.connected, builder: (column) => column);

  GeneratedColumn<int> get lastConnectedAt =>
      $composableBuilder(column: $table.lastConnectedAt, builder: (column) => column);

  GeneratedColumn<int> get totalBytesLast =>
      $composableBuilder(column: $table.totalBytesLast, builder: (column) => column);

  GeneratedColumn<int> get freeBytesLast =>
      $composableBuilder(column: $table.freeBytesLast, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get forgottenAt => $composableBuilder(column: $table.forgottenAt, builder: (column) => column);

  GeneratedColumn<String> get deviceSerial =>
      $composableBuilder(column: $table.deviceSerial, builder: (column) => column);

  GeneratedColumn<String> get devicePlatform =>
      $composableBuilder(column: $table.devicePlatform, builder: (column) => column);

  $PhysicalDisksAnnotationComposer get physicalDiskId {
    final $PhysicalDisksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.physicalDiskId,
      referencedTable: $db.physicalDisks,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $PhysicalDisksAnnotationComposer(
            $db: $db,
            $table: $db.physicalDisks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> scansRefs<T extends Object>(Expression<T> Function($ScansAnnotationComposer a) f) {
    final $ScansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.sourceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fileInstancesRefs<T extends Object>(Expression<T> Function($FileInstancesAnnotationComposer a) f) {
    final $FileInstancesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.sourceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesAnnotationComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> operationsRefs<T extends Object>(Expression<T> Function($OperationsAnnotationComposer a) f) {
    final $OperationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.destSourceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SourcesTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Sources,
          SourceRow,
          $SourcesFilterComposer,
          $SourcesOrderingComposer,
          $SourcesAnnotationComposer,
          $SourcesCreateCompanionBuilder,
          $SourcesUpdateCompanionBuilder,
          (SourceRow, $SourcesReferences),
          SourceRow,
          PrefetchHooks Function({bool physicalDiskId, bool scansRefs, bool fileInstancesRefs, bool operationsRefs})
        > {
  $SourcesTableManager(_$CatalogDatabase db, Sources table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SourcesFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SourcesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SourcesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> volumeGuid = const Value.absent(),
                Value<int?> volumeSerial = const Value.absent(),
                Value<String?> volumeLabel = const Value.absent(),
                Value<String?> filesystem = const Value.absent(),
                Value<int?> volumeSizeBytes = const Value.absent(),
                Value<int?> physicalDiskId = const Value.absent(),
                Value<String?> markerId = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> deviceModel = const Value.absent(),
                Value<String> rootRelPath = const Value.absent(),
                Value<String?> lastMountPath = const Value.absent(),
                Value<bool> connected = const Value.absent(),
                Value<int?> lastConnectedAt = const Value.absent(),
                Value<int?> totalBytesLast = const Value.absent(),
                Value<int?> freeBytesLast = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> forgottenAt = const Value.absent(),
                Value<String?> deviceSerial = const Value.absent(),
                Value<String?> devicePlatform = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                name: name,
                kind: kind,
                volumeGuid: volumeGuid,
                volumeSerial: volumeSerial,
                volumeLabel: volumeLabel,
                filesystem: filesystem,
                volumeSizeBytes: volumeSizeBytes,
                physicalDiskId: physicalDiskId,
                markerId: markerId,
                deviceId: deviceId,
                deviceModel: deviceModel,
                rootRelPath: rootRelPath,
                lastMountPath: lastMountPath,
                connected: connected,
                lastConnectedAt: lastConnectedAt,
                totalBytesLast: totalBytesLast,
                freeBytesLast: freeBytesLast,
                createdAt: createdAt,
                updatedAt: updatedAt,
                forgottenAt: forgottenAt,
                deviceSerial: deviceSerial,
                devicePlatform: devicePlatform,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                Value<String?> volumeGuid = const Value.absent(),
                Value<int?> volumeSerial = const Value.absent(),
                Value<String?> volumeLabel = const Value.absent(),
                Value<String?> filesystem = const Value.absent(),
                Value<int?> volumeSizeBytes = const Value.absent(),
                Value<int?> physicalDiskId = const Value.absent(),
                Value<String?> markerId = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> deviceModel = const Value.absent(),
                Value<String> rootRelPath = const Value.absent(),
                Value<String?> lastMountPath = const Value.absent(),
                Value<bool> connected = const Value.absent(),
                Value<int?> lastConnectedAt = const Value.absent(),
                Value<int?> totalBytesLast = const Value.absent(),
                Value<int?> freeBytesLast = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> forgottenAt = const Value.absent(),
                Value<String?> deviceSerial = const Value.absent(),
                Value<String?> devicePlatform = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                volumeGuid: volumeGuid,
                volumeSerial: volumeSerial,
                volumeLabel: volumeLabel,
                filesystem: filesystem,
                volumeSizeBytes: volumeSizeBytes,
                physicalDiskId: physicalDiskId,
                markerId: markerId,
                deviceId: deviceId,
                deviceModel: deviceModel,
                rootRelPath: rootRelPath,
                lastMountPath: lastMountPath,
                connected: connected,
                lastConnectedAt: lastConnectedAt,
                totalBytesLast: totalBytesLast,
                freeBytesLast: freeBytesLast,
                createdAt: createdAt,
                updatedAt: updatedAt,
                forgottenAt: forgottenAt,
                deviceSerial: deviceSerial,
                devicePlatform: devicePlatform,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<Sources, SourceRow>(table), $SourcesReferences(db, table, e))).toList(),
          prefetchHooksCallback:
              ({physicalDiskId = false, scansRefs = false, fileInstancesRefs = false, operationsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (scansRefs) db.scans,
                    if (fileInstancesRefs) db.fileInstances,
                    if (operationsRefs) db.operations,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (physicalDiskId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.physicalDiskId,
                            referencedTable: $SourcesReferences._physicalDiskIdTable(db),
                            referencedColumn: $SourcesReferences._physicalDiskIdTable(db).id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (scansRefs)
                        await $_getPrefetchedDataByColumns<SourceRow, Sources, ScanRow, Scans>(
                          currentTable: table,
                          referencedTable: $SourcesReferences._scansRefsTable(db),
                          managerFromTypedResult: (p0) => $SourcesReferences(db, table, p0).scansRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_id',
                          typedResults: items,
                        ),
                      if (fileInstancesRefs)
                        await $_getPrefetchedDataByColumns<SourceRow, Sources, FileInstanceRow, FileInstances>(
                          currentTable: table,
                          referencedTable: $SourcesReferences._fileInstancesRefsTable(db),
                          managerFromTypedResult: (p0) => $SourcesReferences(db, table, p0).fileInstancesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_id',
                          typedResults: items,
                        ),
                      if (operationsRefs)
                        await $_getPrefetchedDataByColumns<SourceRow, Sources, OperationRow, Operations>(
                          currentTable: table,
                          referencedTable: $SourcesReferences._operationsRefsTable(db),
                          managerFromTypedResult: (p0) => $SourcesReferences(db, table, p0).operationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'dest_source_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $SourcesProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Sources,
      SourceRow,
      $SourcesFilterComposer,
      $SourcesOrderingComposer,
      $SourcesAnnotationComposer,
      $SourcesCreateCompanionBuilder,
      $SourcesUpdateCompanionBuilder,
      (SourceRow, $SourcesReferences),
      SourceRow,
      PrefetchHooks Function({bool physicalDiskId, bool scansRefs, bool fileInstancesRefs, bool operationsRefs})
    >;
typedef $ScansCreateCompanionBuilder = ScansCompanion Function({
  Value<int> id,
  required String sourceId,
  required String kind,
  required String status,
  Value<String?> coverage,
  Value<String?> mountPathUsed,
  required int startedAt,
  Value<int?> finishedAt,
  Value<int> dirsDone,
  Value<int> filesSeen,
  Value<int> bytesSeen,
  Value<int> errorCount,
});
typedef $ScansUpdateCompanionBuilder = ScansCompanion Function({
  Value<int> id,
  Value<String> sourceId,
  Value<String> kind,
  Value<String> status,
  Value<String?> coverage,
  Value<String?> mountPathUsed,
  Value<int> startedAt,
  Value<int?> finishedAt,
  Value<int> dirsDone,
  Value<int> filesSeen,
  Value<int> bytesSeen,
  Value<int> errorCount,
});

final class $ScansReferences extends BaseReferences<_$CatalogDatabase, Scans, ScanRow> {
  $ScansReferences(super.$_db, super.$_table, super.$_typedResult);

  static Sources _sourceIdTable(_$CatalogDatabase db) => db.sources.createAlias('scans__source_id__sources__id');

  $SourcesProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $SourcesTableManager($_db, $_db.sources).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<ScanDirs, List<ScanDirRow>> _scanDirsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.scanDirs, aliasName: 'scans__id__scan_dirs__scan_id');

  $ScanDirsProcessedTableManager get scanDirsRefs {
    final manager = $ScanDirsTableManager(
      $_db,
      $_db.scanDirs,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scanDirsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<ScanErrors, List<ScanErrorRow>> _scanErrorsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.scanErrors, aliasName: 'scans__id__scan_errors__scan_id');

  $ScanErrorsProcessedTableManager get scanErrorsRefs {
    final manager = $ScanErrorsTableManager(
      $_db,
      $_db.scanErrors,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scanErrorsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $ScansFilterComposer extends Composer<_$CatalogDatabase, Scans> {
  $ScansFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverage =>
      $composableBuilder(column: $table.coverage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mountPathUsed =>
      $composableBuilder(column: $table.mountPathUsed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dirsDone =>
      $composableBuilder(column: $table.dirsDone, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get filesSeen =>
      $composableBuilder(column: $table.filesSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bytesSeen =>
      $composableBuilder(column: $table.bytesSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get errorCount =>
      $composableBuilder(column: $table.errorCount, builder: (column) => ColumnFilters(column));

  $SourcesFilterComposer get sourceId {
    final $SourcesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scanDirsRefs(Expression<bool> Function($ScanDirsFilterComposer f) f) {
    final $ScanDirsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanDirs,
      getReferencedColumn: (t) => t.scanId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScanDirsFilterComposer(
            $db: $db,
            $table: $db.scanDirs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scanErrorsRefs(Expression<bool> Function($ScanErrorsFilterComposer f) f) {
    final $ScanErrorsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanErrors,
      getReferencedColumn: (t) => t.scanId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScanErrorsFilterComposer(
            $db: $db,
            $table: $db.scanErrors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ScansOrderingComposer extends Composer<_$CatalogDatabase, Scans> {
  $ScansOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverage =>
      $composableBuilder(column: $table.coverage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mountPathUsed =>
      $composableBuilder(column: $table.mountPathUsed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dirsDone =>
      $composableBuilder(column: $table.dirsDone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get filesSeen =>
      $composableBuilder(column: $table.filesSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bytesSeen =>
      $composableBuilder(column: $table.bytesSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get errorCount =>
      $composableBuilder(column: $table.errorCount, builder: (column) => ColumnOrderings(column));

  $SourcesOrderingComposer get sourceId {
    final $SourcesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScansAnnotationComposer extends Composer<_$CatalogDatabase, Scans> {
  $ScansAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status => $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get coverage => $composableBuilder(column: $table.coverage, builder: (column) => column);

  GeneratedColumn<String> get mountPathUsed =>
      $composableBuilder(column: $table.mountPathUsed, builder: (column) => column);

  GeneratedColumn<int> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(column: $table.finishedAt, builder: (column) => column);

  GeneratedColumn<int> get dirsDone => $composableBuilder(column: $table.dirsDone, builder: (column) => column);

  GeneratedColumn<int> get filesSeen => $composableBuilder(column: $table.filesSeen, builder: (column) => column);

  GeneratedColumn<int> get bytesSeen => $composableBuilder(column: $table.bytesSeen, builder: (column) => column);

  GeneratedColumn<int> get errorCount => $composableBuilder(column: $table.errorCount, builder: (column) => column);

  $SourcesAnnotationComposer get sourceId {
    final $SourcesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> scanDirsRefs<T extends Object>(Expression<T> Function($ScanDirsAnnotationComposer a) f) {
    final $ScanDirsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanDirs,
      getReferencedColumn: (t) => t.scanId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScanDirsAnnotationComposer(
            $db: $db,
            $table: $db.scanDirs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scanErrorsRefs<T extends Object>(Expression<T> Function($ScanErrorsAnnotationComposer a) f) {
    final $ScanErrorsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanErrors,
      getReferencedColumn: (t) => t.scanId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScanErrorsAnnotationComposer(
            $db: $db,
            $table: $db.scanErrors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ScansTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Scans,
          ScanRow,
          $ScansFilterComposer,
          $ScansOrderingComposer,
          $ScansAnnotationComposer,
          $ScansCreateCompanionBuilder,
          $ScansUpdateCompanionBuilder,
          (ScanRow, $ScansReferences),
          ScanRow,
          PrefetchHooks Function({bool sourceId, bool scanDirsRefs, bool scanErrorsRefs})
        > {
  $ScansTableManager(_$CatalogDatabase db, Scans table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ScansFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ScansOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ScansAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> coverage = const Value.absent(),
                Value<String?> mountPathUsed = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int> dirsDone = const Value.absent(),
                Value<int> filesSeen = const Value.absent(),
                Value<int> bytesSeen = const Value.absent(),
                Value<int> errorCount = const Value.absent(),
              }) => ScansCompanion(
                id: id,
                sourceId: sourceId,
                kind: kind,
                status: status,
                coverage: coverage,
                mountPathUsed: mountPathUsed,
                startedAt: startedAt,
                finishedAt: finishedAt,
                dirsDone: dirsDone,
                filesSeen: filesSeen,
                bytesSeen: bytesSeen,
                errorCount: errorCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required String kind,
                required String status,
                Value<String?> coverage = const Value.absent(),
                Value<String?> mountPathUsed = const Value.absent(),
                required int startedAt,
                Value<int?> finishedAt = const Value.absent(),
                Value<int> dirsDone = const Value.absent(),
                Value<int> filesSeen = const Value.absent(),
                Value<int> bytesSeen = const Value.absent(),
                Value<int> errorCount = const Value.absent(),
              }) => ScansCompanion.insert(
                id: id,
                sourceId: sourceId,
                kind: kind,
                status: status,
                coverage: coverage,
                mountPathUsed: mountPathUsed,
                startedAt: startedAt,
                finishedAt: finishedAt,
                dirsDone: dirsDone,
                filesSeen: filesSeen,
                bytesSeen: bytesSeen,
                errorCount: errorCount,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<Scans, ScanRow>(table), $ScansReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({sourceId = false, scanDirsRefs = false, scanErrorsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (scanDirsRefs) db.scanDirs, if (scanErrorsRefs) db.scanErrors],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $ScansReferences._sourceIdTable(db),
                        referencedColumn: $ScansReferences._sourceIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scanDirsRefs)
                    await $_getPrefetchedDataByColumns<ScanRow, Scans, ScanDirRow, ScanDirs>(
                      currentTable: table,
                      referencedTable: $ScansReferences._scanDirsRefsTable(db),
                      managerFromTypedResult: (p0) => $ScansReferences(db, table, p0).scanDirsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'scan_id',
                      typedResults: items,
                    ),
                  if (scanErrorsRefs)
                    await $_getPrefetchedDataByColumns<ScanRow, Scans, ScanErrorRow, ScanErrors>(
                      currentTable: table,
                      referencedTable: $ScansReferences._scanErrorsRefsTable(db),
                      managerFromTypedResult: (p0) => $ScansReferences(db, table, p0).scanErrorsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'scan_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ScansProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Scans,
      ScanRow,
      $ScansFilterComposer,
      $ScansOrderingComposer,
      $ScansAnnotationComposer,
      $ScansCreateCompanionBuilder,
      $ScansUpdateCompanionBuilder,
      (ScanRow, $ScansReferences),
      ScanRow,
      PrefetchHooks Function({bool sourceId, bool scanDirsRefs, bool scanErrorsRefs})
    >;
typedef $ScanDirsCreateCompanionBuilder = ScanDirsCompanion Function({
  required int scanId,
  required String relPath,
  required String status,
});
typedef $ScanDirsUpdateCompanionBuilder = ScanDirsCompanion Function({
  Value<int> scanId,
  Value<String> relPath,
  Value<String> status,
});

final class $ScanDirsReferences extends BaseReferences<_$CatalogDatabase, ScanDirs, ScanDirRow> {
  $ScanDirsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Scans _scanIdTable(_$CatalogDatabase db) => db.scans.createAlias('scan_dirs__scan_id__scans__id');

  $ScansProcessedTableManager get scanId {
    final $_column = $_itemColumn<int>('scan_id')!;

    final manager = $ScansTableManager($_db, $_db.scans).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $ScanDirsFilterComposer extends Composer<_$CatalogDatabase, ScanDirs> {
  $ScanDirsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  $ScansFilterComposer get scanId {
    final $ScansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScanDirsOrderingComposer extends Composer<_$CatalogDatabase, ScanDirs> {
  $ScanDirsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  $ScansOrderingComposer get scanId {
    final $ScansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScanDirsAnnotationComposer extends Composer<_$CatalogDatabase, ScanDirs> {
  $ScanDirsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get relPath => $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get status => $composableBuilder(column: $table.status, builder: (column) => column);

  $ScansAnnotationComposer get scanId {
    final $ScansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScanDirsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          ScanDirs,
          ScanDirRow,
          $ScanDirsFilterComposer,
          $ScanDirsOrderingComposer,
          $ScanDirsAnnotationComposer,
          $ScanDirsCreateCompanionBuilder,
          $ScanDirsUpdateCompanionBuilder,
          (ScanDirRow, $ScanDirsReferences),
          ScanDirRow,
          PrefetchHooks Function({bool scanId})
        > {
  $ScanDirsTableManager(_$CatalogDatabase db, ScanDirs table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ScanDirsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ScanDirsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ScanDirsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> scanId = const Value.absent(),
            Value<String> relPath = const Value.absent(),
            Value<String> status = const Value.absent(),
          }) => ScanDirsCompanion(scanId: scanId, relPath: relPath, status: status),
          createCompanionCallback: ({required int scanId, required String relPath, required String status}) =>
              ScanDirsCompanion.insert(scanId: scanId, relPath: relPath, status: status),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<ScanDirs, ScanDirRow>(table), $ScanDirsReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({scanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $ScanDirsReferences._scanIdTable(db),
                        referencedColumn: $ScanDirsReferences._scanIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $ScanDirsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      ScanDirs,
      ScanDirRow,
      $ScanDirsFilterComposer,
      $ScanDirsOrderingComposer,
      $ScanDirsAnnotationComposer,
      $ScanDirsCreateCompanionBuilder,
      $ScanDirsUpdateCompanionBuilder,
      (ScanDirRow, $ScanDirsReferences),
      ScanDirRow,
      PrefetchHooks Function({bool scanId})
    >;
typedef $ScanErrorsCreateCompanionBuilder = ScanErrorsCompanion Function({
  Value<int> id,
  required int scanId,
  required String relPath,
  required String kind,
  Value<int?> win32Code,
  Value<String?> message,
  required int at,
});
typedef $ScanErrorsUpdateCompanionBuilder = ScanErrorsCompanion Function({
  Value<int> id,
  Value<int> scanId,
  Value<String> relPath,
  Value<String> kind,
  Value<int?> win32Code,
  Value<String?> message,
  Value<int> at,
});

final class $ScanErrorsReferences extends BaseReferences<_$CatalogDatabase, ScanErrors, ScanErrorRow> {
  $ScanErrorsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Scans _scanIdTable(_$CatalogDatabase db) => db.scans.createAlias('scan_errors__scan_id__scans__id');

  $ScansProcessedTableManager get scanId {
    final $_column = $_itemColumn<int>('scan_id')!;

    final manager = $ScansTableManager($_db, $_db.scans).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $ScanErrorsFilterComposer extends Composer<_$CatalogDatabase, ScanErrors> {
  $ScanErrorsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get win32Code =>
      $composableBuilder(column: $table.win32Code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  $ScansFilterComposer get scanId {
    final $ScansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScanErrorsOrderingComposer extends Composer<_$CatalogDatabase, ScanErrors> {
  $ScanErrorsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get win32Code =>
      $composableBuilder(column: $table.win32Code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  $ScansOrderingComposer get scanId {
    final $ScansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScanErrorsAnnotationComposer extends Composer<_$CatalogDatabase, ScanErrors> {
  $ScanErrorsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relPath => $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get win32Code => $composableBuilder(column: $table.win32Code, builder: (column) => column);

  GeneratedColumn<String> get message => $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<int> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  $ScansAnnotationComposer get scanId {
    final $ScansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ScanErrorsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          ScanErrors,
          ScanErrorRow,
          $ScanErrorsFilterComposer,
          $ScanErrorsOrderingComposer,
          $ScanErrorsAnnotationComposer,
          $ScanErrorsCreateCompanionBuilder,
          $ScanErrorsUpdateCompanionBuilder,
          (ScanErrorRow, $ScanErrorsReferences),
          ScanErrorRow,
          PrefetchHooks Function({bool scanId})
        > {
  $ScanErrorsTableManager(_$CatalogDatabase db, ScanErrors table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ScanErrorsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ScanErrorsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ScanErrorsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> scanId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> win32Code = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<int> at = const Value.absent(),
              }) => ScanErrorsCompanion(
                id: id,
                scanId: scanId,
                relPath: relPath,
                kind: kind,
                win32Code: win32Code,
                message: message,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int scanId,
                required String relPath,
                required String kind,
                Value<int?> win32Code = const Value.absent(),
                Value<String?> message = const Value.absent(),
                required int at,
              }) => ScanErrorsCompanion.insert(
                id: id,
                scanId: scanId,
                relPath: relPath,
                kind: kind,
                win32Code: win32Code,
                message: message,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<ScanErrors, ScanErrorRow>(table), $ScanErrorsReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({scanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $ScanErrorsReferences._scanIdTable(db),
                        referencedColumn: $ScanErrorsReferences._scanIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $ScanErrorsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      ScanErrors,
      ScanErrorRow,
      $ScanErrorsFilterComposer,
      $ScanErrorsOrderingComposer,
      $ScanErrorsAnnotationComposer,
      $ScanErrorsCreateCompanionBuilder,
      $ScanErrorsUpdateCompanionBuilder,
      (ScanErrorRow, $ScanErrorsReferences),
      ScanErrorRow,
      PrefetchHooks Function({bool scanId})
    >;
typedef $ContentsCreateCompanionBuilder = ContentsCompanion Function({
  Value<int> id,
  required Uint8List sha256,
  required int sizeBytes,
  Value<String> mediaType,
  required int createdAt,
});
typedef $ContentsUpdateCompanionBuilder = ContentsCompanion Function({
  Value<int> id,
  Value<Uint8List> sha256,
  Value<int> sizeBytes,
  Value<String> mediaType,
  Value<int> createdAt,
});

final class $ContentsReferences extends BaseReferences<_$CatalogDatabase, Contents, ContentRow> {
  $ContentsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<FileInstances, List<FileInstanceRow>> _fileInstancesRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.fileInstances, aliasName: 'contents__id__file_instances__content_id');

  $FileInstancesProcessedTableManager get fileInstancesRefs {
    final manager = $FileInstancesTableManager(
      $_db,
      $_db.fileInstances,
    ).filter((f) => f.contentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_fileInstancesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<MediaMetadata, List<MediaMetadataRow>> _mediaMetadataRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.mediaMetadata, aliasName: 'contents__id__media_metadata__content_id');

  $MediaMetadataProcessedTableManager get mediaMetadataRefs {
    final manager = $MediaMetadataTableManager(
      $_db,
      $_db.mediaMetadata,
    ).filter((f) => f.contentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaMetadataRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<DateCorrections, List<DateCorrectionRow>> _dateCorrectionsRefsTable(
    _$CatalogDatabase db,
  ) => MultiTypedResultKey.fromTable(db.dateCorrections, aliasName: 'contents__id__date_corrections__content_id');

  $DateCorrectionsProcessedTableManager get dateCorrectionsRefs {
    final manager = $DateCorrectionsTableManager(
      $_db,
      $_db.dateCorrections,
    ).filter((f) => f.contentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_dateCorrectionsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<ContentTags, List<ContentTagRow>> _contentTagsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.contentTags, aliasName: 'contents__id__content_tags__content_id');

  $ContentTagsProcessedTableManager get contentTagsRefs {
    final manager = $ContentTagsTableManager(
      $_db,
      $_db.contentTags,
    ).filter((f) => f.contentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_contentTagsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $ContentsFilterComposer extends Composer<_$CatalogDatabase, Contents> {
  $ContentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> fileInstancesRefs(Expression<bool> Function($FileInstancesFilterComposer f) f) {
    final $FileInstancesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesFilterComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mediaMetadataRefs(Expression<bool> Function($MediaMetadataFilterComposer f) f) {
    final $MediaMetadataFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaMetadata,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MediaMetadataFilterComposer(
            $db: $db,
            $table: $db.mediaMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dateCorrectionsRefs(Expression<bool> Function($DateCorrectionsFilterComposer f) f) {
    final $DateCorrectionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dateCorrections,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $DateCorrectionsFilterComposer(
            $db: $db,
            $table: $db.dateCorrections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> contentTagsRefs(Expression<bool> Function($ContentTagsFilterComposer f) f) {
    final $ContentTagsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contentTags,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentTagsFilterComposer(
            $db: $db,
            $table: $db.contentTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ContentsOrderingComposer extends Composer<_$CatalogDatabase, Contents> {
  $ContentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $ContentsAnnotationComposer extends Composer<_$CatalogDatabase, Contents> {
  $ContentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get sha256 => $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes => $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get mediaType => $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> fileInstancesRefs<T extends Object>(Expression<T> Function($FileInstancesAnnotationComposer a) f) {
    final $FileInstancesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesAnnotationComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mediaMetadataRefs<T extends Object>(Expression<T> Function($MediaMetadataAnnotationComposer a) f) {
    final $MediaMetadataAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaMetadata,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MediaMetadataAnnotationComposer(
            $db: $db,
            $table: $db.mediaMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dateCorrectionsRefs<T extends Object>(Expression<T> Function($DateCorrectionsAnnotationComposer a) f) {
    final $DateCorrectionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dateCorrections,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $DateCorrectionsAnnotationComposer(
            $db: $db,
            $table: $db.dateCorrections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> contentTagsRefs<T extends Object>(Expression<T> Function($ContentTagsAnnotationComposer a) f) {
    final $ContentTagsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contentTags,
      getReferencedColumn: (t) => t.contentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentTagsAnnotationComposer(
            $db: $db,
            $table: $db.contentTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ContentsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Contents,
          ContentRow,
          $ContentsFilterComposer,
          $ContentsOrderingComposer,
          $ContentsAnnotationComposer,
          $ContentsCreateCompanionBuilder,
          $ContentsUpdateCompanionBuilder,
          (ContentRow, $ContentsReferences),
          ContentRow,
          PrefetchHooks Function({
            bool fileInstancesRefs,
            bool mediaMetadataRefs,
            bool dateCorrectionsRefs,
            bool contentTagsRefs,
          })
        > {
  $ContentsTableManager(_$CatalogDatabase db, Contents table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ContentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ContentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ContentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> sha256 = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => ContentsCompanion(
                id: id,
                sha256: sha256,
                sizeBytes: sizeBytes,
                mediaType: mediaType,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List sha256,
                required int sizeBytes,
                Value<String> mediaType = const Value.absent(),
                required int createdAt,
              }) => ContentsCompanion.insert(
                id: id,
                sha256: sha256,
                sizeBytes: sizeBytes,
                mediaType: mediaType,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<Contents, ContentRow>(table), $ContentsReferences(db, table, e))).toList(),
          prefetchHooksCallback:
              ({
                fileInstancesRefs = false,
                mediaMetadataRefs = false,
                dateCorrectionsRefs = false,
                contentTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (fileInstancesRefs) db.fileInstances,
                    if (mediaMetadataRefs) db.mediaMetadata,
                    if (dateCorrectionsRefs) db.dateCorrections,
                    if (contentTagsRefs) db.contentTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (fileInstancesRefs)
                        await $_getPrefetchedDataByColumns<ContentRow, Contents, FileInstanceRow, FileInstances>(
                          currentTable: table,
                          referencedTable: $ContentsReferences._fileInstancesRefsTable(db),
                          managerFromTypedResult: (p0) => $ContentsReferences(db, table, p0).fileInstancesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'content_id',
                          typedResults: items,
                        ),
                      if (mediaMetadataRefs)
                        await $_getPrefetchedDataByColumns<ContentRow, Contents, MediaMetadataRow, MediaMetadata>(
                          currentTable: table,
                          referencedTable: $ContentsReferences._mediaMetadataRefsTable(db),
                          managerFromTypedResult: (p0) => $ContentsReferences(db, table, p0).mediaMetadataRefs,
                          currentColumn: 'id',
                          referencedColumn: 'content_id',
                          typedResults: items,
                        ),
                      if (dateCorrectionsRefs)
                        await $_getPrefetchedDataByColumns<ContentRow, Contents, DateCorrectionRow, DateCorrections>(
                          currentTable: table,
                          referencedTable: $ContentsReferences._dateCorrectionsRefsTable(db),
                          managerFromTypedResult: (p0) => $ContentsReferences(db, table, p0).dateCorrectionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'content_id',
                          typedResults: items,
                        ),
                      if (contentTagsRefs)
                        await $_getPrefetchedDataByColumns<ContentRow, Contents, ContentTagRow, ContentTags>(
                          currentTable: table,
                          referencedTable: $ContentsReferences._contentTagsRefsTable(db),
                          managerFromTypedResult: (p0) => $ContentsReferences(db, table, p0).contentTagsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'content_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $ContentsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Contents,
      ContentRow,
      $ContentsFilterComposer,
      $ContentsOrderingComposer,
      $ContentsAnnotationComposer,
      $ContentsCreateCompanionBuilder,
      $ContentsUpdateCompanionBuilder,
      (ContentRow, $ContentsReferences),
      ContentRow,
      PrefetchHooks Function({
        bool fileInstancesRefs,
        bool mediaMetadataRefs,
        bool dateCorrectionsRefs,
        bool contentTagsRefs,
      })
    >;
typedef $FileInstancesCreateCompanionBuilder = FileInstancesCompanion Function({
  Value<int> id,
  required String sourceId,
  required String relPath,
  required String dirRelPath,
  required String name,
  required String ext,
  required int sizeBytes,
  Value<int?> mtime,
  Value<int?> ctime,
  Value<int?> attributes,
  Value<int?> contentId,
  Value<String> hashStatus,
  Value<int?> hashedSize,
  Value<int?> hashedMtime,
  Value<int?> hashedAt,
  Value<int?> lastVerifiedAt,
  Value<String> availability,
  Value<String> integrity,
  Value<int?> firstSeenScanId,
  Value<int?> lastSeenScanId,
  Value<int?> missingConfirmedAt,
  Value<String?> hashError,
  Value<String?> deviceObjectId,
});
typedef $FileInstancesUpdateCompanionBuilder = FileInstancesCompanion Function({
  Value<int> id,
  Value<String> sourceId,
  Value<String> relPath,
  Value<String> dirRelPath,
  Value<String> name,
  Value<String> ext,
  Value<int> sizeBytes,
  Value<int?> mtime,
  Value<int?> ctime,
  Value<int?> attributes,
  Value<int?> contentId,
  Value<String> hashStatus,
  Value<int?> hashedSize,
  Value<int?> hashedMtime,
  Value<int?> hashedAt,
  Value<int?> lastVerifiedAt,
  Value<String> availability,
  Value<String> integrity,
  Value<int?> firstSeenScanId,
  Value<int?> lastSeenScanId,
  Value<int?> missingConfirmedAt,
  Value<String?> hashError,
  Value<String?> deviceObjectId,
});

final class $FileInstancesReferences extends BaseReferences<_$CatalogDatabase, FileInstances, FileInstanceRow> {
  $FileInstancesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Sources _sourceIdTable(_$CatalogDatabase db) =>
      db.sources.createAlias('file_instances__source_id__sources__id');

  $SourcesProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $SourcesTableManager($_db, $_db.sources).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Contents _contentIdTable(_$CatalogDatabase db) =>
      db.contents.createAlias('file_instances__content_id__contents__id');

  $ContentsProcessedTableManager? get contentId {
    final $_column = $_itemColumn<int>('content_id');
    if ($_column == null) return null;
    final manager = $ContentsTableManager($_db, $_db.contents).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Scans _firstSeenScanIdTable(_$CatalogDatabase db) =>
      db.scans.createAlias('file_instances__first_seen_scan_id__scans__id');

  $ScansProcessedTableManager? get firstSeenScanId {
    final $_column = $_itemColumn<int>('first_seen_scan_id');
    if ($_column == null) return null;
    final manager = $ScansTableManager($_db, $_db.scans).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_firstSeenScanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Scans _lastSeenScanIdTable(_$CatalogDatabase db) =>
      db.scans.createAlias('file_instances__last_seen_scan_id__scans__id');

  $ScansProcessedTableManager? get lastSeenScanId {
    final $_column = $_itemColumn<int>('last_seen_scan_id');
    if ($_column == null) return null;
    final manager = $ScansTableManager($_db, $_db.scans).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lastSeenScanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<OperationItems, List<OperationItemRow>> _operationItemsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.operationItems,
        aliasName: 'file_instances__id__operation_items__src_instance_id',
      );

  $OperationItemsProcessedTableManager get operationItemsRefs {
    final manager = $OperationItemsTableManager(
      $_db,
      $_db.operationItems,
    ).filter((f) => f.srcInstanceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationItemsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<SelectionSetItems, List<SelectionSetItemRow>> _selectionSetItemsRefsTable(
    _$CatalogDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.selectionSetItems,
    aliasName: 'file_instances__id__selection_set_items__instance_id',
  );

  $SelectionSetItemsProcessedTableManager get selectionSetItemsRefs {
    final manager = $SelectionSetItemsTableManager(
      $_db,
      $_db.selectionSetItems,
    ).filter((f) => f.instanceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_selectionSetItemsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<IntegrityChecks, List<IntegrityCheckRow>> _integrityChecksRefsTable(
    _$CatalogDatabase db,
  ) =>
      MultiTypedResultKey.fromTable(db.integrityChecks, aliasName: 'file_instances__id__integrity_checks__instance_id');

  $IntegrityChecksProcessedTableManager get integrityChecksRefs {
    final manager = $IntegrityChecksTableManager(
      $_db,
      $_db.integrityChecks,
    ).filter((f) => f.instanceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_integrityChecksRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $FileInstancesFilterComposer extends Composer<_$CatalogDatabase, FileInstances> {
  $FileInstancesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dirRelPath =>
      $composableBuilder(column: $table.dirRelPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ext => $composableBuilder(column: $table.ext, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mtime => $composableBuilder(column: $table.mtime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ctime => $composableBuilder(column: $table.ctime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attributes =>
      $composableBuilder(column: $table.attributes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hashStatus =>
      $composableBuilder(column: $table.hashStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hashedSize =>
      $composableBuilder(column: $table.hashedSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hashedMtime =>
      $composableBuilder(column: $table.hashedMtime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hashedAt =>
      $composableBuilder(column: $table.hashedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastVerifiedAt =>
      $composableBuilder(column: $table.lastVerifiedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get availability =>
      $composableBuilder(column: $table.availability, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get integrity =>
      $composableBuilder(column: $table.integrity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get missingConfirmedAt =>
      $composableBuilder(column: $table.missingConfirmedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hashError =>
      $composableBuilder(column: $table.hashError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceObjectId =>
      $composableBuilder(column: $table.deviceObjectId, builder: (column) => ColumnFilters(column));

  $SourcesFilterComposer get sourceId {
    final $SourcesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ContentsFilterComposer get contentId {
    final $ContentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsFilterComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ScansFilterComposer get firstSeenScanId {
    final $ScansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.firstSeenScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ScansFilterComposer get lastSeenScanId {
    final $ScansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lastSeenScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> operationItemsRefs(Expression<bool> Function($OperationItemsFilterComposer f) f) {
    final $OperationItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.srcInstanceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsFilterComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> selectionSetItemsRefs(Expression<bool> Function($SelectionSetItemsFilterComposer f) f) {
    final $SelectionSetItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.selectionSetItems,
      getReferencedColumn: (t) => t.instanceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetItemsFilterComposer(
            $db: $db,
            $table: $db.selectionSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> integrityChecksRefs(Expression<bool> Function($IntegrityChecksFilterComposer f) f) {
    final $IntegrityChecksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.integrityChecks,
      getReferencedColumn: (t) => t.instanceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $IntegrityChecksFilterComposer(
            $db: $db,
            $table: $db.integrityChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $FileInstancesOrderingComposer extends Composer<_$CatalogDatabase, FileInstances> {
  $FileInstancesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dirRelPath =>
      $composableBuilder(column: $table.dirRelPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ctime =>
      $composableBuilder(column: $table.ctime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attributes =>
      $composableBuilder(column: $table.attributes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hashStatus =>
      $composableBuilder(column: $table.hashStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hashedSize =>
      $composableBuilder(column: $table.hashedSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hashedMtime =>
      $composableBuilder(column: $table.hashedMtime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hashedAt =>
      $composableBuilder(column: $table.hashedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastVerifiedAt =>
      $composableBuilder(column: $table.lastVerifiedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get availability =>
      $composableBuilder(column: $table.availability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get integrity =>
      $composableBuilder(column: $table.integrity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get missingConfirmedAt =>
      $composableBuilder(column: $table.missingConfirmedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hashError =>
      $composableBuilder(column: $table.hashError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceObjectId =>
      $composableBuilder(column: $table.deviceObjectId, builder: (column) => ColumnOrderings(column));

  $SourcesOrderingComposer get sourceId {
    final $SourcesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ContentsOrderingComposer get contentId {
    final $ContentsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsOrderingComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ScansOrderingComposer get firstSeenScanId {
    final $ScansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.firstSeenScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ScansOrderingComposer get lastSeenScanId {
    final $ScansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lastSeenScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $FileInstancesAnnotationComposer extends Composer<_$CatalogDatabase, FileInstances> {
  $FileInstancesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relPath => $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get dirRelPath => $composableBuilder(column: $table.dirRelPath, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ext => $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes => $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get mtime => $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<int> get ctime => $composableBuilder(column: $table.ctime, builder: (column) => column);

  GeneratedColumn<int> get attributes => $composableBuilder(column: $table.attributes, builder: (column) => column);

  GeneratedColumn<String> get hashStatus => $composableBuilder(column: $table.hashStatus, builder: (column) => column);

  GeneratedColumn<int> get hashedSize => $composableBuilder(column: $table.hashedSize, builder: (column) => column);

  GeneratedColumn<int> get hashedMtime => $composableBuilder(column: $table.hashedMtime, builder: (column) => column);

  GeneratedColumn<int> get hashedAt => $composableBuilder(column: $table.hashedAt, builder: (column) => column);

  GeneratedColumn<int> get lastVerifiedAt =>
      $composableBuilder(column: $table.lastVerifiedAt, builder: (column) => column);

  GeneratedColumn<String> get availability =>
      $composableBuilder(column: $table.availability, builder: (column) => column);

  GeneratedColumn<String> get integrity => $composableBuilder(column: $table.integrity, builder: (column) => column);

  GeneratedColumn<int> get missingConfirmedAt =>
      $composableBuilder(column: $table.missingConfirmedAt, builder: (column) => column);

  GeneratedColumn<String> get hashError => $composableBuilder(column: $table.hashError, builder: (column) => column);

  GeneratedColumn<String> get deviceObjectId =>
      $composableBuilder(column: $table.deviceObjectId, builder: (column) => column);

  $SourcesAnnotationComposer get sourceId {
    final $SourcesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ContentsAnnotationComposer get contentId {
    final $ContentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsAnnotationComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ScansAnnotationComposer get firstSeenScanId {
    final $ScansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.firstSeenScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ScansAnnotationComposer get lastSeenScanId {
    final $ScansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lastSeenScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ScansAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> operationItemsRefs<T extends Object>(Expression<T> Function($OperationItemsAnnotationComposer a) f) {
    final $OperationItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.srcInstanceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsAnnotationComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> selectionSetItemsRefs<T extends Object>(
    Expression<T> Function($SelectionSetItemsAnnotationComposer a) f,
  ) {
    final $SelectionSetItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.selectionSetItems,
      getReferencedColumn: (t) => t.instanceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetItemsAnnotationComposer(
            $db: $db,
            $table: $db.selectionSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> integrityChecksRefs<T extends Object>(Expression<T> Function($IntegrityChecksAnnotationComposer a) f) {
    final $IntegrityChecksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.integrityChecks,
      getReferencedColumn: (t) => t.instanceId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $IntegrityChecksAnnotationComposer(
            $db: $db,
            $table: $db.integrityChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $FileInstancesTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          FileInstances,
          FileInstanceRow,
          $FileInstancesFilterComposer,
          $FileInstancesOrderingComposer,
          $FileInstancesAnnotationComposer,
          $FileInstancesCreateCompanionBuilder,
          $FileInstancesUpdateCompanionBuilder,
          (FileInstanceRow, $FileInstancesReferences),
          FileInstanceRow,
          PrefetchHooks Function({
            bool sourceId,
            bool contentId,
            bool firstSeenScanId,
            bool lastSeenScanId,
            bool operationItemsRefs,
            bool selectionSetItemsRefs,
            bool integrityChecksRefs,
          })
        > {
  $FileInstancesTableManager(_$CatalogDatabase db, FileInstances table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $FileInstancesFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $FileInstancesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $FileInstancesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> dirRelPath = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ext = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int?> mtime = const Value.absent(),
                Value<int?> ctime = const Value.absent(),
                Value<int?> attributes = const Value.absent(),
                Value<int?> contentId = const Value.absent(),
                Value<String> hashStatus = const Value.absent(),
                Value<int?> hashedSize = const Value.absent(),
                Value<int?> hashedMtime = const Value.absent(),
                Value<int?> hashedAt = const Value.absent(),
                Value<int?> lastVerifiedAt = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String> integrity = const Value.absent(),
                Value<int?> firstSeenScanId = const Value.absent(),
                Value<int?> lastSeenScanId = const Value.absent(),
                Value<int?> missingConfirmedAt = const Value.absent(),
                Value<String?> hashError = const Value.absent(),
                Value<String?> deviceObjectId = const Value.absent(),
              }) => FileInstancesCompanion(
                id: id,
                sourceId: sourceId,
                relPath: relPath,
                dirRelPath: dirRelPath,
                name: name,
                ext: ext,
                sizeBytes: sizeBytes,
                mtime: mtime,
                ctime: ctime,
                attributes: attributes,
                contentId: contentId,
                hashStatus: hashStatus,
                hashedSize: hashedSize,
                hashedMtime: hashedMtime,
                hashedAt: hashedAt,
                lastVerifiedAt: lastVerifiedAt,
                availability: availability,
                integrity: integrity,
                firstSeenScanId: firstSeenScanId,
                lastSeenScanId: lastSeenScanId,
                missingConfirmedAt: missingConfirmedAt,
                hashError: hashError,
                deviceObjectId: deviceObjectId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required String relPath,
                required String dirRelPath,
                required String name,
                required String ext,
                required int sizeBytes,
                Value<int?> mtime = const Value.absent(),
                Value<int?> ctime = const Value.absent(),
                Value<int?> attributes = const Value.absent(),
                Value<int?> contentId = const Value.absent(),
                Value<String> hashStatus = const Value.absent(),
                Value<int?> hashedSize = const Value.absent(),
                Value<int?> hashedMtime = const Value.absent(),
                Value<int?> hashedAt = const Value.absent(),
                Value<int?> lastVerifiedAt = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String> integrity = const Value.absent(),
                Value<int?> firstSeenScanId = const Value.absent(),
                Value<int?> lastSeenScanId = const Value.absent(),
                Value<int?> missingConfirmedAt = const Value.absent(),
                Value<String?> hashError = const Value.absent(),
                Value<String?> deviceObjectId = const Value.absent(),
              }) => FileInstancesCompanion.insert(
                id: id,
                sourceId: sourceId,
                relPath: relPath,
                dirRelPath: dirRelPath,
                name: name,
                ext: ext,
                sizeBytes: sizeBytes,
                mtime: mtime,
                ctime: ctime,
                attributes: attributes,
                contentId: contentId,
                hashStatus: hashStatus,
                hashedSize: hashedSize,
                hashedMtime: hashedMtime,
                hashedAt: hashedAt,
                lastVerifiedAt: lastVerifiedAt,
                availability: availability,
                integrity: integrity,
                firstSeenScanId: firstSeenScanId,
                lastSeenScanId: lastSeenScanId,
                missingConfirmedAt: missingConfirmedAt,
                hashError: hashError,
                deviceObjectId: deviceObjectId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<FileInstances, FileInstanceRow>(table), $FileInstancesReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                contentId = false,
                firstSeenScanId = false,
                lastSeenScanId = false,
                operationItemsRefs = false,
                selectionSetItemsRefs = false,
                integrityChecksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (operationItemsRefs) db.operationItems,
                    if (selectionSetItemsRefs) db.selectionSetItems,
                    if (integrityChecksRefs) db.integrityChecks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $FileInstancesReferences._sourceIdTable(db),
                            referencedColumn: $FileInstancesReferences._sourceIdTable(db).id,
                          ) as T;
                        }
                        if (contentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.contentId,
                            referencedTable: $FileInstancesReferences._contentIdTable(db),
                            referencedColumn: $FileInstancesReferences._contentIdTable(db).id,
                          ) as T;
                        }
                        if (firstSeenScanId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.firstSeenScanId,
                            referencedTable: $FileInstancesReferences._firstSeenScanIdTable(db),
                            referencedColumn: $FileInstancesReferences._firstSeenScanIdTable(db).id,
                          ) as T;
                        }
                        if (lastSeenScanId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.lastSeenScanId,
                            referencedTable: $FileInstancesReferences._lastSeenScanIdTable(db),
                            referencedColumn: $FileInstancesReferences._lastSeenScanIdTable(db).id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (operationItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          FileInstanceRow,
                          FileInstances,
                          OperationItemRow,
                          OperationItems
                        >(
                          currentTable: table,
                          referencedTable: $FileInstancesReferences._operationItemsRefsTable(db),
                          managerFromTypedResult: (p0) => $FileInstancesReferences(db, table, p0).operationItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'src_instance_id',
                          typedResults: items,
                        ),
                      if (selectionSetItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          FileInstanceRow,
                          FileInstances,
                          SelectionSetItemRow,
                          SelectionSetItems
                        >(
                          currentTable: table,
                          referencedTable: $FileInstancesReferences._selectionSetItemsRefsTable(db),
                          managerFromTypedResult: (p0) => $FileInstancesReferences(db, table, p0).selectionSetItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'instance_id',
                          typedResults: items,
                        ),
                      if (integrityChecksRefs)
                        await $_getPrefetchedDataByColumns<
                          FileInstanceRow,
                          FileInstances,
                          IntegrityCheckRow,
                          IntegrityChecks
                        >(
                          currentTable: table,
                          referencedTable: $FileInstancesReferences._integrityChecksRefsTable(db),
                          managerFromTypedResult: (p0) => $FileInstancesReferences(db, table, p0).integrityChecksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'instance_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $FileInstancesProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      FileInstances,
      FileInstanceRow,
      $FileInstancesFilterComposer,
      $FileInstancesOrderingComposer,
      $FileInstancesAnnotationComposer,
      $FileInstancesCreateCompanionBuilder,
      $FileInstancesUpdateCompanionBuilder,
      (FileInstanceRow, $FileInstancesReferences),
      FileInstanceRow,
      PrefetchHooks Function({
        bool sourceId,
        bool contentId,
        bool firstSeenScanId,
        bool lastSeenScanId,
        bool operationItemsRefs,
        bool selectionSetItemsRefs,
        bool integrityChecksRefs,
      })
    >;
typedef $ClockCorrectionsCreateCompanionBuilder = ClockCorrectionsCompanion Function({
  Value<int> id,
  Value<String?> make,
  Value<String?> model,
  Value<String?> bodySerial,
  Value<int> offsetMs,
  Value<int> years,
  Value<int?> periodStartUtcMs,
  Value<int?> periodEndUtcMs,
  Value<String?> sourceIdsJson,
  Value<String?> note,
  required int createdAt,
  Value<int?> undoneAt,
});
typedef $ClockCorrectionsUpdateCompanionBuilder = ClockCorrectionsCompanion Function({
  Value<int> id,
  Value<String?> make,
  Value<String?> model,
  Value<String?> bodySerial,
  Value<int> offsetMs,
  Value<int> years,
  Value<int?> periodStartUtcMs,
  Value<int?> periodEndUtcMs,
  Value<String?> sourceIdsJson,
  Value<String?> note,
  Value<int> createdAt,
  Value<int?> undoneAt,
});

final class $ClockCorrectionsReferences
    extends BaseReferences<_$CatalogDatabase, ClockCorrections, ClockCorrectionRow> {
  $ClockCorrectionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<MediaMetadata, List<MediaMetadataRow>> _mediaMetadataRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mediaMetadata,
        aliasName: 'clock_corrections__id__media_metadata__clock_correction_id',
      );

  $MediaMetadataProcessedTableManager get mediaMetadataRefs {
    final manager = $MediaMetadataTableManager(
      $_db,
      $_db.mediaMetadata,
    ).filter((f) => f.clockCorrectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaMetadataRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $ClockCorrectionsFilterComposer extends Composer<_$CatalogDatabase, ClockCorrections> {
  $ClockCorrectionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get make => $composableBuilder(column: $table.make, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodySerial =>
      $composableBuilder(column: $table.bodySerial, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get years => $composableBuilder(column: $table.years, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get periodStartUtcMs =>
      $composableBuilder(column: $table.periodStartUtcMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get periodEndUtcMs =>
      $composableBuilder(column: $table.periodEndUtcMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceIdsJson =>
      $composableBuilder(column: $table.sourceIdsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get undoneAt =>
      $composableBuilder(column: $table.undoneAt, builder: (column) => ColumnFilters(column));

  Expression<bool> mediaMetadataRefs(Expression<bool> Function($MediaMetadataFilterComposer f) f) {
    final $MediaMetadataFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaMetadata,
      getReferencedColumn: (t) => t.clockCorrectionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MediaMetadataFilterComposer(
            $db: $db,
            $table: $db.mediaMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ClockCorrectionsOrderingComposer extends Composer<_$CatalogDatabase, ClockCorrections> {
  $ClockCorrectionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodySerial =>
      $composableBuilder(column: $table.bodySerial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get years =>
      $composableBuilder(column: $table.years, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get periodStartUtcMs =>
      $composableBuilder(column: $table.periodStartUtcMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get periodEndUtcMs =>
      $composableBuilder(column: $table.periodEndUtcMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceIdsJson =>
      $composableBuilder(column: $table.sourceIdsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get undoneAt =>
      $composableBuilder(column: $table.undoneAt, builder: (column) => ColumnOrderings(column));
}

class $ClockCorrectionsAnnotationComposer extends Composer<_$CatalogDatabase, ClockCorrections> {
  $ClockCorrectionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get make => $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model => $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get bodySerial => $composableBuilder(column: $table.bodySerial, builder: (column) => column);

  GeneratedColumn<int> get offsetMs => $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<int> get years => $composableBuilder(column: $table.years, builder: (column) => column);

  GeneratedColumn<int> get periodStartUtcMs =>
      $composableBuilder(column: $table.periodStartUtcMs, builder: (column) => column);

  GeneratedColumn<int> get periodEndUtcMs =>
      $composableBuilder(column: $table.periodEndUtcMs, builder: (column) => column);

  GeneratedColumn<String> get sourceIdsJson =>
      $composableBuilder(column: $table.sourceIdsJson, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get undoneAt => $composableBuilder(column: $table.undoneAt, builder: (column) => column);

  Expression<T> mediaMetadataRefs<T extends Object>(Expression<T> Function($MediaMetadataAnnotationComposer a) f) {
    final $MediaMetadataAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaMetadata,
      getReferencedColumn: (t) => t.clockCorrectionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MediaMetadataAnnotationComposer(
            $db: $db,
            $table: $db.mediaMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ClockCorrectionsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          ClockCorrections,
          ClockCorrectionRow,
          $ClockCorrectionsFilterComposer,
          $ClockCorrectionsOrderingComposer,
          $ClockCorrectionsAnnotationComposer,
          $ClockCorrectionsCreateCompanionBuilder,
          $ClockCorrectionsUpdateCompanionBuilder,
          (ClockCorrectionRow, $ClockCorrectionsReferences),
          ClockCorrectionRow,
          PrefetchHooks Function({bool mediaMetadataRefs})
        > {
  $ClockCorrectionsTableManager(_$CatalogDatabase db, ClockCorrections table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ClockCorrectionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ClockCorrectionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ClockCorrectionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> bodySerial = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<int> years = const Value.absent(),
                Value<int?> periodStartUtcMs = const Value.absent(),
                Value<int?> periodEndUtcMs = const Value.absent(),
                Value<String?> sourceIdsJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> undoneAt = const Value.absent(),
              }) => ClockCorrectionsCompanion(
                id: id,
                make: make,
                model: model,
                bodySerial: bodySerial,
                offsetMs: offsetMs,
                years: years,
                periodStartUtcMs: periodStartUtcMs,
                periodEndUtcMs: periodEndUtcMs,
                sourceIdsJson: sourceIdsJson,
                note: note,
                createdAt: createdAt,
                undoneAt: undoneAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> bodySerial = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<int> years = const Value.absent(),
                Value<int?> periodStartUtcMs = const Value.absent(),
                Value<int?> periodEndUtcMs = const Value.absent(),
                Value<String?> sourceIdsJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAt,
                Value<int?> undoneAt = const Value.absent(),
              }) => ClockCorrectionsCompanion.insert(
                id: id,
                make: make,
                model: model,
                bodySerial: bodySerial,
                offsetMs: offsetMs,
                years: years,
                periodStartUtcMs: periodStartUtcMs,
                periodEndUtcMs: periodEndUtcMs,
                sourceIdsJson: sourceIdsJson,
                note: note,
                createdAt: createdAt,
                undoneAt: undoneAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ClockCorrections, ClockCorrectionRow>(table),
                  $ClockCorrectionsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaMetadataRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mediaMetadataRefs) db.mediaMetadata],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaMetadataRefs)
                    await $_getPrefetchedDataByColumns<
                      ClockCorrectionRow,
                      ClockCorrections,
                      MediaMetadataRow,
                      MediaMetadata
                    >(
                      currentTable: table,
                      referencedTable: $ClockCorrectionsReferences._mediaMetadataRefsTable(db),
                      managerFromTypedResult: (p0) => $ClockCorrectionsReferences(db, table, p0).mediaMetadataRefs,
                      currentColumn: 'id',
                      referencedColumn: 'clock_correction_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ClockCorrectionsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      ClockCorrections,
      ClockCorrectionRow,
      $ClockCorrectionsFilterComposer,
      $ClockCorrectionsOrderingComposer,
      $ClockCorrectionsAnnotationComposer,
      $ClockCorrectionsCreateCompanionBuilder,
      $ClockCorrectionsUpdateCompanionBuilder,
      (ClockCorrectionRow, $ClockCorrectionsReferences),
      ClockCorrectionRow,
      PrefetchHooks Function({bool mediaMetadataRefs})
    >;
typedef $MomentsCreateCompanionBuilder = MomentsCompanion Function({
  Value<int> id,
  required String kind,
  Value<String?> name,
  required int startUtcMs,
  required int endUtcMs,
  Value<int> itemCount,
  required int createdAt,
  required int updatedAt,
});
typedef $MomentsUpdateCompanionBuilder = MomentsCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String?> name,
  Value<int> startUtcMs,
  Value<int> endUtcMs,
  Value<int> itemCount,
  Value<int> createdAt,
  Value<int> updatedAt,
});

final class $MomentsReferences extends BaseReferences<_$CatalogDatabase, Moments, MomentRow> {
  $MomentsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<MediaMetadata, List<MediaMetadataRow>> _mediaMetadataRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.mediaMetadata, aliasName: 'moments__id__media_metadata__moment_id');

  $MediaMetadataProcessedTableManager get mediaMetadataRefs {
    final manager = $MediaMetadataTableManager(
      $_db,
      $_db.mediaMetadata,
    ).filter((f) => f.momentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaMetadataRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $MomentsFilterComposer extends Composer<_$CatalogDatabase, Moments> {
  $MomentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startUtcMs =>
      $composableBuilder(column: $table.startUtcMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endUtcMs =>
      $composableBuilder(column: $table.endUtcMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> mediaMetadataRefs(Expression<bool> Function($MediaMetadataFilterComposer f) f) {
    final $MediaMetadataFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaMetadata,
      getReferencedColumn: (t) => t.momentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MediaMetadataFilterComposer(
            $db: $db,
            $table: $db.mediaMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MomentsOrderingComposer extends Composer<_$CatalogDatabase, Moments> {
  $MomentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startUtcMs =>
      $composableBuilder(column: $table.startUtcMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endUtcMs =>
      $composableBuilder(column: $table.endUtcMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $MomentsAnnotationComposer extends Composer<_$CatalogDatabase, Moments> {
  $MomentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get startUtcMs => $composableBuilder(column: $table.startUtcMs, builder: (column) => column);

  GeneratedColumn<int> get endUtcMs => $composableBuilder(column: $table.endUtcMs, builder: (column) => column);

  GeneratedColumn<int> get itemCount => $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> mediaMetadataRefs<T extends Object>(Expression<T> Function($MediaMetadataAnnotationComposer a) f) {
    final $MediaMetadataAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaMetadata,
      getReferencedColumn: (t) => t.momentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MediaMetadataAnnotationComposer(
            $db: $db,
            $table: $db.mediaMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MomentsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Moments,
          MomentRow,
          $MomentsFilterComposer,
          $MomentsOrderingComposer,
          $MomentsAnnotationComposer,
          $MomentsCreateCompanionBuilder,
          $MomentsUpdateCompanionBuilder,
          (MomentRow, $MomentsReferences),
          MomentRow,
          PrefetchHooks Function({bool mediaMetadataRefs})
        > {
  $MomentsTableManager(_$CatalogDatabase db, Moments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $MomentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $MomentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $MomentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> startUtcMs = const Value.absent(),
                Value<int> endUtcMs = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => MomentsCompanion(
                id: id,
                kind: kind,
                name: name,
                startUtcMs: startUtcMs,
                endUtcMs: endUtcMs,
                itemCount: itemCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                Value<String?> name = const Value.absent(),
                required int startUtcMs,
                required int endUtcMs,
                Value<int> itemCount = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => MomentsCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                startUtcMs: startUtcMs,
                endUtcMs: endUtcMs,
                itemCount: itemCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<Moments, MomentRow>(table), $MomentsReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({mediaMetadataRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mediaMetadataRefs) db.mediaMetadata],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaMetadataRefs)
                    await $_getPrefetchedDataByColumns<MomentRow, Moments, MediaMetadataRow, MediaMetadata>(
                      currentTable: table,
                      referencedTable: $MomentsReferences._mediaMetadataRefsTable(db),
                      managerFromTypedResult: (p0) => $MomentsReferences(db, table, p0).mediaMetadataRefs,
                      currentColumn: 'id',
                      referencedColumn: 'moment_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $MomentsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Moments,
      MomentRow,
      $MomentsFilterComposer,
      $MomentsOrderingComposer,
      $MomentsAnnotationComposer,
      $MomentsCreateCompanionBuilder,
      $MomentsUpdateCompanionBuilder,
      (MomentRow, $MomentsReferences),
      MomentRow,
      PrefetchHooks Function({bool mediaMetadataRefs})
    >;
typedef $MediaMetadataCreateCompanionBuilder = MediaMetadataCompanion Function({
  Value<int> contentId,
  Value<int?> captureUtcMs,
  Value<String?> captureLocal,
  Value<int?> tzOffsetMin,
  Value<String?> dateSource,
  Value<String?> dateConfidence,
  Value<bool> dateConflict,
  Value<String?> candidatesJson,
  Value<String?> make,
  Value<String?> model,
  Value<String?> lens,
  Value<int?> iso,
  Value<double?> aperture,
  Value<double?> exposureS,
  Value<double?> focalMm,
  Value<int?> width,
  Value<int?> height,
  Value<int?> orientation,
  Value<double?> lat,
  Value<double?> lon,
  Value<int?> durationMs,
  Value<double?> fps,
  Value<String?> videoCodec,
  Value<String?> audioCodec,
  Value<int?> bitrate,
  Value<String?> software,
  Value<String?> extractor,
  Value<int?> extractedAt,
  Value<String?> bodySerial,
  Value<String> metaStatus,
  Value<String?> metaError,
  Value<int?> effUtcMs,
  Value<String?> effLocal,
  Value<int?> effOffsetMin,
  Value<String?> effSource,
  Value<String?> effConfidence,
  Value<int?> clockCorrectionId,
  Value<int?> effYear,
  Value<int?> effMonth,
  Value<String?> effDay,
  Value<int?> effMinute,
  Value<int?> effWeekday,
  Value<int?> momentId,
});
typedef $MediaMetadataUpdateCompanionBuilder = MediaMetadataCompanion Function({
  Value<int> contentId,
  Value<int?> captureUtcMs,
  Value<String?> captureLocal,
  Value<int?> tzOffsetMin,
  Value<String?> dateSource,
  Value<String?> dateConfidence,
  Value<bool> dateConflict,
  Value<String?> candidatesJson,
  Value<String?> make,
  Value<String?> model,
  Value<String?> lens,
  Value<int?> iso,
  Value<double?> aperture,
  Value<double?> exposureS,
  Value<double?> focalMm,
  Value<int?> width,
  Value<int?> height,
  Value<int?> orientation,
  Value<double?> lat,
  Value<double?> lon,
  Value<int?> durationMs,
  Value<double?> fps,
  Value<String?> videoCodec,
  Value<String?> audioCodec,
  Value<int?> bitrate,
  Value<String?> software,
  Value<String?> extractor,
  Value<int?> extractedAt,
  Value<String?> bodySerial,
  Value<String> metaStatus,
  Value<String?> metaError,
  Value<int?> effUtcMs,
  Value<String?> effLocal,
  Value<int?> effOffsetMin,
  Value<String?> effSource,
  Value<String?> effConfidence,
  Value<int?> clockCorrectionId,
  Value<int?> effYear,
  Value<int?> effMonth,
  Value<String?> effDay,
  Value<int?> effMinute,
  Value<int?> effWeekday,
  Value<int?> momentId,
});

final class $MediaMetadataReferences extends BaseReferences<_$CatalogDatabase, MediaMetadata, MediaMetadataRow> {
  $MediaMetadataReferences(super.$_db, super.$_table, super.$_typedResult);

  static Contents _contentIdTable(_$CatalogDatabase db) =>
      db.contents.createAlias('media_metadata__content_id__contents__id');

  $ContentsProcessedTableManager get contentId {
    final $_column = $_itemColumn<int>('content_id')!;

    final manager = $ContentsTableManager($_db, $_db.contents).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static ClockCorrections _clockCorrectionIdTable(_$CatalogDatabase db) =>
      db.clockCorrections.createAlias('media_metadata__clock_correction_id__clock_corrections__id');

  $ClockCorrectionsProcessedTableManager? get clockCorrectionId {
    final $_column = $_itemColumn<int>('clock_correction_id');
    if ($_column == null) return null;
    final manager = $ClockCorrectionsTableManager($_db, $_db.clockCorrections).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clockCorrectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Moments _momentIdTable(_$CatalogDatabase db) =>
      db.moments.createAlias('media_metadata__moment_id__moments__id');

  $MomentsProcessedTableManager? get momentId {
    final $_column = $_itemColumn<int>('moment_id');
    if ($_column == null) return null;
    final manager = $MomentsTableManager($_db, $_db.moments).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_momentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $MediaMetadataFilterComposer extends Composer<_$CatalogDatabase, MediaMetadata> {
  $MediaMetadataFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get captureUtcMs =>
      $composableBuilder(column: $table.captureUtcMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get captureLocal =>
      $composableBuilder(column: $table.captureLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tzOffsetMin =>
      $composableBuilder(column: $table.tzOffsetMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateSource =>
      $composableBuilder(column: $table.dateSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateConfidence =>
      $composableBuilder(column: $table.dateConfidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dateConflict =>
      $composableBuilder(column: $table.dateConflict, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get candidatesJson =>
      $composableBuilder(column: $table.candidatesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get make => $composableBuilder(column: $table.make, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lens => $composableBuilder(column: $table.lens, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get iso => $composableBuilder(column: $table.iso, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get aperture =>
      $composableBuilder(column: $table.aperture, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get exposureS =>
      $composableBuilder(column: $table.exposureS, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get focalMm =>
      $composableBuilder(column: $table.focalMm, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get width => $composableBuilder(column: $table.width, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orientation =>
      $composableBuilder(column: $table.orientation, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lon => $composableBuilder(column: $table.lon, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fps => $composableBuilder(column: $table.fps, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoCodec =>
      $composableBuilder(column: $table.videoCodec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioCodec =>
      $composableBuilder(column: $table.audioCodec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get software =>
      $composableBuilder(column: $table.software, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extractor =>
      $composableBuilder(column: $table.extractor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get extractedAt =>
      $composableBuilder(column: $table.extractedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodySerial =>
      $composableBuilder(column: $table.bodySerial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metaStatus =>
      $composableBuilder(column: $table.metaStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metaError =>
      $composableBuilder(column: $table.metaError, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get effUtcMs =>
      $composableBuilder(column: $table.effUtcMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get effLocal =>
      $composableBuilder(column: $table.effLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get effOffsetMin =>
      $composableBuilder(column: $table.effOffsetMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get effSource =>
      $composableBuilder(column: $table.effSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get effConfidence =>
      $composableBuilder(column: $table.effConfidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get effYear =>
      $composableBuilder(column: $table.effYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get effMonth =>
      $composableBuilder(column: $table.effMonth, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get effDay =>
      $composableBuilder(column: $table.effDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get effMinute =>
      $composableBuilder(column: $table.effMinute, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get effWeekday =>
      $composableBuilder(column: $table.effWeekday, builder: (column) => ColumnFilters(column));

  $ContentsFilterComposer get contentId {
    final $ContentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsFilterComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ClockCorrectionsFilterComposer get clockCorrectionId {
    final $ClockCorrectionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clockCorrectionId,
      referencedTable: $db.clockCorrections,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ClockCorrectionsFilterComposer(
            $db: $db,
            $table: $db.clockCorrections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MomentsFilterComposer get momentId {
    final $MomentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.momentId,
      referencedTable: $db.moments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MomentsFilterComposer(
            $db: $db,
            $table: $db.moments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MediaMetadataOrderingComposer extends Composer<_$CatalogDatabase, MediaMetadata> {
  $MediaMetadataOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get captureUtcMs =>
      $composableBuilder(column: $table.captureUtcMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get captureLocal =>
      $composableBuilder(column: $table.captureLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tzOffsetMin =>
      $composableBuilder(column: $table.tzOffsetMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateSource =>
      $composableBuilder(column: $table.dateSource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateConfidence =>
      $composableBuilder(column: $table.dateConfidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dateConflict =>
      $composableBuilder(column: $table.dateConflict, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get candidatesJson =>
      $composableBuilder(column: $table.candidatesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lens =>
      $composableBuilder(column: $table.lens, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get iso => $composableBuilder(column: $table.iso, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get aperture =>
      $composableBuilder(column: $table.aperture, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get exposureS =>
      $composableBuilder(column: $table.exposureS, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get focalMm =>
      $composableBuilder(column: $table.focalMm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orientation =>
      $composableBuilder(column: $table.orientation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fps =>
      $composableBuilder(column: $table.fps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoCodec =>
      $composableBuilder(column: $table.videoCodec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioCodec =>
      $composableBuilder(column: $table.audioCodec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get software =>
      $composableBuilder(column: $table.software, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extractor =>
      $composableBuilder(column: $table.extractor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get extractedAt =>
      $composableBuilder(column: $table.extractedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodySerial =>
      $composableBuilder(column: $table.bodySerial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metaStatus =>
      $composableBuilder(column: $table.metaStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metaError =>
      $composableBuilder(column: $table.metaError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get effUtcMs =>
      $composableBuilder(column: $table.effUtcMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get effLocal =>
      $composableBuilder(column: $table.effLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get effOffsetMin =>
      $composableBuilder(column: $table.effOffsetMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get effSource =>
      $composableBuilder(column: $table.effSource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get effConfidence =>
      $composableBuilder(column: $table.effConfidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get effYear =>
      $composableBuilder(column: $table.effYear, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get effMonth =>
      $composableBuilder(column: $table.effMonth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get effDay =>
      $composableBuilder(column: $table.effDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get effMinute =>
      $composableBuilder(column: $table.effMinute, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get effWeekday =>
      $composableBuilder(column: $table.effWeekday, builder: (column) => ColumnOrderings(column));

  $ContentsOrderingComposer get contentId {
    final $ContentsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsOrderingComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ClockCorrectionsOrderingComposer get clockCorrectionId {
    final $ClockCorrectionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clockCorrectionId,
      referencedTable: $db.clockCorrections,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ClockCorrectionsOrderingComposer(
            $db: $db,
            $table: $db.clockCorrections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MomentsOrderingComposer get momentId {
    final $MomentsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.momentId,
      referencedTable: $db.moments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MomentsOrderingComposer(
            $db: $db,
            $table: $db.moments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MediaMetadataAnnotationComposer extends Composer<_$CatalogDatabase, MediaMetadata> {
  $MediaMetadataAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get captureUtcMs => $composableBuilder(column: $table.captureUtcMs, builder: (column) => column);

  GeneratedColumn<String> get captureLocal =>
      $composableBuilder(column: $table.captureLocal, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMin => $composableBuilder(column: $table.tzOffsetMin, builder: (column) => column);

  GeneratedColumn<String> get dateSource => $composableBuilder(column: $table.dateSource, builder: (column) => column);

  GeneratedColumn<String> get dateConfidence =>
      $composableBuilder(column: $table.dateConfidence, builder: (column) => column);

  GeneratedColumn<bool> get dateConflict =>
      $composableBuilder(column: $table.dateConflict, builder: (column) => column);

  GeneratedColumn<String> get candidatesJson =>
      $composableBuilder(column: $table.candidatesJson, builder: (column) => column);

  GeneratedColumn<String> get make => $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model => $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get lens => $composableBuilder(column: $table.lens, builder: (column) => column);

  GeneratedColumn<int> get iso => $composableBuilder(column: $table.iso, builder: (column) => column);

  GeneratedColumn<double> get aperture => $composableBuilder(column: $table.aperture, builder: (column) => column);

  GeneratedColumn<double> get exposureS => $composableBuilder(column: $table.exposureS, builder: (column) => column);

  GeneratedColumn<double> get focalMm => $composableBuilder(column: $table.focalMm, builder: (column) => column);

  GeneratedColumn<int> get width => $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height => $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get orientation => $composableBuilder(column: $table.orientation, builder: (column) => column);

  GeneratedColumn<double> get lat => $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon => $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<double> get fps => $composableBuilder(column: $table.fps, builder: (column) => column);

  GeneratedColumn<String> get videoCodec => $composableBuilder(column: $table.videoCodec, builder: (column) => column);

  GeneratedColumn<String> get audioCodec => $composableBuilder(column: $table.audioCodec, builder: (column) => column);

  GeneratedColumn<int> get bitrate => $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<String> get software => $composableBuilder(column: $table.software, builder: (column) => column);

  GeneratedColumn<String> get extractor => $composableBuilder(column: $table.extractor, builder: (column) => column);

  GeneratedColumn<int> get extractedAt => $composableBuilder(column: $table.extractedAt, builder: (column) => column);

  GeneratedColumn<String> get bodySerial => $composableBuilder(column: $table.bodySerial, builder: (column) => column);

  GeneratedColumn<String> get metaStatus => $composableBuilder(column: $table.metaStatus, builder: (column) => column);

  GeneratedColumn<String> get metaError => $composableBuilder(column: $table.metaError, builder: (column) => column);

  GeneratedColumn<int> get effUtcMs => $composableBuilder(column: $table.effUtcMs, builder: (column) => column);

  GeneratedColumn<String> get effLocal => $composableBuilder(column: $table.effLocal, builder: (column) => column);

  GeneratedColumn<int> get effOffsetMin => $composableBuilder(column: $table.effOffsetMin, builder: (column) => column);

  GeneratedColumn<String> get effSource => $composableBuilder(column: $table.effSource, builder: (column) => column);

  GeneratedColumn<String> get effConfidence =>
      $composableBuilder(column: $table.effConfidence, builder: (column) => column);

  GeneratedColumn<int> get effYear => $composableBuilder(column: $table.effYear, builder: (column) => column);

  GeneratedColumn<int> get effMonth => $composableBuilder(column: $table.effMonth, builder: (column) => column);

  GeneratedColumn<String> get effDay => $composableBuilder(column: $table.effDay, builder: (column) => column);

  GeneratedColumn<int> get effMinute => $composableBuilder(column: $table.effMinute, builder: (column) => column);

  GeneratedColumn<int> get effWeekday => $composableBuilder(column: $table.effWeekday, builder: (column) => column);

  $ContentsAnnotationComposer get contentId {
    final $ContentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsAnnotationComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ClockCorrectionsAnnotationComposer get clockCorrectionId {
    final $ClockCorrectionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clockCorrectionId,
      referencedTable: $db.clockCorrections,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ClockCorrectionsAnnotationComposer(
            $db: $db,
            $table: $db.clockCorrections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MomentsAnnotationComposer get momentId {
    final $MomentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.momentId,
      referencedTable: $db.moments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $MomentsAnnotationComposer(
            $db: $db,
            $table: $db.moments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MediaMetadataTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          MediaMetadata,
          MediaMetadataRow,
          $MediaMetadataFilterComposer,
          $MediaMetadataOrderingComposer,
          $MediaMetadataAnnotationComposer,
          $MediaMetadataCreateCompanionBuilder,
          $MediaMetadataUpdateCompanionBuilder,
          (MediaMetadataRow, $MediaMetadataReferences),
          MediaMetadataRow,
          PrefetchHooks Function({bool contentId, bool clockCorrectionId, bool momentId})
        > {
  $MediaMetadataTableManager(_$CatalogDatabase db, MediaMetadata table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $MediaMetadataFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $MediaMetadataOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $MediaMetadataAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> contentId = const Value.absent(),
                Value<int?> captureUtcMs = const Value.absent(),
                Value<String?> captureLocal = const Value.absent(),
                Value<int?> tzOffsetMin = const Value.absent(),
                Value<String?> dateSource = const Value.absent(),
                Value<String?> dateConfidence = const Value.absent(),
                Value<bool> dateConflict = const Value.absent(),
                Value<String?> candidatesJson = const Value.absent(),
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> lens = const Value.absent(),
                Value<int?> iso = const Value.absent(),
                Value<double?> aperture = const Value.absent(),
                Value<double?> exposureS = const Value.absent(),
                Value<double?> focalMm = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> orientation = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<double?> fps = const Value.absent(),
                Value<String?> videoCodec = const Value.absent(),
                Value<String?> audioCodec = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<String?> software = const Value.absent(),
                Value<String?> extractor = const Value.absent(),
                Value<int?> extractedAt = const Value.absent(),
                Value<String?> bodySerial = const Value.absent(),
                Value<String> metaStatus = const Value.absent(),
                Value<String?> metaError = const Value.absent(),
                Value<int?> effUtcMs = const Value.absent(),
                Value<String?> effLocal = const Value.absent(),
                Value<int?> effOffsetMin = const Value.absent(),
                Value<String?> effSource = const Value.absent(),
                Value<String?> effConfidence = const Value.absent(),
                Value<int?> clockCorrectionId = const Value.absent(),
                Value<int?> effYear = const Value.absent(),
                Value<int?> effMonth = const Value.absent(),
                Value<String?> effDay = const Value.absent(),
                Value<int?> effMinute = const Value.absent(),
                Value<int?> effWeekday = const Value.absent(),
                Value<int?> momentId = const Value.absent(),
              }) => MediaMetadataCompanion(
                contentId: contentId,
                captureUtcMs: captureUtcMs,
                captureLocal: captureLocal,
                tzOffsetMin: tzOffsetMin,
                dateSource: dateSource,
                dateConfidence: dateConfidence,
                dateConflict: dateConflict,
                candidatesJson: candidatesJson,
                make: make,
                model: model,
                lens: lens,
                iso: iso,
                aperture: aperture,
                exposureS: exposureS,
                focalMm: focalMm,
                width: width,
                height: height,
                orientation: orientation,
                lat: lat,
                lon: lon,
                durationMs: durationMs,
                fps: fps,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                bitrate: bitrate,
                software: software,
                extractor: extractor,
                extractedAt: extractedAt,
                bodySerial: bodySerial,
                metaStatus: metaStatus,
                metaError: metaError,
                effUtcMs: effUtcMs,
                effLocal: effLocal,
                effOffsetMin: effOffsetMin,
                effSource: effSource,
                effConfidence: effConfidence,
                clockCorrectionId: clockCorrectionId,
                effYear: effYear,
                effMonth: effMonth,
                effDay: effDay,
                effMinute: effMinute,
                effWeekday: effWeekday,
                momentId: momentId,
              ),
          createCompanionCallback:
              ({
                Value<int> contentId = const Value.absent(),
                Value<int?> captureUtcMs = const Value.absent(),
                Value<String?> captureLocal = const Value.absent(),
                Value<int?> tzOffsetMin = const Value.absent(),
                Value<String?> dateSource = const Value.absent(),
                Value<String?> dateConfidence = const Value.absent(),
                Value<bool> dateConflict = const Value.absent(),
                Value<String?> candidatesJson = const Value.absent(),
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> lens = const Value.absent(),
                Value<int?> iso = const Value.absent(),
                Value<double?> aperture = const Value.absent(),
                Value<double?> exposureS = const Value.absent(),
                Value<double?> focalMm = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> orientation = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<double?> fps = const Value.absent(),
                Value<String?> videoCodec = const Value.absent(),
                Value<String?> audioCodec = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<String?> software = const Value.absent(),
                Value<String?> extractor = const Value.absent(),
                Value<int?> extractedAt = const Value.absent(),
                Value<String?> bodySerial = const Value.absent(),
                Value<String> metaStatus = const Value.absent(),
                Value<String?> metaError = const Value.absent(),
                Value<int?> effUtcMs = const Value.absent(),
                Value<String?> effLocal = const Value.absent(),
                Value<int?> effOffsetMin = const Value.absent(),
                Value<String?> effSource = const Value.absent(),
                Value<String?> effConfidence = const Value.absent(),
                Value<int?> clockCorrectionId = const Value.absent(),
                Value<int?> effYear = const Value.absent(),
                Value<int?> effMonth = const Value.absent(),
                Value<String?> effDay = const Value.absent(),
                Value<int?> effMinute = const Value.absent(),
                Value<int?> effWeekday = const Value.absent(),
                Value<int?> momentId = const Value.absent(),
              }) => MediaMetadataCompanion.insert(
                contentId: contentId,
                captureUtcMs: captureUtcMs,
                captureLocal: captureLocal,
                tzOffsetMin: tzOffsetMin,
                dateSource: dateSource,
                dateConfidence: dateConfidence,
                dateConflict: dateConflict,
                candidatesJson: candidatesJson,
                make: make,
                model: model,
                lens: lens,
                iso: iso,
                aperture: aperture,
                exposureS: exposureS,
                focalMm: focalMm,
                width: width,
                height: height,
                orientation: orientation,
                lat: lat,
                lon: lon,
                durationMs: durationMs,
                fps: fps,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                bitrate: bitrate,
                software: software,
                extractor: extractor,
                extractedAt: extractedAt,
                bodySerial: bodySerial,
                metaStatus: metaStatus,
                metaError: metaError,
                effUtcMs: effUtcMs,
                effLocal: effLocal,
                effOffsetMin: effOffsetMin,
                effSource: effSource,
                effConfidence: effConfidence,
                clockCorrectionId: clockCorrectionId,
                effYear: effYear,
                effMonth: effMonth,
                effDay: effDay,
                effMinute: effMinute,
                effWeekday: effWeekday,
                momentId: momentId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<MediaMetadata, MediaMetadataRow>(table), $MediaMetadataReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({contentId = false, clockCorrectionId = false, momentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (contentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.contentId,
                        referencedTable: $MediaMetadataReferences._contentIdTable(db),
                        referencedColumn: $MediaMetadataReferences._contentIdTable(db).id,
                      ) as T;
                    }
                    if (clockCorrectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.clockCorrectionId,
                        referencedTable: $MediaMetadataReferences._clockCorrectionIdTable(db),
                        referencedColumn: $MediaMetadataReferences._clockCorrectionIdTable(db).id,
                      ) as T;
                    }
                    if (momentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.momentId,
                        referencedTable: $MediaMetadataReferences._momentIdTable(db),
                        referencedColumn: $MediaMetadataReferences._momentIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $MediaMetadataProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      MediaMetadata,
      MediaMetadataRow,
      $MediaMetadataFilterComposer,
      $MediaMetadataOrderingComposer,
      $MediaMetadataAnnotationComposer,
      $MediaMetadataCreateCompanionBuilder,
      $MediaMetadataUpdateCompanionBuilder,
      (MediaMetadataRow, $MediaMetadataReferences),
      MediaMetadataRow,
      PrefetchHooks Function({bool contentId, bool clockCorrectionId, bool momentId})
    >;
typedef $DateCorrectionsCreateCompanionBuilder = DateCorrectionsCompanion Function({
  Value<int> id,
  required int contentId,
  required String captureLocal,
  Value<int?> tzOffsetMin,
  Value<String?> note,
  required int createdAt,
  Value<int?> supersededAt,
});
typedef $DateCorrectionsUpdateCompanionBuilder = DateCorrectionsCompanion Function({
  Value<int> id,
  Value<int> contentId,
  Value<String> captureLocal,
  Value<int?> tzOffsetMin,
  Value<String?> note,
  Value<int> createdAt,
  Value<int?> supersededAt,
});

final class $DateCorrectionsReferences extends BaseReferences<_$CatalogDatabase, DateCorrections, DateCorrectionRow> {
  $DateCorrectionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Contents _contentIdTable(_$CatalogDatabase db) =>
      db.contents.createAlias('date_corrections__content_id__contents__id');

  $ContentsProcessedTableManager get contentId {
    final $_column = $_itemColumn<int>('content_id')!;

    final manager = $ContentsTableManager($_db, $_db.contents).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $DateCorrectionsFilterComposer extends Composer<_$CatalogDatabase, DateCorrections> {
  $DateCorrectionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get captureLocal =>
      $composableBuilder(column: $table.captureLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tzOffsetMin =>
      $composableBuilder(column: $table.tzOffsetMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get supersededAt =>
      $composableBuilder(column: $table.supersededAt, builder: (column) => ColumnFilters(column));

  $ContentsFilterComposer get contentId {
    final $ContentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsFilterComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DateCorrectionsOrderingComposer extends Composer<_$CatalogDatabase, DateCorrections> {
  $DateCorrectionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get captureLocal =>
      $composableBuilder(column: $table.captureLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tzOffsetMin =>
      $composableBuilder(column: $table.tzOffsetMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get supersededAt =>
      $composableBuilder(column: $table.supersededAt, builder: (column) => ColumnOrderings(column));

  $ContentsOrderingComposer get contentId {
    final $ContentsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsOrderingComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DateCorrectionsAnnotationComposer extends Composer<_$CatalogDatabase, DateCorrections> {
  $DateCorrectionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get captureLocal =>
      $composableBuilder(column: $table.captureLocal, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMin => $composableBuilder(column: $table.tzOffsetMin, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get supersededAt => $composableBuilder(column: $table.supersededAt, builder: (column) => column);

  $ContentsAnnotationComposer get contentId {
    final $ContentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsAnnotationComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DateCorrectionsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          DateCorrections,
          DateCorrectionRow,
          $DateCorrectionsFilterComposer,
          $DateCorrectionsOrderingComposer,
          $DateCorrectionsAnnotationComposer,
          $DateCorrectionsCreateCompanionBuilder,
          $DateCorrectionsUpdateCompanionBuilder,
          (DateCorrectionRow, $DateCorrectionsReferences),
          DateCorrectionRow,
          PrefetchHooks Function({bool contentId})
        > {
  $DateCorrectionsTableManager(_$CatalogDatabase db, DateCorrections table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $DateCorrectionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $DateCorrectionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $DateCorrectionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> contentId = const Value.absent(),
                Value<String> captureLocal = const Value.absent(),
                Value<int?> tzOffsetMin = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> supersededAt = const Value.absent(),
              }) => DateCorrectionsCompanion(
                id: id,
                contentId: contentId,
                captureLocal: captureLocal,
                tzOffsetMin: tzOffsetMin,
                note: note,
                createdAt: createdAt,
                supersededAt: supersededAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int contentId,
                required String captureLocal,
                Value<int?> tzOffsetMin = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAt,
                Value<int?> supersededAt = const Value.absent(),
              }) => DateCorrectionsCompanion.insert(
                id: id,
                contentId: contentId,
                captureLocal: captureLocal,
                tzOffsetMin: tzOffsetMin,
                note: note,
                createdAt: createdAt,
                supersededAt: supersededAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<DateCorrections, DateCorrectionRow>(table), $DateCorrectionsReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({contentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (contentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.contentId,
                        referencedTable: $DateCorrectionsReferences._contentIdTable(db),
                        referencedColumn: $DateCorrectionsReferences._contentIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DateCorrectionsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      DateCorrections,
      DateCorrectionRow,
      $DateCorrectionsFilterComposer,
      $DateCorrectionsOrderingComposer,
      $DateCorrectionsAnnotationComposer,
      $DateCorrectionsCreateCompanionBuilder,
      $DateCorrectionsUpdateCompanionBuilder,
      (DateCorrectionRow, $DateCorrectionsReferences),
      DateCorrectionRow,
      PrefetchHooks Function({bool contentId})
    >;
typedef $OperationsCreateCompanionBuilder = OperationsCompanion Function({
  required String id,
  required String kind,
  required String status,
  Value<String?> destSourceId,
  Value<String?> destRootRel,
  Value<String?> template,
  Value<String?> conflictPolicy,
  Value<String?> paramsJson,
  Value<String?> summaryJson,
  Value<String?> undoOf,
  required int createdAt,
  Value<int?> confirmedAt,
  Value<int?> startedAt,
  Value<int?> finishedAt,
  Value<int> rowid,
});
typedef $OperationsUpdateCompanionBuilder = OperationsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> status,
  Value<String?> destSourceId,
  Value<String?> destRootRel,
  Value<String?> template,
  Value<String?> conflictPolicy,
  Value<String?> paramsJson,
  Value<String?> summaryJson,
  Value<String?> undoOf,
  Value<int> createdAt,
  Value<int?> confirmedAt,
  Value<int?> startedAt,
  Value<int?> finishedAt,
  Value<int> rowid,
});

final class $OperationsReferences extends BaseReferences<_$CatalogDatabase, Operations, OperationRow> {
  $OperationsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Sources _destSourceIdTable(_$CatalogDatabase db) =>
      db.sources.createAlias('operations__dest_source_id__sources__id');

  $SourcesProcessedTableManager? get destSourceId {
    final $_column = $_itemColumn<String>('dest_source_id');
    if ($_column == null) return null;
    final manager = $SourcesTableManager($_db, $_db.sources).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_destSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Operations _undoOfTable(_$CatalogDatabase db) =>
      db.operations.createAlias('operations__undo_of__operations__id');

  $OperationsProcessedTableManager? get undoOf {
    final $_column = $_itemColumn<String>('undo_of');
    if ($_column == null) return null;
    final manager = $OperationsTableManager($_db, $_db.operations).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_undoOfTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<OperationItems, List<OperationItemRow>> _operationItemsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.operationItems, aliasName: 'operations__id__operation_items__operation_id');

  $OperationItemsProcessedTableManager get operationItemsRefs {
    final manager = $OperationItemsTableManager(
      $_db,
      $_db.operationItems,
    ).filter((f) => f.operationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationItemsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<OperationEvents, List<OperationEventRow>> _operationEventsRefsTable(
    _$CatalogDatabase db,
  ) => MultiTypedResultKey.fromTable(db.operationEvents, aliasName: 'operations__id__operation_events__operation_id');

  $OperationEventsProcessedTableManager get operationEventsRefs {
    final manager = $OperationEventsTableManager(
      $_db,
      $_db.operationEvents,
    ).filter((f) => f.operationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationEventsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<IntegrityChecks, List<IntegrityCheckRow>> _integrityChecksRefsTable(
    _$CatalogDatabase db,
  ) => MultiTypedResultKey.fromTable(db.integrityChecks, aliasName: 'operations__id__integrity_checks__operation_id');

  $IntegrityChecksProcessedTableManager get integrityChecksRefs {
    final manager = $IntegrityChecksTableManager(
      $_db,
      $_db.integrityChecks,
    ).filter((f) => f.operationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_integrityChecksRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $OperationsFilterComposer extends Composer<_$CatalogDatabase, Operations> {
  $OperationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get destRootRel =>
      $composableBuilder(column: $table.destRootRel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conflictPolicy =>
      $composableBuilder(column: $table.conflictPolicy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paramsJson =>
      $composableBuilder(column: $table.paramsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summaryJson =>
      $composableBuilder(column: $table.summaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get confirmedAt =>
      $composableBuilder(column: $table.confirmedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => ColumnFilters(column));

  $SourcesFilterComposer get destSourceId {
    final $SourcesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationsFilterComposer get undoOf {
    final $OperationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.undoOf,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> operationItemsRefs(Expression<bool> Function($OperationItemsFilterComposer f) f) {
    final $OperationItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.operationId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsFilterComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> operationEventsRefs(Expression<bool> Function($OperationEventsFilterComposer f) f) {
    final $OperationEventsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationEvents,
      getReferencedColumn: (t) => t.operationId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationEventsFilterComposer(
            $db: $db,
            $table: $db.operationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> integrityChecksRefs(Expression<bool> Function($IntegrityChecksFilterComposer f) f) {
    final $IntegrityChecksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.integrityChecks,
      getReferencedColumn: (t) => t.operationId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $IntegrityChecksFilterComposer(
            $db: $db,
            $table: $db.integrityChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $OperationsOrderingComposer extends Composer<_$CatalogDatabase, Operations> {
  $OperationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get destRootRel =>
      $composableBuilder(column: $table.destRootRel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conflictPolicy =>
      $composableBuilder(column: $table.conflictPolicy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paramsJson =>
      $composableBuilder(column: $table.paramsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summaryJson =>
      $composableBuilder(column: $table.summaryJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get confirmedAt =>
      $composableBuilder(column: $table.confirmedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => ColumnOrderings(column));

  $SourcesOrderingComposer get destSourceId {
    final $SourcesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationsOrderingComposer get undoOf {
    final $OperationsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.undoOf,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsOrderingComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OperationsAnnotationComposer extends Composer<_$CatalogDatabase, Operations> {
  $OperationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status => $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get destRootRel =>
      $composableBuilder(column: $table.destRootRel, builder: (column) => column);

  GeneratedColumn<String> get template => $composableBuilder(column: $table.template, builder: (column) => column);

  GeneratedColumn<String> get conflictPolicy =>
      $composableBuilder(column: $table.conflictPolicy, builder: (column) => column);

  GeneratedColumn<String> get paramsJson => $composableBuilder(column: $table.paramsJson, builder: (column) => column);

  GeneratedColumn<String> get summaryJson =>
      $composableBuilder(column: $table.summaryJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get confirmedAt => $composableBuilder(column: $table.confirmedAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(column: $table.finishedAt, builder: (column) => column);

  $SourcesAnnotationComposer get destSourceId {
    final $SourcesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationsAnnotationComposer get undoOf {
    final $OperationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.undoOf,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> operationItemsRefs<T extends Object>(Expression<T> Function($OperationItemsAnnotationComposer a) f) {
    final $OperationItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.operationId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsAnnotationComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> operationEventsRefs<T extends Object>(Expression<T> Function($OperationEventsAnnotationComposer a) f) {
    final $OperationEventsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationEvents,
      getReferencedColumn: (t) => t.operationId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationEventsAnnotationComposer(
            $db: $db,
            $table: $db.operationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> integrityChecksRefs<T extends Object>(Expression<T> Function($IntegrityChecksAnnotationComposer a) f) {
    final $IntegrityChecksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.integrityChecks,
      getReferencedColumn: (t) => t.operationId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $IntegrityChecksAnnotationComposer(
            $db: $db,
            $table: $db.integrityChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $OperationsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Operations,
          OperationRow,
          $OperationsFilterComposer,
          $OperationsOrderingComposer,
          $OperationsAnnotationComposer,
          $OperationsCreateCompanionBuilder,
          $OperationsUpdateCompanionBuilder,
          (OperationRow, $OperationsReferences),
          OperationRow,
          PrefetchHooks Function({
            bool destSourceId,
            bool undoOf,
            bool operationItemsRefs,
            bool operationEventsRefs,
            bool integrityChecksRefs,
          })
        > {
  $OperationsTableManager(_$CatalogDatabase db, Operations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $OperationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $OperationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $OperationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> destSourceId = const Value.absent(),
                Value<String?> destRootRel = const Value.absent(),
                Value<String?> template = const Value.absent(),
                Value<String?> conflictPolicy = const Value.absent(),
                Value<String?> paramsJson = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> undoOf = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> confirmedAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion(
                id: id,
                kind: kind,
                status: status,
                destSourceId: destSourceId,
                destRootRel: destRootRel,
                template: template,
                conflictPolicy: conflictPolicy,
                paramsJson: paramsJson,
                summaryJson: summaryJson,
                undoOf: undoOf,
                createdAt: createdAt,
                confirmedAt: confirmedAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String status,
                Value<String?> destSourceId = const Value.absent(),
                Value<String?> destRootRel = const Value.absent(),
                Value<String?> template = const Value.absent(),
                Value<String?> conflictPolicy = const Value.absent(),
                Value<String?> paramsJson = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> undoOf = const Value.absent(),
                required int createdAt,
                Value<int?> confirmedAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion.insert(
                id: id,
                kind: kind,
                status: status,
                destSourceId: destSourceId,
                destRootRel: destRootRel,
                template: template,
                conflictPolicy: conflictPolicy,
                paramsJson: paramsJson,
                summaryJson: summaryJson,
                undoOf: undoOf,
                createdAt: createdAt,
                confirmedAt: confirmedAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<Operations, OperationRow>(table), $OperationsReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback:
              ({
                destSourceId = false,
                undoOf = false,
                operationItemsRefs = false,
                operationEventsRefs = false,
                integrityChecksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (operationItemsRefs) db.operationItems,
                    if (operationEventsRefs) db.operationEvents,
                    if (integrityChecksRefs) db.integrityChecks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (destSourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.destSourceId,
                            referencedTable: $OperationsReferences._destSourceIdTable(db),
                            referencedColumn: $OperationsReferences._destSourceIdTable(db).id,
                          ) as T;
                        }
                        if (undoOf) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.undoOf,
                            referencedTable: $OperationsReferences._undoOfTable(db),
                            referencedColumn: $OperationsReferences._undoOfTable(db).id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (operationItemsRefs)
                        await $_getPrefetchedDataByColumns<OperationRow, Operations, OperationItemRow, OperationItems>(
                          currentTable: table,
                          referencedTable: $OperationsReferences._operationItemsRefsTable(db),
                          managerFromTypedResult: (p0) => $OperationsReferences(db, table, p0).operationItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'operation_id',
                          typedResults: items,
                        ),
                      if (operationEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          OperationRow,
                          Operations,
                          OperationEventRow,
                          OperationEvents
                        >(
                          currentTable: table,
                          referencedTable: $OperationsReferences._operationEventsRefsTable(db),
                          managerFromTypedResult: (p0) => $OperationsReferences(db, table, p0).operationEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'operation_id',
                          typedResults: items,
                        ),
                      if (integrityChecksRefs)
                        await $_getPrefetchedDataByColumns<
                          OperationRow,
                          Operations,
                          IntegrityCheckRow,
                          IntegrityChecks
                        >(
                          currentTable: table,
                          referencedTable: $OperationsReferences._integrityChecksRefsTable(db),
                          managerFromTypedResult: (p0) => $OperationsReferences(db, table, p0).integrityChecksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'operation_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $OperationsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Operations,
      OperationRow,
      $OperationsFilterComposer,
      $OperationsOrderingComposer,
      $OperationsAnnotationComposer,
      $OperationsCreateCompanionBuilder,
      $OperationsUpdateCompanionBuilder,
      (OperationRow, $OperationsReferences),
      OperationRow,
      PrefetchHooks Function({
        bool destSourceId,
        bool undoOf,
        bool operationItemsRefs,
        bool operationEventsRefs,
        bool integrityChecksRefs,
      })
    >;
typedef $OperationItemsCreateCompanionBuilder = OperationItemsCompanion Function({
  Value<int> id,
  required String operationId,
  required int seq,
  required String srcSourceId,
  required String srcRelPath,
  Value<int?> srcInstanceId,
  required int expectedSize,
  Value<Uint8List?> expectedSha256,
  required String dstSourceId,
  required String dstRelPathPlanned,
  Value<String?> dstRelPathFinal,
  Value<String?> tmpRelPath,
  Value<String?> originalName,
  required String state,
  Value<Uint8List?> srcSha256,
  Value<Uint8List?> dstSha256,
  Value<int> bytesCopied,
  Value<int> attempts,
  Value<String?> lastErrorCode,
  Value<String?> lastErrorMessage,
  required int updatedAt,
  Value<int?> expectedMtime,
  Value<int?> undoOfItemId,
});
typedef $OperationItemsUpdateCompanionBuilder = OperationItemsCompanion Function({
  Value<int> id,
  Value<String> operationId,
  Value<int> seq,
  Value<String> srcSourceId,
  Value<String> srcRelPath,
  Value<int?> srcInstanceId,
  Value<int> expectedSize,
  Value<Uint8List?> expectedSha256,
  Value<String> dstSourceId,
  Value<String> dstRelPathPlanned,
  Value<String?> dstRelPathFinal,
  Value<String?> tmpRelPath,
  Value<String?> originalName,
  Value<String> state,
  Value<Uint8List?> srcSha256,
  Value<Uint8List?> dstSha256,
  Value<int> bytesCopied,
  Value<int> attempts,
  Value<String?> lastErrorCode,
  Value<String?> lastErrorMessage,
  Value<int> updatedAt,
  Value<int?> expectedMtime,
  Value<int?> undoOfItemId,
});

final class $OperationItemsReferences extends BaseReferences<_$CatalogDatabase, OperationItems, OperationItemRow> {
  $OperationItemsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Operations _operationIdTable(_$CatalogDatabase db) =>
      db.operations.createAlias('operation_items__operation_id__operations__id');

  $OperationsProcessedTableManager get operationId {
    final $_column = $_itemColumn<String>('operation_id')!;

    final manager = $OperationsTableManager($_db, $_db.operations).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_operationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Sources _srcSourceIdTable(_$CatalogDatabase db) =>
      db.sources.createAlias('operation_items__src_source_id__sources__id');

  $SourcesProcessedTableManager get srcSourceId {
    final $_column = $_itemColumn<String>('src_source_id')!;

    final manager = $SourcesTableManager($_db, $_db.sources).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_srcSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static FileInstances _srcInstanceIdTable(_$CatalogDatabase db) =>
      db.fileInstances.createAlias('operation_items__src_instance_id__file_instances__id');

  $FileInstancesProcessedTableManager? get srcInstanceId {
    final $_column = $_itemColumn<int>('src_instance_id');
    if ($_column == null) return null;
    final manager = $FileInstancesTableManager($_db, $_db.fileInstances).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_srcInstanceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Sources _dstSourceIdTable(_$CatalogDatabase db) =>
      db.sources.createAlias('operation_items__dst_source_id__sources__id');

  $SourcesProcessedTableManager get dstSourceId {
    final $_column = $_itemColumn<String>('dst_source_id')!;

    final manager = $SourcesTableManager($_db, $_db.sources).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dstSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static OperationItems _undoOfItemIdTable(_$CatalogDatabase db) =>
      db.operationItems.createAlias('operation_items__undo_of_item_id__operation_items__id');

  $OperationItemsProcessedTableManager? get undoOfItemId {
    final $_column = $_itemColumn<int>('undo_of_item_id');
    if ($_column == null) return null;
    final manager = $OperationItemsTableManager($_db, $_db.operationItems).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_undoOfItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<OperationEvents, List<OperationEventRow>> _operationEventsRefsTable(
    _$CatalogDatabase db,
  ) => MultiTypedResultKey.fromTable(db.operationEvents, aliasName: 'operation_items__id__operation_events__item_id');

  $OperationEventsProcessedTableManager get operationEventsRefs {
    final manager = $OperationEventsTableManager(
      $_db,
      $_db.operationEvents,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationEventsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $OperationItemsFilterComposer extends Composer<_$CatalogDatabase, OperationItems> {
  $OperationItemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get srcRelPath =>
      $composableBuilder(column: $table.srcRelPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get expectedSize =>
      $composableBuilder(column: $table.expectedSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get expectedSha256 =>
      $composableBuilder(column: $table.expectedSha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dstRelPathPlanned =>
      $composableBuilder(column: $table.dstRelPathPlanned, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dstRelPathFinal =>
      $composableBuilder(column: $table.dstRelPathFinal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tmpRelPath =>
      $composableBuilder(column: $table.tmpRelPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalName =>
      $composableBuilder(column: $table.originalName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get srcSha256 =>
      $composableBuilder(column: $table.srcSha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get dstSha256 =>
      $composableBuilder(column: $table.dstSha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bytesCopied =>
      $composableBuilder(column: $table.bytesCopied, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastErrorCode =>
      $composableBuilder(column: $table.lastErrorCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastErrorMessage =>
      $composableBuilder(column: $table.lastErrorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get expectedMtime =>
      $composableBuilder(column: $table.expectedMtime, builder: (column) => ColumnFilters(column));

  $OperationsFilterComposer get operationId {
    final $OperationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $SourcesFilterComposer get srcSourceId {
    final $SourcesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $FileInstancesFilterComposer get srcInstanceId {
    final $FileInstancesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcInstanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesFilterComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $SourcesFilterComposer get dstSourceId {
    final $SourcesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dstSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationItemsFilterComposer get undoOfItemId {
    final $OperationItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.undoOfItemId,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsFilterComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> operationEventsRefs(Expression<bool> Function($OperationEventsFilterComposer f) f) {
    final $OperationEventsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationEvents,
      getReferencedColumn: (t) => t.itemId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationEventsFilterComposer(
            $db: $db,
            $table: $db.operationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $OperationItemsOrderingComposer extends Composer<_$CatalogDatabase, OperationItems> {
  $OperationItemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get srcRelPath =>
      $composableBuilder(column: $table.srcRelPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get expectedSize =>
      $composableBuilder(column: $table.expectedSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get expectedSha256 =>
      $composableBuilder(column: $table.expectedSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dstRelPathPlanned =>
      $composableBuilder(column: $table.dstRelPathPlanned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dstRelPathFinal =>
      $composableBuilder(column: $table.dstRelPathFinal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tmpRelPath =>
      $composableBuilder(column: $table.tmpRelPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalName =>
      $composableBuilder(column: $table.originalName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get srcSha256 =>
      $composableBuilder(column: $table.srcSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get dstSha256 =>
      $composableBuilder(column: $table.dstSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bytesCopied =>
      $composableBuilder(column: $table.bytesCopied, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastErrorCode =>
      $composableBuilder(column: $table.lastErrorCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastErrorMessage =>
      $composableBuilder(column: $table.lastErrorMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get expectedMtime =>
      $composableBuilder(column: $table.expectedMtime, builder: (column) => ColumnOrderings(column));

  $OperationsOrderingComposer get operationId {
    final $OperationsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsOrderingComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $SourcesOrderingComposer get srcSourceId {
    final $SourcesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $FileInstancesOrderingComposer get srcInstanceId {
    final $FileInstancesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcInstanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesOrderingComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $SourcesOrderingComposer get dstSourceId {
    final $SourcesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dstSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationItemsOrderingComposer get undoOfItemId {
    final $OperationItemsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.undoOfItemId,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsOrderingComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OperationItemsAnnotationComposer extends Composer<_$CatalogDatabase, OperationItems> {
  $OperationItemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get srcRelPath => $composableBuilder(column: $table.srcRelPath, builder: (column) => column);

  GeneratedColumn<int> get expectedSize => $composableBuilder(column: $table.expectedSize, builder: (column) => column);

  GeneratedColumn<Uint8List> get expectedSha256 =>
      $composableBuilder(column: $table.expectedSha256, builder: (column) => column);

  GeneratedColumn<String> get dstRelPathPlanned =>
      $composableBuilder(column: $table.dstRelPathPlanned, builder: (column) => column);

  GeneratedColumn<String> get dstRelPathFinal =>
      $composableBuilder(column: $table.dstRelPathFinal, builder: (column) => column);

  GeneratedColumn<String> get tmpRelPath => $composableBuilder(column: $table.tmpRelPath, builder: (column) => column);

  GeneratedColumn<String> get originalName =>
      $composableBuilder(column: $table.originalName, builder: (column) => column);

  GeneratedColumn<String> get state => $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<Uint8List> get srcSha256 => $composableBuilder(column: $table.srcSha256, builder: (column) => column);

  GeneratedColumn<Uint8List> get dstSha256 => $composableBuilder(column: $table.dstSha256, builder: (column) => column);

  GeneratedColumn<int> get bytesCopied => $composableBuilder(column: $table.bytesCopied, builder: (column) => column);

  GeneratedColumn<int> get attempts => $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastErrorCode =>
      $composableBuilder(column: $table.lastErrorCode, builder: (column) => column);

  GeneratedColumn<String> get lastErrorMessage =>
      $composableBuilder(column: $table.lastErrorMessage, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get expectedMtime =>
      $composableBuilder(column: $table.expectedMtime, builder: (column) => column);

  $OperationsAnnotationComposer get operationId {
    final $OperationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $SourcesAnnotationComposer get srcSourceId {
    final $SourcesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $FileInstancesAnnotationComposer get srcInstanceId {
    final $FileInstancesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcInstanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesAnnotationComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $SourcesAnnotationComposer get dstSourceId {
    final $SourcesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dstSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SourcesAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationItemsAnnotationComposer get undoOfItemId {
    final $OperationItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.undoOfItemId,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsAnnotationComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> operationEventsRefs<T extends Object>(Expression<T> Function($OperationEventsAnnotationComposer a) f) {
    final $OperationEventsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operationEvents,
      getReferencedColumn: (t) => t.itemId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationEventsAnnotationComposer(
            $db: $db,
            $table: $db.operationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $OperationItemsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          OperationItems,
          OperationItemRow,
          $OperationItemsFilterComposer,
          $OperationItemsOrderingComposer,
          $OperationItemsAnnotationComposer,
          $OperationItemsCreateCompanionBuilder,
          $OperationItemsUpdateCompanionBuilder,
          (OperationItemRow, $OperationItemsReferences),
          OperationItemRow,
          PrefetchHooks Function({
            bool operationId,
            bool srcSourceId,
            bool srcInstanceId,
            bool dstSourceId,
            bool undoOfItemId,
            bool operationEventsRefs,
          })
        > {
  $OperationItemsTableManager(_$CatalogDatabase db, OperationItems table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $OperationItemsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $OperationItemsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $OperationItemsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> srcSourceId = const Value.absent(),
                Value<String> srcRelPath = const Value.absent(),
                Value<int?> srcInstanceId = const Value.absent(),
                Value<int> expectedSize = const Value.absent(),
                Value<Uint8List?> expectedSha256 = const Value.absent(),
                Value<String> dstSourceId = const Value.absent(),
                Value<String> dstRelPathPlanned = const Value.absent(),
                Value<String?> dstRelPathFinal = const Value.absent(),
                Value<String?> tmpRelPath = const Value.absent(),
                Value<String?> originalName = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<Uint8List?> srcSha256 = const Value.absent(),
                Value<Uint8List?> dstSha256 = const Value.absent(),
                Value<int> bytesCopied = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> expectedMtime = const Value.absent(),
                Value<int?> undoOfItemId = const Value.absent(),
              }) => OperationItemsCompanion(
                id: id,
                operationId: operationId,
                seq: seq,
                srcSourceId: srcSourceId,
                srcRelPath: srcRelPath,
                srcInstanceId: srcInstanceId,
                expectedSize: expectedSize,
                expectedSha256: expectedSha256,
                dstSourceId: dstSourceId,
                dstRelPathPlanned: dstRelPathPlanned,
                dstRelPathFinal: dstRelPathFinal,
                tmpRelPath: tmpRelPath,
                originalName: originalName,
                state: state,
                srcSha256: srcSha256,
                dstSha256: dstSha256,
                bytesCopied: bytesCopied,
                attempts: attempts,
                lastErrorCode: lastErrorCode,
                lastErrorMessage: lastErrorMessage,
                updatedAt: updatedAt,
                expectedMtime: expectedMtime,
                undoOfItemId: undoOfItemId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationId,
                required int seq,
                required String srcSourceId,
                required String srcRelPath,
                Value<int?> srcInstanceId = const Value.absent(),
                required int expectedSize,
                Value<Uint8List?> expectedSha256 = const Value.absent(),
                required String dstSourceId,
                required String dstRelPathPlanned,
                Value<String?> dstRelPathFinal = const Value.absent(),
                Value<String?> tmpRelPath = const Value.absent(),
                Value<String?> originalName = const Value.absent(),
                required String state,
                Value<Uint8List?> srcSha256 = const Value.absent(),
                Value<Uint8List?> dstSha256 = const Value.absent(),
                Value<int> bytesCopied = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                required int updatedAt,
                Value<int?> expectedMtime = const Value.absent(),
                Value<int?> undoOfItemId = const Value.absent(),
              }) => OperationItemsCompanion.insert(
                id: id,
                operationId: operationId,
                seq: seq,
                srcSourceId: srcSourceId,
                srcRelPath: srcRelPath,
                srcInstanceId: srcInstanceId,
                expectedSize: expectedSize,
                expectedSha256: expectedSha256,
                dstSourceId: dstSourceId,
                dstRelPathPlanned: dstRelPathPlanned,
                dstRelPathFinal: dstRelPathFinal,
                tmpRelPath: tmpRelPath,
                originalName: originalName,
                state: state,
                srcSha256: srcSha256,
                dstSha256: dstSha256,
                bytesCopied: bytesCopied,
                attempts: attempts,
                lastErrorCode: lastErrorCode,
                lastErrorMessage: lastErrorMessage,
                updatedAt: updatedAt,
                expectedMtime: expectedMtime,
                undoOfItemId: undoOfItemId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable<OperationItems, OperationItemRow>(table), $OperationItemsReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                operationId = false,
                srcSourceId = false,
                srcInstanceId = false,
                dstSourceId = false,
                undoOfItemId = false,
                operationEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (operationEventsRefs) db.operationEvents],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (operationId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.operationId,
                            referencedTable: $OperationItemsReferences._operationIdTable(db),
                            referencedColumn: $OperationItemsReferences._operationIdTable(db).id,
                          ) as T;
                        }
                        if (srcSourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.srcSourceId,
                            referencedTable: $OperationItemsReferences._srcSourceIdTable(db),
                            referencedColumn: $OperationItemsReferences._srcSourceIdTable(db).id,
                          ) as T;
                        }
                        if (srcInstanceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.srcInstanceId,
                            referencedTable: $OperationItemsReferences._srcInstanceIdTable(db),
                            referencedColumn: $OperationItemsReferences._srcInstanceIdTable(db).id,
                          ) as T;
                        }
                        if (dstSourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.dstSourceId,
                            referencedTable: $OperationItemsReferences._dstSourceIdTable(db),
                            referencedColumn: $OperationItemsReferences._dstSourceIdTable(db).id,
                          ) as T;
                        }
                        if (undoOfItemId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.undoOfItemId,
                            referencedTable: $OperationItemsReferences._undoOfItemIdTable(db),
                            referencedColumn: $OperationItemsReferences._undoOfItemIdTable(db).id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (operationEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          OperationItemRow,
                          OperationItems,
                          OperationEventRow,
                          OperationEvents
                        >(
                          currentTable: table,
                          referencedTable: $OperationItemsReferences._operationEventsRefsTable(db),
                          managerFromTypedResult: (p0) => $OperationItemsReferences(db, table, p0).operationEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'item_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $OperationItemsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      OperationItems,
      OperationItemRow,
      $OperationItemsFilterComposer,
      $OperationItemsOrderingComposer,
      $OperationItemsAnnotationComposer,
      $OperationItemsCreateCompanionBuilder,
      $OperationItemsUpdateCompanionBuilder,
      (OperationItemRow, $OperationItemsReferences),
      OperationItemRow,
      PrefetchHooks Function({
        bool operationId,
        bool srcSourceId,
        bool srcInstanceId,
        bool dstSourceId,
        bool undoOfItemId,
        bool operationEventsRefs,
      })
    >;
typedef $OperationEventsCreateCompanionBuilder = OperationEventsCompanion Function({
  Value<int> id,
  required String operationId,
  Value<int?> itemId,
  required int at,
  Value<String?> fromState,
  Value<String?> toState,
  Value<String?> message,
});
typedef $OperationEventsUpdateCompanionBuilder = OperationEventsCompanion Function({
  Value<int> id,
  Value<String> operationId,
  Value<int?> itemId,
  Value<int> at,
  Value<String?> fromState,
  Value<String?> toState,
  Value<String?> message,
});

final class $OperationEventsReferences extends BaseReferences<_$CatalogDatabase, OperationEvents, OperationEventRow> {
  $OperationEventsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Operations _operationIdTable(_$CatalogDatabase db) =>
      db.operations.createAlias('operation_events__operation_id__operations__id');

  $OperationsProcessedTableManager get operationId {
    final $_column = $_itemColumn<String>('operation_id')!;

    final manager = $OperationsTableManager($_db, $_db.operations).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_operationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static OperationItems _itemIdTable(_$CatalogDatabase db) =>
      db.operationItems.createAlias('operation_events__item_id__operation_items__id');

  $OperationItemsProcessedTableManager? get itemId {
    final $_column = $_itemColumn<int>('item_id');
    if ($_column == null) return null;
    final manager = $OperationItemsTableManager($_db, $_db.operationItems).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $OperationEventsFilterComposer extends Composer<_$CatalogDatabase, OperationEvents> {
  $OperationEventsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromState =>
      $composableBuilder(column: $table.fromState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toState =>
      $composableBuilder(column: $table.toState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => ColumnFilters(column));

  $OperationsFilterComposer get operationId {
    final $OperationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationItemsFilterComposer get itemId {
    final $OperationItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsFilterComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OperationEventsOrderingComposer extends Composer<_$CatalogDatabase, OperationEvents> {
  $OperationEventsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromState =>
      $composableBuilder(column: $table.fromState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toState =>
      $composableBuilder(column: $table.toState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => ColumnOrderings(column));

  $OperationsOrderingComposer get operationId {
    final $OperationsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsOrderingComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationItemsOrderingComposer get itemId {
    final $OperationItemsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsOrderingComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OperationEventsAnnotationComposer extends Composer<_$CatalogDatabase, OperationEvents> {
  $OperationEventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get fromState => $composableBuilder(column: $table.fromState, builder: (column) => column);

  GeneratedColumn<String> get toState => $composableBuilder(column: $table.toState, builder: (column) => column);

  GeneratedColumn<String> get message => $composableBuilder(column: $table.message, builder: (column) => column);

  $OperationsAnnotationComposer get operationId {
    final $OperationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationItemsAnnotationComposer get itemId {
    final $OperationItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.operationItems,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationItemsAnnotationComposer(
            $db: $db,
            $table: $db.operationItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OperationEventsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          OperationEvents,
          OperationEventRow,
          $OperationEventsFilterComposer,
          $OperationEventsOrderingComposer,
          $OperationEventsAnnotationComposer,
          $OperationEventsCreateCompanionBuilder,
          $OperationEventsUpdateCompanionBuilder,
          (OperationEventRow, $OperationEventsReferences),
          OperationEventRow,
          PrefetchHooks Function({bool operationId, bool itemId})
        > {
  $OperationEventsTableManager(_$CatalogDatabase db, OperationEvents table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $OperationEventsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $OperationEventsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $OperationEventsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<int?> itemId = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String?> fromState = const Value.absent(),
                Value<String?> toState = const Value.absent(),
                Value<String?> message = const Value.absent(),
              }) => OperationEventsCompanion(
                id: id,
                operationId: operationId,
                itemId: itemId,
                at: at,
                fromState: fromState,
                toState: toState,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationId,
                Value<int?> itemId = const Value.absent(),
                required int at,
                Value<String?> fromState = const Value.absent(),
                Value<String?> toState = const Value.absent(),
                Value<String?> message = const Value.absent(),
              }) => OperationEventsCompanion.insert(
                id: id,
                operationId: operationId,
                itemId: itemId,
                at: at,
                fromState: fromState,
                toState: toState,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<OperationEvents, OperationEventRow>(table), $OperationEventsReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({operationId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (operationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.operationId,
                        referencedTable: $OperationEventsReferences._operationIdTable(db),
                        referencedColumn: $OperationEventsReferences._operationIdTable(db).id,
                      ) as T;
                    }
                    if (itemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.itemId,
                        referencedTable: $OperationEventsReferences._itemIdTable(db),
                        referencedColumn: $OperationEventsReferences._itemIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $OperationEventsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      OperationEvents,
      OperationEventRow,
      $OperationEventsFilterComposer,
      $OperationEventsOrderingComposer,
      $OperationEventsAnnotationComposer,
      $OperationEventsCreateCompanionBuilder,
      $OperationEventsUpdateCompanionBuilder,
      (OperationEventRow, $OperationEventsReferences),
      OperationEventRow,
      PrefetchHooks Function({bool operationId, bool itemId})
    >;
typedef $SavedFiltersCreateCompanionBuilder = SavedFiltersCompanion Function({
  Value<int> id,
  required String name,
  required String definitionJson,
  required int createdAt,
  required int updatedAt,
});
typedef $SavedFiltersUpdateCompanionBuilder = SavedFiltersCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> definitionJson,
  Value<int> createdAt,
  Value<int> updatedAt,
});

class $SavedFiltersFilterComposer extends Composer<_$CatalogDatabase, SavedFilters> {
  $SavedFiltersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get definitionJson =>
      $composableBuilder(column: $table.definitionJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $SavedFiltersOrderingComposer extends Composer<_$CatalogDatabase, SavedFilters> {
  $SavedFiltersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get definitionJson =>
      $composableBuilder(column: $table.definitionJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $SavedFiltersAnnotationComposer extends Composer<_$CatalogDatabase, SavedFilters> {
  $SavedFiltersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get definitionJson =>
      $composableBuilder(column: $table.definitionJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $SavedFiltersTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          SavedFilters,
          SavedFilterRow,
          $SavedFiltersFilterComposer,
          $SavedFiltersOrderingComposer,
          $SavedFiltersAnnotationComposer,
          $SavedFiltersCreateCompanionBuilder,
          $SavedFiltersUpdateCompanionBuilder,
          (SavedFilterRow, BaseReferences<_$CatalogDatabase, SavedFilters, SavedFilterRow>),
          SavedFilterRow,
          PrefetchHooks Function()
        > {
  $SavedFiltersTableManager(_$CatalogDatabase db, SavedFilters table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SavedFiltersFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SavedFiltersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SavedFiltersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => SavedFiltersCompanion(
                id: id,
                name: name,
                definitionJson: definitionJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String definitionJson,
                required int createdAt,
                required int updatedAt,
              }) => SavedFiltersCompanion.insert(
                id: id,
                name: name,
                definitionJson: definitionJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SavedFilters, SavedFilterRow>(table),
                  BaseReferences<_$CatalogDatabase, SavedFilters, SavedFilterRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SavedFiltersProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      SavedFilters,
      SavedFilterRow,
      $SavedFiltersFilterComposer,
      $SavedFiltersOrderingComposer,
      $SavedFiltersAnnotationComposer,
      $SavedFiltersCreateCompanionBuilder,
      $SavedFiltersUpdateCompanionBuilder,
      (SavedFilterRow, BaseReferences<_$CatalogDatabase, SavedFilters, SavedFilterRow>),
      SavedFilterRow,
      PrefetchHooks Function()
    >;
typedef $SelectionSetsCreateCompanionBuilder = SelectionSetsCompanion Function({
  Value<int> id,
  required String name,
  required int createdAt,
});
typedef $SelectionSetsUpdateCompanionBuilder = SelectionSetsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> createdAt,
});

final class $SelectionSetsReferences extends BaseReferences<_$CatalogDatabase, SelectionSets, SelectionSetRow> {
  $SelectionSetsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<SelectionSetItems, List<SelectionSetItemRow>> _selectionSetItemsRefsTable(
    _$CatalogDatabase db,
  ) =>
      MultiTypedResultKey.fromTable(db.selectionSetItems, aliasName: 'selection_sets__id__selection_set_items__set_id');

  $SelectionSetItemsProcessedTableManager get selectionSetItemsRefs {
    final manager = $SelectionSetItemsTableManager(
      $_db,
      $_db.selectionSetItems,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_selectionSetItemsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $SelectionSetsFilterComposer extends Composer<_$CatalogDatabase, SelectionSets> {
  $SelectionSetsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> selectionSetItemsRefs(Expression<bool> Function($SelectionSetItemsFilterComposer f) f) {
    final $SelectionSetItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.selectionSetItems,
      getReferencedColumn: (t) => t.setId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetItemsFilterComposer(
            $db: $db,
            $table: $db.selectionSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SelectionSetsOrderingComposer extends Composer<_$CatalogDatabase, SelectionSets> {
  $SelectionSetsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $SelectionSetsAnnotationComposer extends Composer<_$CatalogDatabase, SelectionSets> {
  $SelectionSetsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> selectionSetItemsRefs<T extends Object>(
    Expression<T> Function($SelectionSetItemsAnnotationComposer a) f,
  ) {
    final $SelectionSetItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.selectionSetItems,
      getReferencedColumn: (t) => t.setId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetItemsAnnotationComposer(
            $db: $db,
            $table: $db.selectionSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SelectionSetsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          SelectionSets,
          SelectionSetRow,
          $SelectionSetsFilterComposer,
          $SelectionSetsOrderingComposer,
          $SelectionSetsAnnotationComposer,
          $SelectionSetsCreateCompanionBuilder,
          $SelectionSetsUpdateCompanionBuilder,
          (SelectionSetRow, $SelectionSetsReferences),
          SelectionSetRow,
          PrefetchHooks Function({bool selectionSetItemsRefs})
        > {
  $SelectionSetsTableManager(_$CatalogDatabase db, SelectionSets table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SelectionSetsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SelectionSetsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SelectionSetsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) => SelectionSetsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required int createdAt,
          }) => SelectionSetsCompanion.insert(id: id, name: name, createdAt: createdAt),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<SelectionSets, SelectionSetRow>(table), $SelectionSetsReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({selectionSetItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (selectionSetItemsRefs) db.selectionSetItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (selectionSetItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      SelectionSetRow,
                      SelectionSets,
                      SelectionSetItemRow,
                      SelectionSetItems
                    >(
                      currentTable: table,
                      referencedTable: $SelectionSetsReferences._selectionSetItemsRefsTable(db),
                      managerFromTypedResult: (p0) => $SelectionSetsReferences(db, table, p0).selectionSetItemsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'set_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $SelectionSetsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      SelectionSets,
      SelectionSetRow,
      $SelectionSetsFilterComposer,
      $SelectionSetsOrderingComposer,
      $SelectionSetsAnnotationComposer,
      $SelectionSetsCreateCompanionBuilder,
      $SelectionSetsUpdateCompanionBuilder,
      (SelectionSetRow, $SelectionSetsReferences),
      SelectionSetRow,
      PrefetchHooks Function({bool selectionSetItemsRefs})
    >;
typedef $SelectionSetItemsCreateCompanionBuilder = SelectionSetItemsCompanion Function({
  required int setId,
  required int instanceId,
});
typedef $SelectionSetItemsUpdateCompanionBuilder = SelectionSetItemsCompanion Function({
  Value<int> setId,
  Value<int> instanceId,
});

final class $SelectionSetItemsReferences
    extends BaseReferences<_$CatalogDatabase, SelectionSetItems, SelectionSetItemRow> {
  $SelectionSetItemsReferences(super.$_db, super.$_table, super.$_typedResult);

  static SelectionSets _setIdTable(_$CatalogDatabase db) =>
      db.selectionSets.createAlias('selection_set_items__set_id__selection_sets__id');

  $SelectionSetsProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $SelectionSetsTableManager($_db, $_db.selectionSets).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static FileInstances _instanceIdTable(_$CatalogDatabase db) =>
      db.fileInstances.createAlias('selection_set_items__instance_id__file_instances__id');

  $FileInstancesProcessedTableManager get instanceId {
    final $_column = $_itemColumn<int>('instance_id')!;

    final manager = $FileInstancesTableManager($_db, $_db.fileInstances).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_instanceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $SelectionSetItemsFilterComposer extends Composer<_$CatalogDatabase, SelectionSetItems> {
  $SelectionSetItemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $SelectionSetsFilterComposer get setId {
    final $SelectionSetsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.selectionSets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetsFilterComposer(
            $db: $db,
            $table: $db.selectionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $FileInstancesFilterComposer get instanceId {
    final $FileInstancesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesFilterComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SelectionSetItemsOrderingComposer extends Composer<_$CatalogDatabase, SelectionSetItems> {
  $SelectionSetItemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $SelectionSetsOrderingComposer get setId {
    final $SelectionSetsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.selectionSets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetsOrderingComposer(
            $db: $db,
            $table: $db.selectionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $FileInstancesOrderingComposer get instanceId {
    final $FileInstancesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesOrderingComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SelectionSetItemsAnnotationComposer extends Composer<_$CatalogDatabase, SelectionSetItems> {
  $SelectionSetItemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $SelectionSetsAnnotationComposer get setId {
    final $SelectionSetsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.selectionSets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $SelectionSetsAnnotationComposer(
            $db: $db,
            $table: $db.selectionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $FileInstancesAnnotationComposer get instanceId {
    final $FileInstancesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesAnnotationComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SelectionSetItemsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          SelectionSetItems,
          SelectionSetItemRow,
          $SelectionSetItemsFilterComposer,
          $SelectionSetItemsOrderingComposer,
          $SelectionSetItemsAnnotationComposer,
          $SelectionSetItemsCreateCompanionBuilder,
          $SelectionSetItemsUpdateCompanionBuilder,
          (SelectionSetItemRow, $SelectionSetItemsReferences),
          SelectionSetItemRow,
          PrefetchHooks Function({bool setId, bool instanceId})
        > {
  $SelectionSetItemsTableManager(_$CatalogDatabase db, SelectionSetItems table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SelectionSetItemsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SelectionSetItemsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SelectionSetItemsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> setId = const Value.absent(),
            Value<int> instanceId = const Value.absent(),
          }) => SelectionSetItemsCompanion(setId: setId, instanceId: instanceId),
          createCompanionCallback: ({required int setId, required int instanceId}) =>
              SelectionSetItemsCompanion.insert(setId: setId, instanceId: instanceId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SelectionSetItems, SelectionSetItemRow>(table),
                  $SelectionSetItemsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, instanceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.setId,
                        referencedTable: $SelectionSetItemsReferences._setIdTable(db),
                        referencedColumn: $SelectionSetItemsReferences._setIdTable(db).id,
                      ) as T;
                    }
                    if (instanceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.instanceId,
                        referencedTable: $SelectionSetItemsReferences._instanceIdTable(db),
                        referencedColumn: $SelectionSetItemsReferences._instanceIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $SelectionSetItemsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      SelectionSetItems,
      SelectionSetItemRow,
      $SelectionSetItemsFilterComposer,
      $SelectionSetItemsOrderingComposer,
      $SelectionSetItemsAnnotationComposer,
      $SelectionSetItemsCreateCompanionBuilder,
      $SelectionSetItemsUpdateCompanionBuilder,
      (SelectionSetItemRow, $SelectionSetItemsReferences),
      SelectionSetItemRow,
      PrefetchHooks Function({bool setId, bool instanceId})
    >;
typedef $TagsCreateCompanionBuilder = TagsCompanion Function({Value<int> id, required String name});
typedef $TagsUpdateCompanionBuilder = TagsCompanion Function({Value<int> id, Value<String> name});

final class $TagsReferences extends BaseReferences<_$CatalogDatabase, Tags, TagRow> {
  $TagsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<ContentTags, List<ContentTagRow>> _contentTagsRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(db.contentTags, aliasName: 'tags__id__content_tags__tag_id');

  $ContentTagsProcessedTableManager get contentTagsRefs {
    final manager = $ContentTagsTableManager(
      $_db,
      $_db.contentTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_contentTagsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $TagsFilterComposer extends Composer<_$CatalogDatabase, Tags> {
  $TagsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  Expression<bool> contentTagsRefs(Expression<bool> Function($ContentTagsFilterComposer f) f) {
    final $ContentTagsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contentTags,
      getReferencedColumn: (t) => t.tagId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentTagsFilterComposer(
            $db: $db,
            $table: $db.contentTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $TagsOrderingComposer extends Composer<_$CatalogDatabase, Tags> {
  $TagsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));
}

class $TagsAnnotationComposer extends Composer<_$CatalogDatabase, Tags> {
  $TagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> contentTagsRefs<T extends Object>(Expression<T> Function($ContentTagsAnnotationComposer a) f) {
    final $ContentTagsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contentTags,
      getReferencedColumn: (t) => t.tagId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentTagsAnnotationComposer(
            $db: $db,
            $table: $db.contentTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $TagsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          Tags,
          TagRow,
          $TagsFilterComposer,
          $TagsOrderingComposer,
          $TagsAnnotationComposer,
          $TagsCreateCompanionBuilder,
          $TagsUpdateCompanionBuilder,
          (TagRow, $TagsReferences),
          TagRow,
          PrefetchHooks Function({bool contentTagsRefs})
        > {
  $TagsTableManager(_$CatalogDatabase db, Tags table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $TagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $TagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $TagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => TagsCompanion(id: id, name: name),
          createCompanionCallback: ({Value<int> id = const Value.absent(), required String name}) =>
              TagsCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<Tags, TagRow>(table), $TagsReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({contentTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (contentTagsRefs) db.contentTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (contentTagsRefs)
                    await $_getPrefetchedDataByColumns<TagRow, Tags, ContentTagRow, ContentTags>(
                      currentTable: table,
                      referencedTable: $TagsReferences._contentTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $TagsReferences(db, table, p0).contentTagsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'tag_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $TagsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      Tags,
      TagRow,
      $TagsFilterComposer,
      $TagsOrderingComposer,
      $TagsAnnotationComposer,
      $TagsCreateCompanionBuilder,
      $TagsUpdateCompanionBuilder,
      (TagRow, $TagsReferences),
      TagRow,
      PrefetchHooks Function({bool contentTagsRefs})
    >;
typedef $ContentTagsCreateCompanionBuilder = ContentTagsCompanion Function({
  required int contentId,
  required int tagId,
});
typedef $ContentTagsUpdateCompanionBuilder = ContentTagsCompanion Function({Value<int> contentId, Value<int> tagId});

final class $ContentTagsReferences extends BaseReferences<_$CatalogDatabase, ContentTags, ContentTagRow> {
  $ContentTagsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Contents _contentIdTable(_$CatalogDatabase db) =>
      db.contents.createAlias('content_tags__content_id__contents__id');

  $ContentsProcessedTableManager get contentId {
    final $_column = $_itemColumn<int>('content_id')!;

    final manager = $ContentsTableManager($_db, $_db.contents).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Tags _tagIdTable(_$CatalogDatabase db) => db.tags.createAlias('content_tags__tag_id__tags__id');

  $TagsProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $TagsTableManager($_db, $_db.tags).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $ContentTagsFilterComposer extends Composer<_$CatalogDatabase, ContentTags> {
  $ContentTagsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $ContentsFilterComposer get contentId {
    final $ContentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsFilterComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $TagsFilterComposer get tagId {
    final $TagsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $TagsFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ContentTagsOrderingComposer extends Composer<_$CatalogDatabase, ContentTags> {
  $ContentTagsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $ContentsOrderingComposer get contentId {
    final $ContentsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsOrderingComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $TagsOrderingComposer get tagId {
    final $TagsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $TagsOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ContentTagsAnnotationComposer extends Composer<_$CatalogDatabase, ContentTags> {
  $ContentTagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $ContentsAnnotationComposer get contentId {
    final $ContentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $ContentsAnnotationComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $TagsAnnotationComposer get tagId {
    final $TagsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $TagsAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ContentTagsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          ContentTags,
          ContentTagRow,
          $ContentTagsFilterComposer,
          $ContentTagsOrderingComposer,
          $ContentTagsAnnotationComposer,
          $ContentTagsCreateCompanionBuilder,
          $ContentTagsUpdateCompanionBuilder,
          (ContentTagRow, $ContentTagsReferences),
          ContentTagRow,
          PrefetchHooks Function({bool contentId, bool tagId})
        > {
  $ContentTagsTableManager(_$CatalogDatabase db, ContentTags table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ContentTagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ContentTagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ContentTagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> contentId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
          }) => ContentTagsCompanion(contentId: contentId, tagId: tagId),
          createCompanionCallback: ({required int contentId, required int tagId}) =>
              ContentTagsCompanion.insert(contentId: contentId, tagId: tagId),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<ContentTags, ContentTagRow>(table), $ContentTagsReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({contentId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (contentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.contentId,
                        referencedTable: $ContentTagsReferences._contentIdTable(db),
                        referencedColumn: $ContentTagsReferences._contentIdTable(db).id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $ContentTagsReferences._tagIdTable(db),
                        referencedColumn: $ContentTagsReferences._tagIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $ContentTagsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      ContentTags,
      ContentTagRow,
      $ContentTagsFilterComposer,
      $ContentTagsOrderingComposer,
      $ContentTagsAnnotationComposer,
      $ContentTagsCreateCompanionBuilder,
      $ContentTagsUpdateCompanionBuilder,
      (ContentTagRow, $ContentTagsReferences),
      ContentTagRow,
      PrefetchHooks Function({bool contentId, bool tagId})
    >;
typedef $IntegrityChecksCreateCompanionBuilder = IntegrityChecksCompanion Function({
  Value<int> id,
  required int instanceId,
  Value<String?> operationId,
  required int checkedAt,
  required String result,
  Value<Uint8List?> observedSha256,
  Value<int?> observedSize,
  Value<int?> observedMtime,
});
typedef $IntegrityChecksUpdateCompanionBuilder = IntegrityChecksCompanion Function({
  Value<int> id,
  Value<int> instanceId,
  Value<String?> operationId,
  Value<int> checkedAt,
  Value<String> result,
  Value<Uint8List?> observedSha256,
  Value<int?> observedSize,
  Value<int?> observedMtime,
});

final class $IntegrityChecksReferences extends BaseReferences<_$CatalogDatabase, IntegrityChecks, IntegrityCheckRow> {
  $IntegrityChecksReferences(super.$_db, super.$_table, super.$_typedResult);

  static FileInstances _instanceIdTable(_$CatalogDatabase db) =>
      db.fileInstances.createAlias('integrity_checks__instance_id__file_instances__id');

  $FileInstancesProcessedTableManager get instanceId {
    final $_column = $_itemColumn<int>('instance_id')!;

    final manager = $FileInstancesTableManager($_db, $_db.fileInstances).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_instanceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static Operations _operationIdTable(_$CatalogDatabase db) =>
      db.operations.createAlias('integrity_checks__operation_id__operations__id');

  $OperationsProcessedTableManager? get operationId {
    final $_column = $_itemColumn<String>('operation_id');
    if ($_column == null) return null;
    final manager = $OperationsTableManager($_db, $_db.operations).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_operationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $IntegrityChecksFilterComposer extends Composer<_$CatalogDatabase, IntegrityChecks> {
  $IntegrityChecksFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get observedSha256 =>
      $composableBuilder(column: $table.observedSha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get observedSize =>
      $composableBuilder(column: $table.observedSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get observedMtime =>
      $composableBuilder(column: $table.observedMtime, builder: (column) => ColumnFilters(column));

  $FileInstancesFilterComposer get instanceId {
    final $FileInstancesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesFilterComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationsFilterComposer get operationId {
    final $OperationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $IntegrityChecksOrderingComposer extends Composer<_$CatalogDatabase, IntegrityChecks> {
  $IntegrityChecksOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get observedSha256 =>
      $composableBuilder(column: $table.observedSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get observedSize =>
      $composableBuilder(column: $table.observedSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get observedMtime =>
      $composableBuilder(column: $table.observedMtime, builder: (column) => ColumnOrderings(column));

  $FileInstancesOrderingComposer get instanceId {
    final $FileInstancesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesOrderingComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationsOrderingComposer get operationId {
    final $OperationsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsOrderingComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $IntegrityChecksAnnotationComposer extends Composer<_$CatalogDatabase, IntegrityChecks> {
  $IntegrityChecksAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get checkedAt => $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<String> get result => $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<Uint8List> get observedSha256 =>
      $composableBuilder(column: $table.observedSha256, builder: (column) => column);

  GeneratedColumn<int> get observedSize => $composableBuilder(column: $table.observedSize, builder: (column) => column);

  GeneratedColumn<int> get observedMtime =>
      $composableBuilder(column: $table.observedMtime, builder: (column) => column);

  $FileInstancesAnnotationComposer get instanceId {
    final $FileInstancesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.fileInstances,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $FileInstancesAnnotationComposer(
            $db: $db,
            $table: $db.fileInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $OperationsAnnotationComposer get operationId {
    final $OperationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.operationId,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $OperationsAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $IntegrityChecksTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          IntegrityChecks,
          IntegrityCheckRow,
          $IntegrityChecksFilterComposer,
          $IntegrityChecksOrderingComposer,
          $IntegrityChecksAnnotationComposer,
          $IntegrityChecksCreateCompanionBuilder,
          $IntegrityChecksUpdateCompanionBuilder,
          (IntegrityCheckRow, $IntegrityChecksReferences),
          IntegrityCheckRow,
          PrefetchHooks Function({bool instanceId, bool operationId})
        > {
  $IntegrityChecksTableManager(_$CatalogDatabase db, IntegrityChecks table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $IntegrityChecksFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $IntegrityChecksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $IntegrityChecksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> instanceId = const Value.absent(),
                Value<String?> operationId = const Value.absent(),
                Value<int> checkedAt = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<Uint8List?> observedSha256 = const Value.absent(),
                Value<int?> observedSize = const Value.absent(),
                Value<int?> observedMtime = const Value.absent(),
              }) => IntegrityChecksCompanion(
                id: id,
                instanceId: instanceId,
                operationId: operationId,
                checkedAt: checkedAt,
                result: result,
                observedSha256: observedSha256,
                observedSize: observedSize,
                observedMtime: observedMtime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int instanceId,
                Value<String?> operationId = const Value.absent(),
                required int checkedAt,
                required String result,
                Value<Uint8List?> observedSha256 = const Value.absent(),
                Value<int?> observedSize = const Value.absent(),
                Value<int?> observedMtime = const Value.absent(),
              }) => IntegrityChecksCompanion.insert(
                id: id,
                instanceId: instanceId,
                operationId: operationId,
                checkedAt: checkedAt,
                result: result,
                observedSha256: observedSha256,
                observedSize: observedSize,
                observedMtime: observedMtime,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<IntegrityChecks, IntegrityCheckRow>(table), $IntegrityChecksReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({instanceId = false, operationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (instanceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.instanceId,
                        referencedTable: $IntegrityChecksReferences._instanceIdTable(db),
                        referencedColumn: $IntegrityChecksReferences._instanceIdTable(db).id,
                      ) as T;
                    }
                    if (operationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.operationId,
                        referencedTable: $IntegrityChecksReferences._operationIdTable(db),
                        referencedColumn: $IntegrityChecksReferences._operationIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $IntegrityChecksProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      IntegrityChecks,
      IntegrityCheckRow,
      $IntegrityChecksFilterComposer,
      $IntegrityChecksOrderingComposer,
      $IntegrityChecksAnnotationComposer,
      $IntegrityChecksCreateCompanionBuilder,
      $IntegrityChecksUpdateCompanionBuilder,
      (IntegrityCheckRow, $IntegrityChecksReferences),
      IntegrityCheckRow,
      PrefetchHooks Function({bool instanceId, bool operationId})
    >;
typedef $SavedScopesCreateCompanionBuilder = SavedScopesCompanion Function({
  Value<int> id,
  required String name,
  required String definitionJson,
  required int createdAt,
  required int updatedAt,
});
typedef $SavedScopesUpdateCompanionBuilder = SavedScopesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> definitionJson,
  Value<int> createdAt,
  Value<int> updatedAt,
});

class $SavedScopesFilterComposer extends Composer<_$CatalogDatabase, SavedScopes> {
  $SavedScopesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get definitionJson =>
      $composableBuilder(column: $table.definitionJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $SavedScopesOrderingComposer extends Composer<_$CatalogDatabase, SavedScopes> {
  $SavedScopesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get definitionJson =>
      $composableBuilder(column: $table.definitionJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $SavedScopesAnnotationComposer extends Composer<_$CatalogDatabase, SavedScopes> {
  $SavedScopesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get definitionJson =>
      $composableBuilder(column: $table.definitionJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $SavedScopesTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          SavedScopes,
          SavedScopeRow,
          $SavedScopesFilterComposer,
          $SavedScopesOrderingComposer,
          $SavedScopesAnnotationComposer,
          $SavedScopesCreateCompanionBuilder,
          $SavedScopesUpdateCompanionBuilder,
          (SavedScopeRow, BaseReferences<_$CatalogDatabase, SavedScopes, SavedScopeRow>),
          SavedScopeRow,
          PrefetchHooks Function()
        > {
  $SavedScopesTableManager(_$CatalogDatabase db, SavedScopes table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SavedScopesFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SavedScopesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SavedScopesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => SavedScopesCompanion(
                id: id,
                name: name,
                definitionJson: definitionJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String definitionJson,
                required int createdAt,
                required int updatedAt,
              }) => SavedScopesCompanion.insert(
                id: id,
                name: name,
                definitionJson: definitionJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SavedScopes, SavedScopeRow>(table),
                  BaseReferences<_$CatalogDatabase, SavedScopes, SavedScopeRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SavedScopesProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      SavedScopes,
      SavedScopeRow,
      $SavedScopesFilterComposer,
      $SavedScopesOrderingComposer,
      $SavedScopesAnnotationComposer,
      $SavedScopesCreateCompanionBuilder,
      $SavedScopesUpdateCompanionBuilder,
      (SavedScopeRow, BaseReferences<_$CatalogDatabase, SavedScopes, SavedScopeRow>),
      SavedScopeRow,
      PrefetchHooks Function()
    >;
typedef $MomentEditsCreateCompanionBuilder = MomentEditsCompanion Function({
  Value<int> id,
  Value<int?> momentId,
  required String op,
  Value<String?> detailJson,
  required int createdAt,
});
typedef $MomentEditsUpdateCompanionBuilder = MomentEditsCompanion Function({
  Value<int> id,
  Value<int?> momentId,
  Value<String> op,
  Value<String?> detailJson,
  Value<int> createdAt,
});

class $MomentEditsFilterComposer extends Composer<_$CatalogDatabase, MomentEdits> {
  $MomentEditsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get momentId =>
      $composableBuilder(column: $table.momentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get op => $composableBuilder(column: $table.op, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detailJson =>
      $composableBuilder(column: $table.detailJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $MomentEditsOrderingComposer extends Composer<_$CatalogDatabase, MomentEdits> {
  $MomentEditsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get momentId =>
      $composableBuilder(column: $table.momentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get op => $composableBuilder(column: $table.op, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detailJson =>
      $composableBuilder(column: $table.detailJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $MomentEditsAnnotationComposer extends Composer<_$CatalogDatabase, MomentEdits> {
  $MomentEditsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get momentId => $composableBuilder(column: $table.momentId, builder: (column) => column);

  GeneratedColumn<String> get op => $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get detailJson => $composableBuilder(column: $table.detailJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $MomentEditsTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          MomentEdits,
          MomentEditRow,
          $MomentEditsFilterComposer,
          $MomentEditsOrderingComposer,
          $MomentEditsAnnotationComposer,
          $MomentEditsCreateCompanionBuilder,
          $MomentEditsUpdateCompanionBuilder,
          (MomentEditRow, BaseReferences<_$CatalogDatabase, MomentEdits, MomentEditRow>),
          MomentEditRow,
          PrefetchHooks Function()
        > {
  $MomentEditsTableManager(_$CatalogDatabase db, MomentEdits table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $MomentEditsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $MomentEditsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $MomentEditsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> momentId = const Value.absent(),
            Value<String> op = const Value.absent(),
            Value<String?> detailJson = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) => MomentEditsCompanion(id: id, momentId: momentId, op: op, detailJson: detailJson, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> momentId = const Value.absent(),
                required String op,
                Value<String?> detailJson = const Value.absent(),
                required int createdAt,
              }) => MomentEditsCompanion.insert(
                id: id,
                momentId: momentId,
                op: op,
                detailJson: detailJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MomentEdits, MomentEditRow>(table),
                  BaseReferences<_$CatalogDatabase, MomentEdits, MomentEditRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MomentEditsProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      MomentEdits,
      MomentEditRow,
      $MomentEditsFilterComposer,
      $MomentEditsOrderingComposer,
      $MomentEditsAnnotationComposer,
      $MomentEditsCreateCompanionBuilder,
      $MomentEditsUpdateCompanionBuilder,
      (MomentEditRow, BaseReferences<_$CatalogDatabase, MomentEdits, MomentEditRow>),
      MomentEditRow,
      PrefetchHooks Function()
    >;

class $CatalogDatabaseManager {
  final _$CatalogDatabase _db;
  $CatalogDatabaseManager(this._db);
  $AppMetaTableManager get appMeta => $AppMetaTableManager(_db, _db.appMeta);
  $SettingsTableManager get settings => $SettingsTableManager(_db, _db.settings);
  $PhysicalDisksTableManager get physicalDisks => $PhysicalDisksTableManager(_db, _db.physicalDisks);
  $SourcesTableManager get sources => $SourcesTableManager(_db, _db.sources);
  $ScansTableManager get scans => $ScansTableManager(_db, _db.scans);
  $ScanDirsTableManager get scanDirs => $ScanDirsTableManager(_db, _db.scanDirs);
  $ScanErrorsTableManager get scanErrors => $ScanErrorsTableManager(_db, _db.scanErrors);
  $ContentsTableManager get contents => $ContentsTableManager(_db, _db.contents);
  $FileInstancesTableManager get fileInstances => $FileInstancesTableManager(_db, _db.fileInstances);
  $ClockCorrectionsTableManager get clockCorrections => $ClockCorrectionsTableManager(_db, _db.clockCorrections);
  $MomentsTableManager get moments => $MomentsTableManager(_db, _db.moments);
  $MediaMetadataTableManager get mediaMetadata => $MediaMetadataTableManager(_db, _db.mediaMetadata);
  $DateCorrectionsTableManager get dateCorrections => $DateCorrectionsTableManager(_db, _db.dateCorrections);
  $OperationsTableManager get operations => $OperationsTableManager(_db, _db.operations);
  $OperationItemsTableManager get operationItems => $OperationItemsTableManager(_db, _db.operationItems);
  $OperationEventsTableManager get operationEvents => $OperationEventsTableManager(_db, _db.operationEvents);
  $SavedFiltersTableManager get savedFilters => $SavedFiltersTableManager(_db, _db.savedFilters);
  $SelectionSetsTableManager get selectionSets => $SelectionSetsTableManager(_db, _db.selectionSets);
  $SelectionSetItemsTableManager get selectionSetItems => $SelectionSetItemsTableManager(_db, _db.selectionSetItems);
  $TagsTableManager get tags => $TagsTableManager(_db, _db.tags);
  $ContentTagsTableManager get contentTags => $ContentTagsTableManager(_db, _db.contentTags);
  $IntegrityChecksTableManager get integrityChecks => $IntegrityChecksTableManager(_db, _db.integrityChecks);
  $SavedScopesTableManager get savedScopes => $SavedScopesTableManager(_db, _db.savedScopes);
  $MomentEditsTableManager get momentEdits => $MomentEditsTableManager(_db, _db.momentEdits);
}
