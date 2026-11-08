import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Pedido>> _orders;
  final Set<String> _cancelando = <String>{};
  final Set<String> _reportando = <String>{};

  @override
  void initState() {
    super.initState();
    _orders = _loadOrders();
  }

  Future<List<Pedido>> _loadOrders() async {
    final session = await LocalStore.getSession();
    final idUsuario = int.tryParse(session?['id'] ?? '') ?? 0;

    if (idUsuario <= 0) {
      return LocalStore.getOrders();
    }

    try {
      final data = await ApiService.obtenerPedidosUsuario(idUsuario);

      return data.map((raw) {
        final row = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

        final fechaTexto =
            (row['fecha_pedido']?.toString() ?? '').replaceFirst(' ', 'T');
        final fecha = DateTime.tryParse(fechaTexto) ?? DateTime.now();

        final itemsRaw = (row['items'] as List?) ?? const [];
        final items = itemsRaw.map((rawItem) {
          final item = rawItem is Map
              ? Map<String, dynamic>.from(rawItem)
              : <String, dynamic>{};

          return PedidoItem(
            productoId:
                int.tryParse(item['id_producto']?.toString() ?? '') ?? 0,
            nombre: item['nombre_producto']?.toString() ?? 'Producto',
            cantidad:
                int.tryParse(item['cantidad']?.toString() ?? '') ?? 0,
            precio:
                double.tryParse(item['precio']?.toString() ?? '0') ?? 0,
          );
        }).toList();

        return Pedido(
          id: 'DM-${row['id_pedido'] ?? '-'}',
          fecha: fecha,
          estado: row['estado_pedido']?.toString() ?? 'Pendiente',
          metodoPago: row['metodo_pago']?.toString() ?? 'Pendiente',
          estadoPago: row['estado_pago']?.toString() ?? 'Pendiente',
          referenciaPago: row['referencia_pago']?.toString() ?? '',
          tipoEntrega:
              row['tipo_entrega']?.toString() ?? 'Recojo en tienda',
          direccion: row['direccion_detalle']?.toString().trim().isNotEmpty == true
              ? row['direccion_detalle'].toString()
              : 'Recojo en tienda',
          telefono: row['telefono']?.toString() ?? '',
          total: double.tryParse(row['total']?.toString() ?? '0') ?? 0,
          items: items,
        );
      }).toList();
    } catch (_) {
      // No presentar un respaldo local como si fuera el estado actual de MySQL.
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() => _orders = _loadOrders());
    await _orders;
  }

  Future<void> _cancelarPedido(Pedido pedido) async {
    if (_cancelando.contains(pedido.id) || pedido.estado != 'Pendiente') return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Text(
          '¿Confirmas la cancelación del pedido ${pedido.id}? '
          'Los repuestos volverán al inventario y el pago pendiente quedará rechazado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;

    final id = int.tryParse(pedido.id.replaceFirst('DM-', '')) ?? 0;
    if (id <= 0) return;
    setState(() => _cancelando.add(pedido.id));
    try {
      await ApiService.cancelarPedidoCliente(id);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido cancelado. El inventario se actualizó en MySQL.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _cancelando.remove(pedido.id));
    }
  }

  Future<void> _reportarPago(Pedido pedido) async {
    if (_reportando.contains(pedido.id)) return;
    final controller = TextEditingController(text: pedido.referenciaPago);
    final formKey = GlobalKey<FormState>();
    final referencia = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Informar pago digital'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pedido ${pedido.id} · ${pedido.metodoPago}. '
                'Ingresa el número de operación que recibiste al pagar. '
                'El administrador verificará el abono antes de confirmarlo.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Número de operación',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                maxLength: 80,
                validator: (value) {
                  final numero = value?.trim() ?? '';
                  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]{5,79}$').hasMatch(numero)) {
                    return 'Escribe una referencia válida (6 a 80 caracteres)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Enviar referencia'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || referencia == null) return;
    final id = int.tryParse(pedido.id.replaceFirst('DM-', '')) ?? 0;
    if (id <= 0) return;

    setState(() => _reportando.add(pedido.id));
    try {
      await ApiService.reportarReferenciaPago(idPedido: id, referencia: referencia);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referencia recibida. El pago sigue pendiente hasta su verificación.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _reportando.remove(pedido.id));
    }
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

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 54),
                    const SizedBox(height: 12),
                    const Text('No se pudo consultar tus pedidos',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 15),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Volver a consultar MySQL'),
                    ),
                  ],
                ),
              ),
            );
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
                            const Text(
                              'Pedidos sincronizados con PHP y MySQL.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
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
            _infoRow(Icons.account_balance_wallet_outlined, 'Pago',
                '${order.metodoPago} · ${order.estadoPago}'),
            if (order.referenciaPago.isNotEmpty)
              _infoRow(Icons.numbers_outlined, 'Operación', order.referenciaPago),
            if (order.estadoPago == 'Pendiente' &&
                (order.estado == 'Pendiente' || order.estado == 'Procesando') &&
                ['Yape', 'Plin', 'Transferencia'].contains(order.metodoPago)) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _reportando.contains(order.id)
                      ? null : () => _reportarPago(order),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(_reportando.contains(order.id)
                      ? 'Enviando...' : order.referenciaPago.isEmpty
                          ? 'Informar número de operación'
                          : 'Corregir número de operación'),
                ),
              ),
            ],
            _infoRow(Icons.phone_outlined, 'Teléfono', order.telefono),
            if (order.tipoEntrega == 'Delivery')
              _infoRow(Icons.location_on_outlined, 'Dirección', order.direccion),
            if (order.estado == 'Pendiente') ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _cancelando.contains(order.id)
                      ? null : () => _cancelarPedido(order),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(_cancelando.contains(order.id)
                      ? 'Cancelando...' : 'Cancelar pedido'),
                ),
              ),
            ],
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
