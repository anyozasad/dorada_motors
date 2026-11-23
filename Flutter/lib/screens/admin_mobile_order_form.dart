import 'package:flutter/material.dart';

/// Formulario de pedido manual con múltiples repuestos y dirección opcional.
class AdminMobileOrderForm extends StatefulWidget {
  final List<Map<String, dynamic>> clientes, productos;
  final Future<List<Map<String, dynamic>>> Function(String) cargarDirecciones;

  const AdminMobileOrderForm({super.key, required this.clientes,
      required this.productos, required this.cargarDirecciones});

  static Future<Map<String, dynamic>?> abrir(BuildContext context, {
    required List<Map<String, dynamic>> clientes,
    required List<Map<String, dynamic>> productos,
    required Future<List<Map<String, dynamic>>> Function(String)
        cargarDirecciones,
  }) => showDialog<Map<String, dynamic>>(context: context,
      builder: (_) => AdminMobileOrderForm(clientes: clientes,
          productos: productos, cargarDirecciones: cargarDirecciones));

  @override
  State<AdminMobileOrderForm> createState() => _AdminMobileOrderFormState();
}

class _LineaVenta {
  String? producto;
  final cantidad = TextEditingController(text: '1');
  void dispose() => cantidad.dispose();
}

class _AdminMobileOrderFormState extends State<AdminMobileOrderForm> {
  final formulario = GlobalKey<FormState>();
  final lineas = <_LineaVenta>[_LineaVenta()];
  String? cliente, direccion;
  String entrega = 'Recojo en tienda';
  String metodo = 'Efectivo';
  bool cargando = false;
  List<Map<String, dynamic>> direcciones = [];

  @override
  void initState() {
    super.initState();
    cliente = widget.clientes.first['id_usuario'].toString();
    lineas.first.producto = widget.productos.first['id_producto'].toString();
    cargarDirecciones();
  }

  Future<void> cargarDirecciones() async {
    final actual = cliente;
    if (actual == null) return;
    setState(() { cargando = true; direccion = null; direcciones = []; });
    try {
      final lista = await widget.cargarDirecciones(actual);
      if (!mounted || actual != cliente) return;
      setState(() {
        direcciones = lista;
        direccion = lista.isEmpty ? null : lista.first['id_direccion'].toString();
      });
    } catch (_) {
      if (mounted && actual == cliente) {
        setState(() { direcciones = []; direccion = null; });
      }
    } finally {
      if (mounted && actual == cliente) setState(() => cargando = false);
    }
  }

  @override
  void dispose() {
    for (final linea in lineas) { linea.dispose(); }
    super.dispose();
  }

  void guardar() {
    if (cargando || !(formulario.currentState?.validate() ?? false)) return;
    if (entrega == 'Delivery' && direccion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente necesita una dirección')));
      return;
    }
    final vistos = <String>{};
    for (final linea in lineas) {
      if (linea.producto == null || !vistos.add(linea.producto!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No repitas repuestos en el pedido')));
        return;
      }
    }
    Navigator.pop(context, <String, dynamic>{
      'id_usuario': cliente,
      'id_direccion': entrega == 'Delivery' ? direccion : 0,
      'tipo_entrega': entrega,
      'metodo_pago': metodo,
      'items': [for (final l in lineas) {
        'id_producto': l.producto, 'cantidad': l.cantidad.text.trim(),
      }],
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(constraints:
      const BoxConstraints(maxHeight: 670, maxWidth: 540),
      child: Padding(padding: const EdgeInsets.all(15),
        child: Form(key: formulario, child: Column(children: [
          Row(children: [
            const Expanded(child: Text('Registrar venta', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
          Expanded(child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: cliente, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cliente activo',
                    border: OutlineInputBorder()),
                  items: [for (final c in widget.clientes) DropdownMenuItem(
                    value: c['id_usuario'].toString(),
                    child: Text(c['nombres'].toString() + ' ' +
                        c['apellidos'].toString(),
                        overflow: TextOverflow.ellipsis))],
                  onChanged: (v) {
                    setState(() => cliente = v);
                    cargarDirecciones();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: entrega,
                  decoration: const InputDecoration(labelText: 'Entrega',
                    border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Recojo en tienda',
                      child: Text('Recojo en tienda')),
                    DropdownMenuItem(value: 'Delivery', child: Text('Delivery')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => entrega = v); },
                ),
                if (entrega == 'Delivery') ...[
                  const SizedBox(height: 12),
                  if (cargando) const LinearProgressIndicator(),
                  DropdownButtonFormField<String>(
                    key: ValueKey('direccion-$cliente-$direccion'),
                    initialValue: direccion, isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Dirección del cliente',
                      border: OutlineInputBorder()),
                    items: [for (final d in direcciones) DropdownMenuItem(
                      value: d['id_direccion'].toString(),
                      child: Text(d['direccion_detalle'].toString(),
                          overflow: TextOverflow.ellipsis))],
                    onChanged: cargando ? null : (v) => direccion = v,
                    validator: (v) => entrega == 'Delivery' && v == null
                        ? 'Selecciona una dirección' : null,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: metodo,
                  decoration: const InputDecoration(labelText: 'Pago',
                    border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Yape', child: Text('Yape')),
                    DropdownMenuItem(value: 'Plin', child: Text('Plin')),
                    DropdownMenuItem(value: 'Transferencia',
                      child: Text('Transferencia')),
                  ],
                  onChanged: (v) { if (v != null) metodo = v; },
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < lineas.length; i++)
                  Card(key: ObjectKey(lineas[i]), child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Text('Repuesto ' + (i+1).toString())),
                        if (lineas.length > 1)
                          IconButton(icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() {
                              final item = lineas.removeAt(i);
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => item.dispose());
                            })),
                      ]),
                      DropdownButtonFormField<String>(
                        initialValue: lineas[i].producto,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Producto', border: OutlineInputBorder()),
                        items: [for (final p in widget.productos)
                          DropdownMenuItem(
                            value: p['id_producto'].toString(),
                            child: Text(p['nombre_producto'].toString() +
                              ' (stock ' + p['stock'].toString() + ')',
                              overflow: TextOverflow.ellipsis))],
                        onChanged: (v) => lineas[i].producto = v,
                      ),
                      const SizedBox(height: 9),
                      TextFormField(controller: lineas[i].cantidad,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad', border: OutlineInputBorder()),
                        validator: (v) {
                          final qty = int.tryParse(v ?? '');
                          return qty == null || qty < 1 || qty > 100000
                            ? 'Cantidad incorrecta' : null;
                        },
                      ),
                    ]))),
                TextButton.icon(onPressed: lineas.length >= 30 ? null : () {
                  setState(() => lineas.add(_LineaVenta()
                    ..producto = widget.productos.first['id_producto']
                        .toString()));
                }, icon: const Icon(Icons.add),
                  label: const Text('Agregar otro repuesto')),
                const Text('Los precios, las ofertas, el costo de delivery '
                    'y el stock se calculan y verifican en MySQL.'),
              ]))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: cargando ? null : guardar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar pedido en MySQL'))),
        ])),
      ),
    ),
  );
}
