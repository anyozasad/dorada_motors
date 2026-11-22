import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'offline_database.dart';
import 'local_store.dart';

/// Una acción offline se guarda en SQLite; MySQL solo cambia tras confirmarse.
class OfflineActions {
  static bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String nuevaClave() {
    final random = Random.secure();
    return List.generate(4, (_) =>
        random.nextInt(1 << 30).toRadixString(16).padLeft(8, '0')).join();
  }

  static Future<int> usuarioActual() async {
    final sesion = await LocalStore.getSession();
    return int.tryParse(sesion?['id'] ?? '') ?? 0;
  }

  static Future<String> _scope() async {
    final usuario = await usuarioActual();
    if (usuario <= 0) throw StateError('Inicia sesión para guardar cambios');
    return 'usuario:$usuario@${ApiService.baseUrl.toLowerCase()}';
  }

  static Future<void> guardarCopia(String nombre, Object? datos) async {
    if (disponible) {
      await OfflineDatabase.guardar(await _scope(), nombre, datos);
    }
  }

  static Future<dynamic> leerCopia(String nombre) async {
    if (!disponible) return null;
    return OfflineDatabase.leer(await _scope(), nombre);
  }

  static Future<bool> registrar({
    required String accion,
    required String clave,
    required Map<String, dynamic> datos,
  }) async {
    if (!disponible) {
      await _enviar(accion, clave, datos);
      return true;
    }
    // Escribir ANTES de intentar la red, incluso si Android cierra la app.
    await OfflineDatabase.encolar(
      clave: clave, scope: await _scope(), accion: accion, datos: datos,
    );
    try {
      // Evita que un formulario offline espere 10 s por cada operación.
      await ApiService.comprobarConexionBackend()
          .timeout(const Duration(seconds: 4));
      await _enviar(accion, clave, datos);
      await OfflineDatabase.confirmar(clave);
      return true;
    } catch (e) {
      if (ApiService.esErrorConexion(e)) return false;
      await OfflineDatabase.registrarError(clave, e.toString());
      rethrow;
    }
  }

  static Future<void> _enviar(
    String accion, String clave, Map<String, dynamic> datos,
  ) async {
    switch (accion) {
      case 'soporte':
        await ApiService.registrarSolicitudSoporte(
          asunto: datos['asunto'] as String,
          mensaje: datos['mensaje'] as String,
          claveOperacion: clave,
        );
      case 'direccion_crear':
        await ApiService.registrarDireccion(
          idUsuario: await usuarioActual(),
          direccion: datos['direccion'] as String,
          referencia: datos['referencia'] as String? ?? '',
          claveOperacion: clave,
        );
      case 'direccion_editar':
        await ApiService.actualizarDireccion(
          idUsuario: await usuarioActual(),
          idDireccion: datos['id_direccion'] as int,
          direccion: datos['direccion'] as String,
          referencia: datos['referencia'] as String? ?? '',
        );
      case 'direccion_eliminar':
        try {
          await ApiService.eliminarDireccion(datos['id_direccion'] as int);
        } catch (e) {
          if (!e.toString().contains('404') &&
              !e.toString().contains('Dirección no encontrada')) {
            rethrow;
          }
        }
      case 'perfil':
        await ApiService.actualizarCuenta(
          nombres: datos['nombres'] as String,
          apellidos: datos['apellidos'] as String,
          correo: datos['correo'] as String,
          telefono: datos['telefono'] as String,
        );
      default:
        throw StateError('Acción de sincronización no admitida: $accion');
    }
  }

  static Future<List<Map<String, dynamic>>> operacionesPendientes({
    String? accion,
  }) async {
    if (!disponible) return [];
    final filas = await OfflineDatabase.pendientes(await _scope());
    if (accion == null) return filas;
    return filas.where((f) => f['accion'] == accion).toList();
  }

  static Future<int> pendientes() async {
    if (!disponible) return 0;
    return OfflineDatabase.contarPendientes(await _scope());
  }

  static Future<int> sincronizar() async {
    if (!disponible) return 0;
    final operaciones = (await OfflineDatabase.pendientes(await _scope()))
        .where((e) => e['accion'] != 'pedido_borrador').toList();
    if (operaciones.isEmpty) return 0;
    try {
      await ApiService.comprobarConexionBackend()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return 0;
    }
    var completadas = 0;
    for (final fila in operaciones) {
      final clave = fila['clave'] as String;
      try {
        await _enviar(
          fila['accion'] as String, clave,
          Map<String, dynamic>.from(fila['datos'] as Map),
        );
        await OfflineDatabase.confirmar(clave);
        completadas++;
      } catch (e) {
        if (ApiService.esErrorConexion(e)) break;
        await OfflineDatabase.registrarError(clave, e.toString());
      }
    }
    return completadas;
  }

  static Future<void> guardarBorradorPedido({
    required String clave,
    required Map<String, dynamic> datos,
  }) async {
    if (!disponible) {
      throw UnsupportedError('Los borradores offline requieren Android');
    }
    await OfflineDatabase.encolar(
      clave: clave, scope: await _scope(),
      accion: 'pedido_borrador', datos: datos,
    );
  }

  static Future<List<Map<String, dynamic>>> borradoresPedido() async {
    if (!disponible) return [];
    return (await OfflineDatabase.pendientes(await _scope()))
        .where((e) => e['accion'] == 'pedido_borrador').toList();
  }

  static Future<void> descartarOperacion(String clave) async {
    if (disponible) await OfflineDatabase.confirmar(clave);
  }

  static Future<void> eliminarBorrador(String clave) async {
    if (disponible) await OfflineDatabase.confirmar(clave);
  }

  /// Requiere confirmación explícita. La clave del borrador se conserva en
  /// todos los reintentos para que la API no pueda duplicar la compra.
  static Future<Map<String, dynamic>> confirmarBorrador(
      Map<String, dynamic> borrador) async {
    final clave = borrador['clave'] as String;
    final datos = Map<String, dynamic>.from(borrador['datos'] as Map);
    try {
      int? direccionId = datos['id_direccion'] as int?;
      if (datos['tipo_entrega'] == 'Delivery' &&
          (direccionId == null || direccionId <= 0)) {
        final direccion = (datos['direccion'] as String? ?? '').trim();
        if (direccion.length < 5) {
          throw StateError('Falta dirección de entrega. Prepara nuevamente tu pedido.');
        }
        direccionId = await ApiService.registrarDireccion(
          idUsuario: await usuarioActual(),
          direccion: direccion,
          claveOperacion: '${clave}D',
        );
      }
      await ApiService.actualizarTelefonoUsuario(
        idUsuario: await usuarioActual(),
        telefono: datos['telefono'] as String,
      );
      final resultado = await ApiService.registrarPedido(
        idUsuario: await usuarioActual(),
        tipoEntrega: datos['tipo_entrega'] as String,
        metodoPago: datos['metodo_pago'] as String,
        idDireccion: direccionId,
        items: (datos['items'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList(),
        totalEsperado: (datos['total_esperado'] as num).toDouble(),
        claveOperacion: clave,
      );
      await eliminarBorrador(clave);
      return resultado;
    } catch (e) {
      if (disponible) await OfflineDatabase.registrarError(clave, e.toString());
      rethrow;
    }
  }
}
