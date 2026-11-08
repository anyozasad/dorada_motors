import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

/// Permite gestionar direcciones del cliente autenticado desde la API PHP.
class DireccionesScreen extends StatefulWidget {
  const DireccionesScreen({super.key});

  @override
  State<DireccionesScreen> createState() => _DireccionesScreenState();
}

class _DireccionesScreenState extends State<DireccionesScreen> {
  List<Map<String, dynamic>> _direcciones = [];
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  int _idUsuario = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final sesion = await LocalStore.getSession();
      _idUsuario = int.tryParse(sesion?['id'] ?? '') ?? 0;
      if (_idUsuario <= 0) throw Exception('Inicia sesión para ver tus direcciones.');

      final data = await ApiService.obtenerDireccionesUsuario(_idUsuario);
      if (!mounted) return;
      setState(() {
        _direcciones = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  void _mensaje(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _editar([Map<String, dynamic>? actual]) async {
    if (_guardando || _idUsuario <= 0) return;

    final direccionController = TextEditingController(
      text: actual?['direccion_detalle']?.toString() ?? '',
    );
    final referenciaController = TextEditingController(
      text: actual?['referencia']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(actual == null ? 'Nueva dirección' : 'Editar dirección'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: direccionController,
                  autofocus: true,
                  maxLength: 255,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 5
                      ? 'Escribe una dirección válida'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: referenciaController,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _guardando = true);
      try {
        if (actual == null) {
          await ApiService.registrarDireccion(
            idUsuario: _idUsuario,
            direccion: direccionController.text,
            referencia: referenciaController.text,
          );
        } else {
          final id = int.tryParse(actual['id_direccion']?.toString() ?? '') ?? 0;
          await ApiService.actualizarDireccion(
            idUsuario: _idUsuario,
            idDireccion: id,
            direccion: direccionController.text,
            referencia: referenciaController.text,
          );
        }
        _mensaje('Dirección guardada correctamente.');
        await _cargar();
      } catch (e) {
        _mensaje(e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
    }

    direccionController.dispose();
    referenciaController.dispose();
  }

  Future<void> _eliminar(Map<String, dynamic> actual) async {
    if (_guardando) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: const Text('¿Deseas eliminar esta dirección? Si está asociada a un pedido no se podrá borrar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final id = int.tryParse(actual['id_direccion']?.toString() ?? '') ?? 0;
    if (id <= 0) return;

    setState(() => _guardando = true);
    try {
      await ApiService.eliminarDireccion(id);
      _mensaje('Dirección eliminada.');
      await _cargar();
    } catch (e) {
      _mensaje(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis direcciones'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualizar'),
        ],
      ),
      floatingActionButton: _idUsuario > 0
          ? FloatingActionButton.extended(
              onPressed: _guardando ? null : () => _editar(),
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Agregar dirección'),
            )
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 54, color: AppColors.muted),
                        const SizedBox(height: 14),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _direcciones.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(25),
                        child: Text('Aún no tienes direcciones guardadas. Agrega una para tus próximas entregas.', textAlign: TextAlign.center),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _direcciones.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final direccion = _direcciones[index];
                          final referencia = direccion['referencia']?.toString() ?? '';
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, color: AppColors.goldDark),
                                      SizedBox(width: 8),
                                      Text('Dirección de entrega', style: TextStyle(fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(direccion['direccion_detalle']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (referencia.trim().isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(referencia, style: const TextStyle(color: AppColors.muted)),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: _guardando ? null : () => _editar(direccion),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Editar'),
                                      ),
                                      TextButton.icon(
                                        onPressed: _guardando ? null : () => _eliminar(direccion),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
