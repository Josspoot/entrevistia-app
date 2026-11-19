import 'dart:math';

import 'package:blobatar/blobatar.dart'
    show
        colorEye,
        colorHead,
        expressionEnterEase,
        expressionEnterMilliseconds,
        identityPose,
        lerpPose;
import 'package:blobatar/flutter.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Apariencia del blob: forma (semilla) + colores.
///
/// [BlobLook.session] se elige al azar UNA vez al abrir la app, así cada
/// apertura sale un blob distinto, pero es el mismo en todas las pantallas.
class BlobLook {
  /// Blobatar genera siempre la misma forma para la misma semilla.
  final String seed;
  final Color head;
  final Color eye;

  const BlobLook(this.seed, this.head, this.eye);

  // Combinaciones de la paleta de la app con ojos legibles
  static const _colors = [
    (AppColors.primary, Colors.white),
    (AppColors.primaryDark, Colors.white),
    (AppColors.secondary, AppColors.textPrimary),
    (AppColors.lilac, AppColors.textPrimary),
    (AppColors.mint, AppColors.textPrimary),
    (AppColors.tertiary, AppColors.textPrimary),
  ];

  factory BlobLook.random([Random? random]) {
    final r = random ?? Random();
    final (head, eye) = _colors[r.nextInt(_colors.length)];
    return BlobLook('blob-${r.nextInt(1000000)}', head, eye);
  }

  static final BlobLook session = BlobLook.random();
}

/// Personaje de EntrevistIA hecho con blobatar (https://blobatar.dev, MIT).
///
/// Blobatar dibuja el blob y sus expresiones; nosotros armamos cada cuadro
/// para controlar a dónde mira y los gestos:
///
///   followText(ctrl) → los ojos siguen al cursor de un campo de texto
///   lookCenter()     → deja de seguir el cursor
///   setThinking(b)   → expresión "pensando" mientras carga
///   nodYes()         → feliz + asiente (arriba/abajo): "sí"
///   shakeNo()        → triste + niega (izquierda/derecha): "no"
///   tocarlo          → salta con una expresión al azar
///   mouse encima     → se levanta un poco (web / escritorio)
///
/// Uso:
///   `final key = GlobalKey<BlobCharacterState>();`
///   BlobCharacter(key: key, size: 180)
///   key.currentState?.shakeNo();
class BlobCharacter extends StatefulWidget {
  final double size;

  /// Apariencia; por defecto, la elegida al azar en esta sesión.
  final BlobLook? look;

  const BlobCharacter({super.key, this.size = 180, this.look});

  @override
  State<BlobCharacter> createState() => BlobCharacterState();
}

