import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/fitness_models.dart';
import '../services/exchange_directory_service.dart';
import 'seed_data.dart';

class LocalFitnessStore {
  LocalFitnessStore({ExchangeDirectoryService? exchangeDirectoryService})
    : _exchangeDirectoryService =
          exchangeDirectoryService ?? ExchangeDirectoryService();

  final ExchangeDirectoryService _exchangeDirectoryService;

  Future<File> get _dataFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'codex_fitness_data.json'));
  }

  Future<File> get _sqliteFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'codex_fitness.sqlite'));
  }

  Future<Directory> getExchangeDirectory() async {
    return _exchangeDirectoryService.resolveExchangeDirectory();
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
      final seed = createSeedFitnessData();
      await save(seed);
      return seed;
    }

    try {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return FitnessData.fromJson(decoded);
    } on Object {
      final seed = createSeedFitnessData();
      await save(seed);
      return seed;
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

  Future<File> writeExchangeJson(
    String fileName,
    Map<String, dynamic> payload,
  ) async {
    final dir = await getExchangeDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file;
  }

  Future<Map<String, dynamic>?> readExchangeJson(String fileName) async {
    final dir = await getExchangeDirectory();
    final file = File(p.join(dir.path, fileName));
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return null;
  }

  Future<bool> exchangeJsonExists(String fileName) async {
    final dir = await getExchangeDirectory();
    return File(p.join(dir.path, fileName)).exists();
  }

  Future<void> deleteExchangeJson(String fileName) async {
    final dir = await getExchangeDirectory();
    final file = File(p.join(dir.path, fileName));
    if (file.existsSync()) await file.delete();
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
