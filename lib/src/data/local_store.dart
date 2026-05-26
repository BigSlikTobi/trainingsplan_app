import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/fitness_models.dart';
import '../services/local_bridge_service.dart';
import 'seed_data.dart';

class LocalFitnessStore {
  LocalFitnessStore();

  Future<File> get _dataFile async {
    final dir = await getApplicationDocumentsDirectory();
    return _migratedFile(
      dir: dir,
      currentName: 't4l_trainer_data.json',
      legacyName: 'codex_fitness_data.json',
    );
  }

  Future<File> get _sqliteFile async {
    final dir = await getApplicationDocumentsDirectory();
    return _migratedFile(
      dir: dir,
      currentName: 't4l_trainer.sqlite',
      legacyName: 'codex_fitness.sqlite',
    );
  }

  Future<File> _migratedFile({
    required Directory dir,
    required String currentName,
    required String legacyName,
  }) async {
    final current = File(p.join(dir.path, currentName));
    if (current.existsSync()) return current;
    final legacy = File(p.join(dir.path, legacyName));
    if (legacy.existsSync()) {
      await legacy.copy(current.path);
    }
    return current;
  }

  Future<FitnessData> load() async {
    final db = await _openDatabase();
    try {
      final rows = db.select(
        'SELECT value FROM app_state WHERE key = ? LIMIT 1',
        ['fitness_data'],
      );
      if (rows.isNotEmpty) {
        return FitnessData.fromJson(
          (jsonDecode(rows.first['value'] as String) as Map)
              .cast<String, dynamic>(),
        );
      }
    } finally {
      db.close();
    }

    final file = await _dataFile;
    if (!file.existsSync()) {
      final empty = createEmptyFitnessData();
      await save(empty);
      return empty;
    }

    try {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return FitnessData.fromJson(decoded);
    } on Object {
      final empty = createEmptyFitnessData();
      await save(empty);
      return empty;
    }
  }

  Future<void> save(FitnessData data) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final db = await _openDatabase();
    try {
      db.execute(
        '''
        INSERT INTO app_state(key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET
          value = excluded.value,
          updated_at = excluded.updated_at
        ''',
        ['fitness_data', encoded, DateTime.now().toIso8601String()],
      );
    } finally {
      db.close();
    }

    final file = await _dataFile;
    await file.writeAsString(encoded);
  }

  Future<LocalBridgeConfig> loadBridgeConfig() async {
    final db = await _openDatabase();
    try {
      final rows = db.select(
        'SELECT value FROM app_state WHERE key = ? LIMIT 1',
        ['local_bridge_config'],
      );
      if (rows.isEmpty) return const LocalBridgeConfig();
      final decoded =
          jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      return LocalBridgeConfig.fromJson(decoded);
    } on Object {
      return const LocalBridgeConfig();
    } finally {
      db.close();
    }
  }

  Future<void> saveBridgeConfig(LocalBridgeConfig config) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(config.toJson());
    final db = await _openDatabase();
    try {
      db.execute(
        '''
        INSERT INTO app_state(key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET
          value = excluded.value,
          updated_at = excluded.updated_at
        ''',
        ['local_bridge_config', encoded, DateTime.now().toIso8601String()],
      );
    } finally {
      db.close();
    }
  }

  Future<Database> _openDatabase() async {
    final file = await _sqliteFile;
    final db = sqlite3.open(file.path);
    db.execute('''
      CREATE TABLE IF NOT EXISTS app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    return db;
  }
}
