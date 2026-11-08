import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Representa el estado real que devuelve la API PHP, sin inferir un éxito
/// cuando el pedido fue cancelado o todavía requiere atención.
class PedidoEstadoBadge extends StatelessWidget {
  final String estado;

  const PedidoEstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final normalized = estado.trim().toLowerCase();
    final Color fondo;
    final Color texto;

    switch (normalized) {
      case 'cancelado':
        fondo = const Color(0xFFFFE9E7);
        texto = AppColors.danger;
      case 'pendiente':
        fondo = AppColors.goldSoft;
        texto = AppColors.goldDark;
      case 'procesando':
        fondo = const Color(0xFFFFF3D6);
        texto = const Color(0xFF946200);
      case 'enviado':
        fondo = const Color(0xFFE8F2FF);
        texto = const Color(0xFF175CD3);
      case 'pagado':
      case 'completado':
        fondo = const Color(0xFFE8F7EF);
        texto = AppColors.success;
      default:
        fondo = const Color(0xFFEDF0F4);
        texto = AppColors.muted;
    }

    return Semantics(
      label: 'Estado del pedido: $estado',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          estado,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: texto,
          ),
        ),
      ),
    );
  }
}
