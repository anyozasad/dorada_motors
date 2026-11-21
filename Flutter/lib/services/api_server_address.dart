import 'package:flutter/foundation.dart';

/// Normaliza la dirección que el cliente escribe para conectar con XAMPP.
/// Admite únicamente http(s) y la ruta conocida de Dorada Motors.
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
      throw const FormatException('Ingresa la IP o URL válida de tu computadora.');
    }
    final android = telefonoAndroid ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (android && const ['localhost', '127.0.0.1'].contains(uri.host.toLowerCase())) {
      throw const FormatException(
          'En un celular debes usar la IP Wi-Fi de tu PC, no localhost.');
    }

    final ruta = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (ruta.isNotEmpty && ruta != '/dorada_api') {
      throw const FormatException(
          'La dirección debe terminar en /dorada_api, no en una página PHP.');
    }
    return uri.replace(path: '/dorada_api', query: null, fragment: null).toString();
  }
}
