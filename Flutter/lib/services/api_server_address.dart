import 'package:flutter/foundation.dart';

/// Acepta IP local de XAMPP o HTTPS público con carpeta PHP.
class ApiServerAddress {
  static String normalizar(String valor, {bool? telefonoAndroid}) {
    final entrada = valor.trim();
    if (entrada.isEmpty) return '';
    final candidata = entrada.contains('://') ? entrada : 'http://$entrada';
    final uri = Uri.tryParse(candidata);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Ingresa la IP o URL válida del servidor.');
    }
    final android = telefonoAndroid ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (android && const ['localhost', '127.0.0.1'].contains(uri.host.toLowerCase())) {
      throw const FormatException(
          'En un celular debes usar la IP Wi-Fi de tu PC, no localhost.');
    }

    // Ejemplo de hosting: https://empresa.pe/tec/dorada_api
    var ruta = uri.path;
    while (ruta.endsWith('/')) {
      ruta = ruta.substring(0, ruta.length - 1);
    }
    if (ruta.toLowerCase().endsWith('.php') || ruta.split('/').contains('..')) {
      throw const FormatException(
          'Escribe la dirección de la carpeta dorada_api, no una página PHP.');
    }
    final rutaApi = ruta.endsWith('/dorada_api')
        ? ruta
        : '$ruta/dorada_api';
    return uri.replace(path: rutaApi, query: null, fragment: null).toString();
  }
}
