import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../services/api_service.dart';
import '../services/offline_actions.dart';
import '../services/local_store.dart';
import '../services/offline_store.dart';
import '../theme/app_theme.dart';
import '../widgets/pedido_estado_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Pedido>> _orders;
  final Set<String> _cancelando = <String>{};
  final Set<String> _reportando = <String>{};
  bool _mostrandoCopiaLocal = false;
  List<Map<String, dynamic>> _borradores = [];
  final Set<String> _borradoresEnviando = {};

  @override
  void initState() {
    super.initState();
    _orders = _loadOrders();
    _cargarBorradores();
  }

  Future<List<Pedido>> _loadOrders() async {
    final session = await LocalStore.getSession();
    final idUsuario = int.tryParse(session?['id'] ?? '') ?? 0;

    if (idUsuario <= 0) {
      throw Exception('Tu sesión venció. Inicia sesión para ver tus pedidos.');
    }

    try {
      final data = await ApiService.obtenerPedidosUsuario(idUsuario);

      final pedidosActualizados = data.map((raw) {
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
          comprobanteId: int.tryParse(row['id_comprobante']?.toString() ?? '') ?? 0,
          metodoPago: row['metodo_pago']?.toString() ?? 'Pendiente',
          estadoPago: row['estado_pago']?.toString() ?? 'Pendiente',
          montoPagado: double.tryParse(row['monto_pagado']?.toString() ?? '') ?? 0,
          saldoPendiente: double.tryParse(row['saldo_pendiente']?.toString() ?? '') ?? 0,
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
      _mostrandoCopiaLocal = false;
      try {
        await OfflineStore.guardarPedidos(idUsuario, pedidosActualizados);
      } catch (_) {
        // No bloquear una lectura válida por error de caché.
      }
      return pedidosActualizados;
    } catch (e) {
      if (!ApiService.esErrorConexion(e)) rethrow;
      final copia = await OfflineStore.obtenerPedidos(idUsuario);
      _mostrandoCopiaLocal = true;
      return copia;
    }
  }

  Future<void> _cargarBorradores() async {
    try {
      final drafts = await OfflineActions.borradoresPedido();
      if (mounted) setState(() => _borradores = drafts);
    } catch (_) {
      // Las consultas de MySQL deben seguir funcionando si falla SQLite.
    }
  }

  Future<void> _confirmarBorrador(Map<String, dynamic> borrador) async {
    final clave = borrador['clave'] as String;
    if (_borradoresEnviando.contains(clave)) return;
    final datos = Map<String, dynamic>.from(borrador['datos'] as Map);
    final monto = (datos['total_esperado'] as num).toDouble();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar envío del pedido'),
        content: Text(
          'Enviarás una compra real a MySQL. Total aproximado: '
          'S/ ${monto.toStringAsFixed(2)}. '
          'Se verificará el precio, las existencias y la tarifa actual. '
          'Si cambió algún dato, no se registrará la compra.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir revisando')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar y enviar')),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    setState(() => _borradoresEnviando.add(clave));
    try {
      final respuesta = await OfflineActions.confirmarBorrador(borrador);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pedido #${respuesta['id_pedido']} registrado en MySQL.'),
      ));
      await _cargarBorradores();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('El borrador sigue en SQLite: '
            '${e.toString().replaceFirst('Exception: ', '')}'),
      ));
      await _cargarBorradores();
    } finally {
      if (mounted) setState(() => _borradoresEnviando.remove(clave));
    }
  }

  Future<void> _descartarBorrador(Map<String, dynamic> borrador) async {
    final clave = borrador['clave'] as String;
    await OfflineActions.eliminarBorrador(clave);
    await _cargarBorradores();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador local descartado.')),
      );
    }
  }

  Widget _tarjetaBorrador(Map<String, dynamic> borrador) {
    final clave = borrador['clave'] as String;
    final datos = Map<String, dynamic>.from(borrador['datos'] as Map);
    final items = (datos['items'] as List? ?? const []);
    final monto = (datos['total_esperado'] as num?)?.toDouble() ?? 0;
    return Card(
      color: AppColors.goldSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('BORRADOR LOCAL · NO ES UNA COMPRA CONFIRMADA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12,
                  color: AppColors.goldDark)),
          const SizedBox(height: 8),
          Text('${items.length} repuesto(s) · S/ ${monto.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('${datos['tipo_entrega'] ?? ''} · ${datos['metodo_pago'] ?? ''}',
              style: const TextStyle(color: AppColors.muted)),
          if (borrador['error'] != null)
            Text('Último error: ${borrador['error']}',
                style: const TextStyle(color: AppColors.danger, fontSize: 11)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            FilledButton.icon(
              onPressed: _borradoresEnviando.contains(clave)
                  ? null : () => _confirmarBorrador(borrador),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Confirmar y enviar'),
            ),
            TextButton(
              onPressed: _borradoresEnviando.contains(clave)
                  ? null : () => _descartarBorrador(borrador),
              child: const Text('Descartar'),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _refresh() async {
    // Una caída de Apache no debe lanzar una excepción sin manejar al
    // deslizar para actualizar: FutureBuilder mostrará el error y Reintentar.
    final nuevaConsulta = _loadOrders();
    if (!mounted) return;
    setState(() => _orders = nuevaConsulta);
    await _cargarBorradores();
    try {
      await nuevaConsulta;
    } catch (_) {
      // El mensaje se presenta en la pantalla de pedidos, sin duplicarlo.
    }
  }

  Future<void> _cancelarPedido(Pedido pedido) async {
    if (_cancelando.contains(pedido.id) || pedido.estado != 'Pendiente') return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Text(
          '¿Confirmas la cancelación del pedido ${pedido.id}? '
          'El stock se restaurará cuando MySQL acepte la cancelación. Sin red, la solicitud quedará guardada en el celular.',
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
      final confirmada = await OfflineActions.registrar(
        accion: 'cancelacion',
        clave: 'cancelar_$id',
        datos: {'id_pedido': id},
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(confirmada
            ? 'Pedido cancelado. El stock se actualizó en MySQL.'
            : 'Solicitud de cancelación guardada en SQLite. '
              'El stock se actualizará cuando MySQL la confirme.'),
      ));
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

  Future<void> _verComprobante(Pedido pedido) async {
    final id = int.tryParse(pedido.id.replaceFirst('DM-', '')) ?? 0;
    if (id <= 0) return;
    try {
      final datos = await ApiService.obtenerComprobanteCliente(id);
      if (!mounted) return;

      final comprobante = Map<String, dynamic>.from(datos['comprobante'] as Map);
      final empresa = Map<String, dynamic>.from(datos['empresa'] as Map);
      final items = (datos['items'] as List? ?? const [])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();

      String soles(dynamic valor) {
        final numero = double.tryParse(valor?.toString() ?? '') ?? 0;
        return 'S/ ${numero.toStringAsFixed(2)}';
      }

      await showDialog<void>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: Text(
            '${comprobante['tipo_comprobante'] ?? 'Comprobante'} '
            '${comprobante['numero_comprobante'] ?? ''}',
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(empresa['razon_social']?.toString() ?? 'Dorada Motors',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  if ((empresa['ruc']?.toString() ?? '').isNotEmpty)
                    Text('RUC ${empresa['ruc']}'),
                  if ((empresa['direccion']?.toString() ?? '').isNotEmpty)
                    Text(empresa['direccion'].toString()),
                  const Divider(height: 25),
                  Text('Pedido: ${comprobante['id_pedido']}'),
                  Text('Cliente: ${comprobante['nombres']} ${comprobante['apellidos']}'),
                  Text('Emisión: ${comprobante['fecha_emision']}'),
                  const SizedBox(height: 10),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${item['cantidad']} × ${item['nombre_producto']}'),
                        ),
                        Text(soles(item['subtotal'])),
                      ],
                    ),
                  )),
                  const Divider(),
                  _infoRow(Icons.receipt_outlined, 'Subtotal', soles(comprobante['subtotal'])),
                  _infoRow(Icons.percent_outlined, 'IGV', soles(comprobante['igv'])),
                  _infoRow(Icons.payments_outlined, 'Total', soles(comprobante['total'])),
                  const SizedBox(height: 10),
                  const Text(
                    'Comprobante de demostración. No está validado electrónicamente por SUNAT.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo consultar el comprobante: '
            '${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _reportarPago(Pedido pedido) async {
    if (_reportando.contains(pedido.id)) return;
    var referenciaIngresada = pedido.referenciaPago;
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
                initialValue: referenciaIngresada,
                onChanged: (valor) => referenciaIngresada = valor,
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
                Navigator.pop(dialogContext, referenciaIngresada.trim());
              }
            },
            child: const Text('Enviar referencia'),
          ),
        ],
      ),
    );
    if (!mounted || referencia == null) return;
    final id = int.tryParse(pedido.id.replaceFirst('DM-', '')) ?? 0;
    if (id <= 0) return;

    setState(() => _reportando.add(pedido.id));
    try {
      final enviada = await OfflineActions.registrar(
        accion: 'pago_referencia',
        clave: 'referencia_$id',
        datos: {'id_pedido': id, 'referencia': referencia},
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enviada
            ? 'Referencia recibida por MySQL. El pago sigue pendiente de revisión.'
            : 'Referencia guardada en SQLite. Se enviará al reconectar. '
              'Esto NO confirma un pago.'),
      ));
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
                children: [
                  if (_borradores.isEmpty) ...[
                    const SizedBox(height: 140),
                    const _EmptyOrders(),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Pedidos guardados sin internet',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    ),
                    ..._borradores.map(_tarjetaBorrador),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                if (_borradores.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Pendientes guardados en SQLite',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  ..._borradores.map(_tarjetaBorrador),
                  const SizedBox(height: 12),
                ],
                if (_mostrandoCopiaLocal)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(children: [
                      Icon(Icons.cloud_off_outlined, color: AppColors.goldDark),
                      SizedBox(width: 9),
                      Expanded(child: Text(
                        'Historial guardado en el celular. Los estados de pagos '
                        'y pedidos se actualizarán al reconectar con MySQL.',
                        style: TextStyle(fontSize: 12, color: AppColors.ink),
                      )),
                    ]),
                  ),
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
              PedidoEstadoBadge(estado: order.estado),
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
            if (order.montoPagado > 0)
              _infoRow(Icons.check_circle_outline, 'Abonado',
                  'S/ ${order.montoPagado.toStringAsFixed(2)}'),
            if (order.estado != 'Cancelado' && order.saldoPendiente > 0)
              _infoRow(Icons.hourglass_bottom_outlined, 'Saldo pendiente',
                  'S/ ${order.saldoPendiente.toStringAsFixed(2)}'),
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
            if (order.comprobanteId > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _verComprobante(order),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Ver comprobante emitido'),
                ),
              ),
            ],
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