class BlobCharacterState extends State<BlobCharacter>
    with TickerProviderStateMixin {
  // Expresiones posibles al tocarlo
  static const _reactions = [surprised, love, wink, happy, shy, smug, scared];
  final _random = Random();

  late final BlobLook _look;
  late final AnimatedBlobatarRenderer _renderer;

  // Reloj que repinta cada cuadro (respira, parpadea, etc.)
  late final AnimationController _clock;
  // Transición suave entre expresiones
  late final AnimationController _morph;
  // Gestos "sí" / "no" / salto
  late final AnimationController _gestureCtrl;
  // Mouse encima (web / escritorio)
  late final AnimationController _hover;

  Pose _fromPose = identityPose;
  Pose _toPose = identityPose;
  late Color _fromHead, _toHead, _fromEye, _toEye;

  // Expresión a la que se regresa después de una reacción
  Expression _resting = idle;

  // Mirada: objetivo y posición actual (se suaviza en cada cuadro)
  Offset? _gazeTarget;
  Offset _gaze = Offset.zero;

  _Gesture? _gesture;

  @override
  void initState() {
    super.initState();
    _look = widget.look ?? BlobLook.session;
    _renderer = AnimatedBlobatarRenderer(
      name: _look.seed,
      options: BlobatarOptions(
        palette: {'head': _hex(_look.head), 'eye': _hex(_look.eye)},
        contrast: false,
      ),
    );
    _fromHead = _toHead = _look.head;
    _fromEye = _toEye = _look.eye;

    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: expressionEnterMilliseconds),
      value: 1,
    );
    _gestureCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _hover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  // ── API pública ──────────────────────────────────────

  /// Los ojos siguen al cursor de [ctrl]. Mide el ancho del texto escrito
  /// hasta el cursor y lo compara con el ancho útil del campo.
  void followText(TextEditingController ctrl) {
    final text = ctrl.text;
    final caret = ctrl.selection.baseOffset.clamp(0, text.length);
    final painter = TextPainter(
      text: TextSpan(
        text: text.substring(0, caret),
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Ancho útil: pantalla - márgenes (28*2) - ícono y padding
    final fieldWidth = MediaQuery.of(context).size.width - 56 - 70;
    final f = (painter.width / fieldWidth).clamp(0.0, 1.0);
    // Unidades del dibujo (100x100): ±7 a los lados, un poco hacia abajo
    _gazeTarget = Offset(-7 + 14 * f, 3);
  }

  /// Deja de seguir el cursor y vuelve a mirar libremente.
  void lookCenter() => _gazeTarget = null;

  /// Expresión de "pensando" mientras se espera una respuesta.
  void setThinking(bool value) {
    _resting = value ? thinking : idle;
    _setExpression(_resting);
  }

  /// Feliz y asiente con la cabeza: "sí".
  Future<void> nodYes() async {
    _resting = idle;
    _setExpression(happy);
    await _play(_Gesture.yes);
  }

  /// Triste y niega con la cabeza: "no".
  Future<void> shakeNo() async {
    _resting = idle;
    _setExpression(sad);
    await _play(_Gesture.no);
    if (mounted) _setExpression(_resting);
  }

  /// Al tocarlo: salta con una expresión al azar y regresa.
  Future<void> _onTap() async {
    if (_gesture != null) return; // no interrumpir un "sí" o "no"
    _setExpression(_reactions[_random.nextInt(_reactions.length)]);
    await _play(_Gesture.hop);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted && _gesture == null) _setExpression(_resting);
  }

  Future<void> _play(_Gesture gesture) async {
    _gesture = gesture;
    _gestureCtrl.duration = Duration(
      milliseconds: gesture == _Gesture.hop ? 500 : 1200,
    );
    await _gestureCtrl.forward(from: 0);
    _gesture = null;
  }

  // ── Expresiones ──────────────────────────────────────

  void _setExpression(Expression expression) {
    final t = expressionEnterEase(_morph.value);
    // Arrancar desde donde va la transición actual
    _fromPose = lerpPose(_fromPose, _toPose, t);
    _fromHead = Color.lerp(_fromHead, _toHead, t)!;
    _fromEye = Color.lerp(_fromEye, _toEye, t)!;

    final palette = _renderer.paletteFor(expression);
    _toPose = expression.pose;
    _toHead = _color(palette[colorHead]!);
    _toEye = _color(palette[colorEye]!);
    _morph.forward(from: 0);
  }

  // ── Cuadro a cuadro ──────────────────────────────────

  AnimatedBlobatarFrame _frame() {
    final t = expressionEnterEase(_morph.value);
    final pose = lerpPose(_fromPose, _toPose, t);
    final elapsed = DateTime.now().millisecondsSinceEpoch.toDouble();

    // Movimiento natural de blobatar: respira, flota, parpadea y mira
    final base = motionAt(_renderer.motionSeeds, elapsed, 1, shake: pose.shake);

    // Suavizar la mirada hacia el objetivo
    final target = _gazeTarget;
    if (target != null) _gaze = Offset.lerp(_gaze, target, 0.2)!;

    var shake = base.shake;
    var bob = base.bob;
    var saccade = target != null ? (_gaze.dx, _gaze.dy) : base.saccade;
    var wrap = target != null ? _noWrap : base.wrap;

    final g = _gestureCtrl.value;
    switch (_gesture) {
      case _Gesture.no:
        // 3 vaivenes a los lados
        final wave = sin(g * 2 * pi * 3);
        shake = (shake.$1 + wave * 7, shake.$2);
        saccade = (wave * 5, 0);
        wrap = _noWrap;
      case _Gesture.yes:
        // 3 bajadas: cuerpo y mirada
        final wave = sin(g * 2 * pi * 3).abs();
        bob = bob + wave * 5;
        saccade = (0, wave * 4);
        wrap = _noWrap;
      case _Gesture.hop:
        // Un salto hacia arriba
        bob = bob - sin(g * pi) * 12;
      case null:
        break;
    }

    return AnimatedBlobatarFrame(
      motion: MotionFrame(
        shake: shake,
        breathe: base.breathe,
        bob: bob,
        saccade: saccade,
        thinkingPhase: base.thinkingPhase,
        blink: base.blink,
        wrap: wrap,
      ),
      pose: pose,
      headColor: Color.lerp(_fromHead, _toHead, t)!,
      eyeColor: Color.lerp(_fromEye, _toEye, t)!,
      hover: Curves.easeOut.transform(_hover.value),
      amplitude: 1,
    );
  }

  static const _noWrap =
      MotionWrap(magnitudeX: 0, side: 0, scaleY: 0, rotation: 0);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTap: _onTap,
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: AnimatedBlobatarPainter(
              renderer: _renderer,
              frameBuilder: _frame,
              repaint: _clock,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    _morph.dispose();
    _gestureCtrl.dispose();
    _hover.dispose();
    super.dispose();
  }

  // ── Utilidades de color ──────────────────────────────

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Color _color(String hex) =>
      Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
}

enum _Gesture { yes, no, hop }
