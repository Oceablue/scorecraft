// lib/renderer/painters/barline_painter.dart
// ============================================================================
// PEINTRE DES BARRES DE MESURE — v2c-93ze
// ============================================================================
// Ce fichier a été extrait de StaffRenderer pour alléger le rendu principal.
// Il gère tous les types de barres (single, double, repeat, heavy, etc.).
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/layout/layout_models.dart';
import '../../models/enums/music_enums.dart';
import '../../utils/constants.dart';

class BarlinePainter {
  BarlinePainter._();

  static void drawBarlineWithType({
    required Canvas canvas,
    required double x,
    required LayoutedSystem system,
    required BarlineType type,
  }) {
    if (system.staves.isEmpty) return;

    switch (type) {
      case BarlineType.none: break;
      case BarlineType.single: _drawSingleBarline(canvas, x, system); break;
      case BarlineType.doubleBar: _drawDoubleBarline(canvas, x, system); break;
      case BarlineType.end:
      case BarlineType.lightHeavy:
        _drawFinalBarline(canvas: canvas, x: x, system: system); break;
      case BarlineType.heavyLight: _drawHeavyLightBarline(canvas, x, system); break;
      case BarlineType.heavyHeavy: _drawHeavyHeavyBarline(canvas, x, system); break;
      case BarlineType.repeatStart: _drawRepeatStart(canvas, x, system); break;
      case BarlineType.repeatEnd: _drawRepeatEnd(canvas, x, system); break;
      case BarlineType.repeatBoth: _drawRepeatBoth(canvas, x, system); break;
      case BarlineType.dashed: _drawDashedBarline(canvas, x, system); break;
      case BarlineType.dotted: _drawDottedBarline(canvas, x, system); break;
      case BarlineType.tick: _drawTickBarline(canvas, x, system); break;
      case BarlineType.heavy: _drawHeavyBarline(canvas, x, system); break;
    }
  }

  static ({double top, double bottom}) _systemVerticalBounds(LayoutedSystem system) {
    final topY = system.staves.first.yTopLine;
    final lastStaff = system.staves.last;
    final double bottomY = lastStaff.yTopLine +
        (lastStaff.lineCount - 1) * ScoreCraftConstants.staffLineSpacing;
    return (top: topY, bottom: bottomY);
  }

  static void _drawSingleBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), paint);
  }

  static void _drawDoubleBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x - 4, bounds.top), Offset(x - 4, bounds.bottom), paint);
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), paint);
  }

  static void _drawFinalBarline({
    required Canvas canvas,
    required double x,
    required LayoutedSystem system,
  }) {
    final bounds = _systemVerticalBounds(system);
    final thinPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x - 5, bounds.top), Offset(x - 5, bounds.bottom), thinPaint);
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thickPaint);
  }

  static void _drawHeavyLightBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final thinPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x - 5, bounds.top), Offset(x - 5, bounds.bottom), thickPaint);
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thinPaint);
  }

  static void _drawHeavyHeavyBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x - 5, bounds.top), Offset(x - 5, bounds.bottom), thickPaint);
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thickPaint);
  }

  static void _drawHeavyBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thickPaint);
  }

  static void _drawDashedBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const double dashLen = 6.0;
    const double gapLen = 4.0;
    double y = bounds.top;
    while (y < bounds.bottom) {
      final endY = (y + dashLen).clamp(bounds.top, bounds.bottom);
      canvas.drawLine(Offset(x, y), Offset(x, endY), paint);
      y += dashLen + gapLen;
    }
  }

  static void _drawDottedBarline(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final paint = Paint()..color = Colors.black;
    const double dotRadius = 1.2;
    const double spacing = 4.0;
    double y = bounds.top;
    while (y <= bounds.bottom) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
      y += spacing;
    }
  }

  static void _drawTickBarline(Canvas canvas, double x, LayoutedSystem system) {
    final topY = system.staves.first.yTopLine;
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(x, topY),
      Offset(x, topY + ScoreCraftConstants.staffLineSpacing),
      paint,
    );
  }

  static void _drawRepeatStart(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final thinPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.black;
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thickPaint);
    canvas.drawLine(Offset(x + 8, bounds.top), Offset(x + 8, bounds.bottom), thinPaint);
    final double midY = (bounds.top + bounds.bottom) / 2;
    final double dotOffset = 4.0 * ScoreCraftConstants.staffLineSpacing / 2;
    canvas.drawCircle(Offset(x + 4, midY - dotOffset), 1.8, dotPaint);
    canvas.drawCircle(Offset(x + 4, midY + dotOffset), 1.8, dotPaint);
  }

  static void _drawRepeatEnd(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final thinPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.black;
    canvas.drawLine(Offset(x - 8, bounds.top), Offset(x - 8, bounds.bottom), thinPaint);
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thickPaint);
    final double midY = (bounds.top + bounds.bottom) / 2;
    final double dotOffset = 4.0 * ScoreCraftConstants.staffLineSpacing / 2;
    canvas.drawCircle(Offset(x - 4, midY - dotOffset), 1.8, dotPaint);
    canvas.drawCircle(Offset(x - 4, midY + dotOffset), 1.8, dotPaint);
  }

  static void _drawRepeatBoth(Canvas canvas, double x, LayoutedSystem system) {
    final bounds = _systemVerticalBounds(system);
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.black;
    canvas.drawLine(Offset(x - 6, bounds.top), Offset(x - 6, bounds.bottom), thickPaint);
    canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), thickPaint);
    final double midY = (bounds.top + bounds.bottom) / 2;
    final double dotOffset = 4.0 * ScoreCraftConstants.staffLineSpacing / 2;
    canvas.drawCircle(Offset(x - 3, midY - dotOffset), 1.8, dotPaint);
    canvas.drawCircle(Offset(x - 3, midY + dotOffset), 1.8, dotPaint);
  }
}