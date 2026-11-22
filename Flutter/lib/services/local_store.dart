import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido.dart';
import 'offline_store.dart';

class LocalStore {
  static const _sessionUserId = 'session_user_id';
  static const _sessionName = 'session_name';
  static const _sessionEmail = 'session_email';
  static const _sessionToken = 'session_token';
  static const _apiBaseUrl = 'api_base_url';
  static const _favorites = 'favorites';
  static const _cart = 'cart';
  static const _guestCart = 'guest_cart';
  static const _orders = 'orders';

  static Future<void> saveSession({
    required int userId,
    required String name,
    required String email,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserId, userId.toString());
    await prefs.setString(_sessionName, name.trim());
    await prefs.setString(_sessionEmail, email.trim().toLowerCase());
    await prefs.setString(_sessionToken, token);
  }

  static Future<void> updateSessionProfile({
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_sessionToken) ?? '').isEmpty) {
      throw StateError('No hay sesión activa para actualizar');
    }
    await prefs.setString(_sessionName, name.trim());
    await prefs.setString(_sessionEmail, email.trim().toLowerCase());
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionUserId);
    final name = prefs.getString(_sessionName);
    final email = prefs.getString(_sessionEmail);

    if (userId == null || name == null || email == null ||
        (prefs.getString(_sessionToken) ?? '').isEmpty) {
      return null;
    }

    return {
      'id': userId,
      'name': name,
      'email': email,
    };
  }

  static Future<String?> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiBaseUrl);
  }

  static Future<void> saveApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrl, url.trim());
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_sessionToken);
    return (token == null || token.isEmpty) ? null : token;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserId);
    await prefs.remove(_sessionName);
    await prefs.remove(_sessionEmail);
    await prefs.remove(_sessionToken);
  }

  // El respaldo móvil debe estar aislado por cuenta. Los datos confirmados
  // se consultan siempre desde MySQL al recuperar conexión.
  static Future<Map<int, int>> getCartForUser(int userId) async {
    if (userId <= 0) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cart_user_$userId');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (int.tryParse(entry.key) != null &&
              entry.value is num && (entry.value as num).toInt() > 0)
            int.parse(entry.key): (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveCartForUser(int userId, Map<int, int> cart) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final data = {
      for (final entry in cart.entries)
        if (entry.key > 0 && entry.value > 0)
          entry.key.toString(): entry.value,
    };
    await prefs.setString('cart_user_$userId', jsonEncode(data));
  }

  static Future<Set<int>> getFavoritesForUser(int userId) async {
    if (userId <= 0) return {};
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('favorites_user_$userId') ?? <String>[])
        .map(int.tryParse).whereType<int>().where((id) => id > 0).toSet();
  }

  static Future<void> saveFavoritesForUser(int userId, Set<int> favorites) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites_user_$userId',
        favorites.where((id) => id > 0).map((id) => id.toString()).toList());
  }

  static Future<void> clearUserShoppingCache(
    int userId, {
    bool conservarPendientes = false,
  }) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    // Quitar los datos que quedarían expuestos en las vistas de invitado.
    await prefs.remove('cart_user_$userId');
    await prefs.remove('favorites_user_$userId');
    if (conservarPendientes) {
      // Una sesión vencida NO significa que el cliente haya elegido borrar
      // su trabajo. SQLite guarda las colas por usuario y servidor y solo
      // volverán a mostrarse cuando inicie sesión con la misma cuenta.
      return;
    }
    await prefs.remove('offline_cart_pending_$userId');
    await prefs.remove('offline_fav_pending_$userId');
    await prefs.remove('offline_orders_user_$userId');
    await OfflineStore.limpiarCuenta(userId);
  }

  static Future<Set<int>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_favorites) ?? <String>[];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> saveFavorites(Set<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favorites,
      favorites.map((e) => e.toString()).toList(),
    );
  }

  static Future<Map<int, int>> getCart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cart);
    if (raw == null || raw.isEmpty) return {};

    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return decoded.map(
      (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
    );
  }

  static Future<void> saveCart(Map<int, int> cart) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = cart.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString(_cart, jsonEncode(encoded));
  }

  static Future<Map<int, int>> getGuestCart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestCart);
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in data.entries)
          if (int.tryParse(entry.key) != null &&
              entry.value is num && (entry.value as num).toInt() > 0)
            int.parse(entry.key): (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveGuestCart(Map<int, int> cart) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = cart.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString(_guestCart, jsonEncode(encoded));
  }

  static Future<void> clearGuestCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestCart);
  }

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cart);
  }

  static Future<List<Pedido>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_orders);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Pedido.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  static Future<void> addOrder(Pedido order) async {
    final orders = await getOrders();
    orders.insert(0, order);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _orders,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
  }
}
