import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'offline_database.dart';

import '../models/pedido.dart';

/// Respaldo móvil persistente. Un catálogo nunca se mezcla con otra API ni
/// los datos privados de un cliente con otra cuenta.
class OfflineStore {
  static bool get _sqliteAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<String> _scopeUsuario(int usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final servidor = prefs.getString('api_base_url') ?? 'http://10.0.2.2/dorada_api';
    return 'user:${_servidor(servidor)}:$usuario';
  }

  static String _servidor(String apiUrl) =>
      base64Url.encode(utf8.encode(apiUrl.trim().toLowerCase()));

  static String _catalogKey(String apiUrl) =>
      'offline_catalog_v1_${_servidor(apiUrl)}';

  static Future<void> guardarCatalogo(
    String apiUrl,
    List<dynamic> productos,
  ) async {
    if (_sqliteAndroid) {
      await OfflineDatabase.guardar(
        'catalogo:${_servidor(apiUrl)}', 'productos', productos,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_catalogKey(apiUrl), jsonEncode(productos));
  }

  static Future<List<dynamic>?> obtenerCatalogo(String apiUrl) async {
    if (_sqliteAndroid) {
      final datos = await OfflineDatabase.leer(
        'catalogo:${_servidor(apiUrl)}', 'productos',
      );
      if (datos is List) return datos;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogKey(apiUrl));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<int, int>> carritoPendiente(int usuario) async {
    if (_sqliteAndroid && usuario > 0) {
      final datos = await OfflineDatabase.leer(
        await _scopeUsuario(usuario), 'carrito_pendiente',
      );
      if (datos is Map) {
        return {
          for (final e in datos.entries)
            if (int.tryParse(e.key.toString()) != null && e.value is num)
              int.parse(e.key.toString()): (e.value as num).toInt(),
        };
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_cart_pending_$usuario');
    if (usuario <= 0 || raw == null) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      return {
        for (final e in data.entries)
          if (int.tryParse(e.key.toString()) != null && e.value is num)
            int.parse(e.key.toString()): (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> guardarCarritoPendiente(
    int usuario,
    Map<int, int> pendientes,
  ) async {
    if (usuario <= 0) return;
    if (_sqliteAndroid) {
      final scope = await _scopeUsuario(usuario);
      await OfflineDatabase.guardar(scope, 'carrito_pendiente', {
        for (final e in pendientes.entries) e.key.toString(): e.value,
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline_cart_pending_$usuario',
      jsonEncode({
        for (final e in pendientes.entries)
          if (e.key > 0) e.key.toString(): e.value,
      }),
    );
  }

  static Future<void> marcarCarrito(
    int usuario,
    int producto,
    int cantidad,
  ) async {
    final data = await carritoPendiente(usuario);
    data[producto] = cantidad < 0 ? 0 : cantidad;
    await guardarCarritoPendiente(usuario, data);
  }

  static Future<Map<int, bool>> favoritosPendientes(int usuario) async {
    if (_sqliteAndroid && usuario > 0) {
      final datos = await OfflineDatabase.leer(
        await _scopeUsuario(usuario), 'favoritos_pendientes',
      );
      if (datos is Map) {
        return {
          for (final e in datos.entries)
            if (int.tryParse(e.key.toString()) != null && e.value is bool)
              int.parse(e.key.toString()): e.value as bool,
        };
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_fav_pending_$usuario');
    if (usuario <= 0 || raw == null) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      return {
        for (final e in data.entries)
          if (int.tryParse(e.key.toString()) != null && e.value is bool)
            int.parse(e.key.toString()): e.value as bool,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> guardarFavoritosPendientes(
    int usuario,
    Map<int, bool> pendientes,
  ) async {
    if (usuario <= 0) return;
    if (_sqliteAndroid) {
      await OfflineDatabase.guardar(
        await _scopeUsuario(usuario), 'favoritos_pendientes', {
          for (final e in pendientes.entries) e.key.toString(): e.value,
        },
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline_fav_pending_$usuario',
      jsonEncode({
        for (final e in pendientes.entries)
          if (e.key > 0) e.key.toString(): e.value,
      }),
    );
  }

  static Future<void> marcarFavorito(
    int usuario,
    int producto,
    bool agregar,
  ) async {
    final data = await favoritosPendientes(usuario);
    data[producto] = agregar;
    await guardarFavoritosPendientes(usuario, data);
  }

  static Future<void> guardarPedidos(int usuario, List<Pedido> pedidos) async {
    if (usuario <= 0) return;
    if (_sqliteAndroid) {
      await OfflineDatabase.guardar(
        await _scopeUsuario(usuario), 'pedidos',
        pedidos.map((p) => p.toJson()).toList(),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline_orders_user_$usuario',
      jsonEncode(pedidos.map((p) => p.toJson()).toList()),
    );
  }

  static Future<List<Pedido>> obtenerPedidos(int usuario) async {
    if (usuario <= 0) return [];
    if (_sqliteAndroid) {
      final datos = await OfflineDatabase.leer(
        await _scopeUsuario(usuario), 'pedidos',
      );
      if (datos is List) {
        return datos.whereType<Map>().map(
          (row) => Pedido.fromJson(Map<String, dynamic>.from(row)),
        ).toList();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_orders_user_$usuario');
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return data.whereType<Map>().map(
        (v) => Pedido.fromJson(Map<String, dynamic>.from(v)),
      ).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> limpiarCuenta(int usuario) async {
    if (usuario <= 0) return;
    if (_sqliteAndroid) {
      await OfflineDatabase.limpiarScope(await _scopeUsuario(usuario));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_cart_pending_$usuario');
    await prefs.remove('offline_fav_pending_$usuario');
    await prefs.remove('offline_orders_user_$usuario');
  }
}
