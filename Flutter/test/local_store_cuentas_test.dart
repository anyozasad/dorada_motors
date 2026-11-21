import 'package:dorada_motors/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Cada cliente tiene su propio carrito y favoritos', () async {
    await LocalStore.saveCartForUser(11, <int, int>{1: 2, 3: 1});
    await LocalStore.saveFavoritesForUser(11, <int>{1, 3});
    await LocalStore.saveCartForUser(22, <int, int>{5: 4});
    await LocalStore.saveFavoritesForUser(22, <int>{5});

    expect(await LocalStore.getCartForUser(11), <int, int>{1: 2, 3: 1});
    expect(await LocalStore.getCartForUser(22), <int, int>{5: 4});
    expect(await LocalStore.getFavoritesForUser(11), <int>{1, 3});
    expect(await LocalStore.getFavoritesForUser(22), <int>{5});
  });

  test('Cerrar la cuenta elimina solo sus datos locales', () async {
    await LocalStore.saveCartForUser(11, <int, int>{1: 1});
    await LocalStore.saveCartForUser(22, <int, int>{5: 3});
    await LocalStore.saveFavoritesForUser(11, <int>{1});
    await LocalStore.saveFavoritesForUser(22, <int>{5});

    await LocalStore.clearUserShoppingCache(11);

    expect(await LocalStore.getCartForUser(11), isEmpty);
    expect(await LocalStore.getFavoritesForUser(11), isEmpty);
    expect(await LocalStore.getCartForUser(22), <int, int>{5: 3});
    expect(await LocalStore.getFavoritesForUser(22), <int>{5});
  });

  test('No muestra productos de otra cuenta ni datos locales corruptos', () async {
    expect(await LocalStore.getCartForUser(0), isEmpty);
    expect(await LocalStore.getFavoritesForUser(0), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart_user_11', 'json-no-valido');
    expect(await LocalStore.getCartForUser(11), isEmpty);

    await LocalStore.saveCartForUser(11, <int, int>{1: -3, 0: 4, 2: 2});
    expect(await LocalStore.getCartForUser(11), <int, int>{2: 2});
  });
}
