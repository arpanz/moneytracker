import 'package:drift/drift.dart' show TableInfo;

import 'app_database.dart';

export 'app_database.dart';

/// Thin wrapper around [AppDatabase] so existing provider code that
/// depends on [DatabaseService] can stay unchanged.
class DatabaseService {
  late AppDatabase _db;

  AppDatabase get db => _db;

  Future<void> initialize() async {
    _db = AppDatabase();
  }

  Future<void> clearAll() async {
    // Delete all rows from every table
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        await _db.delete(table as TableInfo).go();
      }
    });
  }

  Future<void> close() async {
    await _db.close();
  }
}
