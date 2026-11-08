import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/app_theme.dart';
import 'product_image.dart';

class ProductCard extends StatefulWidget {
  final Producto product;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onAddCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
    required this.onAddCart,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;
  bool _pressed = false;

  Producto get product => widget.product;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? .982 : (_hovered ? 1.012 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: _hovered ? .13 : .06),
                blurRadius: _hovered ? 28 : 18,
                offset: Offset(0, _hovered ? 12 : 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _hovered
                        ? AppColors.gold.withValues(alpha: .42)
                        : AppColors.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _hovered
                                      ? const [
                                          Color(0xFFFFFBEE),
                                          Color(0xFFF4F6FA),
                                        ]
                                      : const [
                                          Color(0xFFF8F9FC),
                                          Color(0xFFF1F3F7),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: AnimatedScale(
                                    scale: _hovered ? 1.045 : 1,
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    child: ProductImage(
                                      source: product.imagen,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Imagen de ${product.nombre}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (product.precioOferta != null)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.navy.withValues(alpha: .18),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'OFERTA',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.gold,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 7,
                              top: 7,
                              child: AnimatedScale(
                                scale: widget.favorite ? 1.08 : 1,
                                duration: const Duration(milliseconds: 180),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(13),
                                    onTap: widget.onFavorite,
                                    child: Ink(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: .96),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Icon(
                                        widget.favorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: widget.favorite
                                            ? AppColors.danger
                                            : AppColors.ink,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.goldSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                product.marca,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.goldDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              product.stock > 0
                                  ? '${product.stock} disp.'
                                  : 'Agotado',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: product.stock > 0
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.two_wheeler_outlined,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.tipoVehiculo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.precioOferta != null)
                                  Text(
                                    'S/ ${product.precio.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black38,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  'S/ ${product.precioFinal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.goldDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedScale(
                            scale: _hovered ? 1.06 : 1,
                            duration: const Duration(milliseconds: 170),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(13),
                                onTap: product.disponible
                                    ? widget.onAddCart
                                    : null,
                                child: Ink(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: product.disponible
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.navySoft,
                                              AppColors.navy,
                                            ],
                                          )
                                        : null,
                                    color: product.disponible
                                        ? null
                                        : const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    product.disponible
                                        ? Icons.add_shopping_cart_rounded
                                        : Icons.block,
                                    color: product.disponible
                                        ? Colors.white
                                        : AppColors.muted,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
