// lib/renderer/beam_drawer.dart
// ============================================================================
// PAINTEUR DE LIGATURES (BEAMS) ET DRAPEAUX — v2c-94y
// ============================================================================
// v2c-94n : Agrandissement du drapeau des grâces (0.8) et ajustement
//           de son ancrage (X: -0.5, Y: 5.0 pour "descendre" sur la hampe).
// v2c-94y : migration vers StemDirectionResolver.shouldStemBeUp (fin de
//           la duplication — le resolver est maintenant l'unique source
//           de vérité pour la direction de hampe).
//           _diatonicDiff conservé (utilisé localement pour les accords).
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/events/music_event.dart';
import '../models/events/pitch.dart';
import '../models/enums/music_enums.dart';
import '../models/layout/layout_models.dart';
import '../services/smufl/smufl.dart';
import '../utils/music_text_style.dart';
import 'stem_anchor.dart';
import 'stem_direction_resolver.dart';   // v2c-94y

class BeamDrawer {
  final double scale;
  final double staffLineSpacing;
  final double stemLength;
  final Paint linePaint;
  final Paint beamPaint;

  BeamDrawer({
    required this.scale,
    required this.staffLineSpacing,
    required this.stemLength,
    required this.linePaint,
    required this.beamPaint,
  });

  static const double _hookLengthSp = 2.6;
  static const double _graceScale = 0.7;

  static StemAnchor _resolveAnchorFor(LayoutedNote note, bool stemUp) {
    if (note.event is! NoteEvent) {
      return const StemAnchor(xSp: 0.65, ySp: 0);
    }
    final anchor = StemAnchorResolver.forPitchOrEvent(
      note.pitch,
      note.event as NoteEvent,
      stemUp,
    );

    if (note.isGrace) {
      return StemAnchor(xSp: anchor.xSp * _graceScale, ySp: anchor.ySp * _graceScale);
    }
    return anchor;
  }

  // ==========================================================================
  // 1. LIGATURES (BEAMS) MULTI-NIVEAUX
  // ==========================================================================

