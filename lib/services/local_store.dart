import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido.dart';

class LocalStore {
  static const _userName = 'user_name';
  static const _userEmail = 'user_email';
  static const _userPasswordHash = 'user_password_hash';
  static const _sessionEmail = 'session_email';
  static const _favorites = 'favorites';
  static const _cart = 'cart';
  static const _orders = 'orders';

  static String _hashPassword(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static Future<String?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    if (name.trim().length < 3) return 'Ingresa tu nombre completo.';
    if (!cleanEmail.contains('@')) return 'Ingresa un correo válido.';
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';

    await prefs.setString(_userName, name.trim());
    await prefs.setString(_userEmail, cleanEmail);
    await prefs.setString(_userPasswordHash, _hashPassword(password));
    await prefs.setString(_sessionEmail, cleanEmail);
    return null;
  }

  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_userEmail);
    final savedHash = prefs.getString(_userPasswordHash);
    final cleanEmail = email.trim().toLowerCase();

    if (savedEmail == null || savedHash == null) {
      return 'Aún no existe una cuenta registrada en este dispositivo.';
    }
    if (savedEmail != cleanEmail || savedHash != _hashPassword(password)) {
      return 'Correo o contraseña incorrectos.';
    }

    await prefs.setString(_sessionEmail, cleanEmail);
    return null;
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionEmail = prefs.getString(_sessionEmail);
    final savedEmail = prefs.getString(_userEmail);
    final savedName = prefs.getString(_userName);

    if (sessionEmail == null || savedEmail == null || savedName == null) {
      return null;
    }
    if (sessionEmail != savedEmail) return null;

    return {'name': savedName, 'email': savedEmail};
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
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
