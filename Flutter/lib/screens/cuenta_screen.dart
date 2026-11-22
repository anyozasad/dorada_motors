import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/offline_actions.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class CuentaScreen extends StatefulWidget {
  final VoidCallback onUpdated;

  const CuentaScreen({super.key, required this.onUpdated});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _claveActual = TextEditingController();
  final _claveNueva = TextEditingController();
  final _claveConfirmar = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCuenta();
  }

  @override
  void dispose() {
    for (final c in [
      _nombres, _apellidos, _correo, _telefono,
      _claveActual, _claveNueva, _claveConfirmar,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarCuenta() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      Map<String, dynamic> cuenta;
      try {
        final respuesta = await ApiService.obtenerCuenta();
        cuenta = Map<String, dynamic>.from(respuesta['usuario'] as Map);
        await OfflineActions.guardarCopia('cuenta', cuenta);
      } catch (e) {
        if (!ApiService.esErrorConexion(e)) rethrow;
        final copia = await OfflineActions.leerCopia('cuenta');
        if (copia is Map) {
          cuenta = Map<String, dynamic>.from(copia);
        } else {
          // La sesión ya validada anteriormente aporta nombre y correo
          // para editar el perfil offline en la primera apertura.
          final sesion = await LocalStore.getSession();
          if (sesion == null) {
            throw Exception('No hay una sesión local para editar tu perfil.');
          }
          final nombre = (sesion['name'] ?? '').trim().split(' ');
          cuenta = <String, dynamic>{
            'nombres': nombre.isEmpty ? '' : nombre.first,
            'apellidos': nombre.length > 1 ? nombre.skip(1).join(' ') : '',
            'correo': sesion['email'] ?? '',
            'telefono': '',
          };
        }
      }
      final operaciones = await OfflineActions.operacionesPendientes(accion: 'perfil');
      if (operaciones.isNotEmpty) {
        cuenta.addAll(Map<String, dynamic>.from(operaciones.last['datos'] as Map));
      }
      if (!mounted) return;
      setState(() {
        _nombres.text = cuenta['nombres']?.toString() ?? '';
        _apellidos.text = cuenta['apellidos']?.toString() ?? '';
        _correo.text = cuenta['correo']?.toString() ?? '';
        _telefono.text = cuenta['telefono']?.toString() ?? '';
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardarPerfil() async {
    if (_guardando || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      final datos = <String, dynamic>{
        'nombres': _nombres.text.trim(),
        'apellidos': _apellidos.text.trim(),
        'correo': _correo.text.trim().toLowerCase(),
        'telefono': _telefono.text.trim(),
      };
      final id = await OfflineActions.usuarioActual();
      final guardado = await OfflineActions.registrar(
        accion: 'perfil', clave: 'perfil_$id', datos: datos,
      );
      await OfflineActions.guardarCopia('cuenta', datos);
      await LocalStore.updateSessionProfile(
        name: [datos['nombres'] as String, datos['apellidos'] as String]
            .where((parte) => parte.isNotEmpty).join(' '),
        email: datos['correo'] as String,
      );
      widget.onUpdated();
      _avisar(guardado ? 'Datos actualizados en MySQL.'
          : 'Datos guardados en SQLite. Se sincronizarán al reconectar.');
    } catch (e) {
      _avisar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarClave() async {
    if (_guardando) return;
    if (_claveActual.text.isEmpty || _claveNueva.text.length < 8) {
      _avisar('Escribe tu contraseña actual y una nueva de mínimo 8 caracteres.');
      return;
    }
    if (_claveNueva.text != _claveConfirmar.text) {
      _avisar('Las contraseñas nuevas no coinciden.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await ApiService.cambiarClave(
        actual: _claveActual.text,
        nueva: _claveNueva.text,
      );
      _claveActual.clear();
      _claveNueva.clear();
      _claveConfirmar.clear();
      _avisar('Contraseña cambiada. Se cerraron las demás sesiones.');
    } catch (e) {
      _avisar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _campo(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.goldDark),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargarCuenta,
            tooltip: 'Actualizar datos',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _cargarCuenta, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  children: [
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(19),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Datos personales',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              const Text('Sin internet se guardan en SQLite; MySQL se actualiza al reconectar.',
                                  style: TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _nombres,
                                decoration: _campo('Nombres', Icons.person_outline),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'Ingresa tus nombres' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _apellidos,
                                decoration: _campo('Apellidos', Icons.badge_outlined),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _correo,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _campo('Correo electrónico', Icons.email_outlined),
                                validator: (v) =>
                                    !(v?.contains('@') ?? false) ? 'Correo inválido' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _telefono,
                                keyboardType: TextInputType.phone,
                                decoration: _campo('Teléfono', Icons.phone_outlined),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _guardando ? null : _guardarPerfil,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(_guardando ? 'Guardando...' : 'Guardar datos'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(19),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Seguridad de la cuenta',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            const Text('Para cambiar la contraseña, confirma la actual.',
                                style: TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 17),
                            TextField(
                              controller: _claveActual,
                              obscureText: true,
                              decoration: _campo('Contraseña actual', Icons.lock_outline),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _claveNueva,
                              obscureText: true,
                              decoration: _campo('Nueva contraseña', Icons.key_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _claveConfirmar,
                              obscureText: true,
                              decoration: _campo('Confirmar contraseña', Icons.verified_user_outlined),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _guardando ? null : _cambiarClave,
                              icon: const Icon(Icons.password_outlined),
                              label: const Text('Cambiar contraseña'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