  void drawBeamFromIndices(
    Canvas canvas,
    List<int> indices,
    LayoutedMeasure measure,
    List<Map<String, double>> positions, {
    String? selectedNoteId,
    double dragOffsetY = 0.0,
  }) {
    if (indices.length < 2) return;

    final List<double> xPos = [];
    final List<double> yPos = [];
    for (final idx in indices) {
      final note = measure.notes[idx];
      final double dy = (selectedNoteId != null && note.id == selectedNoteId)
          ? dragOffsetY
          : 0.0;
      xPos.add(positions[idx]['x']!);
      yPos.add(positions[idx]['y']! + dy);
    }

    final firstNote = measure.notes[indices.first];
    final double firstEffectiveYLine =
        _effectiveYLine(firstNote, positions[indices.first]['y']!, yPos.first);

    // v2c-94y : direction de hampe via StemDirectionResolver.
    final bool stemUp = StemDirectionResolver.shouldStemBeUp(
      firstNote,
      effectiveYLine: firstEffectiveYLine,
    );

    double primaryBeamY;
    {
      double extremeY = stemUp ? double.infinity : double.negativeInfinity;

      for (int i = 0; i < indices.length; i++) {
        final n = measure.notes[indices[i]];
        double startYLine = n.yLine;
        double extraSp = 0.0;

        double effectiveStemLength = n.isGrace ? stemLength * _graceScale : stemLength;

        if (n.event is NoteEvent) {
          final ne = n.event as NoteEvent;

          if (ne.pitches.length > 1) {
            final primary = ne.pitches.first;
            double minYL = n.yLine;
            double maxYL = n.yLine;
            for (final p in ne.pitches) {
              final int diff = _diatonicDiff(primary, p);
              final double yl = n.yLine - diff * 0.5;
              if (yl < minYL) minYL = yl;
              if (yl > maxYL) maxYL = yl;
            }
            startYLine = stemUp ? maxYL : minYL;
            extraSp += (maxYL - minYL) * staffLineSpacing;
          }

          if (ne.tremoloType != TremoloType.none) {
            if (ne.tremoloType == TremoloType.unmeasured) {
              extraSp += staffLineSpacing * 0.5;
            } else {
              final int cnt = ne.tremoloCount <= 0 ? 1 : ne.tremoloCount;
              final bool isBeamable = ne.durationType.isBeamable;
              final bool hasFlag = isBeamable && ne.beams.isEmpty;
              if (hasFlag) {
                extraSp +=
                    (1.8 + (cnt - 1) * 1.05 + 0.3) * staffLineSpacing;
              } else {
                extraSp += (cnt * 0.6 + 0.4) * staffLineSpacing;
              }
            }
          }
        }

        final double yOffsetSp = _resolveAnchorFor(n, stemUp).ySp;

        final double nStaffBaseY = yPos[i] - n.yLine * staffLineSpacing;
        final double startYPx = nStaffBaseY + startYLine * staffLineSpacing
            + yOffsetSp * staffLineSpacing;
        final double stemEndY = stemUp
            ? startYPx - effectiveStemLength - extraSp
            : startYPx + effectiveStemLength + extraSp;

        if (stemUp) {
          if (stemEndY < extremeY) extremeY = stemEndY;
        } else {
          if (stemEndY > extremeY) extremeY = stemEndY;
        }
      }

      primaryBeamY = extremeY;
    }

    final double beamThickness = _getBeamThickness(
      measure.notes[indices.first].event.durationType,
      isGrace: measure.notes[indices.first].isGrace,
    );
    final double levelGap = beamThickness + 2.0 * scale;

    int maxLevel = 1;
    for (final idx in indices) {
      final event = measure.notes[idx].event;
      if (event is NoteEvent) {
        for (final key in event.beams.keys) {
          if (key > maxLevel) maxLevel = key;
        }
      }
    }

    for (int i = 0; i < xPos.length; i++) {
      final note = measure.notes[indices[i]];
      final anchor = _resolveAnchorFor(note, stemUp);

      final double stemOffset = staffLineSpacing * anchor.xSp;
      final double stemX = stemUp ? xPos[i] + stemOffset : xPos[i] - stemOffset;
      final double stemStartY = yPos[i] + staffLineSpacing * anchor.ySp;

      canvas.drawLine(
        Offset(stemX, stemStartY),
        Offset(stemX, primaryBeamY),
        linePaint,
      );
    }

    for (int level = 1; level <= maxLevel; level++) {
      final double levelY = stemUp
          ? primaryBeamY + (level - 1) * levelGap
          : primaryBeamY - (level - 1) * levelGap;

      _drawBeamLevel(
        canvas: canvas,
        indices: indices,
        measure: measure,
        xPos: xPos,
        levelY: levelY,
        level: level,
        stemUp: stemUp,
        beamThickness: beamThickness,
      );
    }

    for (int i = 0; i < indices.length; i++) {
      final n = measure.notes[indices[i]];
      if (n.event is! NoteEvent) continue;
      final ne = n.event as NoteEvent;
      if (ne.tremoloType != TremoloType.single) continue;

      final double xSp = _resolveAnchorFor(n, stemUp).xSp;
      final double stemOffset = staffLineSpacing * xSp;
      final double stemX = stemUp
          ? xPos[i] + stemOffset
          : xPos[i] - stemOffset;

      _drawTremoloOnBeam(
        canvas: canvas,
        stemX: stemX,
        beamY: primaryBeamY,
        stemUp: stemUp,
        count: ne.tremoloCount,
        beamThickness: beamThickness,
      );
    }
  }

