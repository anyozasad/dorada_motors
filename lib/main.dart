import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/local_store.dart';
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

enum AppMode { loading, login, guest, authenticated }

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
    final session = await LocalStore.getSession();
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

  void _logout() {
    LocalStore.logout();
    setState(() {
      _session = null;
      _mode = AppMode.login;
    });
  }

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Widget _withDashboardAccess(Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: 18,
          bottom: 96,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'dashboardFab',
              onPressed: _openDashboard,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.dashboard_rounded, color: AppColors.gold),
              label: const Text(
                'Dashboard',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case AppMode.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AppMode.login:
        return LoginScreen(
          onAuthenticated: _loadSession,
          onGuest: _guest,
        );
      case AppMode.guest:
        return _withDashboardAccess(
          MainShell(
            isGuest: true,
            onLoginRequested: _showLogin,
            onLogout: _logout,
          ),
        );
      case AppMode.authenticated:
        return _withDashboardAccess(
          MainShell(
            isGuest: false,
            userName: _session?['name'],
            userEmail: _session?['email'],
            onLoginRequested: _showLogin,
            onLogout: _logout,
          ),
        );
    }
  }
}
