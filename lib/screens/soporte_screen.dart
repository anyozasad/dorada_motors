import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SoporteScreen extends StatefulWidget {
  const SoporteScreen({super.key});

  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

class _SoporteScreenState extends State<SoporteScreen> {
  bool _cargando = true;
  bool _enviando = false;
  String? _error;
  List<Map<String, dynamic>> _solicitudes = [];

  @override
  void initState() {
    super.initState();
    _actualizar();
  }

  Future<void> _actualizar() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final lista = await ApiService.obtenerSolicitudesSoporte();
      if (!mounted) return;
      setState(() {
        _solicitudes = lista
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _nuevoCaso() async {
    if (_enviando) return;
    final asunto = TextEditingController();
    final mensaje = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar consulta'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: asunto,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Asunto',
                    prefixIcon: Icon(Icons.subject_outlined),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 5
                      ? 'Escribe un asunto de al menos 5 caracteres'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: mensaje,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: '¿En qué podemos ayudarte?',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? 'Describe la consulta con al menos 10 caracteres'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _enviando = true);
      try {
        await ApiService.registrarSolicitudSoporte(
          asunto: asunto.text,
          mensaje: mensaje.text,
        );
        _mensaje('Solicitud enviada. Puedes consultar aquí la respuesta.');
        await _actualizar();
      } catch (e) {
        _mensaje(e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _enviando = false);
      }
    }
    asunto.dispose();
    mensaje.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y soporte'),
        actions: [
          IconButton(
            onPressed: _actualizar,
            tooltip: 'Actualizar solicitudes',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _enviando ? null : _nuevoCaso,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nueva consulta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 45, color: AppColors.muted),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _actualizar, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _actualizar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estamos para ayudarte',
                                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                            SizedBox(height: 7),
                            Text('Envía una consulta sobre tu pedido o repuesto. La respuesta del administrador aparecerá aquí.',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Mis consultas (${_solicitudes.length})',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (_solicitudes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(25),
                          child: Text('Aún no hay consultas. Usa «Nueva consulta» para escribir al administrador.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._solicitudes.map((solicitud) {
                        final estado = solicitud['estado']?.toString() ?? 'Abierto';
                        final respuesta = solicitud['respuesta']?.toString().trim() ?? '';
                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          child: ExpansionTile(
                            title: Text(solicitud['asunto']?.toString() ?? 'Consulta',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('#${solicitud['id_solicitud']} • $estado',
                                style: const TextStyle(color: AppColors.goldDark)),
                            childrenPadding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(solicitud['mensaje']?.toString() ?? ''),
                              ),
                              const Divider(height: 22),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  respuesta.isEmpty
                                      ? 'Todavía no hay respuesta del administrador.'
                                      : 'Respuesta: $respuesta',
                                  style: TextStyle(
                                    color: respuesta.isEmpty ? AppColors.muted : AppColors.ink,
                                    fontWeight: respuesta.isEmpty ? FontWeight.normal : FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
