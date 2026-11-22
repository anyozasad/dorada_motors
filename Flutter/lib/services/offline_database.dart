import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// SQLite del dispositivo: datos persistentes incluso con modo avión.
/// La API remota no recibe estos cambios hasta existir conexión.
class OfflineDatabase {
  OfflineDatabase._();

  static Database? _instancia;
  static Future<Database>? _abriendo;

  static Future<Database> _db() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite local solo está habilitado en Android');
    }
    if (_instancia != null) return _instancia!;
    _abriendo ??= _abrir();
    try {
      return await _abriendo!;
    } catch (_) {
      _abriendo = null;
      rethrow;
    }
  }

  static Future<Database> _abrir() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      path.join(dir, 'dorada_motors_local_v1.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE cache (
            scope TEXT NOT NULL,
            nombre TEXT NOT NULL,
            contenido TEXT NOT NULL,
            actualizado TEXT NOT NULL,
            PRIMARY KEY (scope, nombre)
          )
        ''');
        await database.execute('''
          CREATE TABLE operaciones (
            clave TEXT PRIMARY KEY,
            scope TEXT NOT NULL,
            accion TEXT NOT NULL,
            payload TEXT NOT NULL,
            estado TEXT NOT NULL DEFAULT 'pendiente',
            error TEXT,
            actualizado TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_operaciones_scope ON operaciones(scope, estado)',
        );
      },
    );
    _instancia = db;
    return db;
  }

  static Future<void> guardar(
    String scope,
    String nombre,
    Object? datos,
  ) async {
    final db = await _db();
    await db.insert(
      'cache',
      {
        'scope': scope,
        'nombre': nombre,
        'contenido': jsonEncode(datos),
        'actualizado': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<dynamic> leer(String scope, String nombre) async {
    final db = await _db();
    final rows = await db.query(
      'cache',
      columns: ['contenido'],
      where: 'scope=? AND nombre=?',
      whereArgs: [scope, nombre],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['contenido'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Si clave es la misma, se guarda el estado FINAL: dos pulsaciones del
  /// carrito no se convierten en dos ventas ni cantidades duplicadas.
  static Future<void> encolar({
    required String clave,
    required String scope,
    required String accion,
    required Map<String, dynamic> datos,
  }) async {
    final db = await _db();
    await db.insert(
      'operaciones',
      {
        'clave': clave,
        'scope': scope,
        'accion': accion,
        'payload': jsonEncode(datos),
        'estado': 'pendiente',
        'error': null,
        'actualizado': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> pendientes(String scope) async {
    final db = await _db();
    final rows = await db.query(
      'operaciones',
      where: 'scope=? AND estado IN (?, ?)',
      whereArgs: [scope, 'pendiente', 'error'],
      orderBy: 'actualizado ASC',
    );
    return rows.map((row) {
      final data = Map<String, dynamic>.from(row);
      data['datos'] = jsonDecode(row['payload'] as String);
      return data;
    }).toList();
  }

  static Future<void> confirmar(String clave) async {
    final db = await _db();
    await db.delete(
      'operaciones',
      where: 'clave=?',
      whereArgs: [clave],
    );
  }

  static Future<void> registrarError(String clave, String mensaje) async {
    final db = await _db();
    await db.update(
      'operaciones',
      {'estado': 'error', 'error': mensaje},
      where: 'clave=?',
      whereArgs: [clave],
    );
  }

  static Future<int> contarPendientes(String scope) async {
    final db = await _db();
    final filas = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM operaciones WHERE scope=?",
      [scope],
    );
    return (filas.first['total'] as num).toInt();
  }

  static Future<void> limpiarScope(String scope) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete('cache', where: 'scope=?', whereArgs: [scope]);
      await txn.delete('operaciones', where: 'scope=?', whereArgs: [scope]);
    });
  }

  @visibleForTesting
  static Future<void> cerrarPruebas() async {
    await _instancia?.close();
    _instancia = null;
    _abriendo = null;
  }
}
