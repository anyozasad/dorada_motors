import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../services/local_store.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Pedido>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 72, color: Colors.black26),
                  SizedBox(height: 14),
                  Text('Aún no tienes pedidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ExpansionTile(
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3C6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFD6A715)),
                ),
                title: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${_date(order.fecha)} • ${order.estado}'),
                trailing: Text(
                  'S/ ${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD6A715)),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const Divider(),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item.nombre} x${item.cantidad}')),
                          Text('S/ ${item.subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Entrega: ${order.tipoEntrega}\nPago: ${order.metodoPago}\nTeléfono: ${order.telefono}'),
                  ),
                  if (order.tipoEntrega == 'Delivery')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Dirección: ${order.direccion}'),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _date(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }
}
