import 'package:flutter_test/flutter_test.dart';
import 'package:dorada_motors/services/product_image_url.dart';

void main() {
  const api = 'http://192.168.1.15/dorada_api';

  test('muestra las fotos empaquetadas de los productos iniciales', () {
    expect(
      ProductImageUrl.resolver(
        'assets/imagenes/01_kit_transmision_dtiex.png',
        api,
      ),
      'assets/imagenes/01_kit_transmision_dtiex.png',
    );
  });

  test('muestra las fotos nuevas subidas desde el dashboard PHP', () {
    expect(
      ProductImageUrl.resolver('uploads/productos/foto.jpg', api),
      'http://192.168.1.15/dorada_api/uploads/productos/foto.jpg',
    );
  });

  test('corrige fotos con localhost al usar un celular real', () {
    expect(
      ProductImageUrl.resolver(
        'http://localhost/dorada_api/uploads/productos/foto.jpg',
        api,
      ),
      'http://192.168.1.15/dorada_api/uploads/productos/foto.jpg',
    );
  });

  test('admite una API en una carpeta de hosting', () {
    expect(
      ProductImageUrl.resolver(
        'uploads/productos/foto.jpg',
        'https://ejemplo.pe/tec/dorada_api',
      ),
      'https://ejemplo.pe/tec/dorada_api/uploads/productos/foto.jpg',
    );
  });

  test('usa imagen local si no hay foto y bloquea rutas inseguras', () {
    expect(
      ProductImageUrl.resolver('', api),
      ProductImageUrl.fallbackAsset,
    );
    expect(
      ProductImageUrl.resolver('../../privado.jpg', api),
      ProductImageUrl.fallbackAsset,
    );
  });
}
