import 'package:flutter/material.dart';

/// Paleta de EntrevistIA — inspirada en un orbe iridiscente.
/// ─────────────────────
/// Primario   → Azul cobalto  #2F4BDB
/// Secundario → Lima          #E8F982
/// Terciario  → Durazno       #F5A06E
/// Acentos del orbe → lila, menta, cielo y periwinkle
class AppColors {
  AppColors._();

  // ── Primario ──────────────────────────────────────────
  static const Color primary = Color(0xFF2F4BDB);
  static const Color primaryLight = Color(0xFF8EA2F2);
  static const Color primaryDark = Color(0xFF1B2FA8);

  // ── Secundario ────────────────────────────────────────
  static const Color secondary = Color(0xFFE8F982);
  static const Color secondaryLight = Color(0xFFF4FCC2);
  static const Color secondaryDark = Color(0xFFC9DB4F);

  // ── Terciario ─────────────────────────────────────────
  static const Color tertiary = Color(0xFFF5A06E);

  // ── Acentos del orbe ──────────────────────────────────
  static const Color lilac = Color(0xFFD9C4F2);
  static const Color mint = Color(0xFFA8F0DC);
  static const Color sky = Color(0xFF9FD8F5);

  // ── Fondos ────────────────────────────────────────────
  static const Color background = Color(0xFFEAF0FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF4F7FE);
  static const Color border = Color(0xFFD9E1F7);

  // ── Texto ─────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF141B3D);
  static const Color textSecondary = Color(0xFF5A6285);
  static const Color textHint = Color(0xFF9AA1BF);

  // ── Estados ───────────────────────────────────────────
  static const Color error = Color(0xFFE5484D);
  static const Color success = Color(0xFF2BB673);
  static const Color warning = tertiary;
}
