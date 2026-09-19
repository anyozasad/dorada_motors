import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido.dart';

class LocalStore {
  static const _sessionUserId = 'session_user_id';
  static const _sessionName = 'session_name';
  static const _sessionEmail = 'session_email';
  static const _favorites = 'favorites';
  static const _cart = 'cart';
  static const _orders = 'orders';

  static Future<void> saveSession({
    required int userId,
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserId, userId.toString());
    await prefs.setString(_sessionName, name.trim());
    await prefs.setString(_sessionEmail, email.trim().toLowerCase());
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionUserId);
    final name = prefs.getString(_sessionName);
    final email = prefs.getString(_sessionEmail);

    if (userId == null || name == null || email == null) {
      return null;
    }

    return {
      'id': userId,
      'name': name,
      'email': email,
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserId);
    await prefs.remove(_sessionName);
    await prefs.remove(_sessionEmail);
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
