import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/local_step.dart';
import 'api_service.dart';

class OfflineSyncService {
  static Database? _db;

  static Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'walkwin_steps.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE local_steps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT UNIQUE NOT NULL,
            total_steps INTEGER NOT NULL,
            source TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  /// Save or update today's step count locally, marked as unsynced.
  static Future<void> saveSteps({
    required String date,
    required int steps,
    required String source,
  }) async {
    final db = await _database;
    await db.insert(
      'local_steps',
      LocalStep(date: date, totalSteps: steps, source: source, synced: false).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all unsynced records.
  static Future<List<LocalStep>> getPending() async {
    final db = await _database;
    final rows = await db.query('local_steps', where: 'synced = 0');
    return rows.map(LocalStep.fromMap).toList();
  }

  /// Mark a record as synced by id.
  static Future<void> markSynced(int id) async {
    final db = await _database;
    await db.update(
      'local_steps',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Flush all unsynced records to the backend if online.
  static Future<void> flushPending() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final pending = await getPending();
    for (final record in pending) {
      try {
        await ApiService.syncSteps(record.date, record.totalSteps, source: record.source);
        await markSynced(record.id!);
      } catch (_) {
        // Will retry on next flush
      }
    }
  }

  /// Listen for connectivity changes and auto-flush.
  static void listenAndSync() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        flushPending();
      }
    });
  }
}
