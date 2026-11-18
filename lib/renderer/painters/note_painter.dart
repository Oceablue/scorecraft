// lib/renderer/painters/note_painter.dart
// ============================================================================
// PEINTRE DES NOTES, SILENCES, ARTICULATIONS — v2c-121
// ============================================================================
// v2c-121 : FIX de la largeur de la courbe de substitution heel-toe.
//           La courbe part du bord gauche du 1er glyphe et finit au bord
//           droit du 2ème glyphe (au lieu de centre à centre), en utilisant
//           leurs largeurs réelles (TextPainter.width).
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/events/music_event.dart';
import '../../models/events/pitch.dart';
import '../../models/events/notations.dart';
import '../../models/enums/music_enums.dart';
import '../../models/layout/layout_models.dart';
import '../../models/score/measure.dart';
import '../../services/smufl/smufl.dart';
import '../../services/smufl/dynamic_glyphs.dart';
import '../../utils/music_text_style.dart';
import '../stem_anchor.dart';
import '../stem_direction_resolver.dart';
import 'expression_painter.dart';

class NotePainter {
  final double scale;
  final double staffLineSpacing;
  final double noteFontSize;
  final double stemLength;
  final TextStyle noteStyle;
  final Paint linePaint;
  final Paint beamPaint;
  final Color selectionColor;
  final ExpressionPainter expressionPainter;

  NotePainter({
    required this.scale,
    required this.staffLineSpacing,
    required this.noteFontSize,
    required this.stemLength,
    required this.noteStyle,
    required this.linePaint,
    required this.beamPaint,
    required this.selectionColor,
    required this.expressionPainter,
  });

  static const double graceScale = 0.7;

  // ==========================================================================
  // HELPERS DE RÉSOLUTION SMuFL
  // ==========================================================================

  static String _normalNoteheadName(DurationType dur, bool filled) {
    switch (dur) {
      case DurationType.whole:
        return filled ? 'noteheadWholeFilled' : 'noteheadWhole';
      case DurationType.half:
        return filled ? 'noteheadHalfFilled' : 'noteheadHalf';
      default:
        return filled ? 'noteheadBlack' : 'noteheadHalf';
    }
  }

  static String _specialNoteheadName(NoteheadShape shape, bool filled) {
    switch (shape) {
      case NoteheadShape.slash:
        return filled ? 'noteheadSlashHorizontalEnds' : 'noteheadSlashWhiteHalf';
      case NoteheadShape.triangle:
        return filled ? 'noteheadTriangleUpBlack' : 'noteheadTriangleUpWhite';
      case NoteheadShape.invertedTriangle:
        return filled ? 'noteheadTriangleDownBlack' : 'noteheadTriangleDownWhite';
      case NoteheadShape.diamond:
        return filled ? 'noteheadDiamondBlack' : 'noteheadDiamondWhite';
      case NoteheadShape.square:
        return filled ? 'noteheadSquareBlack' : 'noteheadSquareWhite';
      case NoteheadShape.x:
        return filled ? 'noteheadXBlack' : 'noteheadXHalf';
      case NoteheadShape.cross:
        return filled ? 'noteheadPlusBlack' : 'noteheadPlusHalf';
      case NoteheadShape.circleX:
        return filled ? 'noteheadCircleX' : 'noteheadCircleXHalf';
      case NoteheadShape.circleDot:
        return filled ? 'noteheadBlack' : 'noteheadHalf';
      case NoteheadShape.arrowDown:
        return filled ? 'noteheadLargeArrowDownBlack' : 'noteheadLargeArrowDownHalf';
      case NoteheadShape.arrowUp:
        return filled ? 'noteheadLargeArrowUpBlack' : 'noteheadLargeArrowUpHalf';
      case NoteheadShape.slashed:
        return filled ? 'noteheadSlashedBlack1' : 'noteheadSlashedHalf1';
      case NoteheadShape.backSlashed:
        return filled ? 'noteheadSlashedBlack2' : 'noteheadSlashedHalf2';
      case NoteheadShape.cluster:
        return filled ? 'noteheadClusterSquareBlack' : 'noteheadClusterSquareWhite';
      case NoteheadShape.normal:
      case NoteheadShape.none:
        return filled ? 'noteheadBlack' : 'noteheadHalf';
    }
  }

  static double _noteHeadVisualWidthSp(DurationType type) {
    switch (type) {
      case DurationType.maxima: return 3.0;
      case DurationType.longa:
      case DurationType.doubleWhole: return 1.0;
      case DurationType.whole: return 1.49;
      default: return 1.3;
    }
  }

  static const double _parenthesisGapSp = 0.15;
  static const double _parenthesisFontSizeFactor = 3.0;

