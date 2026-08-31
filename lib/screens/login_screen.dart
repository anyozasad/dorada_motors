import 'package:flutter/material.dart';

import '../services/local_store.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onGuest;

  const LoginScreen({
    super.key,
    required this.onAuthenticated,
    required this.onGuest,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa correo y contraseña.')),
      );
      return;
    }

    setState(() => _loading = true);
    final error = await LocalStore.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    widget.onAuthenticated();
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onRegistered: () {
            Navigator.of(context).pop();
            widget.onAuthenticated();
          },
        ),
      ),
    );
  }

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.lock_reset_rounded,
          color: AppColors.goldDark,
          size: 42,
        ),
        title: const Text('Recuperar contraseña'),
        content: const Text(
          'La recuperación de contraseña quedará disponible cuando la aplicación se conecte con el servicio de usuarios.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _PremiumLoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    children: [
                      _brandHeader(),
                      const SizedBox(height: 22),
                      _loginCard(),
                      const SizedBox(height: 22),
                      _benefitsPanel(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader() {
    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: .16),
                blurRadius: 28,
                offset: const Offset(0, 13),
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
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
              color: AppColors.navy,
              height: 1.05,
            ),
            children: [
              TextSpan(text: 'DORADA '),
              TextSpan(
                text: 'MOTORS',
                style: TextStyle(color: AppColors.goldDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                "ADN Import's • Repuestos para moto y motokar",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _loginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .12),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Transform.translate(
              offset: const Offset(0, -49),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldSoft, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: .10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 38,
                  color: AppColors.goldDark,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: const Column(
              children: [
                Text(
                  'Bienvenido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Ingresa a tu cuenta para continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: _fieldDecoration(
                    label: 'Correo electrónico',
                    icon: Icons.mail_outline_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _login(),
                  decoration: _fieldDecoration(
                    label: 'Contraseña',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 57,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, color: AppColors.gold),
                              SizedBox(width: 10),
                              Text(
                                'INICIAR SESIÓN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .6,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Flexible(
                      child: Text(
                        '¿No tienes una cuenta?',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _openRegister,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Crear cuenta',
                        style: TextStyle(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'O CONTINÚA COMO',
                        style: TextStyle(
                          color: AppColors.muted.withValues(alpha: .85),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: widget.onGuest,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.navy, width: 1.2),
                      foregroundColor: AppColors.navy,
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text(
                      'Continuar como invitado',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: AppColors.navy),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
      ),
    );
  }

  Widget _benefitsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navySoft],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .18),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 14,
            children: [
              _BenefitItem(
                icon: Icons.verified_user_outlined,
                title: 'CALIDAD',
                subtitle: 'GARANTIZADA',
              ),
              _BenefitItem(
                icon: Icons.workspace_premium_outlined,
                title: 'MARCAS',
                subtitle: 'ORIGINALES',
              ),
              _BenefitItem(
                icon: Icons.local_shipping_outlined,
                title: 'ENVÍOS',
                subtitle: 'RÁPIDOS',
              ),
              _BenefitItem(
                icon: Icons.support_agent_rounded,
                title: 'SOPORTE',
                subtitle: 'CONFIABLE',
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(height: 1, color: AppColors.gold.withValues(alpha: .55)),
          const SizedBox(height: 15),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Potencia, calidad y confianza en cada repuesto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumLoginBackground extends StatelessWidget {
  const _PremiumLoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDFDFE), Color(0xFFF3F5F8)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -165,
          left: -80,
          right: -80,
          child: Container(
            height: 265,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.navy, Color(0xFF06294A)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.elliptical(320, 90),
                bottomRight: Radius.elliptical(320, 90),
              ),
            ),
          ),
        ),
        Positioned(
          top: 82,
          left: -58,
          child: Icon(
            Icons.two_wheeler_rounded,
            size: 170,
            color: AppColors.navy.withValues(alpha: .045),
          ),
        ),
        Positioned(
          top: 125,
          right: -40,
          child: Icon(
            Icons.local_shipping_outlined,
            size: 155,
            color: AppColors.gold.withValues(alpha: .055),
          ),
        ),
        Positioned(
          top: 97,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.gold.withValues(alpha: .9),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: .25)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
