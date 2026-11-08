import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Presentación consistente de fotos en catálogo, detalle, carrito y checkout.
/// Si XAMPP no responde o una ruta no existe, se muestra el logo local sin
/// dejar el cuadro de producto en blanco.
class ProductImage extends StatelessWidget {
  static const String fallbackAsset = 'assets/imagenes/logo_adn_imports.png';

  final String source;
  final BoxFit fit;
  final String? semanticLabel;

  const ProductImage({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  Widget _fallback() => Image.asset(
        fallbackAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 38,
            color: AppColors.muted,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ruta = source.trim();
    if (ruta.isEmpty) return _fallback();

    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return Image.network(
        ruta,
        fit: fit,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Opacity(opacity: .35, child: _fallback()),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.goldDark,
                  ),
                ),
              ),
            ],
          );
        },
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return Image.asset(
      ruta,
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }
}