  void _drawNoteheadParentheses({
    required Canvas canvas,
    required double centerX,
    required double centerY,
    required double glyphWidth,
    required Color color,
  }) {
    final double gapPx = staffLineSpacing * _parenthesisGapSp;
    final TextStyle parenStyle = MusicTextStyle.music(
      fontSize: staffLineSpacing * _parenthesisFontSizeFactor,
      color: color,
    );

    final leftPainter = TextPainter(
      text: TextSpan(text: Smufl.glyph('noteheadParenthesisLeft'), style: parenStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final rightPainter = TextPainter(
      text: TextSpan(text: Smufl.glyph('noteheadParenthesisRight'), style: parenStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final double leftX = centerX - glyphWidth / 2 - gapPx - leftPainter.width;
    final double rightX = centerX + glyphWidth / 2 + gapPx;

    leftPainter.paint(canvas, Offset(leftX, centerY - leftPainter.height / 2));
    rightPainter.paint(canvas, Offset(rightX, centerY - rightPainter.height / 2));
  }

  // ==========================================================================
  // SILENCES
  // ==========================================================================

  void drawRest(Canvas canvas, LayoutedNote note, double x, double y) {
    final restName = _getRestName(note.event.durationType);
    final restPainter = TextPainter(
      text: TextSpan(text: Smufl.glyph(restName), style: noteStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final bool isMeasureRest = note.event is RestEvent && (note.event as RestEvent).isMeasureRest;

    final double paintY;
    if (isMeasureRest) {
      final double ascent = restPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      paintY = y - ascent;
    } else {
      paintY = y - restPainter.height / 2;
    }

    restPainter.paint(canvas, Offset(x - restPainter.width / 2, paintY));

    if (note.event is RestEvent) {
      final re = note.event as RestEvent;
      if (re.noteheadParentheses) {
        _drawNoteheadParentheses(
          canvas: canvas, centerX: x, centerY: y,
          glyphWidth: restPainter.width, color: Colors.black,
        );
      }
    }

    if (note.event.dotType != DotType.none) {
      _drawRestDots(canvas, note, x, y, restPainter.width);
    }
  }

  void _drawRestDots(Canvas canvas, LayoutedNote note, double restCenterX, double restCenterY, double restWidth) {
    final int count = note.event.dotType.count;
    if (count == 0) return;

    double restHalfWidthSp;
    switch (note.event.durationType) {
      case DurationType.whole:
      case DurationType.half:
      case DurationType.doubleWhole:
      case DurationType.longa:
      case DurationType.maxima:
        restHalfWidthSp = 0.55; break;
      default: restHalfWidthSp = 0.35;
    }

    const double dotGapSp = 0.3;
    final double dotRadius = staffLineSpacing * 0.2;
    final double dotSpacing = staffLineSpacing * 0.6;

    final double startX = restCenterX + staffLineSpacing * (restHalfWidthSp + dotGapSp) + dotRadius;
    final double staffTopY = restCenterY - note.yLine * staffLineSpacing;
    const double dotYLine = 1.5;
    final double dotY = staffTopY + dotYLine * staffLineSpacing;

    final paint = Paint()..color = Colors.black;

    for (int i = 0; i < count; i++) {
      final dx = startX + i * dotSpacing;
      canvas.drawCircle(Offset(dx, dotY), dotRadius, paint);
    }
  }

  void drawMultiMeasureRest({
    required Canvas canvas, required int count, required double x,
    required double measureWidth, required double staffTopY,
  }) {
    final double barY = staffTopY + 2.0 * staffLineSpacing;
    final double ticksCenterY = staffTopY + 2.0 * staffLineSpacing;
    final double barThickness = staffLineSpacing * 0.7;
    final double tickThickness = staffLineSpacing * 0.3;
    final double tickHeight = staffLineSpacing * 2.0;

    double barWidth = measureWidth * 0.75;
    barWidth = barWidth.clamp(staffLineSpacing * 4.0, staffLineSpacing * 14.0);

    final double centerX = x + measureWidth / 2;
    final double leftX = centerX - barWidth / 2;
    final double rightX = centerX + barWidth / 2;

    final paint = Paint()..color = Colors.black;

    canvas.drawRect(Rect.fromLTWH(leftX, barY - barThickness / 2, barWidth, barThickness), paint);
    final double ticksTop = ticksCenterY - tickHeight / 2;
    canvas.drawRect(Rect.fromLTWH(leftX, ticksTop, tickThickness, tickHeight), paint);
    canvas.drawRect(Rect.fromLTWH(rightX - tickThickness, ticksTop, tickThickness, tickHeight), paint);

    final numberPainter = TextPainter(
      text: TextSpan(
        text: Smufl.timeSignatureNumber(count),
        style: MusicTextStyle.music(fontSize: staffLineSpacing * 3.0, color: Colors.black, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double numberGap = staffLineSpacing * 2.4;
    final double numberX = centerX - numberPainter.width / 2;
    final double baselineOffset = numberPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final double baselineY = barY - barThickness / 2 - numberGap;

    numberPainter.paint(canvas, Offset(numberX, baselineY - baselineOffset));
  }

  // ==========================================================================
  // NOTES
  // ==========================================================================

  void drawNote({
    required Canvas canvas, required LayoutedNote note, required double xPx,
    required double yPx, required double staffBaseY, required bool isSelected,
    double? dragOffsetY, SlashNotation? slashNotation,
  }) {
    if (note.event is NoteEvent) {
      final ne = note.event as NoteEvent;
      if (!ne.printObject) return;
    }

    if (slashNotation != null) {
      _drawSlashNote(canvas: canvas, note: note, xPx: xPx, staffBaseY: staffBaseY, isSelected: isSelected, dragOffsetY: dragOffsetY, slashNotation: slashNotation);
      return;
    }

    final bool isGrace = note.isGrace;
    final bool graceSlash = note.event is NoteEvent && (note.event as NoteEvent).graceSlash;
    final TextStyle effectiveNoteStyle = isGrace ? noteStyle.copyWith(fontSize: noteStyle.fontSize! * graceScale) : noteStyle;

    final double yPxFinal = isSelected && dragOffsetY != null ? yPx + dragOffsetY : yPx;
    final double yLineForLedger = isSelected && dragOffsetY != null ? note.yLine + dragOffsetY / staffLineSpacing : note.yLine;

    final bool hasAcc = note.displayAccidental != null && note.displayAccidental != Accidental.none;
    final Color noteColor = isSelected ? selectionColor : Colors.black;

    _drawLedgerLines(canvas, xPx, yLineForLedger, staffBaseY, hasAccidental: hasAcc);

    if (!note.isChordMember && note.event.durationType.needsStem) {
      final bool stemUp = StemDirectionResolver.shouldStemBeUp(note, effectiveYLine: yLineForLedger);
      double stemStartYLine = yLineForLedger;
      double effectiveStemLength = isGrace ? stemLength * graceScale : stemLength;
      bool hasArrowPair = false;
      double arrowPairCenterYLine = yLineForLedger;
      const double arrowPairCenterXSp = 0.0;

      if (note.event is NoteEvent) {
        final ne = note.event as NoteEvent;
        if (ne.pitches.length >= 2) {
          int? upIdx, downIdx;
          for (int i = 0; i < ne.pitches.length; i++) {
            final head = ne.pitches[i].notehead ?? ne.notehead;
            if (head == NoteheadShape.arrowUp) upIdx = i;
            if (head == NoteheadShape.arrowDown) downIdx = i;
          }
          if (upIdx != null && downIdx != null) {
            final primary = ne.pitches.first;
            final upDiff = _diatonicDiff(primary, ne.pitches[upIdx]);
            final downDiff = _diatonicDiff(primary, ne.pitches[downIdx]);
            final upYLine = yLineForLedger - upDiff * 0.5;
            final downYLine = yLineForLedger - downDiff * 0.5;
            arrowPairCenterYLine = (upYLine + downYLine) / 2;
            if ((yLineForLedger - arrowPairCenterYLine).abs() <= 3.0) hasArrowPair = true;
          }
        }
      }

      if (note.event is NoteEvent) {
        final ne = note.event as NoteEvent;
        if (ne.pitches.length > 1 && !hasArrowPair) {
          final Pitch primary = ne.pitches.first;
          double minYLine = yLineForLedger;
          double maxYLine = yLineForLedger;

          for (final pitch in ne.pitches) {
            final int diff = _diatonicDiff(primary, pitch);
            final double yl = yLineForLedger - diff * 0.5;
            if (yl < minYLine) minYLine = yl;
            if (yl > maxYLine) maxYLine = yl;
          }

          stemStartYLine = stemUp ? maxYLine : minYLine;
          final double spanPx = (maxYLine - minYLine) * staffLineSpacing;
          final double minStemPx = isGrace ? stemLength * graceScale : stemLength;
          final double requiredPx = spanPx + 0.5 * staffLineSpacing;
          effectiveStemLength = math.max(minStemPx, requiredPx);
        } else if (hasArrowPair) {
          stemStartYLine = arrowPairCenterYLine;
        }

        if (ne.tremoloType != TremoloType.none) {
          if (ne.tremoloType == TremoloType.unmeasured) {
            effectiveStemLength += staffLineSpacing * 0.5;
          } else {
            final int cnt = ne.tremoloCount <= 0 ? 1 : ne.tremoloCount;
            final bool isBeamable = ne.durationType.isBeamable;
            final bool hasFlag = isBeamable && ne.beams.isEmpty;
            if (hasFlag) {
              effectiveStemLength += (1.8 + (cnt - 1) * 1.05 + 0.3) * staffLineSpacing;
            } else {
              effectiveStemLength += (cnt * 0.6 + 0.4) * staffLineSpacing;
            }
          }
        }
      }

      StemAnchor anchor;
      if (hasArrowPair) {
        anchor = const StemAnchor(xSp: arrowPairCenterXSp, ySp: 0);
      } else if (note.event is NoteEvent) {anchor = StemAnchorResolver.forPitchOrEvent(note.pitch, note.event as NoteEvent, stemUp);}
      else {anchor = const StemAnchor(xSp: 0.65, ySp: 0);}

      if (isGrace) anchor = StemAnchor(xSp: anchor.xSp * graceScale, ySp: anchor.ySp * graceScale);

      final double staffBaseYForChord = yPxFinal - yLineForLedger * staffLineSpacing;
      final double stemStartYPx = staffBaseYForChord + stemStartYLine * staffLineSpacing;

      _drawStem(canvas, xPx, stemStartYPx, stemUp, effectiveStemLength, anchor);

      if (graceSlash) {
        final double stemX = stemUp ? xPx + staffLineSpacing * anchor.xSp : xPx - staffLineSpacing * anchor.xSp;
        final double slashY = stemUp ? stemStartYPx - effectiveStemLength * 0.8 : stemStartYPx + effectiveStemLength * 0.8;
        final slashPaint = Paint()..color = noteColor..strokeWidth = 1.5..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(stemX - staffLineSpacing * 0.6, slashY + staffLineSpacing * 0.9), Offset(stemX + staffLineSpacing * 0.6, slashY - staffLineSpacing * 0.9), slashPaint);
      }

      if (note.event is NoteEvent) {
        final ne = note.event as NoteEvent;
        if (ne.tremoloType != TremoloType.none && ne.beams.isEmpty) {
            final bool isBeamable = ne.durationType.isBeamable;
            final bool hasFlag = isBeamable && ne.beams.isEmpty;
            _drawTremolo(
              canvas: canvas, xNote: xPx, stemStartYPx: stemStartYPx, stemUp: stemUp,
              effectiveStemLength: effectiveStemLength, tremoloType: ne.tremoloType,
              tremoloCount: ne.tremoloCount, hasFlag: hasFlag, anchor: anchor,
            );
        }
      }
    }

    _drawAccidental(canvas, note, xPx, yPxFinal, styleOverride: effectiveNoteStyle);
    _drawNoteHead(canvas, note, xPx, yPxFinal, noteColor, styleOverride: effectiveNoteStyle);

    if (note.event.dotType != DotType.none) _drawNoteDots(canvas, note, xPx, yPxFinal, isGrace: isGrace);

    if (isSelected) _drawSelectionHighlight(canvas, note, xPx, yPxFinal);
  }

  void _drawSlashNote({
    required Canvas canvas, required LayoutedNote note, required double xPx,
    required double staffBaseY, required bool isSelected, required double? dragOffsetY,
    required SlashNotation slashNotation,
  }) {
    final double slashYPx = staffBaseY + 2.0 * staffLineSpacing;
    final Color noteColor = isSelected ? selectionColor : Colors.black;

    final slashPainter = TextPainter(
      text: TextSpan(text: Smufl.glyph('noteheadSlashHorizontalEnds'), style: noteStyle.copyWith(color: noteColor)),
      textDirection: TextDirection.ltr,
    )..layout();

    slashPainter.paint(canvas, Offset(xPx - slashPainter.width / 2, slashYPx - slashPainter.height / 2));

    if (slashNotation.useStems) {
      const bool stemUp = false;
      final StemAnchor anchor = StemAnchorResolver.forNotehead(NoteheadShape.slash, DurationType.quarter, stemUp, true);
      _drawStem(canvas, xPx, slashYPx, stemUp, stemLength, anchor);
    }

    if (isSelected) _drawSelectionHighlight(canvas, note, xPx, slashYPx);
  }

  void _drawTremolo({
    required Canvas canvas, required double xNote, required double stemStartYPx,
    required bool stemUp, required double effectiveStemLength, required TremoloType tremoloType,
    required int tremoloCount, bool hasFlag = false, StemAnchor? anchor,
  }) {
    final double offsetSp = anchor?.xSp ?? 0.6;
    final double stemX = stemUp ? xNote + staffLineSpacing * offsetSp : xNote - staffLineSpacing * offsetSp;
    final double stemEndYPx = stemUp ? stemStartYPx - effectiveStemLength : stemStartYPx + effectiveStemLength;
    final paint = Paint()..color = Colors.black;

    if (tremoloType == TremoloType.unmeasured) {
      const double posFactor = 0.60;
      final double centerY = stemStartYPx + (stemEndYPx - stemStartYPx) * posFactor;
      final glyphPainter = TextPainter(
        text: TextSpan(text: Smufl.glyph('buzzRoll'), style: MusicTextStyle.music(fontSize: staffLineSpacing * 3.0, color: Colors.black, height: 1.0)),
        textDirection: TextDirection.ltr,
      )..layout();
      glyphPainter.paint(canvas, Offset(stemX - glyphPainter.width / 2, centerY - glyphPainter.height / 2 + staffLineSpacing * 1.2));
      return;
    }

    final int count = tremoloCount <= 0 ? 1 : tremoloCount;
    final double barWidth = staffLineSpacing * 1.75;
    final double barThickness = staffLineSpacing * 0.55;
    final double spacing = staffLineSpacing * 1.05;
    final double tiltRadians = stemUp ? -0.12 : 0.12;
    final double topMargin = hasFlag ? staffLineSpacing * 1.8 : staffLineSpacing * 0.5;
    final double firstBarY = stemUp ? stemEndYPx + topMargin : stemEndYPx - topMargin;

    for (int i = 0; i < count; i++) {
      final double barCenterY = stemUp ? firstBarY + i * spacing : firstBarY - i * spacing;
      canvas.save();
      canvas.translate(stemX, barCenterY);
      canvas.rotate(tiltRadians);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: barWidth, height: barThickness), paint);
      canvas.restore();
    }
  }

  void _drawNoteDots(Canvas canvas, LayoutedNote note, double xPx, double yPx, {bool isGrace = false}) {
    final int count = note.event.dotType.count;
    if (count == 0) return;

    final double yLine = note.yLine;
    final double dotYLine = (yLine == yLine.roundToDouble()) ? yLine - 0.5 : yLine;
    final double staffBaseY = yPx - yLine * staffLineSpacing;
    final double dotY = staffBaseY + dotYLine * staffLineSpacing;

    final double headHalfWidthSp = _noteHeadVisualWidthSp(note.event.durationType) / 2;
    double dotGapSp;
    switch (note.event.durationType) {
      case DurationType.maxima:
      case DurationType.longa:
      case DurationType.doubleWhole:
        dotGapSp = 0.5; break;
      default: dotGapSp = 0.35;
    }

    final double dotRadius = staffLineSpacing * (isGrace ? 0.12 : 0.2);
    final double dotSpacing = staffLineSpacing * (isGrace ? 0.4 : 0.6);
    final double gapFactor = isGrace ? graceScale : 1.0;
    final double startX = xPx + staffLineSpacing * (headHalfWidthSp * gapFactor + dotGapSp) + dotRadius;
    final paint = Paint()..color = Colors.black;

    for (int i = 0; i < count; i++) {
      canvas.drawCircle(Offset(startX + i * dotSpacing, dotY), dotRadius, paint);
    }
  }

  void _drawLedgerLines(Canvas canvas, double x, double yLine, double staffBaseY, {bool hasAccidental = false}) {
    final double rightExt = staffLineSpacing * 1.2;
    final double leftExt = hasAccidental ? staffLineSpacing * 0.8 : staffLineSpacing * 1.2;
    final ledgerPaint = Paint()
      ..color = Colors.black..strokeWidth = 1.5..strokeCap = StrokeCap.butt..style = PaintingStyle.stroke;

    if (yLine < 0) {
      for (double line = -1.0; line >= yLine - 0.01; line -= 1.0) {
        canvas.drawLine(Offset(x - leftExt, staffBaseY + line * staffLineSpacing), Offset(x + rightExt, staffBaseY + line * staffLineSpacing), ledgerPaint);
      }
    } else if (yLine > 4) {
      for (double line = 5.0; line <= yLine + 0.01; line += 1.0) {
        canvas.drawLine(Offset(x - leftExt, staffBaseY + line * staffLineSpacing), Offset(x + rightExt, staffBaseY + line * staffLineSpacing), ledgerPaint);
      }
    }
  }

  static String? _accidentalName(Accidental acc) {
    switch (acc) {
      case Accidental.sharp: return 'accidentalSharp';
      case Accidental.flat: return 'accidentalFlat';
      case Accidental.natural: return 'accidentalNatural';
      case Accidental.doubleSharp: return 'accidentalSharpSharp';
      case Accidental.doubleFlat: return 'accidentalDoubleFlat';
      case Accidental.quarterSharp: return 'accidentalQuarterToneSharpStein';
      case Accidental.quarterFlat: return 'accidentalQuarterToneFlatStein';
      case Accidental.threeQuarterSharp: return 'accidentalThreeQuarterTonesSharpStein';
      case Accidental.threeQuarterFlat: return 'accidentalThreeQuarterTonesFlatZimmermann';
      case Accidental.flatUp: return 'accidentalQuarterToneFlatArrowUp';
      case Accidental.flatDown: return 'accidentalQuarterToneFlatNaturalArrowDown';
      case Accidental.naturalUp: return 'accidentalQuarterToneSharpNaturalArrowUp';
      case Accidental.naturalDown: return 'accidentalQuarterToneFlatNaturalArrowDown';
      case Accidental.sharpUp: return 'accidentalQuarterToneSharpNaturalArrowUp';
      case Accidental.sharpDown: return 'accidentalQuarterToneSharpArrowDown';
      case Accidental.doubleSharpUp: return 'accidentalThreeQuarterTonesSharpArrowUp';
      case Accidental.doubleSharpDown: return 'accidentalThreeQuarterTonesSharpArrowDown';
      case Accidental.doubleFlatUp: return 'accidentalThreeQuarterTonesFlatArrowUp';
      case Accidental.doubleFlatDown: return 'accidentalThreeQuarterTonesFlatArrowDown';
      case Accidental.arrowUp: return 'accidentalArrowUp';
      case Accidental.arrowDown: return 'accidentalArrowDown';
      case Accidental.arrowBoth: return null;
      case Accidental.slashQuarterSharp: return 'accidentalQuarterToneSharp4';
      case Accidental.slashFlat: return 'accidentalQuarterToneFlat4';
      case Accidental.sori: return 'accidentalSori';
      case Accidental.koron: return 'accidentalKoron';
      default: return null;
    }
  }

  void _drawAccidental(Canvas canvas, LayoutedNote note, double x, double y, {TextStyle? styleOverride}) {
    final accidental = note.displayAccidental;
    if (accidental == null || accidental == Accidental.none) return;

    if (accidental == Accidental.arrowBoth) { _drawArrowBothFallback(canvas, x, y); return; }

    final name = _accidentalName(accidental);
    if (name == null) return;
    final effectiveStyle = styleOverride ?? noteStyle;
    final accGlyph = Smufl.glyph(name);

    String? leftGlyphName;
    String? rightGlyphName;

    if (note.accidentalEditorial && note.accidentalCautionary) {
      leftGlyphName = 'accidentalBracketLeft'; rightGlyphName = 'accidentalBracketRight';
    } else if (note.accidentalEditorial) {
      leftGlyphName = 'accidentalBracketLeft'; rightGlyphName = 'accidentalBracketRight';
    } else if (note.accidentalCautionary) {
      leftGlyphName = 'accidentalParensLeft'; rightGlyphName = 'accidentalParensRight';
    }

    final accPainter = TextPainter(text: TextSpan(text: accGlyph, style: effectiveStyle), textDirection: TextDirection.ltr)..layout();
    TextPainter? leftPainter;
    TextPainter? rightPainter;

    if (leftGlyphName != null) leftPainter = TextPainter(text: TextSpan(text: Smufl.glyph(leftGlyphName), style: effectiveStyle), textDirection: TextDirection.ltr)..layout();
    if (rightGlyphName != null) rightPainter = TextPainter(text: TextSpan(text: Smufl.glyph(rightGlyphName), style: effectiveStyle), textDirection: TextDirection.ltr)..layout();

    final double headHalfWidthSp = _noteHeadVisualWidthSp(note.event.durationType) / 2;
    const double accidentalGapSp = 0.55;
    final double accWidth = accPainter.width;
    final double glyphCenterX = x - staffLineSpacing * (headHalfWidthSp * (note.isGrace ? graceScale : 1.0) + accidentalGapSp) + note.accidentalOffsetX;
    final double accLeft = glyphCenterX - accWidth / 2;

    if (leftPainter != null) leftPainter.paint(canvas, Offset(accLeft - leftPainter.width, y - leftPainter.height / 2));
    accPainter.paint(canvas, Offset(accLeft, y - accPainter.height / 2));
    if (rightPainter != null) rightPainter.paint(canvas, Offset(accLeft + accWidth, y - rightPainter.height / 2));
  }

  void _drawArrowBothFallback(Canvas canvas, double noteX, double noteY) {
    const double accidentalOffsetFactor = 1.5;
    final double offset = staffLineSpacing * accidentalOffsetFactor;
    final double w = staffLineSpacing * 0.55;
    final double h = staffLineSpacing * 0.4;
    final double gap = staffLineSpacing * 0.7;
    final double cx = noteX - offset - w / 2;
    final fillPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = Colors.black..strokeWidth = staffLineSpacing * 0.11..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx, noteY - gap), Offset(cx, noteY + gap), strokePaint);
    final topPath = Path()..moveTo(cx, noteY - gap - h * 0.1)..lineTo(cx - w / 2, noteY - gap + h * 0.7)..lineTo(cx + w / 2, noteY - gap + h * 0.7)..close();
    canvas.drawPath(topPath, fillPaint);
    final bottomPath = Path()..moveTo(cx, noteY + gap + h * 0.1)..lineTo(cx - w / 2, noteY + gap - h * 0.7)..lineTo(cx + w / 2, noteY + gap - h * 0.7)..close();
    canvas.drawPath(bottomPath, fillPaint);
  }

  void _drawNoteHead(Canvas canvas, LayoutedNote note, double x, double y, Color color, {TextStyle? styleOverride}) {
    if (note.event is! NoteEvent) return;
    final ne = note.event as NoteEvent;
    final NoteheadShape shape = note.pitch?.notehead ?? ne.notehead;
    if (shape == NoteheadShape.none) return;

    if (shape == NoteheadShape.normal && (ne.durationType == DurationType.doubleWhole || ne.durationType == DurationType.longa || ne.durationType == DurationType.maxima)) {
      _drawBreveHead(canvas, x, y, color, ne.durationType); return;
    }

    final bool isFilled = note.pitch?.noteheadFilled ?? StemAnchorResolver.isFilled(ne);
    final String glyphName = shape == NoteheadShape.normal
      ? _normalNoteheadName(ne.durationType, isFilled)
      : _specialNoteheadName(shape, isFilled);

    final effectiveStyle = styleOverride ?? noteStyle;
    final notePainter = TextPainter(text: TextSpan(text: Smufl.glyph(glyphName), style: effectiveStyle.copyWith(color: color)), textDirection: TextDirection.ltr)..layout();
    notePainter.paint(canvas, Offset(x - notePainter.width / 2, y - notePainter.height / 2));

    final bool hasParentheses = note.pitch?.noteheadParentheses ?? ne.noteheadParentheses;
    if (hasParentheses) _drawNoteheadParentheses(canvas: canvas, centerX: x, centerY: y, glyphWidth: notePainter.width, color: color);
  }

  void _drawBreveHead(Canvas canvas, double x, double y, Color color, DurationType type) {
    final double bodyWidth = type == DurationType.maxima ? staffLineSpacing * 3.0 : staffLineSpacing * 1.0;
    final double bodyHeight = staffLineSpacing * 1.25;
    final double bodyYOffset = -staffLineSpacing * 0.5;
    final double bodyCenterY = y + bodyYOffset;
    final double bodyLeft = x - bodyWidth / 2;
    final double bodyRight = x + bodyWidth / 2;
    final double bodyTop = bodyCenterY - bodyHeight / 2;
    final double bodyBottom = bodyCenterY + bodyHeight / 2;
    final double thickBarHeight = staffLineSpacing * 0.28;
    final double thinLine = 1.5;
    final double leftLineTop = y - staffLineSpacing * 1.5;
    final double leftLineHeight = staffLineSpacing * 2.0;
    final double rightLineTop = y - staffLineSpacing * 1.5;
    final double downStemLength = staffLineSpacing * 3.0;
    final double rightLineHeight = bodyHeight + downStemLength;
    final fillPaint = Paint()..color = color;

    if (type == DurationType.doubleWhole) {
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyTop, bodyWidth, thinLine), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyBottom - thinLine, bodyWidth, thinLine), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyTop, thinLine, bodyHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyRight - thinLine, bodyTop, thinLine, bodyHeight), fillPaint);
    } else if (type == DurationType.longa) {
      canvas.drawRect(Rect.fromLTWH(bodyLeft, leftLineTop, thinLine, leftLineHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyRight - thinLine, rightLineTop, thinLine, rightLineHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyTop, bodyWidth, thickBarHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyBottom - thinLine, bodyWidth, thinLine), fillPaint);
    } else if (type == DurationType.maxima) {
      canvas.drawRect(Rect.fromLTWH(bodyLeft, leftLineTop, thinLine, leftLineHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyRight - thinLine, rightLineTop, thinLine, rightLineHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyTop, bodyWidth, thickBarHeight), fillPaint);
      canvas.drawRect(Rect.fromLTWH(bodyLeft, bodyBottom - thickBarHeight, bodyWidth, thickBarHeight), fillPaint);
    }
  }

