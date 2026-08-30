import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: .055),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF8F9FC), Color(0xFFF1F3F7)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              product.imagen,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image_not_supported_outlined, size: 44, color: Colors.black26),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'OFERTA',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.gold),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 7,
                        top: 7,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: onFavorite,
                            icon: Icon(
                              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: favorite ? AppColors.danger : AppColors.ink,
                              size: 20,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.goldSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          product.marca,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.goldDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        product.stock > 0 ? '${product.stock} disp.' : 'Agotado',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: product.stock > 0 ? AppColors.success : AppColors.danger,
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
                  style: const TextStyle(fontSize: 14, height: 1.22, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.two_wheeler_outlined, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.tipoVehiculo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
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
                              style: const TextStyle(fontSize: 10, color: Colors.black38, decoration: TextDecoration.lineThrough),
                            ),
                          Text(
                            'S/ ${product.precioFinal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.goldDark),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: product.disponible ? onAddCart : null,
                      child: Ink(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: product.disponible ? AppColors.navy : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          product.disponible ? Icons.add_shopping_cart_rounded : Icons.block,
                          color: product.disponible ? Colors.white : AppColors.muted,
                          size: 19,
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
    );
  }
}
