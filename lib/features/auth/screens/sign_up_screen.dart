import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../shared/character/blob_character.dart';

/// Pantalla de registro con validaciones visibles por campo.
///
/// Reglas:
///   - Correo institucional: @tecdesoftware.edu.mx
///   - Contraseña: 8+ chars, mayúscula, minúscula, número y símbolo
///   - Confirmación de contraseña
///   - Errores específicos de Firebase permitidos aquí
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _characterKey = GlobalKey<BlobCharacterState>();
  final _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Igual que en el login: el blob sigue al cursor del correo
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
  bool _isObscureConfirm = true;
  bool _isLoading = false;

  // ── Validadores ────────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio.';
    }
    if (!value.trim().endsWith('@tecdesoftware.edu.mx')) {
      return 'Usa tu correo institucional (@tecdesoftware.edu.mx).';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (value.length < 8) {
      return 'Mínimo 8 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Incluye al menos una mayúscula.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Incluye al menos una minúscula.';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Incluye al menos un número.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Incluye al menos un símbolo.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordCtrl.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  // ── Registro ───────────────────────────────────────────

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) {
      _characterKey.currentState?.shakeNo();
      return;
    }

    setState(() => _isLoading = true);
    _characterKey.currentState?.setThinking(true);
    FocusScope.of(context).unfocus();

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      _characterKey.currentState?.setThinking(false);
      setState(() => _isLoading = false);
      await _characterKey.currentState?.nodYes();

      if (!mounted) return;
      // Cerrar sesión para que inicie desde el login
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Inicia sesión con tu nuevo correo.'),
        ),
      );
      Navigator.pop(context); // Volver al login
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _characterKey.currentState?.setThinking(false);
      setState(() => _isLoading = false);
      _characterKey.currentState?.shakeNo();

      // Aquí SÍ se permiten mensajes específicos (sección 3.1 B)
      final msg = switch (e.code) {
        'email-already-in-use' => 'Este correo ya tiene una cuenta.',
        'weak-password' =>
          'La contraseña es demasiado débil. Intenta otra.',
        'invalid-email' => 'El correo no es válido.',
        _ => 'No se pudo crear la cuenta. Intenta de nuevo.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),
                BlobCharacter(key: _characterKey, size: 130),
                const SizedBox(height: 24),

                // ── Reglas visibles ─────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requisitos de la contraseña:',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      ...[
                        'Mínimo 8 caracteres',
                        'Al menos una letra mayúscula',
                        'Al menos una letra minúscula',
                        'Al menos un número',
                        'Al menos un símbolo (!@#\$%…)',
                      ].map(
                        (rule) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 14, color: AppColors.textHint),
                              const SizedBox(width: 8),
                              Text(rule,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Correo ──────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  decoration: const InputDecoration(
                    hintText: 'usuario@tecdesoftware.edu.mx',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Contraseña ──────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _isObscure,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Confirmar ───────────────────────────
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _isObscureConfirm,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirm,
                  onFieldSubmitted: (_) => _onSignUp(),
                  decoration: InputDecoration(
                    hintText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                          () => _isObscureConfirm = !_isObscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Botón ───────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _onSignUp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }
}
