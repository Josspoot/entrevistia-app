import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Orbe animado que reemplaza al oso de Rive.
///
/// Estados:
///   idle     → pulsa suavemente (respiración)
///   loading  → gira más rápido y pulsa
///   success  → se expande verde con glow
///   fail     → sacudida + rojo
///
/// Uso:
///   final orbKey = GlobalKey of OrbWidgetState;
///   OrbWidget(key: orbKey, size: 160)
///   orbKey.currentState?.triggerSuccess();
///   orbKey.currentState?.triggerFail();
///   orbKey.currentState?.setLoading(true);
class OrbWidget extends StatefulWidget {
  final double size;

  const OrbWidget({super.key, this.size = 160});

  @override
  State<OrbWidget> createState() => OrbWidgetState();
}

class OrbWidgetState extends State<OrbWidget>
    with TickerProviderStateMixin {
  // ── Controladores ────────────────────────────────────
  late final AnimationController _breatheCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _resultCtrl;
  late final AnimationController _shakeCtrl;

  // ── Estado visual ────────────────────────────────────
  _OrbState _state = _OrbState.idle;
  Color _glowColor = AppColors.primaryLight;

  @override
  void initState() {
    super.initState();

    // Respiración: escala suave 0.95 ↔ 1.05
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Rotación del gradiente
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();

    // Flash de resultado (success / fail)
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Sacudida en fallo
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  // ── API pública ──────────────────────────────────────

  void setLoading(bool loading) {
    setState(() {
      _state = loading ? _OrbState.loading : _OrbState.idle;
      _glowColor = AppColors.primaryLight;
    });
    // Las manchas se mueven más rápido mientras carga.
    // repeat() reinicia el ciclo para aplicar la nueva duración.
    _rotateCtrl.duration = Duration(milliseconds: loading ? 2500 : 9000);
    _rotateCtrl.repeat();
  }

  Future<void> triggerSuccess() async {
    setState(() {
      _state = _OrbState.success;
      _glowColor = AppColors.success;
    });
    _resultCtrl.forward(from: 0);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _state = _OrbState.idle;
      _glowColor = AppColors.primaryLight;
    });
  }

  Future<void> triggerFail() async {
    setState(() {
      _state = _OrbState.fail;
      _glowColor = AppColors.error;
    });
    _shakeCtrl.forward(from: 0);
    _resultCtrl.forward(from: 0);
    await Future.delayed(const Duration(seconds: 1, milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _state = _OrbState.idle;
      _glowColor = AppColors.primaryLight;
    });
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breatheCtrl,
        _rotateCtrl,
        _resultCtrl,
        _shakeCtrl,
      ]),
      builder: (context, child) {
        // Escala: respiración + pulso de resultado
        final breathe = 0.95 + 0.1 * _breatheCtrl.value;
        final resultPulse = _state == _OrbState.success
            ? 1.0 + 0.08 * sin(_resultCtrl.value * pi)
            : 1.0;
        final scale = breathe * resultPulse;

        // Sacudida horizontal en fallo
        final shakeOffset = _state == _OrbState.fail
            ? sin(_shakeCtrl.value * pi * 6) * 8
            : 0.0;

        // Opacidad del glow
        final glowOpacity = _state == _OrbState.idle
            ? 0.3 + 0.15 * _breatheCtrl.value
            : 0.5 + 0.3 * sin(_resultCtrl.value * pi);

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _OrbPainter(
                  rotation: _rotateCtrl.value * 2 * pi,
                  glowColor: _glowColor,
                  glowOpacity: glowOpacity,
                  tint: _state == _OrbState.success || _state == _OrbState.fail
                      ? _glowColor
                      : null,
                  tintStrength: 0.45 * sin(_resultCtrl.value * pi),
                  isLoading: _state == _OrbState.loading,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _rotateCtrl.dispose();
    _resultCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }
}

// ── Estado interno ───────────────────────────────────────
enum _OrbState { idle, loading, success, fail }

// ── Painter ──────────────────────────────────────────────
/// Una mancha de color que orbita dentro de la esfera.
class _Blob {
  final Color color;
  final double orbit; // distancia al centro (fracción del radio)
  final double size; // tamaño de la mancha (fracción del radio)
  final int speed; // vueltas por ciclo; entero para que el loop no salte
  final double phase; // ángulo inicial

  const _Blob(this.color, this.orbit, this.size, this.speed, this.phase);
}

// Orden = orden de dibujo: primero los azules (fondo), al final los vivos.
const _blobs = [
  _Blob(AppColors.primaryDark, 0.70, 0.45, 1, 1.0),
  _Blob(AppColors.primary, 0.60, 0.45, -1, 2.4),
  _Blob(AppColors.sky, 0.55, 0.38, 2, 4.0),
  _Blob(AppColors.lilac, 0.55, 0.40, -1, 3.6),
  _Blob(AppColors.mint, 0.50, 0.38, 1, 5.3),
  _Blob(AppColors.secondary, 0.38, 0.42, -1, 0.2),
  _Blob(AppColors.tertiary, 0.55, 0.26, 1, 0.9),
];

class _OrbPainter extends CustomPainter {
  final double rotation;
  final Color glowColor;
  final double glowOpacity;
  final bool isLoading;
  final Color? tint;
  final double tintStrength;

  _OrbPainter({
    required this.rotation,
    required this.glowColor,
    required this.glowOpacity,
    required this.isLoading,
    this.tint,
    this.tintStrength = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final orbRadius = radius * 0.75;
    final orbRect = Rect.fromCircle(center: center, radius: orbRadius);

    // ── Glow exterior ────────────────────────────────
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.25)
      ..color = glowColor.withValues(alpha: glowOpacity);
    canvas.drawCircle(center, orbRadius * 1.02, glowPaint);

    // Todo lo que sigue se recorta a la esfera
    canvas.save();
    canvas.clipPath(Path()..addOval(orbRect));

    // ── Base: periwinkle claro arriba, cobalto abajo ─
    canvas.drawRect(
      orbRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lilac, AppColors.primaryLight, AppColors.primary],
        ).createShader(orbRect),
    );

    // ── Manchas de color difuminadas ─────────────────
    for (final b in _blobs) {
      final angle = rotation * b.speed + b.phase;
      final pos = center +
          Offset(cos(angle), sin(angle)) * (b.orbit * orbRadius);
      canvas.drawCircle(
        pos,
        b.size * orbRadius,
        Paint()
          ..color = b.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, orbRadius * 0.16),
      );
    }

    // ── Tinte de resultado (verde éxito / rojo fallo) ─
    if (tint != null && tintStrength > 0) {
      canvas.drawRect(
        orbRect,
        Paint()..color = tint!.withValues(alpha: tintStrength),
      );
    }

    // ── Brillo superior izquierdo ────────────────────
    final highlightCenter =
        Offset(center.dx - orbRadius * 0.35, center.dy - orbRadius * 0.4);
    canvas.drawCircle(
      highlightCenter,
      orbRadius * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: highlightCenter, radius: orbRadius * 0.6),
        ),
    );

    // ── Sombra suave en el borde (da volumen) ────────
    canvas.drawCircle(
      center,
      orbRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            AppColors.primaryDark.withValues(alpha: 0.18),
          ],
          stops: const [0.75, 1.0],
        ).createShader(orbRect),
    );

    canvas.restore();

    // ── Anillo de carga ──────────────────────────────
    if (isLoading) {
      final ringPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final ringRect = Rect.fromCircle(center: center, radius: radius * 0.88);
      canvas.drawArc(ringRect, rotation, pi * 1.2, false, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}
