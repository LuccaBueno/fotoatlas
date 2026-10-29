import 'dart:convert';

import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../util/clock.dart';

/// Configurações do usuário guardadas no catálogo (tabela `settings`, JSON).
class SettingsStore {
  SettingsStore(this.db);
  final CatalogDatabase db;

  Future<Object?> get(String key) async {
    final row = await db
        .customSelect('SELECT value_json FROM settings WHERE "key" = ?', variables: [Variable.withString(key)])
        .getSingleOrNull();
    return row == null ? null : jsonDecode(row.read<String>('value_json'));
  }

  Future<void> set(String key, Object? value) => db.customStatement(
    'INSERT INTO settings ("key", value_json, updated_at) VALUES (?, ?, ?) '
    'ON CONFLICT("key") DO UPDATE SET value_json = excluded.value_json, updated_at = excluded.updated_at',
    [key, jsonEncode(value), nowMs()],
  );
}
