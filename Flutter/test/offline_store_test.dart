import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dorada_motors/services/offline_store.dart';
import 'package:dorada_motors/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Catálogo guardado funciona sin API y no se mezcla entre servidores',
      () async {
    const servidorA = 'http://192.168.1.10/dorada_api';
    const servidorB = 'http://192.168.1.20/dorada_api';
    await OfflineStore.guardarCatalogo(servidorA, [
      {'id_producto': 1, 'nombre_producto': 'Repuesto guardado', 'stock': 4}
    ]);

    final copia = await OfflineStore.obtenerCatalogo(servidorA);
    expect(copia, isNotNull);
    expect((copia!.first as Map)['nombre_producto'], 'Repuesto guardado');
    expect(await OfflineStore.obtenerCatalogo(servidorB), isNull);
  });

  test('Una cantidad pendiente reemplaza a la anterior y conserva el borrado',
      () async {
    await OfflineStore.marcarCarrito(9, 15, 3);
    await OfflineStore.marcarCarrito(9, 15, 2);
    await OfflineStore.marcarCarrito(9, 16, 0);

    expect(await OfflineStore.carritoPendiente(9), {15: 2, 16: 0});
    expect(await OfflineStore.carritoPendiente(10), isEmpty);

    final pendientes = await OfflineStore.carritoPendiente(9);
    pendientes.remove(15);
    await OfflineStore.guardarCarritoPendiente(9, pendientes);
    expect(await OfflineStore.carritoPendiente(9), {16: 0});
  });

  test('Favoritos offline guardan la última acción sin duplicarla', () async {
    await OfflineStore.marcarFavorito(4, 8, true);
    await OfflineStore.marcarFavorito(4, 8, false);
    await OfflineStore.marcarFavorito(4, 9, true);
    expect(await OfflineStore.favoritosPendientes(4), {8: false, 9: true});
    expect(await OfflineStore.favoritosPendientes(5), isEmpty);
  });

  test('La copia privada del usuario se puede borrar al cerrar sesión',
      () async {
    await OfflineStore.marcarCarrito(7, 11, 2);
    await OfflineStore.marcarFavorito(7, 11, true);
    await OfflineStore.limpiarCuenta(7);
    expect(await OfflineStore.carritoPendiente(7), isEmpty);
    expect(await OfflineStore.favoritosPendientes(7), isEmpty);
  });

  test('Solo los errores de red permiten registrar cambios offline', () {
    expect(ApiService.esErrorConexion(
      Exception('SocketException: Connection refused'),
    ), isTrue);
    expect(ApiService.esErrorConexion(
      Exception('TimeoutException after 0:00:08.000000'),
    ), isTrue);
    expect(ApiService.esErrorConexion(
      Exception('La cantidad supera el stock disponible'),
    ), isFalse);
    expect(ApiService.esErrorConexion(
      Exception('Contraseña incorrecta'),
    ), isFalse);
  });
}
