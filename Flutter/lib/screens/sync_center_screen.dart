import 'package:flutter/material.dart';

import '../services/offline_actions.dart';
import '../services/offline_store.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'orders_screen.dart';

/// Aquí se diferencia entre "almacenado en el celular" y "guardado en MySQL".
/// Una operación rechazada nunca se descarta ni se reintenta silenciosamente.
class SyncCenterScreen extends StatefulWidget {
  final Future<void> Function() onSyncShopping;

  const SyncCenterScreen({super.key, required this.onSyncShopping});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  List<Map<String, dynamic>> _operaciones = [];
  Map<int, int> _carritoItems = {};
  Map<int, bool> _favoritosItems = {};
  Map<int, String> _nombresProducto = {};
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final usuario = await OfflineActions.usuarioActual();
      final operaciones = await OfflineActions.operacionesPendientes();
      final carrito = await OfflineStore.carritoPendiente(usuario);
      final favoritos = await OfflineStore.favoritosPendientes(usuario);
      final catalogo = await OfflineStore.obtenerCatalogo(ApiService.baseUrl);
      final nombres = <int, String>{};
      for (final producto in catalogo ?? const []) {
        if (producto is! Map) continue;
        final id = int.tryParse(producto['id_producto']?.toString()
            ?? producto['id']?.toString() ?? '') ?? 0;
        if (id > 0) {
          nombres[id] = producto['nombre']?.toString()
              ?? producto['nombre_producto']?.toString() ?? 'Producto #$id';
        }
      }
      if (!mounted) return;
      setState(() {
        _operaciones = operaciones;
        _carritoItems = carrito;
        _favoritosItems = favoritos;
        _nombresProducto = nombres;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _sincronizar() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      final completadas = await OfflineActions.sincronizar();
      await widget.onSyncShopping();
      await _cargar();
      if (!mounted) return;
      final rechazadas = _operaciones
          .where((fila) => fila['estado'] == 'error').length;
      _aviso('Se sincronizaron $completadas operación(es) de formularios. '
          '${rechazadas > 0 ? 'Hay $rechazadas que requieren revisión.' : 'Revisa el estado del carrito y favoritos.'}');
    } catch (e) {
      _aviso('No se pudo sincronizar: $e');
      await _cargar();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _reintentar(Map<String, dynamic> fila) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      final confirmada =
          await OfflineActions.reintentarOperacion(fila['clave'] as String);
      _aviso(confirmada
          ? 'MySQL confirmó la operación.'
          : 'La operación cambió durante el envío. Se conserva la última versión.');
    } catch (e) {
      _aviso('MySQL todavía no aceptó la operación: $e');
    } finally {
      await _cargar();
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _descartar(Map<String, dynamic> fila) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambio local'),
        content: const Text(
          'Se eliminará este cambio pendiente del celular. '
          'No se deshará ningún cambio que el servidor ya haya recibido. '
          'Si MySQL rechazó la operación, revisa primero el motivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar del celular'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    try {
      await OfflineActions.descartarOperacion(fila['clave'] as String);
      await _cargar();
      _aviso('Cambio local descartado.');
    } catch (e) {
      _aviso('No se pudo descartar: $e');
    }
  }

  Future<void> _descartarCompraLocal({
    required int producto,
    required bool favorito,
  }) async {
    if (_enviando) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(favorito
            ? 'Descartar favorito pendiente' : 'Descartar cambio del carrito'),
        content: const Text(
          'Se cancelará únicamente el cambio local que no llegó a MySQL. '
          'El servidor conservará su estado actual. '
          'No se eliminará ningún pedido o venta confirmada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar cambio'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    final usuario = await OfflineActions.usuarioActual();
    if (favorito) {
      final estado = _favoritosItems[producto];
      if (estado != null) {
        await OfflineStore.confirmarFavoritoSiIgual(
            usuario, producto, estado);
      }
    } else {
      final cantidad = _carritoItems[producto];
      if (cantidad != null) {
        await OfflineStore.confirmarCarritoSiIgual(
            usuario, producto, cantidad);
      }
    }
    await _cargar();
    _aviso('Cambio local descartado. Actualiza tu carrito al reconectar.');
  }

  String _titulo(Map<String, dynamic> fila) {
    switch (fila['accion']) {
      case 'perfil':
        return 'Datos de mi cuenta';
      case 'direccion_crear':
        return 'Nueva dirección';
      case 'direccion_editar':
        return 'Editar dirección';
      case 'direccion_eliminar':
        return 'Eliminar dirección';
      case 'soporte':
        return 'Consulta al administrador';
      case 'cancelacion':
        return 'Solicitud de cancelación';
      case 'pago_referencia':
        return 'Informar referencia de pago';
      case 'pedido_borrador':
        return 'Borrador de pedido';
      default:
        return 'Cambio pendiente';
    }
  }

  String _detalle(Map<String, dynamic> fila) {
    final datos = Map<String, dynamic>.from(fila['datos'] as Map);
    switch (fila['accion']) {
      case 'perfil':
        return '${datos['nombres'] ?? ''} ${datos['apellidos'] ?? ''}'.trim();
      case 'direccion_crear':
      case 'direccion_editar':
        return datos['direccion']?.toString() ?? '';
      case 'direccion_eliminar':
        return 'Dirección #${datos['id_direccion'] ?? ''}';
      case 'soporte':
        return datos['asunto']?.toString() ?? '';
      case 'cancelacion':
      case 'pago_referencia':
        return 'Pedido #${datos['id_pedido'] ?? ''}';
      case 'pedido_borrador':
        return 'Requiere confirmar precio y stock en Mis pedidos';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final borradores = _operaciones
        .where((op) => op['accion'] == 'pedido_borrador').length;
    final cambios = _operaciones
        .where((op) => op['accion'] != 'pedido_borrador').toList();
    final rechazados = cambios.where((op) => op['estado'] == 'error').length;
    final sinEnviar = cambios.where((op) => op['estado'] == 'pendiente').length;
    final cambiosCarrito = _carritoItems.entries.toList();
    final cambiosFavoritos = _favoritosItems.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de sincronización'),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar datos locales',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    children: [
                      Card(
                        color: AppColors.navy,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tus datos están protegidos en el celular',
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 17, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 7),
                              const Text(
                                'Pendiente no significa guardado en MySQL. '
                                'Los cambios se envían cuando el servidor esté disponible. '
                                'Una operación rechazada requiere revisión.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$sinEnviar pendientes · $rechazados con error · '
                                '$borradores borradores',
                                style: const TextStyle(color: AppColors.gold,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (cambiosCarrito.isNotEmpty ||
                          cambiosFavoritos.isNotEmpty) ...[
                        const Text('Cambios de compras pendientes',
                            style: TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                          'Si MySQL rechaza un producto por stock, puedes '
                          'corregir el carrito o descartar aquí su cambio local.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        ...cambiosCarrito.map((item) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.shopping_cart_outlined,
                                color: AppColors.goldDark),
                            title: Text(_nombresProducto[item.key]
                                ?? 'Producto #${item.key}'),
                            subtitle: Text('Cantidad pendiente: ${item.value}'),
                            trailing: IconButton(
                              onPressed: _enviando ? null : () =>
                                  _descartarCompraLocal(
                                    producto: item.key, favorito: false),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Descartar cambio local',
                            ),
                          ),
                        )),
                        ...cambiosFavoritos.map((item) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.favorite_outline,
                                color: AppColors.goldDark),
                            title: Text(_nombresProducto[item.key]
                                ?? 'Producto #${item.key}'),
                            subtitle: Text(item.value
                                ? 'Agregar a favoritos pendiente'
                                : 'Quitar de favoritos pendiente'),
                            trailing: IconButton(
                              onPressed: _enviando ? null : () =>
                                  _descartarCompraLocal(
                                    producto: item.key, favorito: true),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Descartar cambio local',
                            ),
                          ),
                        )),
                      ],
                      if (borradores > 0)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined,
                                color: AppColors.goldDark),
                            title: Text('$borradores borrador(es) de compra'),
                            subtitle: const Text(
                              'No son pedidos confirmados. '
                              'Revisa precio y stock antes de enviarlos.',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OrdersScreen(),
                                ),
                              );
                              await _cargar();
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _enviando ? null : _sincronizar,
                          icon: _enviando
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(_enviando
                              ? 'Sincronizando...' : 'Sincronizar pendientes'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Operaciones del cliente (${cambios.length})',
                          style: const TextStyle(fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (cambios.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'No hay cambios de formularios pendientes. '
                            'Consulta los borradores de compra por separado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ...cambios.map((fila) {
                        final error = fila['estado'] == 'error';
                        final detalle = _detalle(fila);
                        return Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(error ? Icons.error_outline
                                      : Icons.schedule_outlined,
                                      color: error
                                          ? AppColors.danger : AppColors.goldDark),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_titulo(fila),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900))),
                                ]),
                                if (detalle.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(detalle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                const SizedBox(height: 6),
                                Text(error ? 'Rechazado: requiere revisión'
                                    : 'Guardado solo en el celular',
                                    style: TextStyle(
                                      color: error
                                          ? AppColors.danger : AppColors.goldDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    )),
                                if (error && fila['error'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: SelectableText(
                                      fila['error'].toString()
                                          .replaceFirst('Exception: ', ''),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, children: [
                                  OutlinedButton.icon(
                                    onPressed: _enviando
                                        ? null : () => _reintentar(fila),
                                    icon: const Icon(Icons.refresh, size: 17),
                                    label: const Text('Reintentar'),
                                  ),
                                  TextButton(
                                    onPressed: _enviando
                                        ? null : () => _descartar(fila),
                                    child: const Text('Descartar'),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
