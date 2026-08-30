import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../models/producto.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

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

  double get _subtotal {
    double total = 0;
    widget.cart.forEach((id, qty) {
      final product = widget.products.firstWhere((p) => p.id == id);
      total += product.precioFinal * qty;
    });
    return total;
  }

  double get _deliveryCost => _delivery == 'Delivery' ? 5.0 : 0.0;
  double get _total => _subtotal + _deliveryCost;

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
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.goldDark, size: 42),
            ),
            const SizedBox(height: 18),
            const Text('¡Pedido registrado!', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Tu pedido ${order.id} fue creado correctamente.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _summaryRow('Estado', order.estado),
                  const SizedBox(height: 8),
                  _summaryRow('Total', 'S/ ${order.total.toStringAsFixed(2)}', strong: true),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
        ],
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalizar compra'),
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navySoft]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.navy.withValues(alpha: .16), blurRadius: 22, offset: const Offset(0, 10)),
                  ],
                ),
                child: const Row(
                  children: [
                    _CheckoutStep(icon: Icons.shopping_cart_checkout_rounded, label: 'Carrito'),
                    _StepLine(),
                    _CheckoutStep(icon: Icons.local_shipping_outlined, label: 'Entrega'),
                    _StepLine(),
                    _CheckoutStep(icon: Icons.verified_outlined, label: 'Confirmar'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _sectionCard(
                title: 'Datos del cliente',
                icon: Icons.person_outline_rounded,
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: 'Ej. 987 654 321',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Tipo de entrega',
                icon: Icons.local_shipping_outlined,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _selectCard(
                            title: 'Recojo',
                            subtitle: 'En tienda',
                            icon: Icons.storefront_outlined,
                            selected: _delivery == 'Recojo en tienda',
                            onTap: () => setState(() => _delivery = 'Recojo en tienda'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _selectCard(
                            title: 'Delivery',
                            subtitle: 'S/ 5.00',
                            icon: Icons.delivery_dining_outlined,
                            selected: _delivery == 'Delivery',
                            onTap: () => setState(() => _delivery = 'Delivery'),
                          ),
                        ),
                      ],
                    ),
                    if (_delivery == 'Delivery') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de entrega',
                          hintText: 'Jr., avenida, referencia...',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Método de pago',
                icon: Icons.account_balance_wallet_outlined,
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: ['Yape', 'Plin', 'Efectivo', 'Transferencia'].map((method) {
                    final selected = _payment == method;
                    return ChoiceChip(
                      avatar: Icon(_paymentIcon(method), size: 18, color: selected ? AppColors.navy : AppColors.muted),
                      label: Text(method),
                      selected: selected,
                      onSelected: (_) => setState(() => _payment = method),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Resumen del pedido',
                icon: Icons.receipt_long_outlined,
                child: Column(
                  children: [
                    ...widget.cart.entries.map((entry) {
                      final p = widget.products.firstWhere((product) => product.id == entry.key);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Image.asset(p.imagen, fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text('Cantidad: ${entry.value}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Text('S/ ${(p.precioFinal * entry.value).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 22),
                    _summaryRow('Subtotal', 'S/ ${_subtotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _summaryRow('Entrega', _deliveryCost == 0 ? 'Gratis' : 'S/ ${_deliveryCost.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                    _summaryRow('TOTAL', 'S/ ${_total.toStringAsFixed(2)}', strong: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _confirm,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(_saving ? 'Registrando pedido...' : 'Confirmar pedido • S/ ${_total.toStringAsFixed(2)}'),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('Tus datos se usan solo para gestionar el pedido', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .035), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.goldDark, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _selectCard({required String title, required String subtitle, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldSoft : AppColors.background,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.goldDark : AppColors.muted),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'Efectivo':
        return Icons.payments_outlined;
      case 'Transferencia':
        return Icons.account_balance_outlined;
      default:
        return Icons.phone_android_outlined;
    }
  }

  Widget _summaryRow(String label, String value, {bool strong = false}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 17 : 13, fontWeight: strong ? FontWeight.w900 : FontWeight.w600, color: strong ? AppColors.ink : AppColors.muted))),
        Text(value, style: TextStyle(fontSize: strong ? 21 : 14, fontWeight: FontWeight.w900, color: strong ? AppColors.goldDark : AppColors.ink)),
      ],
    );
  }
}

class _CheckoutStep extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CheckoutStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: AppColors.gold, size: 21),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 22, height: 1, color: Colors.white24, margin: const EdgeInsets.only(bottom: 20));
  }
}
