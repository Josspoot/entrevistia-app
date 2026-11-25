import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Nombre de la app con "IA" resaltado: Entrevist**IA**.
class Wordmark extends StatelessWidget {
  final double fontSize;

  const Wordmark({super.key, this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
        children: const [
          TextSpan(text: 'Entrevist'),
          TextSpan(
            text: 'IA',
            style: TextStyle(
              color: AppColors.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo azul noche con dos brillos suaves de la paleta iridiscente.
class NightBackground extends StatelessWidget {
  final Widget? child;

  const NightBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.night),
      child: Stack(
        children: [
          _glow(const Alignment(1.2, -1.1), AppColors.primary, 0.45),
          _glow(const Alignment(-1.3, -0.3), AppColors.lilac, 0.18),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }

  Widget _glow(Alignment alignment, Color color, double alpha) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: 0.9,
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halo de luz detrás del blob para que resalte sobre el fondo oscuro.
class Halo extends StatelessWidget {
  final double size;
  final Widget child;

  const Halo({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.lilac.withValues(alpha: 0.45),
            AppColors.sky.withValues(alpha: 0.12),
            AppColors.sky.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
