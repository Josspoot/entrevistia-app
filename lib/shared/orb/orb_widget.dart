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
  Color _glowColor = AppColors.primary;

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
      duration: const Duration(milliseconds: 3000),
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
      _glowColor = AppColors.primary;
    });
    if (loading) {
      _rotateCtrl.duration = const Duration(milliseconds: 1200);
    } else {
      _rotateCtrl.duration = const Duration(milliseconds: 3000);
    }
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
      _glowColor = AppColors.primary;
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
      _glowColor = AppColors.primary;
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
class _OrbPainter extends CustomPainter {
  final double rotation;
  final Color glowColor;
  final double glowOpacity;
  final bool isLoading;

  _OrbPainter({
    required this.rotation,
    required this.glowColor,
    required this.glowOpacity,
    required this.isLoading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Glow exterior ────────────────────────────────
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4)
      ..color = glowColor.withValues(alpha: glowOpacity);
    canvas.drawCircle(center, radius * 0.85, glowPaint);

    // ── Gradiente principal ──────────────────────────
    final gradientPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: rotation,
        endAngle: rotation + 2 * pi,
        colors: [
          AppColors.primary,
          AppColors.secondary,
          AppColors.primaryLight,
          AppColors.primary,
        ],
        stops: const [0.0, 0.33, 0.66, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.75),
      );
    canvas.drawCircle(center, radius * 0.75, gradientPaint);

    // ── Reflejo interior ─────────────────────────────
    final innerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(center.dx - radius * 0.2, center.dy - radius * 0.25),
          radius: radius * 0.45,
        ),
      );
    canvas.drawCircle(center, radius * 0.72, innerGlow);

    // ── Anillo de carga ──────────────────────────────
    if (isLoading) {
      final ringPaint = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final ringRect = Rect.fromCircle(center: center, radius: radius * 0.85);
      canvas.drawArc(ringRect, rotation, pi * 1.2, false, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}