  static int _diatonicDiff(Pitch p1, Pitch p2) {
    int letterIdx(NoteLetter l) {
      switch (l) {
        case NoteLetter.C: return 0; case NoteLetter.D: return 1; case NoteLetter.E: return 2;
        case NoteLetter.F: return 3; case NoteLetter.G: return 4; case NoteLetter.A: return 5;
        case NoteLetter.B: return 6;
      }
    }
    return (p2.octave * 7 + letterIdx(p2.letter)) - (p1.octave * 7 + letterIdx(p1.letter));
  }

  void _drawStem(Canvas canvas, double x, double y, bool stemUp, [double? overrideStemLength, StemAnchor? anchor]) {
    final double length = overrideStemLength ?? stemLength;
    final StemAnchor a = anchor ?? const StemAnchor(xSp: 0.6, ySp: 0);
    final double stemX = stemUp ? x + staffLineSpacing * a.xSp : x - staffLineSpacing * a.xSp;
    final double stemStartY = y + staffLineSpacing * a.ySp;
    final double stemYEnd = stemUp ? stemStartY - length : stemStartY + length;
    canvas.drawLine(Offset(stemX, stemStartY), Offset(stemX, stemYEnd), linePaint);
  }

  void _drawSelectionHighlight(Canvas canvas, LayoutedNote note, double x, double y) {
    final double radius = 8.0 * scale;
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = selectionColor..strokeWidth = 1.5..style = PaintingStyle.stroke);
  }

  // ==========================================================================
  // ARTICULATIONS
  // ==========================================================================

  void drawArticulations(Canvas canvas, List<Articulation> articulations, double x, double y, double staffTopY, {required bool autoAbove}) {
    if (articulations.isEmpty) return;

    int aboveStack = 0;
    int belowStack = 0;

    for (final art in articulations) {
      if (art.type == ArticulationType.none) continue;
      final bool above = _resolveSide(art, autoAbove);
      final int stackIndex = above ? aboveStack : belowStack;

      _drawOneArticulation(canvas, art.type, x, y, above: above, stackIndex: stackIndex, staffTopY: staffTopY);

      if (above) {
        aboveStack++;
      } else {
        belowStack++;
      }
    }
  }

  bool _resolveSide(Articulation art, bool autoAbove) {
    if (art.placement == 'above') return true;
    if (art.placement == 'below') return false;
    switch (art.type) {
      case ArticulationType.fermata:
      case ArticulationType.shortFermata:
      case ArticulationType.longFermata:
        return true;
      default:
        return autoAbove;
    }
  }

  void _drawOneArticulation(Canvas canvas, ArticulationType type, double x, double y, {required bool above, required int stackIndex, required double staffTopY}) {
    final double baseOffset = staffLineSpacing * 1.5;
    final double stackOffset = stackIndex * staffLineSpacing * 1.8;
    final double offset = baseOffset + stackOffset;
    double artY = above ? y - offset : y + offset;
    double artYLine = (artY - staffTopY) / staffLineSpacing;
    artYLine = (artYLine * 2).round() / 2.0;
    if (artYLine % 1.0 == 0.0) { if (above) {
      artYLine -= 0.5;
    } else {
      artYLine += 0.5;
    } }
    artY = staffTopY + artYLine * staffLineSpacing;

    switch (type) {
      case ArticulationType.staccato: _drawStaccato(canvas, x, artY); break;
      case ArticulationType.staccatissimo: _drawStaccatissimo(canvas, x, artY, above: above); break;
      case ArticulationType.spiccato: _drawGlyph(canvas, Smufl.glyph(above ? 'articStaccatissimoWedgeAbove' : 'articStaccatissimoWedgeBelow'), x, artY); break;
      case ArticulationType.tenuto: _drawTenuto(canvas, x, artY); break;
      case ArticulationType.accent: _drawAccent(canvas, x, artY); break;
      case ArticulationType.marcato: _drawMarcato(canvas, x, artY, above: above); break;
      case ArticulationType.softAccent: _drawGlyph(canvas, Smufl.glyph(above ? 'articSoftAccentAbove' : 'articSoftAccentBelow'), x, artY); break;
      case ArticulationType.stress: _drawGlyph(canvas, Smufl.glyph(above ? 'articStressAbove' : 'articStressBelow'), x, artY); break;
      case ArticulationType.unstress: _drawGlyph(canvas, Smufl.glyph(above ? 'articUnstressAbove' : 'articUnstressBelow'), x, artY); break;
      case ArticulationType.scoop: _drawGlyph(canvas, Smufl.glyph('brassScoop'), x, artY); break;
      case ArticulationType.plop: _drawGlyph(canvas, Smufl.glyph('brassPlop'), x, artY); break;
      case ArticulationType.doit: _drawGlyph(canvas, Smufl.glyph('brassDoitMedium'), x, artY); break;
      case ArticulationType.falloff: _drawGlyph(canvas, Smufl.glyph('brassFallLipMedium'), x, artY); break;
      case ArticulationType.breathMark: _drawGlyph(canvas, Smufl.glyph('breathMarkComma'), x, artY); break;
      case ArticulationType.caesura: _drawGlyph(canvas, Smufl.glyph('caesura'), x, artY); break;
      case ArticulationType.fermata: _drawGlyph(canvas, Smufl.glyph(above ? 'fermataAbove' : 'fermataBelow'), x, artY); break;
      case ArticulationType.shortFermata: _drawGlyph(canvas, Smufl.glyph(above ? 'fermataShortAbove' : 'fermataShortBelow'), x, artY); break;
      case ArticulationType.longFermata: _drawGlyph(canvas, Smufl.glyph(above ? 'fermataLongAbove' : 'fermataLongBelow'), x, artY); break;
      case ArticulationType.trill: _drawGlyph(canvas, Smufl.glyph('ornamentTrill'), x, artY); break;
      case ArticulationType.mordent: _drawGlyph(canvas, Smufl.glyph('ornamentMordent'), x, artY); break;
      case ArticulationType.turn: _drawGlyph(canvas, Smufl.glyph('ornamentTurn'), x, artY); break;
      case ArticulationType.none: return;
    }
  }

  void _drawStaccato(Canvas canvas, double x, double y) { canvas.drawCircle(Offset(x, y), staffLineSpacing * 0.28, Paint()..color = Colors.black); }
  void _drawStaccatissimo(Canvas canvas, double x, double y, {required bool above}) {
    final width = staffLineSpacing * 0.6; final height = staffLineSpacing * 0.9;
    final path = Path();
    if (above) { path.moveTo(x - width / 2, y - height / 2); path.lineTo(x + width / 2, y - height / 2); path.lineTo(x, y + height / 2); }
    else { path.moveTo(x - width / 2, y + height / 2); path.lineTo(x + width / 2, y + height / 2); path.lineTo(x, y - height / 2); }
    path.close(); canvas.drawPath(path, Paint()..color = Colors.black);
  }
  void _drawTenuto(Canvas canvas, double x, double y) { canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: staffLineSpacing * 1.3, height: staffLineSpacing * 0.2), Paint()..color = Colors.black); }
  void _drawAccent(Canvas canvas, double x, double y) {
    final paint = Paint()..color = Colors.black..strokeWidth = staffLineSpacing * 0.16..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path()..moveTo(x - staffLineSpacing * 0.7, y - staffLineSpacing * 0.4)..lineTo(x + staffLineSpacing * 0.7, y)..lineTo(x - staffLineSpacing * 0.7, y + staffLineSpacing * 0.4);
    canvas.drawPath(path, paint);
  }
  void _drawMarcato(Canvas canvas, double x, double y, {required bool above}) {
    final paint = Paint()..color = Colors.black..strokeWidth = staffLineSpacing * 0.18..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path();
    if (above) { path.moveTo(x - staffLineSpacing * 0.7, y - staffLineSpacing * 0.45); path.lineTo(x, y + staffLineSpacing * 0.45); path.lineTo(x + staffLineSpacing * 0.7, y - staffLineSpacing * 0.45); }
    else { path.moveTo(x - staffLineSpacing * 0.7, y + staffLineSpacing * 0.45); path.lineTo(x, y - staffLineSpacing * 0.45); path.lineTo(x + staffLineSpacing * 0.7, y + staffLineSpacing * 0.45); }
    canvas.drawPath(path, paint);
  }
  void _drawGlyph(Canvas canvas, String glyph, double x, double y) {
    final painter = TextPainter(text: TextSpan(text: glyph, style: MusicTextStyle.music(fontSize: staffLineSpacing * 4.0, color: Colors.black, height: 1.0)), textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, Offset(x - painter.width / 2, y - painter.height / 2));
  }

  static String _getRestName(DurationType type) {
    switch (type) {
      case DurationType.maxima: return 'restMaxima'; case DurationType.longa: return 'restLonga';
      case DurationType.doubleWhole: return 'restDoubleWhole'; case DurationType.whole: return 'restWhole';
      case DurationType.half: return 'restHalf'; case DurationType.quarter: return 'restQuarter';
      case DurationType.eighth: return 'rest8th'; case DurationType.sixteenth: return 'rest16th';
      case DurationType.thirtySecond: return 'rest32nd'; case DurationType.sixtyFourth: return 'rest64th';
      case DurationType.oneHundredTwentyEighth: return 'rest128th'; case DurationType.twoHundredFiftySixth: return 'rest256th';
      case DurationType.fiveHundredTwelfth: return 'rest512th'; case DurationType.oneThousandTwentyFourth: return 'rest1024th';
    }
  }

  void drawFermatas(Canvas canvas, List<FermataNotation> fermatas, double x, double y, double staffTopY, double staffBottomY) {
    for (final fermata in fermatas) {
      final bool isInverted = fermata.type == 'inverted';
      final String shape = fermata.shape;

      // 1. Déterminer le glyphe de base
      String glyphName;
      switch (shape) {
        case 'square':
        case 'double-square':
          glyphName = isInverted ? 'fermataLongBelow' : 'fermataLongAbove';
          break;
        case 'angled':
        case 'double-angled':
          glyphName = isInverted ? 'fermataShortBelow' : 'fermataShortAbove';
          break;
        case 'half-curve':
        case 'double-dot':
        case 'normal':
        default:
          glyphName = isInverted ? 'fermataBelow' : 'fermataAbove';
          break;
      }

      // 2. Vérifier si un glyphe NATIF existe pour les variantes
      String? nativeGlyph;
      if (shape == 'double-dot') nativeGlyph = isInverted ? 'fermataDoubleDotBelow' : 'fermataDoubleDotAbove';
      if (shape == 'half-curve') nativeGlyph = isInverted ? 'fermataHalfCurveBelow' : 'fermataHalfCurveAbove';
      if (shape == 'double-square') nativeGlyph = isInverted ? 'fermataDoubleSquareBelow' : 'fermataDoubleSquareAbove';
      if (shape == 'double-angled') nativeGlyph = isInverted ? 'fermataDoubleAngledBelow' : 'fermataDoubleAngledAbove';

      final hasNative = nativeGlyph != null && Smufl.has(nativeGlyph);
      if (hasNative) {
        glyphName = nativeGlyph!;
      }

      final painter = TextPainter(
        text: TextSpan(
          text: Smufl.glyph(glyphName), 
          style: MusicTextStyle.music(fontSize: staffLineSpacing * 4.0, color: Colors.black, height: 1.0)
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      double yPos = isInverted ? y + staffLineSpacing * 2.5 : y - staffLineSpacing * 2.5;
      painter.paint(canvas, Offset(x - painter.width / 2, yPos - painter.height / 2));

      // 3. Fallback (si le glyphe natif n'existe pas dans la police)
      if (!hasNative && (shape == 'double-dot' || shape == 'double-square' || shape == 'double-angled' || shape == 'half-curve')) {
        // Sur le glyphe standard, le point est situé un peu en dessous du centre (pour 'above')
        final double dotY = isInverted 
            ? yPos - painter.height * 0.15 
            : yPos + painter.height * 0.15;

        // A. Masquer le point central avec un rectangle de la couleur du fond (blanc)
        final coverPaint = Paint()..color = Colors.white;
        // Un rectangle plus grand (1.5 sp) pour être sûr de bien cacher le point
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, dotY), width: staffLineSpacing * 1.5, height: staffLineSpacing * 1.5), 
          coverPaint
        );

        // B. Dessiner les nouveaux points (sauf pour half-curve qui n'en a pas)
        if (shape != 'half-curve') {
          final dotPaint = Paint()..color = Colors.black;
          final double dotRadius = staffLineSpacing * 0.2;
          final double dotSpacing = staffLineSpacing * 0.6;
          
          canvas.drawCircle(Offset(x - dotSpacing / 2, dotY), dotRadius, dotPaint);
          canvas.drawCircle(Offset(x + dotSpacing / 2, dotY), dotRadius, dotPaint);
        }
      }
    }
  }
  /// v2c-32e : dessine UNE vague d'arpège (déjà groupée par le caller).
  /// [yTop]    = yPx de la note la PLUS HAUTE du groupe
  /// [yBottom] = yPx de la note la PLUS BASSE du groupe
  void drawArpeggiateLine(
    Canvas canvas,
    double x,
    double yTop,
    double yBottom, {
    String? direction,
  }) {
    final double arpX = x - staffLineSpacing * 1.8;
    final double extend = staffLineSpacing * 0.5;
    final double top = yTop - extend;
    final double bottom = yBottom + extend;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Wavy line
    final path = Path();
    bool isLeft = true;
    double currentY = top;
    final double stepY = staffLineSpacing * 0.35;
    final double stepX = staffLineSpacing * 0.30;
    path.moveTo(arpX, currentY);
    while (currentY < bottom) {
      currentY += stepY;
      if (currentY > bottom) currentY = bottom;
      path.lineTo(isLeft ? arpX - stepX : arpX + stepX, currentY);
      isLeft = !isLeft;
    }
    canvas.drawPath(path, paint);

    // Flèche directionnelle (taille validée en 32d : 0.85 / 0.45)
    if (direction == 'up' || direction == 'down') {
      final fillPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      final double arrowHeight = staffLineSpacing * 0.85;
      final double arrowHalfWidth = staffLineSpacing * 0.45;

      final Path arrowPath;
      if (direction == 'up') {
        arrowPath = Path()
          ..moveTo(arpX, top - arrowHeight)
          ..lineTo(arpX - arrowHalfWidth, top)
          ..lineTo(arpX + arrowHalfWidth, top)
          ..close();
      } else {
        arrowPath = Path()
          ..moveTo(arpX, bottom + arrowHeight)
          ..lineTo(arpX - arrowHalfWidth, bottom)
          ..lineTo(arpX + arrowHalfWidth, bottom)
          ..close();
      }
      canvas.drawPath(arrowPath, fillPaint);
    }
  }

  /// v2c-32e : dessine un bracket non-arpeggiate groupé.
  void drawNonArpeggiateBracket(
    Canvas canvas,
    double x,
    double yTop,
    double yBottom, {
    required bool hasTop,
    required bool hasBottom,
  }) {
    final double arpX = x - staffLineSpacing * 1.8;
    final double tickWidth = staffLineSpacing * 0.8;
    final double yShift = -staffLineSpacing * 0.25;
    final double top = yTop - staffLineSpacing * 0.5 + yShift;
    final double bottom = yBottom + staffLineSpacing * 0.5 + yShift;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    if (hasTop && hasBottom) {
      canvas.drawLine(Offset(arpX, top), Offset(arpX, bottom), paint);
      canvas.drawLine(Offset(arpX, top), Offset(arpX + tickWidth, top), paint);
      canvas.drawLine(Offset(arpX, bottom), Offset(arpX + tickWidth, bottom), paint);
    } else if (hasTop) {
      canvas.drawLine(Offset(arpX, top), Offset(arpX, top + staffLineSpacing * 1.5), paint);
      canvas.drawLine(Offset(arpX, top), Offset(arpX + tickWidth, top), paint);
    } else if (hasBottom) {
      canvas.drawLine(Offset(arpX, bottom), Offset(arpX, bottom - staffLineSpacing * 1.5), paint);
      canvas.drawLine(Offset(arpX, bottom), Offset(arpX + tickWidth, bottom), paint);
    }
  }
  void drawOrnaments(
    Canvas canvas, List<OrnamentNotation> ornaments, double x, double y, double staffTopY, bool autoAbove, {
    int startAboveStack = 0, int startBelowStack = 0,
  }) {
    final staticOrnaments = ornaments.where((o) => o.type != 'wavy-line').toList();
    if (staticOrnaments.isEmpty) return;
    int aboveStack = startAboveStack; int belowStack = startBelowStack;

    for (final orn in staticOrnaments) {
      bool above = orn.placement == 'above' || (orn.placement != 'below' && autoAbove);
      int stackIndex = above ? aboveStack : belowStack;
      double baseOffset = staffLineSpacing * 3.2;
      double stackOffset = stackIndex * staffLineSpacing * 2.8;
      double offsetY = baseOffset + stackOffset;
      double ornY = above ? y - offsetY : y + offsetY;

      String glyphName = 'ornamentTrill';
      String? fallbackChar; double rotation = 0.0;

      switch (orn.type) {
        case 'trill-mark': glyphName = 'ornamentTrill'; break;
        case 'turn': glyphName = above ? 'ornamentTurn' : 'ornamentTurnInverted'; break;
        case 'inverted-turn': glyphName = above ? 'ornamentTurnInverted' : 'ornamentTurn'; break;
        case 'delayed-turn': glyphName = 'ornamentTurnSlash'; break;
        case 'delayed-inverted-turn': glyphName = 'ornamentTurnSlash'; break;
        case 'vertical-turn': glyphName = 'ornamentTurn'; rotation = math.pi / 2; break;
        case 'inverted-vertical-turn': glyphName = 'ornamentTurnInverted'; rotation = math.pi / 2; break;
        case 'mordent': glyphName = 'ornamentMordent'; break;
        case 'inverted-mordent':
          if (Smufl.has('ornamentMordentInverted')) {
            glyphName = 'ornamentMordentInverted';
          } else {
            fallbackChar = String.fromCharCode(0xE56C);
          }
          break;
        case 'schleifer': glyphName = 'ornamentSchleifer'; break;
        case 'haydn': glyphName = 'ornamentHaydn'; break;
        case 'shake':
          if (Smufl.has('ornamentShake')) {
            glyphName = 'ornamentShake';
          } else {
            fallbackChar = String.fromCharCode(0xE567);
          }
          break;
        default: continue;
      }

      final String glyphToDraw = fallbackChar ?? Smufl.glyph(glyphName);
      if (rotation != 0.0) {
        canvas.save(); canvas.translate(x, ornY); canvas.rotate(rotation);
        _drawGlyph(canvas, glyphToDraw, 0, 0); canvas.restore();
      } else {
        _drawGlyph(canvas, glyphToDraw, x, ornY);
      }
      if (above) {
        aboveStack++;
      } else {
        belowStack++;
      }
    }
  }

  void drawTechnicals(
    Canvas canvas, List<TechnicalNotation> technicals, double x, double y, double staffTopY, bool autoAbove, {
    int startAboveStack = 0, int startBelowStack = 0,
  }) {
    if (technicals.isEmpty) return;
    int aboveStack = startAboveStack; int belowStack = startBelowStack;

    final textTypes = ['fingering', 'pluck', 'fret', 'string', 'other-technical'];
    final textTechs = technicals.where((t) => textTypes.contains(t.type)).toList();

    final heelToeTechs = technicals.where((t) => t.type == 'heel' || t.type == 'toe').toList();

    final otherTechs = technicals.where((t) =>
      !textTypes.contains(t.type) && t.type != 'heel' && t.type != 'toe'
    ).toList();

    // ══════════════════════════════════════════════════════════════════════
    // 1. DESSIN DES AUTRES GLYPHES
    // ══════════════════════════════════════════════════════════════════════
    for (final tech in otherTechs) {
      bool above = tech.placement == 'above' || (tech.placement != 'below' && autoAbove);
      int stackIndex = above ? aboveStack : belowStack;

      double baseOffset = staffLineSpacing * (tech.type == 'harmonic' ? 2.0 : 3.2);
      double stackOffset = stackIndex * staffLineSpacing * 2.8;
      double yPos = above ? y - (baseOffset + stackOffset) : y + (baseOffset + stackOffset);

      String? glyphName;
      String? fallbackText;

      switch (tech.type) {
        case 'up-bow': glyphName = 'stringsUpBow'; break;
        case 'down-bow': glyphName = 'stringsDownBow'; break;
        case 'harmonic': glyphName = 'stringsHarmonic'; break;
        case 'thumb-position': glyphName = 'stringsThumbPosition'; break;
        case 'snap-pizzicato': glyphName = above ? 'pluckedSnapPizzicatoAbove' : 'pluckedSnapPizzicatoBelow'; break;
        case 'open-string': glyphName = 'fingering0'; break;
        
        case 'double-tongue': glyphName = above ? 'doubleTongueAbove' : 'doubleTongueBelow'; fallbackText = 'T'; break;
        case 'triple-tongue': glyphName = above ? 'tripleTongueAbove' : 'tripleTongueBelow'; fallbackText = '3T'; break;
        case 'stopped': glyphName = 'brassMuteClosed'; fallbackText = '+'; break;
        case 'open': glyphName = 'brassMuteOpen'; fallbackText = 'o'; break;
        case 'half-muted': glyphName = 'brassMuteHalf'; fallbackText = 'M'; break;
        case 'harmon-mute': glyphName = 'brassHarmonMuteClosed'; fallbackText = 'Harm.'; break;
        case 'brass-bend': glyphName = 'brassBend'; fallbackText = 'bend'; break;
        case 'flip': glyphName = 'brassFlip'; fallbackText = 'flip'; break;
        case 'smear': glyphName = 'brassSmear'; fallbackText = 'smear'; break;

        case 'fingernails': glyphName = 'pluckedFingernailFlick'; fallbackText = 'fing.'; break;
        case 'golpe': glyphName = 'guitarGolpe'; fallbackText = 'G'; break;
        
        case 'hole':
          final closed = tech.attributes['closed'] == 'yes';
          glyphName = closed ? 'windClosedHole' : 'windOpenHole';
          fallbackText = closed ? '●' : '○';
          break;
        case 'arrow':
          final dir = tech.attributes['direction'] ?? 'up';
          glyphName = dir == 'down' ? 'arrowBlackDown' : 'arrowBlackUp';
          fallbackText = dir == 'down' ? '↓' : '↑';
          break;
        case 'handbell':
          final sounding = tech.attributes['sounding'];
          if (sounding == 'lift') { glyphName = 'handbellLift'; }
          else if (sounding == 'echo') { glyphName = 'handbellEcho'; }
          else if (sounding == 'ring') { glyphName = 'handbellRing'; }
          else { glyphName = 'handbellDamp'; }
          fallbackText = 'bell';
          break;
        
        case 'hammer-on':
        case 'pull-off':
          final isHammer = tech.type == 'hammer-on';
          final letter = isHammer ? 'H' : 'P';
          final tp = TextPainter(
            text: TextSpan(text: letter, style: TextStyle(fontFamily: 'Arial', fontSize: staffLineSpacing * 1.8, color: Colors.black, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
            textDirection: TextDirection.ltr,
          )..layout();

          final double letterOffset = staffLineSpacing * 2.0;
          final double letterY = above ? y - letterOffset - tp.height : y + letterOffset;
          final double letterX = x - tp.width / 2;

          tp.paint(canvas, Offset(letterX, letterY));

          final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.2;
          final path = Path();
          final double curveY = above ? letterY + tp.height + 1 : letterY - 1;
          path.moveTo(letterX - 3, curveY);
          path.quadraticBezierTo(x, above ? curveY + 5 : curveY - 5, letterX + tp.width + 3, curveY);
          canvas.drawPath(path, paint);
          break;

        case 'bend':
          final bendValueStr = tech.text ?? '';
          final bendValue = double.tryParse(bendValueStr) ?? 0.0;

          final paint = Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;

          final path = Path();

          final double startX = x + staffLineSpacing * 1.0;
          final double startY = y;

          final double absValue = bendValue.abs();
          final double heightOffset = absValue * (staffLineSpacing * 0.8);
          final double lengthOffset = math.max(3.5, absValue * 1.2) * staffLineSpacing;

          final double endX = startX + lengthOffset;
          final double endY = bendValue > 0 ? startY - heightOffset : startY + heightOffset;

          if (bendValue != 0) {
            path.moveTo(startX, startY);
            path.quadraticBezierTo(startX + lengthOffset * 0.4, endY, endX, endY);
            canvas.drawPath(path, paint);
          } else {
            path.moveTo(startX, startY);
            path.lineTo(endX, startY);
            canvas.drawPath(path, paint);
          }

          final tp = TextPainter(
            text: TextSpan(text: bendValueStr, style: TextStyle(fontFamily: 'Arial', fontSize: staffLineSpacing * 1.6, color: Colors.black, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(endX + 6, endY - tp.height / 2));
          break;

        case 'tap':
          final tapText = tech.text?.isNotEmpty == true ? tech.text! : 'T';
          final tp = TextPainter(
            text: TextSpan(text: tapText, style: TextStyle(fontFamily: 'Arial', fontSize: staffLineSpacing * 1.8, color: Colors.black, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x - tp.width / 2, yPos - tp.height / 2));
          break;

        default: break;
      }

      if (glyphName != null) {
        if (Smufl.has(glyphName)) {
          _drawGlyph(canvas, Smufl.glyph(glyphName), x, yPos);
        } else if (fallbackText != null) {
          final tp = TextPainter(
            text: TextSpan(text: fallbackText, style: TextStyle(fontFamily: 'Arial', fontSize: staffLineSpacing * 1.8, color: Colors.black, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x - tp.width / 2, yPos - tp.height / 2));
        }
      }

      if (above) aboveStack++; else belowStack++;
    }

    // ══════════════════════════════════════════════════════════════════════
    // 2. DESSIN DE HEEL / TOE (Alignés horizontalement avec liaison)
    // ══════════════════════════════════════════════════════════════════════
    if (heelToeTechs.isNotEmpty) {
      bool above = heelToeTechs.first.placement == 'above' || (heelToeTechs.first.placement != 'below' && autoAbove);
      int stackIndex = above ? aboveStack : belowStack;

      double baseOffset = staffLineSpacing * 3.2;
      double stackOffset = stackIndex * staffLineSpacing * 2.8;
      double yPos = above ? y - (baseOffset + stackOffset) : y + (baseOffset + stackOffset);

      final double glyphSpacing = staffLineSpacing * 0.2; 

      // 1ère passe : mesurer les glyphes
      final List<TextPainter> painters = [];
      final List<double> widths = [];
      double totalWidth = 0.0;

      for (int i = 0; i < heelToeTechs.length; i++) {
        final tech = heelToeTechs[i];
        final String glyphName = tech.type == 'heel' ? 'keyboardPedalHeel1' : 'keyboardPedalToe1';
        final String fallback = tech.type == 'heel' ? 'U' : 'V';
        
        TextPainter tp;
        if (Smufl.has(glyphName)) {
          tp = TextPainter(
            text: TextSpan(text: Smufl.glyph(glyphName), style: MusicTextStyle.music(fontSize: staffLineSpacing * 4.0, color: Colors.black, height: 1.0)),
            textDirection: TextDirection.ltr,
          )..layout();
        } else {
          tp = TextPainter(
            text: TextSpan(text: fallback, style: TextStyle(fontFamily: 'Arial', fontSize: staffLineSpacing * 2.0, fontWeight: FontWeight.normal)), 
            textDirection: TextDirection.ltr,
          )..layout();
        }
        painters.add(tp);
        widths.add(tp.width);
        totalWidth += tp.width;
        if (i > 0) totalWidth += glyphSpacing;
      }

      double currentX = x - (totalWidth / 2);
      
      final List<double> topEdges = [];
      final List<double> bottomEdges = [];
      final List<double> leftEdges = [];
      final List<double> rightEdges = [];

      // 2ème passe : dessiner et enregistrer les coordonnées
      for (int i = 0; i < heelToeTechs.length; i++) {
        final tp = painters[i];
        final w = widths[i];
        
        final leftX = currentX;
        final rightX = currentX + w;
        final topY = yPos - tp.height / 2;
        final bottomY = yPos + tp.height / 2;

        leftEdges.add(leftX);
        rightEdges.add(rightX);
        topEdges.add(topY);
        bottomEdges.add(bottomY);

        tp.paint(canvas, Offset(leftX, topY));

        currentX += w + glyphSpacing;
      }

      // 3ème passe : dessin de la courbe de substitution
      for (int i = 0; i < heelToeTechs.length; i++) {
        if (heelToeTechs[i].substitution) {
          // On prend le bord gauche du précédent (s'il existe) et le bord droit du courant
          final double curveStartX = (i > 0 ? leftEdges[i-1] : leftEdges[i]) - (staffLineSpacing * 0.1);
          final double curveEndX = rightEdges[i] + (staffLineSpacing * 0.1);
          
          // On se base sur la vraie limite du glyphe pour placer la courbe
          double edgeY;
          if (above) {
             edgeY = math.min(i > 0 ? topEdges[i-1] : topEdges[i], topEdges[i]) - (staffLineSpacing * 0.4);
          } else {
             edgeY = math.max(i > 0 ? bottomEdges[i-1] : bottomEdges[i], bottomEdges[i]) + (staffLineSpacing * 0.4);
          }

          final paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.2;
          final path = Path();
          path.moveTo(curveStartX, edgeY);
          
          // Amplitude généreuse pour un bel arc
          final double bulge = above ? - (staffLineSpacing * 1.2) : (staffLineSpacing * 1.2);
          path.quadraticBezierTo((curveStartX + curveEndX) / 2, edgeY + bulge, curveEndX, edgeY);
          
          canvas.drawPath(path, paint);
        }
      }

      if (above) aboveStack++; else belowStack++;
    }

    // 3. TEXTES STANDARDS
    final textAbove = textTechs.where((t) => t.placement == 'above' || (t.placement != 'below' && autoAbove)).toList();
    final textBelow = textTechs.where((t) => t.placement == 'below' || (t.placement != 'above' && !autoAbove)).toList();

    if (textAbove.isNotEmpty) { _drawTextGroup(canvas, textAbove, x, y, true, aboveStack); aboveStack++; }
    if (textBelow.isNotEmpty) { _drawTextGroup(canvas, textBelow, x, y, false, belowStack); belowStack++; }
  }

  void _drawTextGroup(Canvas canvas, List<TechnicalNotation> group, double x, double y, bool above, int stackIdx) {
    if (group.isEmpty) return;

    // ══════════════════════════════════════════════════════════════════════
    // v2c-112 : Rendu spécifique pour les numéros de corde (guitare)
    // ══════════════════════════════════════════════════════════════════════
    if (group.first.type == 'string' && group.length == 1) {
      final text = group.first.text;
      if (text != null && text.isNotEmpty) {
        final digit = int.tryParse(text);
        if (digit != null && digit >= 0 && digit <= 9) {
          final glyphName = 'guitarString$digit';
          if (Smufl.has(glyphName)) {
            final fontSize = staffLineSpacing * 3.2;
            final tp = TextPainter(
              text: TextSpan(
                text: Smufl.glyph(glyphName),
                style: MusicTextStyle.music(fontSize: fontSize, color: Colors.black, height: 1.0)
              ),
              textDirection: TextDirection.ltr,
            )..layout();

            double baseOffset = staffLineSpacing * 3.2;
            double stackOffset = stackIdx * staffLineSpacing * 2.8;
            double yPos = above ? y - (baseOffset + stackOffset) : y + (baseOffset + stackOffset);

            tp.paint(canvas, Offset(x - tp.width / 2, yPos - tp.height / 2));
            return; 
          }
        }
      }
    }

    // ══════════════════════════════════════════════════════════════════════
    // Rendu standard en texte (fingering, pluck, fret, bend, other-technical, etc.)
    // ══════════════════════════════════════════════════════════════════════
    final isFingering = group.first.type == 'fingering';
    bool hasSubstitution = false;
    String displayText = "";
    bool isFirst = true;

    for (final t in group) {
      if (t.text == null) continue;

      if (!isFirst) {
        displayText += isFingering ? "" : ",";
      }

      if (isFingering && t.alternate) {
        displayText += "(${t.text})";
      } else {
        displayText += t.text!;
      }
      
      if (t.substitution) hasSubstitution = true;
      isFirst = false;
    }

    if (displayText.isEmpty) return;

    final fontSize = staffLineSpacing * (isFingering ? 2.0 : 2.2);
    final tp = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          fontFamily: 'Arial',
          fontSize: fontSize,
          color: Colors.black,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double baseOffset = staffLineSpacing * 3.2;
    double stackOffset = stackIdx * staffLineSpacing * 2.8;
    double yPos = above ? y - (baseOffset + stackOffset) : y + (baseOffset + stackOffset);

    final paintX = x - tp.width / 2;
    final paintY = yPos - tp.height / 2;
    tp.paint(canvas, Offset(paintX, paintY));

    // Dessin du Slur pour la substitution de doigté (ex: 2~3)
    if (isFingering && hasSubstitution) {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final path = Path();
      final curveY = paintY - (staffLineSpacing * 0.2); 
      path.moveTo(paintX + 1, curveY);
      path.quadraticBezierTo(paintX + tp.width / 2, curveY - (staffLineSpacing * 0.6), paintX + tp.width - 1, curveY);
      canvas.drawPath(path, paint);
    }
  }

  void drawWavyLines(
    Canvas canvas, LayoutedMeasure measure, List<Map<String, double>> notePositions,
    bool autoAbove, {String? selectedNoteId, double dragOffsetY = 0.0}) {
    int i = 0;
    while (i < measure.notes.length) {
      final note = measure.notes[i];
      if (note.event is! NoteEvent) { i++; continue; }
      final ne = note.event as NoteEvent;
      final startOrn = ne.notations.ornaments.firstWhere((o) => o.type == 'wavy-line' && o.wavyLineType == 'start', orElse: () => const OrnamentNotation(type: 'none'));

      if (startOrn.type != 'wavy-line') { i++; continue; }

      int endIdx = i;
      bool foundStop = false;
      while (endIdx < measure.notes.length) {
        final endNote = measure.notes[endIdx];
        if (endNote.event is NoteEvent) {
          final endNe = endNote.event as NoteEvent;
          if (endNe.notations.ornaments.any((o) => o.type == 'wavy-line' && o.wavyLineType == 'stop')) {
            foundStop = true; break;
          }
        }
        endIdx++;
      }
      if (!foundStop) endIdx = measure.notes.length - 1;
      if (endIdx <= i) { i = endIdx + 1; continue; }

      final double startX = notePositions[i]['x']! + staffLineSpacing * 0.8;
      final double endX = notePositions[endIdx]['x']! - staffLineSpacing * 0.8;
      if (endX <= startX) { i = endIdx + 1; continue; }

      final bool stemUp = StemDirectionResolver.shouldStemBeUp(note);
      bool above = !stemUp;
      if (startOrn.placement == 'above') above = true;
      if (startOrn.placement == 'below') above = false;

      double minY = double.infinity, maxY = double.negativeInfinity;
      for (int j = i; j <= endIdx; j++) {
        final n = measure.notes[j];
        double y = notePositions[j]['y']!;
        if (selectedNoteId != null && n.id == selectedNoteId) y += dragOffsetY;
        if (y < minY) minY = y; if (y > maxY) maxY = y;
        if (n.event.durationType.needsStem) {
          final noteStemUp = StemDirectionResolver.shouldStemBeUp(n);
          final double stemLen = n.isGrace ? stemLength * graceScale : stemLength;
          if (noteStemUp) { if (y - stemLen < minY) minY = y - stemLen; }
          else { if (y + stemLen > maxY) maxY = y + stemLen; }
        }
      }

      final double clearance = staffLineSpacing * 0.6;
      final double lineY = above ? minY - clearance : maxY + clearance;
      final paint = Paint()..color = Colors.black..strokeWidth = 2.2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      final path = Path();
      final double amp = staffLineSpacing * 0.22;
      final double wavelength = staffLineSpacing * 1.2;
      final int waves = ((endX - startX) / wavelength).floor();

      if (waves > 0) {
        path.moveTo(startX, lineY);
        double currentX = startX;
        for (int w = 0; w < waves; w++) {
          final nextX1 = currentX + wavelength * 0.5;
          path.quadraticBezierTo(currentX + wavelength * 0.25, lineY + amp, nextX1, lineY);
          currentX = nextX1;
          final nextX2 = currentX + wavelength * 0.5;
          path.quadraticBezierTo(currentX + wavelength * 0.25, lineY - amp, nextX2, lineY);
          currentX = nextX2;
        }
        canvas.drawPath(path, paint);
      }
      i = endIdx + 1;
    }
  }

  // ==========================================================================
  // v2c-114 : DYNAMIQUES (notations)
  // ==========================================================================

  void drawNoteDynamic(
    Canvas canvas,
    DynamicType type,
    String? text,
    double x,
    double staffTopY,
    bool above,
  ) {
    final double yPos =
        above ? staffTopY - staffLineSpacing * 3.0 : staffTopY + staffLineSpacing * 7.0;

    if (text != null && text.isNotEmpty) {
      final musicalGlyphs = DynamicGlyphs.resolveCustom(text);
      if (musicalGlyphs != null && musicalGlyphs.isNotEmpty) {
        _paintDynamicGlyphString(canvas, musicalGlyphs, x, yPos);
      } else {
        _paintDynamicTextFallback(canvas, text, x, yPos);
      }
      return;
    }

    if (type == DynamicType.none) return;

    final glyphs = DynamicGlyphs.resolve(type);
    if (glyphs == null || glyphs.isEmpty) return;

    _paintDynamicGlyphString(canvas, glyphs, x, yPos);
  }

  void _paintDynamicGlyphString(
    Canvas canvas,
    String glyphs,
    double x,
    double yCenter,
  ) {
    final fontSize = staffLineSpacing * 3.8;
    final tp = TextPainter(
      text: TextSpan(
        text: glyphs,
        style: MusicTextStyle.music(fontSize: fontSize, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, yCenter - tp.height / 2));
  }

  void _paintDynamicTextFallback(
    Canvas canvas,
    String text,
    double x,
    double yCenter,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Arial',
          fontFamilyFallback: const ['Roboto', 'sans-serif'],
          fontSize: staffLineSpacing * 3.0,
          color: Colors.black,
          fontStyle: FontStyle.italic,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, yCenter - tp.height / 2));
  }

  NotePainter copyWith({
    double? scale, double? staffLineSpacing, double? noteFontSize, double? stemLength,
    TextStyle? noteStyle, Paint? linePaint, Paint? beamPaint, Color? selectionColor,
    ExpressionPainter? expressionPainter,
  }) {
    return NotePainter(
      scale: scale ?? this.scale, staffLineSpacing: staffLineSpacing ?? this.staffLineSpacing,
      noteFontSize: noteFontSize ?? this.noteFontSize, stemLength: stemLength ?? this.stemLength,
      noteStyle: noteStyle ?? this.noteStyle, linePaint: linePaint ?? this.linePaint,
      beamPaint: beamPaint ?? this.beamPaint, selectionColor: selectionColor ?? this.selectionColor,
      expressionPainter: expressionPainter ?? this.expressionPainter,
    );
  }
}