import 'package:flutter/material.dart';

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
    setState(() {
      _session = null;
      _mode = AppMode.login;
    });
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
        return MainShell(
          isGuest: true,
          onLoginRequested: _showLogin,
          onLogout: _logout,
        );
      case AppMode.authenticated:
        return MainShell(
          isGuest: false,
          userName: _session?['name'],
          userEmail: _session?['email'],
          onLoginRequested: _showLogin,
          onLogout: _logout,
        );
    }
  }
}
