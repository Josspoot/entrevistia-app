import 'package:flutter/material.dart';

/// Paleta de EntrevistIA
/// ─────────────────────
/// Primario  → Índigo eléctrico  #6C63FF
/// Secundario → Cyan              #00E5FF
/// Terciario → Ámbar              #FFB74D
class AppColors {
  AppColors._();

  // ── Primario ──────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42DB);

  // ── Secundario ────────────────────────────────────────
  static const Color secondary = Color(0xFF00E5FF);
  static const Color secondaryLight = Color(0xFF6EFFFF);
  static const Color secondaryDark = Color(0xFF00B2CC);

  // ── Terciario ─────────────────────────────────────────
  static const Color tertiary = Color(0xFFFFB74D);
  static const Color tertiaryLight = Color(0xFFFFE97D);
  static const Color tertiaryDark = Color(0xFFC88719);

  // ── Fondos ────────────────────────────────────────────
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF25253D);

  // ── Texto ─────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0C3);
  static const Color textHint = Color(0xFF6E6E85);

  // ── Estados ───────────────────────────────────────────
  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF69F0AE);
  static const Color warning = tertiary;
}
