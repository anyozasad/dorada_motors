// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';

/// Compra de varios productos; PHP verifica y guarda todo en una transacción.
class AdminMobilePurchaseForm extends StatefulWidget {
  final List<Map<String, dynamic>> proveedores, productos;
  const AdminMobilePurchaseForm({
    super.key, required this.proveedores, required this.productos,
  });

  static Future<Map<String, dynamic>?> abrir(BuildContext context, {
    required List<Map<String, dynamic>> proveedores,
    required List<Map<String, dynamic>> productos,
  }) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => AdminMobilePurchaseForm(
        proveedores: proveedores, productos: productos));

  @override
  State<AdminMobilePurchaseForm> createState() => _CompraState();
}

class _Linea {
  String? id;
  final cantidad = TextEditingController(text: '1');
  final precio = TextEditingController(text: '0.00');
  void dispose() { cantidad.dispose(); precio.dispose(); }
}

class _CompraState extends State<AdminMobilePurchaseForm> {
  final form = GlobalKey<FormState>();
  final List<_Linea> lineas = [_Linea()];
  String? proveedor;

  @override
  void initState() {
    super.initState();
    proveedor = widget.proveedores.first['id_proveedor'].toString();
    lineas.first.id = widget.productos.first['id_producto'].toString();
  }

  @override
  void dispose() {
    for (final linea in lineas) { linea.dispose(); }
    super.dispose();
  }

  void guardar() {
    if (! (form.currentState?.validate() ?? false)) return;
    final ids = <String>{};
    for (final linea in lineas) {
      if (linea.id == null || !ids.add(linea.id!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No repitas productos en una compra.')));
        return;
      }
    }
    Navigator.pop(context, {
      'id_proveedor': proveedor,
      'items': [
        for (final l in lineas) {
          'id_producto': l.id,
          'cantidad': l.cantidad.text.trim(),
          'precio_compra': l.precio.text.trim(),
        },
      ],
    });
  }

  void agregar() {
    if (lineas.length >= 30) return;
    setState(() => lineas.add(_Linea()
      ..id = widget.productos.first['id_producto'].toString()));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(constraints:
      const BoxConstraints(maxWidth: 550, maxHeight: 680),
      child: Padding(padding: const EdgeInsets.all(15),
        child: Form(key: form, child: Column(children: [
          Row(children: [
            const Expanded(child: Text('Registrar compra',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
          ]),
          Expanded(child: SingleChildScrollView(child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: proveedor,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Proveedor activo',
                  border: OutlineInputBorder()),
                items: [
                  for (final p in widget.proveedores) DropdownMenuItem(
                    value: p['id_proveedor'].toString(),
                    child: Text(p['razon_social'].toString(),
                      overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => proveedor = v,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < lineas.length; i++)
                Card(key: ObjectKey(lineas[i]), child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: Text('Producto ' + (i + 1).toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (lineas.length > 1)
                          IconButton(icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() {
                              final eliminado = lineas.removeAt(i);
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => eliminado.dispose());
                            })),
                      ]),
                      DropdownButtonFormField<String>(
                        initialValue: lineas[i].id,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Repuesto',
                          border: OutlineInputBorder()),
                        items: [
                          for (final p in widget.productos) DropdownMenuItem(
                            value: p['id_producto'].toString(),
                            child: Text(p['nombre_producto'].toString(),
                              overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => lineas[i].id = v,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lineas[i].cantidad,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cantidad',
                          border: OutlineInputBorder()),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 100000
                              ? 'Cantidad inválida' : null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lineas[i].precio,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                        decoration: const InputDecoration(labelText: 'Costo S/',
                          border: OutlineInputBorder()),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          return n == null || n < 0 || n > 10000000
                              ? 'Costo inválido' : null;
                        },
                      ),
                    ]))),
              TextButton.icon(onPressed: agregar,
                icon: const Icon(Icons.add),
                label: const Text('Agregar otra línea')),
            ]))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: guardar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar compra y aumentar stock'))),
        ])),
      ),
    ),
  );
}
