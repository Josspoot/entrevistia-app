import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../shared/character/blob_character.dart';
import '../../home/screens/home_screen.dart';

/// Login seguro según OWASP:
/// - Solo se valida que los campos no estén vacíos.
/// - Ante cualquier error de Firebase se muestra UN mensaje global.
/// - Personaje blob: sigue el cursor del correo, piensa mientras carga,
///   niega al fallar y asiente al entrar.
/// - CircularProgressIndicator mientras Firebase responde.
/// - Navigator.pushReplacement al catálogo en éxito.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _characterKey = GlobalKey<BlobCharacterState>();
  final _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // El personaje sigue al cursor mientras se escribe el correo
    _emailCtrl.addListener(_followEmailCursor);
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        _followEmailCursor();
      } else {
        _characterKey.currentState?.lookCenter();
      }
    });
  }

  void _followEmailCursor() {
    if (!_emailFocus.hasFocus) return;
    _characterKey.currentState?.followText(_emailCtrl);
  }

  bool _isObscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Login OWASP ────────────────────────────────────────
  Future<void> _onLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    // Solo validar que no estén vacíos (OWASP: sin regex ni pistas)
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Completa todos los campos.';
      });
      _characterKey.currentState?.shakeNo();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _characterKey.currentState?.setThinking(true);
    FocusScope.of(context).unfocus();

    try {
      // Espera mínima para que el spinner y la animación se perciban
      await Future.delayed(const Duration(seconds: 1));

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ── Éxito ──────────────────────────────────────
      if (!mounted) return;
      setState(() => _isLoading = false);
      _characterKey.currentState?.setThinking(false);

      // "Sí" con la cabeza antes de entrar
      await _characterKey.currentState?.nodYes();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException {
      // ── Fallo: mensaje global único ────────────────
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Credenciales inválidas. Verifica tu correo y contraseña.';
      });
      // "No" con la cabeza
      _characterKey.currentState?.shakeNo();
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Personaje ─────────────────────────────
              BlobCharacter(key: _characterKey, size: 170),

              const SizedBox(height: 12),

              Text(
                'EntrevistIA',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Prepárate para tu próxima entrevista',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 36),

              // ── Email ─────────────────────────────────
              TextField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // ── Password ──────────────────────────────
              TextField(
                controller: _passwordCtrl,
                obscureText: _isObscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onLogin(),
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),

              // ── Forgot password ───────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPasswordDialog(),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),

              // ── Error global ──────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Botón Login ───────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _onLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Iniciar sesión'),
              ),

              const SizedBox(height: 20),

              // ── Ir a registro ─────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tienes cuenta?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text('Regístrate'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Diálogo de recuperación ────────────────────────────
  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetCtrl.text.trim();
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Si el correo está registrado, recibirás un enlace de recuperación.',
                    ),
                  ),
                );
              } on FirebaseAuthException {
                // Mensaje genérico por seguridad (OWASP)
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Si el correo está registrado, recibirás un enlace de recuperación.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }
}
