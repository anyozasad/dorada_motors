import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../models/producto.dart';
import '../services/local_store.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<int, int> cart;
  final List<Producto> products;
  final VoidCallback onCompleted;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.products,
    required this.onCompleted,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _delivery = 'Recojo en tienda';
  String _payment = 'Yape';
  bool _saving = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  double get _total {
    double total = 0;
    widget.cart.forEach((id, qty) {
      final product = widget.products.firstWhere((p) => p.id == id);
      total += product.precioFinal * qty;
    });
    return total;
  }

  Future<void> _confirm() async {
    if (_phoneController.text.trim().length < 7) {
      _message('Ingresa un teléfono válido.');
      return;
    }
    if (_delivery == 'Delivery' && _addressController.text.trim().length < 5) {
      _message('Ingresa la dirección de entrega.');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final items = widget.cart.entries.map((entry) {
      final p = widget.products.firstWhere((product) => product.id == entry.key);
      return PedidoItem(
        productoId: p.id,
        nombre: p.nombre,
        cantidad: entry.value,
        precio: p.precioFinal,
      );
    }).toList();

    final order = Pedido(
      id: 'DM-${now.millisecondsSinceEpoch.toString().substring(7)}',
      fecha: now,
      estado: 'Pendiente',
      metodoPago: _payment,
      tipoEntrega: _delivery,
      direccion: _delivery == 'Delivery' ? _addressController.text.trim() : 'Recojo en tienda',
      telefono: _phoneController.text.trim(),
      total: _total,
      items: items,
    );

    await LocalStore.addOrder(order);
    await LocalStore.clearCart();
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onCompleted();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFFD6A715), size: 54),
        title: const Text('Pedido registrado'),
        content: Text(
          'Tu pedido ${order.id} fue creado correctamente.\n\nEstado: ${order.estado}\nTotal: S/ ${order.total.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Finalizar compra'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Datos del cliente'),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _input('Teléfono', Icons.phone_outlined),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Tipo de entrega'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Recojo en tienda', label: Text('Recojo'), icon: Icon(Icons.store_outlined)),
                  ButtonSegment(value: 'Delivery', label: Text('Delivery'), icon: Icon(Icons.delivery_dining_outlined)),
                ],
                selected: {_delivery},
                onSelectionChanged: (value) => setState(() => _delivery = value.first),
              ),
              if (_delivery == 'Delivery') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: _input('Dirección de entrega', Icons.location_on_outlined),
                ),
              ],
              const SizedBox(height: 24),
              _sectionTitle('Método de pago'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Yape', 'Plin', 'Efectivo', 'Transferencia'].map((method) {
                  return ChoiceChip(
                    label: Text(method),
                    selected: _payment == method,
                    onSelected: (_) => setState(() => _payment = method),
                  );
                }).toList(),
              ),
              const SizedBox(height: 26),
              _sectionTitle('Resumen'),
              const SizedBox(height: 10),
              ...widget.cart.entries.map((entry) {
                final p = widget.products.firstWhere((product) => product.id == entry.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text('${p.nombre} x${entry.value}')),
                      Text('S/ ${(p.precioFinal * entry.value).toStringAsFixed(2)}'),
                    ],
                  ),
                );
              }),
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text('TOTAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  Text(
                    'S/ ${_total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFD6A715)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar pedido', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
