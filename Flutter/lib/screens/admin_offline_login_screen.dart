// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';

import '../services/admin_offline_repository.dart';
import 'admin_mobile_screen.dart';

/// Acceso al almacén y a las ventas guardados exclusivamente en el dispositivo.
/// No necesita dirección IP, Wi-Fi, cuenta PHP ni XAMPP.
class AdminOfflineLoginScreen extends StatefulWidget {
  const AdminOfflineLoginScreen({super.key});

  @override
  State<AdminOfflineLoginScreen> createState() => _AdminOfflineLoginScreenState();
}

class _AdminOfflineLoginScreenState extends State<AdminOfflineLoginScreen> {
  final password = TextEditingController();
  final confirmacion = TextEditingController();
  bool? configurado;
  bool guardando = false;
  bool ocultar = true;

  @override
  void initState() {
    super.initState();
    verificar();
  }

  Future<void> verificar() async {
    try {
      final existe = await AdminOfflineRepository.estaConfigurado();
      if (mounted) setState(() => configurado = existe);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirmacion.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (guardando) return;
    final clave = password.text;
    if (clave.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Escribe al menos 8 caracteres')));
      return;
    }
    setState(() => guardando = true);
    try {
      if (configurado == false) {
        if (clave != confirmacion.text) {
          throw StateError('Las contraseñas no coinciden');
        }
        await AdminOfflineRepository.crearAcceso(clave);
      } else {
        if (!await AdminOfflineRepository.comprobarAcceso(clave)) {
          throw StateError('Contraseña local incorrecta');
        }
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => AdminMobileDashboardScreen(
          modoLocal: true,
          onLogout: () {},
        ),
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administrador sin laptop')),
    body: configurado == null
        ? const Center(child: CircularProgressIndicator())
        : Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 450),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.phonelink_off,
                    color: Color(0xFFB8860B), size: 64),
                const SizedBox(height: 16),
                Text(configurado! ? 'Entrar al dashboard local'
                    : 'Crear acceso local', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text(
                  'No necesitas encender tu laptop. Los productos, '
                  'clientes, ventas, pagos y movimientos se guardan en '
                  'SQLite de este teléfono, NO en MySQL. '
                  'Esta es una base de datos independiente.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                if (!configurado!) const Card(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Primer ingreso: configura tu propia '
                    'contraseña de 8 caracteres o más. No existe una '
                    'contraseña predeterminada. Recuerda esta clave.'),
                )),
                const SizedBox(height: 14),
                TextField(controller: password, obscureText: ocultar,
                  onSubmitted: (_) => entrar(),
                  decoration: InputDecoration(
                    labelText: configurado! ? 'Contraseña del celular'
                        : 'Crear contraseña local (mínimo 8)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(ocultar
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => ocultar = !ocultar)),
                  )),
                if (!configurado!) ...[
                  const SizedBox(height: 12),
                  TextField(controller: confirmacion, obscureText: ocultar,
                    onSubmitted: (_) => entrar(),
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña local',
                      border: OutlineInputBorder(),
                    )),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(onPressed: guardando ? null : entrar,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(guardando ? 'Verificando...'
                    : (configurado! ? 'Abrir dashboard'
                    : 'Crear acceso y abrir dashboard'))),
                const SizedBox(height: 9),
                const Text('La administración local es independiente de '
                    'las cuentas de usuarios y empleados de PHP/MySQL.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12)),
              ]),
          ),
        )),
  );
}
