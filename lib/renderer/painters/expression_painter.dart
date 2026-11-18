// lib/renderer/painters/expression_painter.dart
// ============================================================================
// PEINTRE DES EXPRESSIONS MUSICALES (LIAISONS, ARTICULATIONS) — v2c-94u
// ============================================================================
// v2c-94u : Réduction de la courbure (bulge) des slurs pour un rendu plus plat.
//           - base bulge : 0.8 sp (au lieu de 1.2).
//           - ratio dx    : 0.1 (au lieu de 0.15).
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/enums/music_enums.dart';
import '../../utils/music_text_style.dart';

class ExpressionPainter {
  final double lineSpacing;
  final Color color;
  final double strokeWidth;
  final double defaultSlurHeight;

  ExpressionPainter({
    required this.lineSpacing,
    required this.color,
    this.strokeWidth = 1.8,
    this.defaultSlurHeight = 2.0,
  });

  static const double tieAnchorOffset = 4.0;

  /// v2c-94v : hauteur minimale augmentée (0.5 → 0.85 sp).
  /// Les ties entre GRÂCES sont très courtes (dx ≈ 1.5 sp) ; avec l'ancienne
  /// valeur elles étaient plates et invisibles. Behind Bars recommande
  /// 0.6–0.9 sp pour les ties courtes.
  static const double tieMinHeightSp = 0.85;

  static const double tieMaxHeightSp = 1.4;

  /// v2c-94v : épaisseur +27% pour rester lisible sur les ties courtes.
  static const double tieThicknessSp = 0.28;

  // ==========================================================================
  // SLURS
  // ==========================================================================

  void drawSlur(
    Canvas canvas,
    Offset start,
    Offset end, {
    bool curveUp = true,
    double heightMultiplier = 1.0,
    bool startIsGrace = false,
    bool endIsGrace = false,
  }) {
    final double rawDx = end.dx - start.dx;
    if (rawDx.abs() < 1.0) return;

    // 1. DÉCALAGES HORIZONTAUX
    final double startOffsetX = startIsGrace ? 0.0 : lineSpacing * 0.4;
    final double endOffsetX = endIsGrace ? 0.0 : lineSpacing * 0.8;

    final double startX = start.dx + startOffsetX;
    final double endX = end.dx - endOffsetX;
    final double actualDx = endX - startX;

    // 2. DÉCALAGES VERTICAUX
    // Note normale : 1.15 sp (rayon 0.65 + marge 0.5).
    // Note de grâce : 0.85 sp (rayon 0.45 + marge 0.4).
    final double baseYOffset = 1.15 * lineSpacing;
    final double graceYOffset = 0.85 * lineSpacing;

    final double startYOffset = startIsGrace ? graceYOffset : baseYOffset;
    final double endYOffset = endIsGrace ? graceYOffset : baseYOffset;

    final double sign = curveUp ? -1.0 : 1.0;
    final double yStart = start.dy + sign * startYOffset;
    final double yEnd = end.dy + sign * endYOffset;

    // ═══════════════════════════════════════════════════════════════════════
    // 🎯 3. COURBURE (BULGE) - RÉDUITE
    // ═══════════════════════════════════════════════════════════════════════
    // 0.8 sp de base (au lieu de 1.2) et 0.1 fois le dx (au lieu de 0.15).
    double bulge = math.max(lineSpacing * 0.6, actualDx.abs() * 0.08);
    bulge *= heightMultiplier;

    final double cp1x = startX + actualDx * 0.25;
    final double cp2x = startX + actualDx * 0.75;

    final double cp1y = yStart + (yEnd - yStart) * 0.25 + sign * bulge;
    final double cp2y = yStart + (yEnd - yStart) * 0.75 + sign * bulge;

    final Path path = Path()
      ..moveTo(startX, yStart)
      ..cubicTo(cp1x, cp1y, cp2x, cp2y, endX, yEnd);

    final Paint slurPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(path, slurPaint);
  }

  // ==========================================================================
  // TIES
  // ==========================================================================

