import 'package:flutter/material.dart';

/// Mirrorly palette — editorial black, surgical indigo, laboratory sky.
/// Reads like an analysis report from a high-end cosmetic surgery clinic.
abstract final class AppColors {
  // ── Base layers (near-black to elevated) ─────────────────────────────────
  static const base       = Color(0xFF07070A); // deeper than black
  static const surface1   = Color(0xFF0E0E12); // first lift
  static const surface2   = Color(0xFF16161B); // card
  static const surface3   = Color(0xFF23232A); // divider/stroke
  static const surfaceElevated = Color(0xFF1D1D24); // overlay cards

  // ── Accent (indigo) ──────────────────────────────────────────────────────
  static const accent     = Color(0xFF8B94F5); // softer indigo
  static const accentDeep = Color(0xFF6366F1);
  static const accentBorder = Color(0xFF3730A3);
  static const accentGlow = Color(0x338B94F5); // translucent glow

  // ── Measurement sky ──────────────────────────────────────────────────────
  static const measure    = Color(0xFF38BDF8);
  static const measureDim = Color(0xFF0EA5E9);
  static const measureGlow = Color(0x3338BDF8);

  // ── Gold — earned achievements / premium ─────────────────────────────────
  static const gold       = Color(0xFFD4A96A);
  static const goldDim    = Color(0xFF9E7A3A);

  // ── Text (high-contrast editorial) ───────────────────────────────────────
  static const textPrimary   = Color(0xFFF7F7F9);
  static const textSecondary = Color(0xFFA8A8B2);
  static const textTertiary  = Color(0xFF6D6D78);
  static const textMuted     = Color(0xFF4A4A55);

  // ── Signals ──────────────────────────────────────────────────────────────
  static const signalGreen = Color(0xFF4ADE80);
  static const signalAmber = Color(0xFFFBBF24);
  static const signalRed   = Color(0xFFF87171);

  // ── Utility ──────────────────────────────────────────────────────────────
  static const divider = Color(0xFF1F1F26);
  static const scrim   = Color(0xCC000000);
}
