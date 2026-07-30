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

  /// Guarda o actualiza el conteo de pasos del día de forma local.
  ///
  /// Garantía de no pérdida: usa un upsert con MAX para que el valor guardado
  /// nunca sea menor que el que ya estaba almacenado. Si el registro del día
  /// ya existía con 5000 pasos y se llama con 3000, se conservan los 5000.
  static Future<void> saveSteps({
    required String date,
    required int steps,
    required String source,
  }) async {
    final db = await _database;
    // Upsert con MAX: nunca sobreescribe con un valor menor.
    // ON CONFLICT DO UPDATE requiere SQLite ≥ 3.24 (disponible en Android 8+).
    await db.rawInsert(
      '''
      INSERT INTO local_steps (date, total_steps, source, synced)
      VALUES (?, ?, ?, 0)
      ON CONFLICT(date) DO UPDATE SET
        total_steps = MAX(local_steps.total_steps, excluded.total_steps),
        source      = excluded.source,
        synced      = CASE
                        WHEN excluded.total_steps > local_steps.total_steps THEN 0
                        ELSE local_steps.synced
                      END
      ''',
      [date, steps, source],
    );
  }

  /// Devuelve los pasos guardados localmente para una fecha determinada.
  /// Retorna null si no hay registro para esa fecha.
  static Future<int?> getStepsForDate(String date) async {
    final db = await _database;
    final rows = await db.query(
      'local_steps',
      columns: ['total_steps'],
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['total_steps'] as int?;
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

  /// Envía todos los registros pendientes al backend si hay internet.
  /// Cada registro se intenta de forma independiente: si uno falla, los demás
  /// siguen intentándose (no falla en cascada).
  /// Retorna la última respuesta exitosa, o null si nada fue sincronizado.
  static Future<Map<String, dynamic>?> flushPending() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return null;

    final pending = await getPending();
    Map<String, dynamic>? lastResponse;
    for (final record in pending) {
      try {
        final response = await ApiService.syncSteps(
          record.date,
          record.totalSteps,
          source: record.source,
        );
        await markSynced(record.id!);
        lastResponse = response;
      } catch (_) {
        // El registro permanece como synced=0 y se reintentará en el próximo flush.
        // No interrumpimos el loop para que otros registros pendientes sigan intentando.
      }
    }
    return lastResponse;
  }

  /// Escucha cambios de conectividad y hace flush automático al recuperar internet.
  static void listenAndSync() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        flushPending();
      }
    });
  }
}

