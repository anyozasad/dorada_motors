import 'package:flutter/material.dart';

import '../models/producto.dart';

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
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.asset(
                        product.imagen,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported_outlined, size: 44, color: Colors.black26),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filledTonal(
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: favorite ? Colors.red : const Color(0xFF111827),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3C6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.marca,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFD39E00)),
                  ),
                ),
                const Spacer(),
                Text(
                  product.stock > 0 ? 'Stock ${product.stock}' : 'Agotado',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              product.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.precioOferta != null)
                        Text(
                          'S/ ${product.precio.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Colors.black45, decoration: TextDecoration.lineThrough),
                        ),
                      Text(
                        'S/ ${product.precioFinal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD6A715)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: product.disponible ? onAddCart : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: product.disponible ? const Color(0xFF111827) : Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 19),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
