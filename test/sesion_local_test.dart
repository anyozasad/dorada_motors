import 'package:dorada_motors/services/local_store.dart';
import 'package:dorada_motors/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el inicio y cierre de sesión guardan y eliminan el token', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await LocalStore.getToken(), isNull);
    expect(await LocalStore.getSession(), isNull);

    await LocalStore.saveSession(
      userId: 7,
      name: 'Cliente de prueba',
      email: 'cliente@example.com',
      token: 'token_de_prueba',
    );

    final session = await LocalStore.getSession();
    expect(session?['id'], '7');
    expect(session?['name'], 'Cliente de prueba');
    expect(await LocalStore.getToken(), 'token_de_prueba');

    await LocalStore.logout();
    expect(await LocalStore.getToken(), isNull);
    expect(await LocalStore.getSession(), isNull);
  });

  test('una sesión antigua sin token exige autenticarse', () async {
    SharedPreferences.setMockInitialValues({
      'session_user_id': '4',
      'session_name': 'Cliente anterior',
      'session_email': 'anterior@example.com',
    });
    expect(await LocalStore.getSession(), isNull);
  });

  test('la configuración del servidor PHP se guarda y se usa', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.saveApiBaseUrl('http://192.168.1.10/dorada_api');
    expect(await LocalStore.getApiBaseUrl(), 'http://192.168.1.10/dorada_api');
    ApiService.configurarServidor('http://192.168.1.10/dorada_api/');
    expect(ApiService.baseUrl, 'http://192.168.1.10/dorada_api');
    ApiService.configurarServidor(null);
  });

  test('el carrito y favoritos conservan sus valores locales', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.saveFavorites({2, 5});
    await LocalStore.saveCart({2: 1, 5: 3});
    expect(await LocalStore.getFavorites(), {2, 5});
    expect(await LocalStore.getCart(), {2: 1, 5: 3});
    await LocalStore.clearCart();
    expect(await LocalStore.getCart(), isEmpty);
  });
}