  void drawTie(
    Canvas canvas,
    Offset start,
    Offset end, {
    bool curveUp = true,
  }) {
    final double dx = end.dx - start.dx;
    if (dx.abs() < 1.0) return;

    final double sign = curveUp ? -1.0 : 1.0;

    // ═══════════════════════════════════════════════════════════════════════
    // v2c-94v : INSET PROPORTIONNEL
    // ───────────────────────────────────────────────────────────────────────
    // AVANT : inset = 3.0 (fixe). Pour un tie grace-grace (dx ≈ 10.8px),
    //         ça mangeait 6/10.8 = 55% de la largeur utile → la courbe
    //         devenait un point invisible.
    // APRÈS : inset ≤ 15% du dx (donc ≤ 1.6px pour un tie de grâce).
    // ═══════════════════════════════════════════════════════════════════════
    final double effectiveInset = math.min(3.0, dx.abs() * 0.15);
    final double x0 = start.dx + effectiveInset;
    final double x1 = end.dx - effectiveInset;
    final double usableWidth = x1 - x0;

    final double y0 = start.dy + sign * tieAnchorOffset;
    final double y1 = end.dy + sign * tieAnchorOffset;

    double height = dx * 0.10;
    final double minH = lineSpacing * tieMinHeightSp;
    final double maxH = lineSpacing * tieMaxHeightSp;
    if (height < minH) height = minH;
    if (height > maxH) height = maxH;

    final double thickness = lineSpacing * tieThicknessSp;

    // ═══════════════════════════════════════════════════════════════════════
    // v2c-94v : FIX CRITIQUE — les control points doivent être calculés sur
    // la largeur UTILE (x1 - x0), pas sur dx (qui incluait les insets).
    //
    // AVANT (bug) : cp1x = x0 + dx * 0.25 ; pour un tie de grâce, cp1x et
    //               cp2x dépassaient x1 → courbe écrasée à l'horizontale.
    // APRÈS        : cp1x = x0 + usableWidth * 0.25, toujours dans [x0, x1].
    // ═══════════════════════════════════════════════════════════════════════
    final double cp1x = x0 + usableWidth * 0.25;
    final double cp2x = x0 + usableWidth * 0.75;

    final double avgY = (y0 + y1) / 2;

    final double cpOuterY = avgY + sign * height * (4.0 / 3.0);
    final double cpInnerY = avgY + sign * (height - thickness) * (4.0 / 3.0);

    final Path path = Path()
      ..moveTo(x0, y0)
      ..cubicTo(cp1x, cpOuterY, cp2x, cpOuterY, x1, y1)
      ..cubicTo(cp2x, cpInnerY, cp1x, cpInnerY, x0, y0)
      ..close();

    final Paint tiePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, tiePaint);
  }
  // ==========================================================================
  // ARTICULATIONS
  // ==========================================================================

  void drawArticulation(
    Canvas canvas,
    ArticulationType type,
    double x,
    double y, {
    String position = 'above',
  }) {
    if (type == ArticulationType.none) return;

    final bool isAbove = position == 'above';
    final double offsetY = isAbove ? -(lineSpacing * 0.8) : (lineSpacing * 0.8);
    final double yPos = y + offsetY;

    String glyph = '';
    final double fontSize = lineSpacing * 4.0;

    switch (type) {
      case ArticulationType.staccato: glyph = isAbove ? '\uE4A0' : '\uE4A1'; break;
      case ArticulationType.staccatissimo: glyph = isAbove ? '\uE4A4' : '\uE4A5'; break;
      case ArticulationType.tenuto: glyph = isAbove ? '\uE4A2' : '\uE4A3'; break;
      case ArticulationType.accent: glyph = isAbove ? '\uE4AC' : '\uE4AD'; break;
      case ArticulationType.marcato: glyph = isAbove ? '\uE4A8' : '\uE4A9'; break;
      case ArticulationType.fermata: glyph = isAbove ? '\uE4C0' : '\uE4C1'; break;
      case ArticulationType.shortFermata: glyph = isAbove ? '\uE4C2' : '\uE4C3'; break;
      case ArticulationType.longFermata: glyph = isAbove ? '\uE4C4' : '\uE4C5'; break;
      case ArticulationType.trill: glyph = '\uE5C0'; break;
      case ArticulationType.mordent: glyph = '\uE5C4'; break;
      case ArticulationType.turn: glyph = '\uE5C7'; break;
      default: return;
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: MusicTextStyle.music(fontSize: fontSize, color: color, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, yPos - textPainter.height / 2));
  }

  ExpressionPainter copyWith({
    double? lineSpacing,
    Color? color,
    double? strokeWidth,
    double? defaultSlurHeight,
  }) {
    return ExpressionPainter(
      lineSpacing: lineSpacing ?? this.lineSpacing,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      defaultSlurHeight: defaultSlurHeight ?? this.defaultSlurHeight,
    );
  }
}
