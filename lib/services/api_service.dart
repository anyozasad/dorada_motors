import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_store.dart';

class ApiService {
  static String get baseUrl {
    const configurada = String.fromEnvironment('API_BASE_URL');
    if (configurada.isNotEmpty) {
      return configurada.endsWith('/')
          ? configurada.substring(0, configurada.length - 1)
          : configurada;
    }

    if (kIsWeb) {
      return 'http://localhost/dorada_api';
    }

    return 'http://10.0.2.2/dorada_api';
  }

  static Future<Map<String, String>> _headers({bool enviarJson = false}) async {
    final token = await LocalStore.getToken();
    return {
      'Accept': 'application/json',
      if (enviarJson) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _getJson(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: await _headers(),
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
          headers: await _headers(enviarJson: true),
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

  static Future<dynamic> _putJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/$endpoint'),
          headers: await _headers(enviarJson: true),
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

  static Future<void> cerrarSesion() async {
    final token = await LocalStore.getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/cliente_logout.php'),
        headers: await _headers(enviarJson: true),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // La sesión local siempre puede cerrarse sin conexión.
    }
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

  static Future<List<dynamic>> obtenerCategorias() =>
      _getList('categorias.php');

  static Future<List<dynamic>> obtenerMarcas() =>
      _getList('marcas.php');

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

  static Future<Map<String, dynamic>> actualizarTelefonoUsuario({
    required int idUsuario,
    required String telefono,
  }) async {
    final decoded = await _putJson('usuarios.php', {
      'id_usuario': idUsuario,
      'telefono': telefono.trim(),
    });

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Respuesta inválida al actualizar teléfono');
  }

  static Future<int> registrarDireccion({
    required int idUsuario,
    required String direccion,
    String referencia = '',
  }) async {
    final decoded = await _postJson('direcciones.php', {
      'id_usuario': idUsuario,
      'departamento': 'Ucayali',
      'provincia': 'Coronel Portillo',
      'distrito': 'Callería',
      'direccion_detalle': direccion.trim(),
      'referencia': referencia.trim(),
    });

    if (decoded is Map) {
      final id = int.tryParse(decoded['id_direccion']?.toString() ?? '') ?? 0;
      if (id > 0) return id;
    }

    throw Exception('No se pudo registrar la dirección');
  }

  static Future<Map<String, dynamic>> registrarPedido({
    required int idUsuario,
    required String tipoEntrega,
    required String metodoPago,
    required List<Map<String, dynamic>> items,
    int? idDireccion,
    double costoEntrega = 0,
  }) async {
    final decoded = await _postJson('pedidos.php', {
      'id_usuario': idUsuario,
      'id_direccion': idDireccion,
      'tipo_entrega': tipoEntrega,
      'estado_pedido': 'Pendiente',
      'metodo_pago': metodoPago,
      'estado_pago': 'Pendiente',
      'costo_entrega': costoEntrega,
      'items': items,
    });

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Respuesta inválida al registrar el pedido');
  }

  static Future<List<dynamic>> obtenerPedidosUsuario(int idUsuario) =>
      _getList('pedidos.php?id_usuario=$idUsuario');

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
