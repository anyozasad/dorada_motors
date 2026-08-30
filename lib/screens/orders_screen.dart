import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Pedido>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = LocalStore.getOrders();
  }

  Future<void> _refresh() async {
    setState(() => _orders = LocalStore.getOrders());
    await _orders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: FutureBuilder<List<Pedido>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  _EmptyOrders(),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navySoft]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(17)),
                        child: const Icon(Icons.receipt_long_outlined, color: AppColors.gold, size: 29),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${orders.length} pedido${orders.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            const Text('Consulta tus compras y el detalle de entrega.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ...orders.map(_orderCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _orderCard(Pedido order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: .04), blurRadius: 16, offset: const Offset(0, 7)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.goldDark),
          ),
          title: Row(
            children: [
              Expanded(child: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink))),
              _statusChip(order.estado),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(_date(order.fecha), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
          trailing: Text(
            'S/ ${order.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.goldDark),
          ),
          children: [
            const Divider(),
            ...order.items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(13)),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Text('${item.cantidad}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(item.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    Text('S/ ${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _infoRow(Icons.local_shipping_outlined, 'Entrega', order.tipoEntrega),
            _infoRow(Icons.account_balance_wallet_outlined, 'Pago', order.metodoPago),
            _infoRow(Icons.phone_outlined, 'Teléfono', order.telefono),
            if (order.tipoEntrega == 'Delivery')
              _infoRow(Icons.location_on_outlined, 'Dirección', order.direccion),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final isPending = status.toLowerCase().contains('pend');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPending ? AppColors.goldSoft : const Color(0xFFE8F7EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isPending ? AppColors.goldDark : AppColors.success),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.goldDark),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        ],
      ),
    );
  }

  String _date(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined, size: 46, color: AppColors.goldDark),
            ),
            const SizedBox(height: 18),
            const Text('Aún no tienes pedidos', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('Cuando confirmes una compra aparecerá aquí con su estado y detalle.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
