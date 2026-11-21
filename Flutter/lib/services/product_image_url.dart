/// Resuelve fotografías del catálogo tanto para el APK como para Flutter Web.
/// Las fotos de demostración se incluyen en assets; las nuevas subidas por PHP
/// se obtienen desde el mismo servidor de la API configurado en el dispositivo.
class ProductImageUrl {
  static const fallbackAsset = 'assets/imagenes/logo_adn_imports.png';

  static bool _servidorLocal(String host) {
    final normalizado = host.toLowerCase();
    return normalizado == 'localhost' ||
        normalizado == '127.0.0.1' ||
        normalizado == '10.0.2.2';
  }

  static String resolver(String? origen, String apiBaseUrl) {
    var ruta = (origen ?? '').trim().replaceAll('\\', '/');
    if (ruta.isEmpty) return fallbackAsset;

    // Las imágenes iniciales están empaquetadas con Flutter y funcionan
    // incluso en el teléfono, sin consultar a XAMPP por cada fotografía.
    if (ruta.startsWith('assets/imagenes/')) return ruta;

    final servidor = Uri.tryParse(
      apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/',
    );
    if (servidor == null ||
        (servidor.scheme != 'http' && servidor.scheme != 'https') ||
        servidor.host.isEmpty) {
      return fallbackAsset;
    }

    final absoluta = Uri.tryParse(ruta);
    if (absoluta != null && absoluta.hasScheme) {
      if (absoluta.scheme != 'http' && absoluta.scheme != 'https') {
        return fallbackAsset;
      }
      // Un URL guardado desde el dashboard usando localhost funciona en la PC,
      // pero en Android localhost es el propio teléfono, no el servidor PHP.
      if (_servidorLocal(absoluta.host) &&
          !_servidorLocal(servidor.host)) {
        // Mantener la carpeta del servidor PHP configurado, que puede vivir
        // bajo /tec/dorada_api; no copiar la IP/puerto/localhost de la foto.
        var relativa = absoluta.path;
        final carpetaApi = relativa.lastIndexOf('/dorada_api/');
        if (carpetaApi >= 0) {
          relativa = relativa.substring(carpetaApi + '/dorada_api/'.length);
        } else {
          relativa = relativa.startsWith('/')
              ? relativa.substring(1)
              : relativa;
        }
        if (relativa.split('/').contains('..')) return fallbackAsset;
        return servidor.resolve(relativa).toString();
      }
      return absoluta.toString();
    }

    if (ruta.startsWith('//')) {
      return '${servidor.scheme}:$ruta';
    }

    while (ruta.startsWith('./')) {
      ruta = ruta.substring(2);
    }
    if (ruta.startsWith('PHP/dorada_api/')) {
      ruta = ruta.substring('PHP/dorada_api/'.length);
    } else if (ruta.startsWith('dorada_api/')) {
      ruta = ruta.substring('dorada_api/'.length);
    }
    if (ruta.startsWith('/uploads/') || ruta.startsWith('/assets/')) {
      ruta = ruta.substring(1);
    }
    // No permitir rutas relativas que escapen del directorio público de la API.
    if (ruta.split('/').contains('..')) return fallbackAsset;

    return servidor.resolve(ruta).toString();
  }
}
