import 'package:dorada_motors/services/api_server_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admite IP sola y añade la carpeta de la API', () {
    expect(ApiServerAddress.normalizar('192.168.1.10', telefonoAndroid: true),
        'http://192.168.1.10/dorada_api');
    expect(ApiServerAddress.normalizar('192.168.1.10:8081', telefonoAndroid: true),
        'http://192.168.1.10:8081/dorada_api');
  });

  test('Respeta URL completa sin duplicar dorada_api', () {
    expect(ApiServerAddress.normalizar(' https://mi-servidor.test/dorada_api/ ',
        telefonoAndroid: false), 'https://mi-servidor.test/dorada_api');
    expect(ApiServerAddress.normalizar('http://10.0.2.2/dorada_api',
        telefonoAndroid: true), 'http://10.0.2.2/dorada_api');
    expect(ApiServerAddress.normalizar('https://servidor.pe/tec/dorada_api',
        telefonoAndroid: true), 'https://servidor.pe/tec/dorada_api');
    expect(ApiServerAddress.normalizar('https://servidor.pe/tec',
        telefonoAndroid: true), 'https://servidor.pe/tec/dorada_api');
  });

  test('Un celular físico no debe apuntar a localhost', () {
    expect(
      () => ApiServerAddress.normalizar('http://localhost/dorada_api',
          telefonoAndroid: true),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ApiServerAddress.normalizar('127.0.0.1', telefonoAndroid: true),
      throwsA(isA<FormatException>()),
    );
  });

  test('No acepta rutas ajenas a la API ni credenciales', () {
    for (final url in <String>[
      '192.168.1.10/admin_login.php',
      'http://192.168.1.10/dorada_api/productos.php',
      'http://usuario:clave@192.168.1.10/dorada_api',
      'https://192.168.1.10/dorada_api?token=123',
      'ftp://192.168.1.10/dorada_api',
    ]) {
      expect(
        () => ApiServerAddress.normalizar(url, telefonoAndroid: true),
        throwsA(isA<FormatException>()),
        reason: url,
      );
    }
  });

  test('La dirección vacía permite restablecer una configuración', () {
    expect(ApiServerAddress.normalizar(' ', telefonoAndroid: false), '');
    expect(ApiServerAddress.normalizar('localhost', telefonoAndroid: false),
        'http://localhost/dorada_api');
  });
}
