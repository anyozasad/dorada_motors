import 'package:dorada_motors/services/api_service.dart';
import 'package:dorada_motors/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.configurarServidor('http://localhost/dorada_api');
  });

  Future<void> guardarCliente() => LocalStore.saveSession(
        userId: 8,
        name: 'Cliente de prueba',
        email: 'cliente@example.test',
        token: List.filled(64, 'a').join(),
      );

  test('Sin token local no intenta autenticar al cliente', () async {
    final client = MockClient((_) async => throw StateError('No debió llamar la API'));
    expect(await ApiService.verificarSesion(client: client), isFalse);
    client.close();
  });

  test('MySQL confirma sesión activa y se mantiene Flutter autenticado', () async {
    await guardarCliente();
    final client = MockClient((request) async {
      expect(request.url.path, '/dorada_api/cuenta.php');
      expect(request.headers['Authorization'], 'Bearer ${List.filled(64, 'a').join()}');
      return http.Response(
        '{"estado":true,"usuario":{"id_usuario":8,"correo":"cliente@example.test"}}',
        200,
      );
    });
    expect(await ApiService.verificarSesion(client: client), isTrue);
    client.close();
  });

  test('Token vencido devuelve false para pedir nuevo inicio de sesión', () async {
    await guardarCliente();
    final client = MockClient((_) async => http.Response(
          '{"estado":false,"mensaje":"Tu sesión venció"}',
          401,
        ));
    expect(await ApiService.verificarSesion(client: client), isFalse);
    client.close();
  });

  test('Con Apache caído no se elimina la sesión local por error de red', () async {
    await guardarCliente();
    final client = MockClient((_) async => throw Exception('Servidor desconectado'));
    expect(await ApiService.verificarSesion(client: client), isNull);
    expect(await LocalStore.getToken(), isNotNull);
    client.close();
  });

  test('Un fallo HTTP 500 o respuesta inválida no se confunde con token vencido', () async {
    await guardarCliente();
    final error = MockClient((_) async => http.Response('Error de MySQL', 500));
    expect(await ApiService.verificarSesion(client: error), isNull);
    error.close();

    final respuestaInvalida = MockClient((_) async => http.Response(
          '{"estado":true,"usuario":null}',
          200,
        ));
    expect(await ApiService.verificarSesion(client: respuestaInvalida), isNull);
    respuestaInvalida.close();
  });
}
