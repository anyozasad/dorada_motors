import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost/dorada_api';
    }

    return 'http://10.0.2.2/dorada_api';
  }

  static Future<dynamic> _getJson(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} al consultar $endpoint');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map && decoded['estado'] == false) {
      throw Exception(
        decoded['mensaje']?.toString() ?? 'Error devuelto por la API',
      );
    }

    return decoded;
  }

  static Future<dynamic> _postJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Respuesta inválida del servidor en $endpoint');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map && decoded['mensaje'] != null) {
        throw Exception(decoded['mensaje'].toString());
      }
      throw Exception('HTTP ${response.statusCode} al consultar $endpoint');
    }

    if (decoded is Map && decoded['estado'] == false) {
      throw Exception(
        decoded['mensaje']?.toString() ?? 'Error devuelto por la API',
      );
    }

    return decoded;
  }

  static Future<List<dynamic>> _getList(String endpoint) async {
    final decoded = await _getJson(endpoint);

    if (decoded is List) {
      return decoded;
    }

    throw Exception('Respuesta inválida de $endpoint');
  }

  static Future<List<dynamic>> obtenerProductos() =>
      _getList('productos.php');

  static Future<List<dynamic>> obtenerUsuarios() =>
      _getList('usuarios.php');

  static Future<List<dynamic>> obtenerPedidos() =>
      _getList('pedidos.php');

  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final decoded = await _postJson('login.php', {
      'correo': correo.trim().toLowerCase(),
      'contrasena': contrasena,
    });

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Respuesta inválida del inicio de sesión');
  }

  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombres,
    required String apellidos,
    required String correo,
    required String contrasena,
    String telefono = '',
  }) async {
    final decoded = await _postJson('usuarios.php', {
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'correo': correo.trim().toLowerCase(),
      'contrasena': contrasena,
      'telefono': telefono.trim(),
    });

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Respuesta inválida al registrar usuario');
  }

  static Future<Map<String, dynamic>> obtenerDashboard() async {
    final decoded = await _getJson('dashboard_api.php');

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Respuesta inválida del dashboard');
  }
}