  void _drawTremoloOnBeam({
    required Canvas canvas,
    required double stemX,
    required double beamY,
    required bool stemUp,
    required int count,
    required double beamThickness,
  }) {
    if (count <= 0) return;

    final paint = Paint()..color = Colors.black;

    final double barWidth = staffLineSpacing * 1.75;
    final double barThickness = staffLineSpacing * 0.55;
    final double spacing = staffLineSpacing * 1.05;
    final double tiltRadians = stemUp ? -0.12 : 0.12;

    final double topMargin = staffLineSpacing * 0.65;

    final double beamInnerEdge = stemUp
        ? beamY + beamThickness
        : beamY - beamThickness;

    for (int i = 0; i < count; i++) {
      final double barCenterY = stemUp
          ? beamInnerEdge + topMargin + i * spacing
          : beamInnerEdge - topMargin - i * spacing;

      canvas.save();
      canvas.translate(stemX, barCenterY);
      canvas.rotate(tiltRadians);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: barWidth,
          height: barThickness,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawBeamLevel({
    required Canvas canvas,
    required List<int> indices,
    required LayoutedMeasure measure,
    required List<double> xPos,
    required double levelY,
    required int level,
    required bool stemUp,
    required double beamThickness,
  }) {
    int? segStart;

    for (int i = 0; i < indices.length; i++) {
      final event = measure.notes[indices[i]].event;
      final BeamType? beamType =
          (event is NoteEvent) ? event.beams[level] : null;

      switch (beamType) {
        case BeamType.start:
          if (segStart != null && i > segStart) {
            _drawBeamSegment(
              canvas, segStart, i - 1, indices, measure,
              xPos, levelY, stemUp, beamThickness,
            );
          }
          segStart = i;
          break;

        case BeamType.end:
          if (segStart != null) {
            _drawBeamSegment(
              canvas, segStart, i, indices, measure,
              xPos, levelY, stemUp, beamThickness,
            );
            segStart = null;
          }
          break;

        case BeamType.forwardHook:
          _drawHook(
            canvas: canvas,
            measure: measure,
            indices: indices,
            noteIndexInGroup: i,
            xPos: xPos,
            levelY: levelY,
            stemUp: stemUp,
            beamThickness: beamThickness,
            direction: _HookDirection.forward,
          );
          break;

        case BeamType.backwardHook:
          _drawHook(
            canvas: canvas,
            measure: measure,
            indices: indices,
            noteIndexInGroup: i,
            xPos: xPos,
            levelY: levelY,
            stemUp: stemUp,
            beamThickness: beamThickness,
            direction: _HookDirection.backward,
          );
          break;

        case BeamType.continue_:
        case BeamType.none:
        case BeamType.forward:
        case BeamType.backward:
        case null:
          break;
      }
    }

    if (segStart != null && segStart < indices.length - 1) {
      _drawBeamSegment(
        canvas, segStart, indices.length - 1, indices, measure,
        xPos, levelY, stemUp, beamThickness,
      );
    }
  }

  void _drawHook({
    required Canvas canvas,
    required LayoutedMeasure measure,
    required List<int> indices,
    required int noteIndexInGroup,
    required List<double> xPos,
    required double levelY,
    required bool stemUp,
    required double beamThickness,
    required _HookDirection direction,
  }) {
    if (noteIndexInGroup < 0 || noteIndexInGroup >= indices.length) return;

    final note = measure.notes[indices[noteIndexInGroup]];
    final double anchorXSp = _resolveAnchorFor(note, stemUp).xSp;

    final double stemX = stemUp
        ? xPos[noteIndexInGroup] + staffLineSpacing * anchorXSp
        : xPos[noteIndexInGroup] - staffLineSpacing * anchorXSp;

    final double hookLengthPx = _hookLengthSp * staffLineSpacing;

    _HookDirection effectiveDir = direction;
    if (direction == _HookDirection.forward &&
        noteIndexInGroup == indices.length - 1) {
      effectiveDir = _HookDirection.backward;
    } else if (direction == _HookDirection.backward &&
        noteIndexInGroup == 0) {
      effectiveDir = _HookDirection.forward;
    }

    final double leftX;
    final double rightX;
    switch (effectiveDir) {
      case _HookDirection.forward:
        leftX = stemX;
        rightX = stemX + hookLengthPx;
        break;
      case _HookDirection.backward:
        leftX = stemX - hookLengthPx;
        rightX = stemX;
        break;
    }

    if (rightX <= leftX) return;

    _drawSingleBeam(canvas, leftX, rightX, levelY, stemUp, beamThickness);
  }

  void _drawBeamSegment(
    Canvas canvas,
    int startIdx,
    int endIdx,
    List<int> indices,
    LayoutedMeasure measure,
    List<double> xPos,
    double levelY,
    bool stemUp,
    double beamThickness,
  ) {
    if (startIdx > endIdx) return;

    final double leftXSp =
        _resolveAnchorFor(measure.notes[indices[startIdx]], stemUp).xSp;
    final double rightXSp =
        _resolveAnchorFor(measure.notes[indices[endIdx]], stemUp).xSp;

    final double leftX = stemUp
        ? xPos[startIdx] + staffLineSpacing * leftXSp
        : xPos[startIdx] - staffLineSpacing * leftXSp;
    final double rightX = stemUp
        ? xPos[endIdx] + staffLineSpacing * rightXSp
        : xPos[endIdx] - staffLineSpacing * rightXSp;

    if (rightX <= leftX) return;

    _drawSingleBeam(canvas, leftX, rightX, levelY, stemUp, beamThickness);
  }

  void _drawSingleBeam(
    Canvas canvas,
    double leftX,
    double rightX,
    double beamY,
    bool stemUp,
    double beamThickness,
  ) {
    final path = Path()
      ..moveTo(leftX, beamY)
      ..lineTo(rightX, beamY)
      ..lineTo(rightX, beamY + (stemUp ? beamThickness : -beamThickness))
      ..lineTo(leftX, beamY + (stemUp ? beamThickness : -beamThickness))
      ..close();

    canvas.drawPath(path, beamPaint);
  }

  // ==========================================================================
  // 2. DRAPEAUX
  // ==========================================================================
  // ═══════════════════════════════════════════════════════════════════════════
// TODO(v2c-94y2) — DOUBLE HAMPE POTENTIELLE SUR LES GRÂCES
// ───────────────────────────────────────────────────────────────────────────
// Contexte : NotePainter.drawNote dessine TOUJOURS une hampe pour une note
// beâmable (y compris grâces), ET BeamDrawer.drawFlagFromIndex en redessine
// une par-dessus via flushBeamGroup sur indices.length == 1, pour y attacher
// le flag.
//
// Visuellement invisible quand les 2 longueurs coïncident :
//   - grâces mono-pitch (spanYLine = 0)  → 24a, 24d, 24e sont OK
//   - grâces beâmées (jamais de flag)     → 24b est OK
//
// Risque : si un futur test contient un ACCORD de grâces NON-beâmé
// (spanYLine > 0 + pas de <beam>), les 2 hampes pourraient diverger et
// laisser un "escalier" visible.
//
// Fix propre (si l'artefact apparaît) : passer un flag `skipStem` à
// NotePainter depuis StaffRenderer quand la note est dans un beam group
// OU quand un flag sera attaché — impossible actuellement car NotePainter
// ne sait pas si la note sera flushée seule ou en groupe (la décision est
// prise dans _drawNotesInMeasure APRÈS drawNote).
// ═══════════════════════════════════════════════════════════════════════════

  void drawFlagFromIndex(
    Canvas canvas,
    int index,
    LayoutedMeasure measure,
    List<Map<String, double>> positions, {
    String? selectedNoteId,
    double dragOffsetY = 0.0,
  }) {
    final note = measure.notes[index];
    final double xPx = positions[index]['x']!;

    final bool isDraggedNote =
        selectedNoteId != null && note.id == selectedNoteId;
    final double dy = isDraggedNote ? dragOffsetY : 0.0;
    final double yPx = positions[index]['y']! + dy;

    final double effectiveYLine =
        _effectiveYLine(note, positions[index]['y']!, yPx);

    // v2c-94y : direction de hampe via StemDirectionResolver.
    final bool stemUp = StemDirectionResolver.shouldStemBeUp(
      note,
      effectiveYLine: effectiveYLine,
    );

    double startYLine = note.yLine;
    double spanYLine = 0.0;
    double extraTremoloSp = 0.0;

    if (note.event is NoteEvent) {
      final ne = note.event as NoteEvent;
      if (ne.pitches.length > 1) {
        final primary = ne.pitches.first;
        double minYLine = note.yLine;
        double maxYLine = note.yLine;
        for (final p in ne.pitches) {
          final int diff = _diatonicDiff(primary, p);
          final double yl = note.yLine - diff * 0.5;
          if (yl < minYLine) minYLine = yl;
          if (yl > maxYLine) maxYLine = yl;
        }
        startYLine = stemUp ? maxYLine : minYLine;
        spanYLine = maxYLine - minYLine;
      }

      if (ne.tremoloType != TremoloType.none) {
        if (ne.tremoloType == TremoloType.unmeasured) {
          extraTremoloSp = 0.5;
        } else {
          final int cnt = ne.tremoloCount <= 0 ? 1 : ne.tremoloCount;
          final bool isBeamable = ne.durationType.isBeamable;
          final bool hasFlag = isBeamable && ne.beams.isEmpty;
          if (hasFlag) {
            extraTremoloSp = 1.8 + (cnt - 1) * 1.05 + 0.3;
          } else {
            extraTremoloSp = cnt * 0.6 + 0.4;
          }
        }
      }
    }

    final anchor = _resolveAnchorFor(note, stemUp);

    final double staffBaseY = yPx - note.yLine * staffLineSpacing;
    final double startYPx = staffBaseY + startYLine * staffLineSpacing
        + staffLineSpacing * anchor.ySp;

    // ═══════════════════════════════════════════════════════════════════════
    // v2c-94w : FIX FLAGS DES CHORDS DE GRÂCES (test W3C 24b).
    // ───────────────────────────────────────────────────────────────────────
    // AVANT : effectiveStemLength = base + span + tremolo.
    //         Pour un chord grace [B4, D5], ça donnait 17.64 + 7.2 = 24.84
    //         → le flag était dessiné 7.2 px (1 sp) AU-DESSUS du sommet réel
    //           de la hampe tracée par NotePainter (qui n'a que 17.64 px).
    //         Visuel : flag qui "flotte" au-dessus de la hampe.
    //
    // APRÈS : on aligne la logique sur celle de NotePainter.drawNote —
    //         max(base, span + marge) au lieu de base + span. Le flag tombe
    //         exactement au sommet de la hampe, comme en 24a (mono-pitch).
    //
    // ⚠ NE PAS appliquer ce fix à drawBeamFromIndices : pour les beams,
    //    la hampe DOIT être plus longue pour faire tenir les barres de
    //    croches/doubles sans mordre la portée. Le flag, lui, est un
    //    glyphe positionné au sommet réel de la hampe.
    // ═══════════════════════════════════════════════════════════════════════
    final double baseStemLength = note.isGrace ? stemLength * _graceScale : stemLength;
    final double spanPx = spanYLine * staffLineSpacing;
    final double requiredForChordPx = spanPx + 0.5 * staffLineSpacing;
    final double effectiveStemLength =
        math.max(baseStemLength, requiredForChordPx) +
        extraTremoloSp * staffLineSpacing;

    final double stemOffset = staffLineSpacing * anchor.xSp;
    final double stemX = stemUp ? xPx + stemOffset : xPx - stemOffset;
    final double stemYEnd = stemUp
        ? startYPx - effectiveStemLength
        : startYPx + effectiveStemLength;

    final String? flagGlyph = _getFlagGlyph(note.event.durationType, stemUp);
    if (flagGlyph == null) return;

    // v2c-94n : On agrandit un peu plus le drapeau des grâces (0.8)
    final double graceFlagScale = note.isGrace ? 0.8 : 1.0;
    final flagPainter = TextPainter(
      text: TextSpan(
        text: flagGlyph,
        style: MusicTextStyle.music(
          fontSize: staffLineSpacing * 4.0 * graceFlagScale,
          color: Colors.black,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Ajustements (X: -0.5 pour rapprocher, Y: 5.0 pour descendre)
    final double flagUpXAdjust   = -0.5;
    final double flagDownXAdjust = -0.5;
    final double flagUpYAdjust   = 5.0;
    final double flagDownYAdjust = -4.0;

    final double drawY = stemUp
        ? stemYEnd - flagPainter.height + (flagUpYAdjust * scale)
        : stemYEnd + (flagDownYAdjust * scale);

    final double drawX = stemUp
        ? stemX + (flagUpXAdjust * scale)
        : stemX - flagPainter.width + (flagDownXAdjust * scale);

    flagPainter.paint(canvas, Offset(drawX, drawY));
  }

  String? _getFlagGlyph(DurationType type, bool stemUp) {
    switch (type) {
      case DurationType.eighth:
        return Smufl.glyph(stemUp ? 'flag8thUp' : 'flag8thDown');
      case DurationType.sixteenth:
        return Smufl.glyph(stemUp ? 'flag16thUp' : 'flag16thDown');
      case DurationType.thirtySecond:
        return Smufl.glyph(stemUp ? 'flag32ndUp' : 'flag32ndDown');
      case DurationType.sixtyFourth:
        return Smufl.glyph(stemUp ? 'flag64thUp' : 'flag64thDown');
      case DurationType.oneHundredTwentyEighth:
        return Smufl.glyph(stemUp ? 'flag128thUp' : 'flag128thDown');
      case DurationType.twoHundredFiftySixth:
        return Smufl.glyph(stemUp ? 'flag256thUp' : 'flag256thDown');
      case DurationType.fiveHundredTwelfth:
        return Smufl.glyph(stemUp ? 'flag512thUp' : 'flag512thDown');
      case DurationType.oneThousandTwentyFourth:
        return Smufl.glyph(stemUp ? 'flag1024thUp' : 'flag1024thDown');
      default:
        return null;
    }
  }

  // ==========================================================================
  // 3. UTILITAIRES
  // ==========================================================================

  double _effectiveYLine(LayoutedNote note, double baseYPx, double currentYPx) {
    final double deltaPx = currentYPx - baseYPx;
    return note.yLine + deltaPx / staffLineSpacing;
  }

  double _getBeamThickness(DurationType type, {bool isGrace = false}) {
    double base = 3.0 * scale;
    if (type == DurationType.sixtyFourth) {
      base = 2.5 * scale;
    }
    return isGrace ? base * _graceScale : base;
  }

  static int _diatonicDiff(Pitch p1, Pitch p2) {
    int letterIdx(NoteLetter l) {
      switch (l) {
        case NoteLetter.C: return 0;
        case NoteLetter.D: return 1;
        case NoteLetter.E: return 2;
        case NoteLetter.F: return 3;
        case NoteLetter.G: return 4;
        case NoteLetter.A: return 5;
        case NoteLetter.B: return 6;
      }
    }
    final int d1 = p1.octave * 7 + letterIdx(p1.letter);
    final int d2 = p2.octave * 7 + letterIdx(p2.letter);
    return d2 - d1;
  }

  // ==========================================================================
  // 4. FLUSH
  // ==========================================================================

  void flushBeamGroup(
    Canvas canvas,
    List<int> indices,
    LayoutedMeasure measure,
    List<Map<String, double>> positions, {
    String? selectedNoteId,
    double dragOffsetY = 0.0,
  }) {
    if (indices.isEmpty) return;

    if (indices.length >= 2) {
      drawBeamFromIndices(
        canvas, indices, measure, positions,
        selectedNoteId: selectedNoteId,
        dragOffsetY: dragOffsetY,
      );
    } else if (indices.length == 1) {
      drawFlagFromIndex(
        canvas, indices.first, measure, positions,
        selectedNoteId: selectedNoteId,
        dragOffsetY: dragOffsetY,
      );
    }

    indices.clear();
  }

  // ==========================================================================
  // 5. COPY WITH
  // ==========================================================================

  BeamDrawer copyWith({
    double? scale,
    double? staffLineSpacing,
    double? stemLength,
    Paint? linePaint,
    Paint? beamPaint,
  }) {
    return BeamDrawer(
      scale: scale ?? this.scale,
      staffLineSpacing: staffLineSpacing ?? this.staffLineSpacing,
      stemLength: stemLength ?? this.stemLength,
      linePaint: linePaint ?? this.linePaint,
      beamPaint: beamPaint ?? this.beamPaint,
    );
  }
}

// ============================================================================
// v2c-93z : ÉNUMÉRATION INTERNE POUR LA DIRECTION DES HOOKS
// ============================================================================

enum _HookDirection { forward, backward }