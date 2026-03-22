import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'pomodoro_sync.dart';
import 'schema/pomodoro_schema.dart';

class PomodoroDatabaseOwner {
  PomodoroDatabaseOwner({
    this.fileName = 'pomogotchi.db',
    PomodoroSyncCoordinator? syncCoordinator,
  }) : _syncCoordinator = syncCoordinator ?? PomodoroSyncCoordinator();

  final String fileName;
  final PomodoroSyncCoordinator _syncCoordinator;
  PowerSyncDatabase? _database;

  bool get isInitialized => _database != null;

  PowerSyncDatabase get database {
    final db = _database;
    if (db == null) {
      throw StateError('PowerSync database has not been initialized');
    }
    return db;
  }

  Future<PowerSyncDatabase> initialize() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await _databasePath();
    final db = PowerSyncDatabase(schema: pomodoroSchema, path: dbPath);
    try {
      await db.initialize();
      await _syncCoordinator.attach(db);
      _database = db;
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> dispose() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await _syncCoordinator.dispose();
      await db.close();
    }
  }

  Future<void> clearForSignOut() async {
    final db = _database;
    _database = null;
    if (db == null) {
      return;
    }

    await _syncCoordinator.dispose();
    try {
      await db.disconnectAndClear();
    } catch (_) {
      await db.disconnect();
    }
    await db.close();
  }

  Future<String> _databasePath() async {
    if (kIsWeb) {
      return fileName;
    }

    final supportDirectory = await getApplicationSupportDirectory();
    return join(supportDirectory.path, fileName);
  }
}
