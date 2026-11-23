import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/admin_mobile_screen.dart';
import 'screens/main_shell.dart';
import 'services/local_store.dart';
import 'services/offline_store.dart';
import 'services/offline_actions.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DoradaMotorsApp());
}

class DoradaMotorsApp extends StatelessWidget {
  const DoradaMotorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dorada Motors',
      theme: AppTheme.light,
      home: const AppRoot(),
    );
  }
}

enum AppMode { loading, login, guest, authenticated, admin }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppMode _mode = AppMode.loading;
  Map<String, String>? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    ApiService.configurarServidor(await LocalStore.getApiBaseUrl());
    final sesionAdmin = await AdminMobileApi.sesion();
    if (sesionAdmin != null) {
      final vigenteAdmin = await AdminMobileApi.verificar();
      if (vigenteAdmin == false) {
        await AdminMobileApi.limpiar();
      } else {
        if (!mounted) return;
        setState(() { _session = null; _mode = AppMode.admin; });
        return;
      }
    }
    var session = await LocalStore.getSession();
    if (session != null) {
      // No confundir un token guardado con una sesión vigente en MySQL.
      // Solo borrar el acceso si el servidor respondió 401/403; con Apache
      // apagado se conserva la sesión y las pantallas muestran el error de red.
      final vigente = await ApiService.verificarSesion();
      if (vigente == false) {
        final userId = int.tryParse(session['id'] ?? '') ?? 0;
        // Una sesión expirada NO debe eliminar los borradores ni ediciones
        // pendientes: podrán sincronizarse al iniciar sesión otra vez.
        await LocalStore.clearUserShoppingCache(
          userId, conservarPendientes: true,
        );
        await LocalStore.logout();
        await LocalStore.clearCart();
        await LocalStore.saveFavorites(<int>{});
        session = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _mode = session == null ? AppMode.login : AppMode.authenticated;
    });
  }

  void _guest() {
    setState(() {
      _session = null;
      _mode = AppMode.guest;
    });
  }

  void _showLogin() {
    setState(() => _mode = AppMode.login);
  }

  Future<void> _logout() async {
    final session = await LocalStore.getSession();
    final userId = int.tryParse(session?['id'] ?? '') ?? 0;

    // El cliente puede cerrar sesión sin perder sus cambios pendientes:
    // se conservan en SQLite, separados por cuenta y servidor.
    final pendientes = await OfflineActions.pendientes();
    final carrito = await OfflineStore.carritoPendiente(userId);
    final favoritos = await OfflineStore.favoritosPendientes(userId);
    final total = pendientes + carrito.length + favoritos.length;
    var descartarPendientes = false;
    if (total > 0 && mounted) {
      final seleccion = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tienes cambios sin enviar'),
          content: Text(
            'Hay $total registro(s) guardados solo en este celular. '
            'Puedes salir conservándolos en SQLite para tu próximo inicio '
            'de sesión, o descartarlos definitivamente. '
            'Ninguno se guardará en MySQL hasta recuperar la conexión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'volver'),
              child: const Text('Volver'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'descartar'),
              child: const Text('Salir y descartar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'conservar'),
              child: const Text('Salir y conservar'),
            ),
          ],
        ),
      );
      if (seleccion == null || seleccion == 'volver') return;
      descartarPendientes = seleccion == 'descartar';
    }

    // El usuario puede salir incluso si Apache está apagado.
    try {
      await ApiService.cerrarSesion();
    } catch (_) {
      // Nunca bloquear el cierre de sesión por una falla de red.
    }
    if (descartarPendientes || total == 0) {
      await OfflineActions.limpiarCuentaLocal();
    }
    await LocalStore.clearUserShoppingCache(
      userId,
      conservarPendientes: total > 0 && !descartarPendientes,
    );
    await LocalStore.logout();
    await LocalStore.clearCart();
    await LocalStore.saveFavorites(<int>{});
    if (!mounted) return;
    setState(() {
      _session = null;
      _mode = AppMode.login;
    });
  }


  @override
  Widget build(BuildContext context) {
    final child = switch (_mode) {
      AppMode.loading => const _BrandSplash(),
      AppMode.login => LoginScreen(
          onAuthenticated: _loadSession,
          onGuest: _guest,
          onAdminAuthenticated: _loadSession,
        ),
      AppMode.admin => AdminMobileDashboardScreen(onLogout: _showLogin),
      AppMode.guest => MainShell(
          isGuest: true,
          onLoginRequested: _showLogin,
          onLogout: _logout,
          onProfileUpdated: _loadSession,
        ),
      AppMode.authenticated => MainShell(
          isGuest: false,
          userName: _session?['name'],
          userEmail: _session?['email'],
          onLoginRequested: _showLogin,
          onLogout: _logout,
          onProfileUpdated: _loadSession,
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_mode),
        child: child,
      ),
    );
  }
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDFDFE),
              Color(0xFFF3F4F7),
            ],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .88, end: 1),
            duration: const Duration(milliseconds: 720),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Opacity(
              opacity: value.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(scale: value, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: .14),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset(
                      'assets/imagenes/logo_adn_imports.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'DORADA MOTORS',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "ADN Import's · Repuestos para moto y motokar",
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
