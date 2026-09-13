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

  static Future<List<dynamic>> _getList(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} al consultar $endpoint');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map && decoded['estado'] == false) {
      throw Exception(decoded['mensaje'] ?? 'Error devuelto por la API');
    }

    throw Exception('Respuesta inválida de $endpoint');
  }

  static Future<List<dynamic>> obtenerProductos() =>
      _getList('productos.php');

  static Future<List<dynamic>> obtenerUsuarios() =>
      _getList('usuarios.php');

  static Future<List<dynamic>> obtenerPedidos() =>
      _getList('pedidos.php');

  static Future<Map<String, dynamic>> obtenerDashboard() async {
    final resultados = await Future.wait<List<dynamic>>([
      obtenerProductos(),
      obtenerUsuarios(),
      obtenerPedidos(),
    ]);

    final productos = resultados[0];
    final usuarios = resultados[1];
    final pedidos = resultados[2];

    double totalVentas = 0;
    for (final item in pedidos) {
      if (item is Map) {
        final value = item['total'];
        totalVentas += double.tryParse(value?.toString() ?? '0') ?? 0;
      }
    }

    final ultimosPedidos = pedidos.take(5).toList();

    return {
      'productos': productos.length,
      'usuarios': usuarios.length,
      'pedidos': pedidos.length,
      'ventas': totalVentas,
      'ultimos_pedidos': ultimosPedidos,
    };
  }
}
