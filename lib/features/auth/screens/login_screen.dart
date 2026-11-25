import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../shared/brand/brand.dart';
import '../../../shared/character/blob_character.dart';
import '../../home/screens/home_screen.dart';

/// Login seguro según OWASP:
/// - Solo se valida que los campos no estén vacíos.
/// - Ante cualquier error de Firebase se muestra UN mensaje global.
/// - Personaje blob: sigue el cursor del correo, piensa mientras carga,
///   niega al fallar y asiente al entrar.
/// - CircularProgressIndicator mientras Firebase responde.
/// - Navigator.pushReplacement al catálogo en éxito.
///
/// Animaciones:
/// 1. Intro: el logo (blob + nombre) aparece grande y luego se acerca a
///    la cámara hasta desaparecer.
/// 2. Entrada: aparece el encabezado y la tarjeta sube desde abajo.
/// 3. Salida: al entrar, la tarjeta baja y todo se desvanece hacia el catálogo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  /// La intro completa solo se ve al abrir la app; al volver al login
  /// (por ejemplo al cerrar sesión) solo entra la tarjeta.
  static bool _introPlayed = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _characterKey = GlobalKey<BlobCharacterState>();
  final _emailFocus = FocusNode();

  // 0 → 1 a lo largo de toda la intro + entrada (ver intervalos abajo)
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  // 0 → 1 en la animación de salida tras un login correcto
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // ── Línea de tiempo de la intro ─────────────────────────
  // Cada Interval toma solo un tramo de los 2.8 s del controlador.
  late final _logoIn = _curve(0.00, 0.18, Curves.easeOutBack);
  late final _textIn = _curve(0.08, 0.25, Curves.easeOut);
  late final _textOut = _curve(0.38, 0.46, Curves.easeIn);
  late final _zoom = _curve(0.38, 0.62, Curves.easeInCubic);
  late final _logoOut = _curve(0.50, 0.62, Curves.easeIn);
  late final _splashBgOut = _curve(0.52, 0.66, Curves.easeOut);
  late final _headerIn = _curve(0.58, 0.80, Curves.easeOutCubic);
  late final _cardIn = _curve(0.66, 1.00, Curves.easeOutCubic);

  Animation<double> _curve(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  bool _isObscure = true;
  bool _isLoading = false;
  String? _errorMessage;

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

    // Si la intro ya se vio, se arranca desde el tramo de entrada
    _intro.forward(from: _introPlayed ? 0.56 : 0);
    _introPlayed = true;
  }

  void _followEmailCursor() {
    if (!_emailFocus.hasFocus) return;
    _characterKey.currentState?.followText(_emailCtrl);
  }

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

      // "Sí" con la cabeza, luego la animación de salida
      await _characterKey.currentState?.nodYes();
      await _exit.forward();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        // Transición de desvanecido hacia el catálogo
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on FirebaseAuthException {
      // ── Fallo: mensaje global único ────────────────
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Credenciales inválidas. Verifica tu correo y contraseña.';
      });
      _characterKey.currentState?.setThinking(false);
      // "No" con la cabeza
      _characterKey.currentState?.shakeNo();
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // íconos blancos en la barra de estado
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: Stack(
          children: [
            Positioned.fill(child: NightBackground(child: _buildLogin())),
            // La intro va encima y deja pasar los toques cuando termina
            Positioned.fill(child: IgnorePointer(child: _buildSplash())),
          ],
        ),
      ),
    );
  }

  /// Logo grande que aparece y luego "atraviesa" la pantalla.
  Widget _buildSplash() {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        if (_splashBgOut.value >= 1) return const SizedBox.shrink();
        // El logo crece de 1x a 9x mientras se desvanece
        final scale = _logoIn.value * (1 + _zoom.value * 8);
        return Opacity(
          opacity: 1 - _splashBgOut.value,
          child: NightBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: (1 - _logoOut.value).clamp(0, 1),
                    child: Transform.scale(
                      scale: scale,
                      child: const Halo(
                        size: 260,
                        child: BlobCharacter(size: 150),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: (_textIn.value - _textOut.value).clamp(0, 1),
                    child: Column(
                      children: [
                        const Wordmark(fontSize: 34),
                        const SizedBox(height: 8),
                        Text(
                          'Prepárate para tu próxima entrevista',
                          style: TextStyle(color: AppColors.onNight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogin() {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            // Ocupa al menos toda la pantalla para que la tarjeta quede abajo
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [_animatedHeader(), const Spacer(), _animatedCard()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Encabezado: entra con la intro y se desvanece en la salida.
  Widget _animatedHeader() {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _exit]),
      builder: (context, child) {
        final t = _headerIn.value;
        return Opacity(
          opacity: (t * (1 - _exit.value)).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          children: [
            Halo(
              size: 200,
              child: BlobCharacter(key: _characterKey, size: 130),
            ),
            const SizedBox(height: 8),
            const Wordmark(fontSize: 22),
            const SizedBox(height: 14),
            const Text(
              'Bienvenido de nuevo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tu próxima entrevista empieza aquí.',
              style: TextStyle(color: AppColors.onNight),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta blanca: sube al entrar y baja en la salida.
  Widget _animatedCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _exit]),
      builder: (context, child) {
        final hidden =
            (1 - _cardIn.value) + Curves.easeInCubic.transform(_exit.value);
        return FractionalTranslation(
          translation: Offset(0, hidden),
          child: child,
        );
      },
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Iniciar sesión',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),

          // ── Email ─────────────────────────────────
          TextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
              fillColor: AppColors.surfaceLight,
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
              fillColor: AppColors.surfaceLight,
              suffixIcon: IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ),
            ),
          ),

          // ── Forgot password ───────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),

          // ── Error global ──────────────────────────
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
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

          const SizedBox(height: 12),

          // ── Ir a registro (Navigator.push) ────────
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('¿No tienes cuenta?'),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text('Regístrate'),
              ),
            ],
          ),
        ],
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
              } on FirebaseAuthException {
                // Mismo mensaje exista o no el correo (OWASP)
              }
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
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
