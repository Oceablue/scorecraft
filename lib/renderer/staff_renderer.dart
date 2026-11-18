// lib/renderer/staff_renderer.dart
// ============================================================================
// RENDU PRINCIPAL DE LA PARTITION — v2c-114-32e
// ============================================================================
// v2c-114 : Réservation de l'espace vertical pour les dynamiques de notation
//           (pour que les paroles soient poussées plus bas) + passage de
//           `staffTopY` à `drawNoteDynamic` (au lieu de `yPx`) pour que les
//           dynamiques soient toujours placées 3 espaces sous la portée.
// v2c-32d : Arpeggios PARTIELS + directions (test W3C 32d).
//           Le span (yTop/yBottom) est calculé à partir des pitchIndex
//           porteurs du marqueur, pas de l'accord entier.
// v2c-32e : Arpèges CROSS-STAFF et CROSS-VOICE (test W3C 32e).
//           Le dessin est DIFFÉRÉ au niveau SYSTÈME : on collecte des
//           ancres (_ArpeggioAnchor), puis on les groupe par
//           (timePosition, number) pour n'en dessiner qu'un seul span.
//           Rétrocompatible avec 32d : chaque chord reste dans son propre
//           groupe (tp identique, number=1 par défaut).
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/layout/layout_models.dart';
import '../models/score/score_document.dart';
import '../models/events/music_event.dart';
import '../models/enums/music_enums.dart';
import '../services/layout/layout_engine.dart';
import '../services/smufl/smufl.dart';
import '../utils/constants.dart';
import '../utils/music_text_style.dart';
import 'stem_direction_resolver.dart';
import 'painters/structure_painter.dart';
import 'painters/note_painter.dart';
import 'painters/expression_painter.dart';
import 'painters/direction_painter.dart';
import 'painters/lyric_painter.dart';
import 'painters/tuplet_painter.dart';
import 'painters/barline_painter.dart';
import 'painters/connection_painter.dart';
import 'beam_drawer.dart';

class StaffRenderer {
  static final List<_NotePosition> _lastPositions = [];
  static const Color _selectionColor = Color(0xFF4A90D9);

  static void drawScore(
    Canvas canvas,
    ScoreDocument document,
    List<LayoutedSystem> systems, {
    LayoutedNote? selectedNote,
    double? dragOffsetY,
  }) {
    _lastPositions.clear();

    final pageLayout = document.pageLayout;
    const double scale = ScoreCraftConstants.scale;
    const double staffLineSpacing = ScoreCraftConstants.staffLineSpacing;

    final double noteFontSize = staffLineSpacing * 4.3;
    final double clefFontSize = staffLineSpacing * 4.5;
    final double timeSigFontSize = staffLineSpacing * 2.8;
    final double stemLength = ScoreCraftConstants.stemLength;

    final double marginLeft = pageLayout.marginLeft;

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final beamPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final noteStyle = MusicTextStyle.music(fontSize: noteFontSize, color: Colors.black);
    final clefStyle = MusicTextStyle.music(fontSize: clefFontSize, color: Colors.black);
    final timeSigStyle = MusicTextStyle.music(fontSize: timeSigFontSize, color: Colors.black, fontWeight: FontWeight.bold);

    final structurePainter = StructurePainter(
      scale: scale,
      staffLineSpacing: staffLineSpacing,
      clefStyle: clefStyle,
      timeSigStyle: timeSigStyle,
      linePaint: linePaint,
    );

    final expressionPainter = ExpressionPainter(
      lineSpacing: staffLineSpacing,
      color: Colors.black,
      strokeWidth: 1.8,
      defaultSlurHeight: 2.0,
    );

    final beamDrawer = BeamDrawer(
      scale: scale,
      staffLineSpacing: staffLineSpacing,
      stemLength: stemLength,
      linePaint: linePaint,
      beamPaint: beamPaint,
    );

    final notePainter = NotePainter(
      scale: scale,
      staffLineSpacing: staffLineSpacing,
      noteFontSize: noteFontSize,
      stemLength: stemLength,
      noteStyle: noteStyle,
      linePaint: linePaint,
      beamPaint: beamPaint,
      selectionColor: _selectionColor,
      expressionPainter: expressionPainter,
    );

    final directionPainter = DirectionPainter(lineSpacing: staffLineSpacing);
    final lyricPainter = LyricPainter(lineSpacing: staffLineSpacing);
    final tupletPainter = TupletPainter(lineSpacing: staffLineSpacing);

    final anchors = <String, NoteAnchor>{};
    final pitchAnchors = <String, NoteAnchor>{};

    for (int sysIdx = 0; sysIdx < systems.length; sysIdx++) {
      final system = systems[sysIdx];
      if (system.staves.isEmpty) continue;
      final bool isFirstSystem = sysIdx == 0;

      // v2c-32e : ancres d'arpège collectées pour CE système
      final systemArpeggioAnchors = <_ArpeggioAnchor>[];

      final double indent = isFirstSystem ? LayoutEngine.firstSystemIndent : 0.0;
      final double staffLineStartX = marginLeft + indent;

      for (final layoutedStaff in system.staves) {
        _drawStaffLinesForStaff(
          canvas: canvas,
          layoutedStaff: layoutedStaff,
          structurePainter: structurePainter,
          staffLineStartX: staffLineStartX,
          marginLeft: marginLeft,
        );
      }

      _drawStartBlock(
        canvas: canvas,
        document: document,
        system: system,
        marginLeft: marginLeft,
        scale: scale,
        structurePainter: structurePainter,
        isFirstSystem: isFirstSystem,
      );

      // ══════════════════════════════════════════════════════════════════════
      // v2c-107 : Calcul du point le plus bas GLOBAL pour chaque portée
      // ══════════════════════════════════════════════════════════════════════
      final Map<int, double> staffRealBottomY = {};
      for (final ls in system.staves) {
        final double staffBottom = ls.yTopLine + (ls.lineCount - 1) * ls.lineSpacing;
        double maxVisualYLine = (ls.lineCount - 1).toDouble();

        for (final m in ls.measures) {
          for (final n in m.notes) {
            if (n.isRest) continue;

            double noteBottomYLine = n.yLine;

            // Hampes vers le bas
            if (n.event.durationType.needsStem) {
              final stemUp = StemDirectionResolver.shouldStemBeUp(n);
              if (!stemUp) noteBottomYLine += ScoreCraftConstants.stemLengthFactor;
            }

            if (n.event is NoteEvent) {
              final ne = n.event as NoteEvent;

              for (final art in ne.articulations) {
                final isBelow = art.placement == 'below' || (art.placement == null && !StemDirectionResolver.shouldStemBeUp(n));
                if (isBelow) noteBottomYLine += 2.0;
              }
              
              // v2c-32f : Fermata overhang
              for (final f in ne.notations.fermatas) {
                final isInverted = f.type == 'inverted';
                if (isInverted) noteBottomYLine += 3.0;
              }

              for (final m in ne.notations.accidentalMarks) {
                if (m.placement == 'below') noteBottomYLine += 2.5;
              }

              // v2c-114 : Prise en compte des dynamiques
              final otherDyn = ne.rawNotations['other-dynamics'];
              final hasStdDyn = ne.dynamicMark != DynamicType.none;
              final hasCustomDyn = otherDyn != null && otherDyn.isNotEmpty;
              if (hasStdDyn || hasCustomDyn) {
                final double dynBottomYLine = (ls.lineCount - 1) + 5.0;
                if (dynBottomYLine > noteBottomYLine) noteBottomYLine = dynBottomYLine;
              }

              // v2c-107 : Prise en compte des techniques en bas
              final textTypes = ['fingering', 'pluck', 'fret', 'string'];
              int belowTechsCount = 0;
              for (final tech in ne.notations.technicals) {
                final isBelow = tech.placement == 'below' ||
                                (tech.placement != 'above' && StemDirectionResolver.shouldStemBeUp(n));
                if (isBelow) {
                  if (textTypes.contains(tech.type)) {
                    if (belowTechsCount == 0) belowTechsCount++;
                  } else {
                    belowTechsCount++;
                  }
                }
              }
              if (belowTechsCount > 0) {
                noteBottomYLine += (3.2 + (belowTechsCount - 1) * 2.8);
              }
            }

            if (noteBottomYLine > maxVisualYLine) maxVisualYLine = noteBottomYLine;
          }
        }

        staffRealBottomY[ls.globalStaffIndex] = math.max(staffBottom, ls.yTopLine + maxVisualYLine * ls.lineSpacing);
      }

      final firstStaff = system.staves.first;
      final measureCount = firstStaff.measures.length;

      for (int measureIdx = 0; measureIdx < measureCount; measureIdx++) {
        final firstMeasureOfColumn = firstStaff.measures[measureIdx];
        final measureAbsoluteX = marginLeft + firstMeasureOfColumn.x;

        for (final layoutedStaff in system.staves) {
          if (measureIdx >= layoutedStaff.measures.length) continue;
          final measure = layoutedStaff.measures[measureIdx];

          final bool isFirstMeasureOfSystem = measureIdx == 0;
          if (!isFirstMeasureOfSystem) {
            if (measure.source.clef != null) {
              const double clefGlyphWidth = 20.0;
              final double barlineX = marginLeft + measure.x;
              final double clefX = barlineX - clefGlyphWidth - 2;
              structurePainter.drawClef(canvas, measure.source.clef!, clefX, layoutedStaff.yTopLine);
            }

            double cursorX = marginLeft + measure.x + 4;
            final int idx = _findStaffIndex(document, layoutedStaff.globalStaffIndex) ?? 0;
            final ClefType staffClef = idx < document.staves.length ? document.staves[idx].clef : ClefType.treble;

            final keySig = measure.source.keySignature;
            final cancel = keySig.cancel;

            if (cancel != null && cancel.location != 'right') {
              if (cancel.location == 'before-barline') {
                final double cancelW = structurePainter.keyCancelWidth(cancel);
                structurePainter.drawKeyCancel(canvas, marginLeft + measure.x - cancelW - 4, layoutedStaff.yTopLine, cancel, staffClef);
              } else {
                final double cancelW = structurePainter.drawKeyCancel(canvas, cursorX, layoutedStaff.yTopLine, cancel, staffClef);
                cursorX += cancelW + 4.0;
              }
            }

            if (measure.source.showKeySignature && (keySig.fifths != 0 || keySig.isCustom)) {
              structurePainter.drawKeySignature(canvas, cursorX, layoutedStaff.yTopLine, keySig, staffClef);
              final int count = keySig.alterationCount.clamp(0, 7);
              cursorX += count * ScoreCraftConstants.staffLineSpacing * 1.375 + 8.0;
            }

            if (cancel != null && cancel.location == 'right') {
              final double cancelW = structurePainter.drawKeyCancel(canvas, cursorX, layoutedStaff.yTopLine, cancel, staffClef);
              cursorX += cancelW + 4.0;
            }

            if (measure.source.showTimeSignature) {
              final ts = measure.source.timeSignature;
              switch (ts.display) {
                case TimeSignatureType.common:
                  structurePainter.drawTimeSignatureSymbol(canvas, 'common', cursorX, layoutedStaff.yTopLine); break;
                case TimeSignatureType.cut:
                  structurePainter.drawTimeSignatureSymbol(canvas, 'cut', cursorX, layoutedStaff.yTopLine); break;
                case TimeSignatureType.standard:
                  structurePainter.drawTimeSignature(canvas, ts.beats, ts.beatType, cursorX, layoutedStaff.yTopLine, beatGroups: ts.beatGroups, fractions: ts.fractions, interchangeable: ts.interchangeable); break;
                case TimeSignatureType.singleNumber:
                  structurePainter.drawTimeSignature(canvas, ts.beats, ts.beatType, cursorX, layoutedStaff.yTopLine, beatGroups: ts.beatGroups, fractions: ts.fractions, singleNumber: true, interchangeable: ts.interchangeable); break;
                case TimeSignatureType.senzaMisura:
                  if (ts.senzaMisuraText != null) structurePainter.drawSenzaMisuraText(canvas, ts.senzaMisuraText!, cursorX, layoutedStaff.yTopLine); break;
              }
            }
          }

          if (measure.source.midMeasureKeyChanges.isNotEmpty) {
            for (final kc in measure.source.midMeasureKeyChanges) {
              LayoutedNote? anchorNote;
              for (final n in measure.notes) {
                if (n.timePosition >= kc.timePosition) { anchorNote = n; break; }
              }
              if (anchorNote == null) continue;

              final int idxS = _findStaffIndex(document, layoutedStaff.globalStaffIndex) ?? 0;
              final ClefType staffClef = idxS < document.staves.length ? document.staves[idxS].clef : ClefType.treble;

              double kcX = marginLeft + measure.x + anchorNote.x;
              final keySigMid = kc.keySignature;
              final cancelMid = keySigMid.cancel;

              double cancelW = 0.0;
              if (cancelMid != null) cancelW = structurePainter.keyCancelWidth(cancelMid);
              final ksW = keySigMid.alterationCount * ScoreCraftConstants.staffLineSpacing * 1.375 + 8.0;
              kcX -= (cancelW + ksW + 8.0);

              double drawX = kcX;
              if (cancelMid != null) {
                structurePainter.drawKeyCancel(canvas, drawX, layoutedStaff.yTopLine, cancelMid, staffClef);
                drawX += cancelW;
              }
              structurePainter.drawKeySignature(canvas, drawX, layoutedStaff.yTopLine, keySigMid, staffClef);
            }
          }

          _drawNotesInMeasure(
            canvas: canvas,
            measure: measure,
            measureStartX: marginLeft + measure.x,
            staffTopY: layoutedStaff.yTopLine,
            staffIndex: layoutedStaff.globalStaffIndex,
            systemIndex: sysIdx,
            anchors: anchors,
            pitchAnchors: pitchAnchors,
            notePainter: notePainter,
            beamDrawer: beamDrawer,
            directionPainter: directionPainter,
            lyricPainter: lyricPainter,
            tupletPainter: tupletPainter,
            selectedNote: selectedNote,
            dragOffsetY: dragOffsetY,
            stemLength: stemLength,
            staffRealBottomY: staffRealBottomY[layoutedStaff.globalStaffIndex] ?? layoutedStaff.yTopLine,
            systemArpeggioAnchors: systemArpeggioAnchors, // v2c-32e
          );
        }

        if (measureIdx < measureCount - 1) {
          final currentMeasure = firstStaff.measures[measureIdx];
          final barX = measureAbsoluteX + firstMeasureOfColumn.finalWidth;
          BarlinePainter.drawBarlineWithType(
            canvas: canvas,
            x: barX,
            system: system,
            type: currentMeasure.endBarline ?? currentMeasure.source.rightBarline,
          );
        }
      }

      if (firstStaff.measures.isNotEmpty) {
        final lastMeasure = firstStaff.measures.last;
        final lastBarX = marginLeft + lastMeasure.x + lastMeasure.finalWidth;
        final barType = lastMeasure.endBarline ?? lastMeasure.source.rightBarline;

        if (barType.isFinal) {
          BarlinePainter.drawBarlineWithType(canvas: canvas, x: lastBarX, system: system, type: BarlineType.lightHeavy);
        } else {
          BarlinePainter.drawBarlineWithType(canvas: canvas, x: lastBarX, system: system, type: barType);
        }
      }

      final List<List<LayoutedStaff>> partGroups = [];
      for (final ls in system.staves) {
        if (partGroups.isEmpty ||
            partGroups.last.first.partId != ls.partId) {
          partGroups.add([ls]);
        } else {
          partGroups.last.add(ls);
        }
      }

      for (final group in partGroups) {
        if (group.length < 2) continue;

        final double staffTopY = group.first.yTopLine;
        final lastStaff = group.last;
        final double staffBottomY =
            lastStaff.yTopLine + (lastStaff.lineCount - 1) * lastStaff.lineSpacing;
        const double bracePadding = 4.0;
        final double braceRightX =
            marginLeft + (isFirstSystem ? LayoutEngine.firstSystemIndent : 0) - 4;
        structurePainter.drawBrace(
          canvas,
          braceRightX,
          staffTopY - bracePadding,
          staffBottomY + bracePadding,
        );
      }

      // v2c-32e : dessine tous les arpèges du système (groupés par tp+number)
      _drawSystemArpeggios(canvas, systemArpeggioAnchors, notePainter);
    }

    final connectionPainter = ConnectionPainter(
      expressionPainter: expressionPainter,
      anchors: anchors,
      pitchAnchors: pitchAnchors,
    );
    connectionPainter.drawConnections(canvas: canvas, document: document);
  }
  static void _drawStaffLinesForStaff({
    required Canvas canvas,
    required LayoutedStaff layoutedStaff,
    required StructurePainter structurePainter,
    required double staffLineStartX,
    required double marginLeft,
  }) {
    if (layoutedStaff.measures.isEmpty) {
      structurePainter.drawStaffLines(canvas, staffLineStartX, layoutedStaff.lineCount > 0 ? 200.0 : 0.0, layoutedStaff.yTopLine, lineCount: layoutedStaff.lineCount);
      return;
    }

    final double staffTopY = layoutedStaff.yTopLine;
    final List<LayoutedMeasure> measures = layoutedStaff.measures;

    if (measures.isNotEmpty) {
      final LayoutedMeasure firstMeasure = measures.first;
      final double firstMeasureStartX = marginLeft + firstMeasure.x;
      final double preMeasureWidth = firstMeasureStartX - staffLineStartX;
      if (preMeasureWidth > 0.1) {
        structurePainter.drawStaffLines(canvas, staffLineStartX, preMeasureWidth, staffTopY, lineCount: firstMeasure.staffLineCount, hiddenLines: firstMeasure.hiddenLines);
      }
    }

    for (int mIdx = 0; mIdx < measures.length; mIdx++) {
      final LayoutedMeasure measure = measures[mIdx];
      final double measureStartX = marginLeft + measure.x;
      final double measureEndX = measureStartX + measure.finalWidth;

      if (measure.midMeasureStaffLineChanges.isEmpty) {
        structurePainter.drawStaffLines(canvas, measureStartX, measure.finalWidth, staffTopY, lineCount: measure.staffLineCount, hiddenLines: measure.hiddenLines);
        continue;
      }

      double segStartX = measureStartX;
      int currentLineCount = measure.staffLineCount;

      for (final change in measure.midMeasureStaffLineChanges) {
        double segEndX = measureEndX;
        for (final n in measure.notes) {
          if (n.timePosition >= change.timePosition) { segEndX = measureStartX + n.x; break; }
        }
        final double segWidth = segEndX - segStartX;
        if (segWidth > 0.1) {
          structurePainter.drawStaffLines(canvas, segStartX, segWidth, staffTopY, lineCount: currentLineCount, hiddenLines: measure.hiddenLines);
        }
        segStartX = segEndX;
        currentLineCount = change.lineCount;
      }
      final double segWidth = measureEndX - segStartX;
      if (segWidth > 0.1) {
        structurePainter.drawStaffLines(canvas, segStartX, segWidth, staffTopY, lineCount: currentLineCount, hiddenLines: measure.hiddenLines);
      }
    }
  }

  static void _drawStartBlock({
    required Canvas canvas,
    required ScoreDocument document,
    required LayoutedSystem system,
    required double marginLeft,
    required double scale,
    required StructurePainter structurePainter,
    required bool isFirstSystem,
  }) {
    final double indent = isFirstSystem ? LayoutEngine.firstSystemIndent : 0.0;
    double x = marginLeft + 4 + indent;

    for (final layoutedStaff in system.staves) {
      final idx = _findStaffIndex(document, layoutedStaff.globalStaffIndex);
      if (idx == null) continue;
      final staff = document.staves[idx];

      ClefType effectiveClef = staff.clef;
      if (layoutedStaff.measures.isNotEmpty) {
        final firstMeasureOfSystem = layoutedStaff.measures.first;
        final String targetMeasureId = firstMeasureOfSystem.source.id;
        ClefType running = staff.clef;
        for (final m in staff.measures) {
          if (m.clef != null) running = m.clef!;
          if (m.id == targetMeasureId) break;
        }
        effectiveClef = running;
      }
      structurePainter.drawClef(canvas, effectiveClef, x, layoutedStaff.yTopLine);
    }
    x += 26 * scale + 4;

    final firstMeasure = system.staves.first.measures.isNotEmpty ? system.staves.first.measures.first.source : null;

    if (firstMeasure != null && (firstMeasure.keySignature.fifths != 0 || firstMeasure.keySignature.isCustom || firstMeasure.keySignature.cancel != null)) {
      for (final layoutedStaff in system.staves) {
        final idx = _findStaffIndex(document, layoutedStaff.globalStaffIndex);
        if (idx == null) continue;
        final staff = document.staves[idx];
        final keySig = firstMeasure.keySignature;
        final cancel = keySig.cancel;

        if (cancel != null && cancel.location != 'right') {
          final double cancelW = structurePainter.drawKeyCancel(canvas, x, layoutedStaff.yTopLine, cancel, staff.clef);
          x += cancelW + 4.0;
        }
        structurePainter.drawKeySignature(canvas, x, layoutedStaff.yTopLine, keySig, staff.clef);
      }

      final int displayCount = firstMeasure.keySignature.alterationCount.clamp(0, 7);
      x += 16 * scale * displayCount;

      final cancelAfter = firstMeasure.keySignature.cancel;
      if (cancelAfter != null && cancelAfter.location == 'right') {
        for (final layoutedStaff in system.staves) {
          final idx = _findStaffIndex(document, layoutedStaff.globalStaffIndex);
          if (idx == null) continue;
          final staff = document.staves[idx];
          structurePainter.drawKeyCancel(canvas, x, layoutedStaff.yTopLine, cancelAfter, staff.clef);
        }
        x += structurePainter.keyCancelWidth(cancelAfter) + 4.0;
      }
    }

    for (final layoutedStaff in system.staves) {
      if (layoutedStaff.measures.isEmpty) continue;
      final firstMeasureOfStaff = layoutedStaff.measures.first.source;
      if (!firstMeasureOfStaff.showTimeSignature) continue;

      final ts = firstMeasureOfStaff.timeSignature;
      switch (ts.display) {
        case TimeSignatureType.common:
          structurePainter.drawTimeSignatureSymbol(canvas, 'common', x, layoutedStaff.yTopLine); break;
        case TimeSignatureType.cut:
          structurePainter.drawTimeSignatureSymbol(canvas, 'cut', x, layoutedStaff.yTopLine); break;
        case TimeSignatureType.standard:
          structurePainter.drawTimeSignature(canvas, ts.beats, ts.beatType, x, layoutedStaff.yTopLine, beatGroups: ts.beatGroups, fractions: ts.fractions, interchangeable: ts.interchangeable); break;
        case TimeSignatureType.singleNumber:
          structurePainter.drawTimeSignature(canvas, ts.beats, ts.beatType, x, layoutedStaff.yTopLine, beatGroups: ts.beatGroups, fractions: ts.fractions, singleNumber: true, interchangeable: ts.interchangeable); break;
        case TimeSignatureType.senzaMisura:
          if (ts.senzaMisuraText != null) structurePainter.drawSenzaMisuraText(canvas, ts.senzaMisuraText!, x, layoutedStaff.yTopLine); break;
      }
    }
  }

  static void _drawNotesInMeasure({
    required Canvas canvas,
    required LayoutedMeasure measure,
    required double measureStartX,
    required double staffTopY,
    required int staffIndex,
    required int systemIndex,
    required Map<String, NoteAnchor> anchors,
    required Map<String, NoteAnchor> pitchAnchors,
    required NotePainter notePainter,
    required BeamDrawer beamDrawer,
    required DirectionPainter directionPainter,
    required LyricPainter lyricPainter,
    required TupletPainter tupletPainter,
    required LayoutedNote? selectedNote,
    required double? dragOffsetY,
    required double stemLength,
    required double staffRealBottomY,
    required List<_ArpeggioAnchor> systemArpeggioAnchors, // v2c-32e
  }) {
    final lineSpacing = ScoreCraftConstants.staffLineSpacing;

    if (measure.isMultiRestBar) {
      notePainter.drawMultiMeasureRest(canvas: canvas, count: measure.multiRestCount, x: measureStartX, measureWidth: measure.finalWidth, staffTopY: staffTopY);
      return;
    }

    final notePositions = <Map<String, double>>[];
    for (final note in measure.notes) {
      final xPx = measureStartX + note.x;
      final yPx = staffTopY + note.yLine * lineSpacing;
      notePositions.add({'x': xPx, 'y': yPx});
      _lastPositions.add(_NotePosition(note, Offset(xPx, yPx)));

      if (!note.isChordMember && !note.isRest) {
        anchors[note.eventId] = NoteAnchor(note: note, x: xPx, y: yPx, staffIndex: staffIndex, systemIndex: systemIndex);
      }
      if (!note.isRest) {
        pitchAnchors[note.id] = NoteAnchor(note: note, x: xPx, y: yPx, staffIndex: staffIndex, systemIndex: systemIndex);
      }
    }

    final beamGroupIndices = <int>[];

    for (int j = 0; j < measure.notes.length; j++) {
      final layoutedNote = measure.notes[j];
      final xPx = notePositions[j]['x']!;
      final yPx = notePositions[j]['y']!;

      if (beamGroupIndices.isNotEmpty) {
        final lastIdx = beamGroupIndices.last;
        final lastVoice = measure.notes[lastIdx].voiceIndex;
        if (lastVoice != layoutedNote.voiceIndex) {
          beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
        }
      }

      if (layoutedNote.isRest) {
        notePainter.drawRest(canvas, layoutedNote, xPx, yPx);

        if (layoutedNote.event is RestEvent) {
          final restEvent = layoutedNote.event as RestEvent;
          if (restEvent.notations.fermatas.isNotEmpty) {
            notePainter.drawFermatas(
              canvas, restEvent.notations.fermatas, xPx, yPx, staffTopY, staffRealBottomY,
            );
          }
        }

        if (beamGroupIndices.isNotEmpty) {
          beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
        }
        continue;
      }

      final isSelected = selectedNote != null && selectedNote.id == layoutedNote.id;

      notePainter.drawNote(
        canvas: canvas, note: layoutedNote, xPx: xPx, yPx: yPx, staffBaseY: staffTopY,
        isSelected: isSelected, dragOffsetY: dragOffsetY, slashNotation: measure.slashNotation,
      );

      if (layoutedNote.event is NoteEvent) {
        final noteEvent = layoutedNote.event as NoteEvent;

        if (!layoutedNote.isChordMember) {
          if (noteEvent.articulations.isNotEmpty) {
            final stemUp = StemDirectionResolver.shouldStemBeUp(layoutedNote);
            final autoAbove = !stemUp;
            notePainter.drawArticulations(canvas, noteEvent.articulations, xPx, yPx, staffTopY, autoAbove: autoAbove);
          }

          if (noteEvent.notations.fermatas.isNotEmpty) {
            notePainter.drawFermatas(
              canvas, noteEvent.notations.fermatas, xPx, yPx, staffTopY, staffRealBottomY,
            );
          }

          final stemUp = StemDirectionResolver.shouldStemBeUp(layoutedNote);
          final autoAbove = !stemUp;
          int currentAbove = 0;
          int currentBelow = 0;
          bool isAbove(String placement) => placement == 'above' || (placement != 'below' && autoAbove);

          // 1. Ornements
          int ornAbove = 0, ornBelow = 0;
          for (final o in noteEvent.notations.ornaments) {
            if (o.type != 'wavy-line') { if (isAbove(o.placement)) {
              ornAbove++;
            } else {
              ornBelow++;
            } }
          }
          if (noteEvent.notations.ornaments.isNotEmpty) {
            notePainter.drawOrnaments(
              canvas, noteEvent.notations.ornaments, xPx, yPx, staffTopY, autoAbove,
              startAboveStack: 0, startBelowStack: 0,
            );
            currentAbove += ornAbove; currentBelow += ornBelow;
          }

          // 2. Technicals
          int techAbove = 0, techBelow = 0;
          for (final t in noteEvent.notations.technicals) {
            if (isAbove(t.placement)) {
              techAbove++;
            } else {
              techBelow++;
            }
          }
          if (noteEvent.notations.technicals.isNotEmpty) {
            notePainter.drawTechnicals(
              canvas, noteEvent.notations.technicals, xPx, yPx, staffTopY, autoAbove,
              startAboveStack: currentAbove, startBelowStack: currentBelow,
            );

            final textTypes = ['fingering', 'pluck', 'fret', 'string', 'hammer-on', 'pull-off', 'bend'];
            int glyphTechsAbove = noteEvent.notations.technicals.where((t) => !textTypes.contains(t.type) && isAbove(t.placement)).length;
            int textTechsAbove = noteEvent.notations.technicals.any((t) => textTypes.contains(t.type) && isAbove(t.placement)) ? 1 : 0;
            int glyphTechsBelow = noteEvent.notations.technicals.where((t) => !textTypes.contains(t.type) && !isAbove(t.placement)).length;
            int textTechsBelow = noteEvent.notations.technicals.any((t) => textTypes.contains(t.type) && !isAbove(t.placement)) ? 1 : 0;

            currentAbove += (glyphTechsAbove + textTechsAbove);
            currentBelow += (glyphTechsBelow + textTechsBelow);
          }

          // 3. Accidental Marks
          if (noteEvent.notations.accidentalMarks.isNotEmpty) {
            for (final mark in noteEvent.notations.accidentalMarks) {
              final markIsAbove = isAbove(mark.placement);
              final stackIdx = markIsAbove ? currentAbove : currentBelow;
              final double yOffset = (lineSpacing * 3.2) + (stackIdx * lineSpacing * 2.8);
              final double accY = markIsAbove ? yPx - yOffset : yPx + yOffset;

              String glyphName = 'accidentalNatural';
              if (mark.type == 'double-sharp') {glyphName = 'accidentalSharpSharp';}
              else if (mark.type == 'flat') {glyphName = 'accidentalFlat';}
              else if (mark.type == 'sharp') {glyphName = 'accidentalSharp';}
              else if (mark.type == 'natural') {glyphName = 'accidentalNatural';}
              else if (mark.type == 'three-quarters-flat') {glyphName = 'accidentalThreeQuarterTonesFlatZimmermann';}

              final accPainter = TextPainter(
                text: TextSpan(text: Smufl.glyph(glyphName), style: MusicTextStyle.music(fontSize: lineSpacing * 3.5, color: Colors.black, height: 1.0)),
                textDirection: TextDirection.ltr,
              )..layout();

              accPainter.paint(canvas, Offset(xPx - accPainter.width / 2, accY - accPainter.height / 2));
              if (markIsAbove) {
                currentAbove++;
              } else {
                currentBelow++;
              }
            }
          }

          // ══════════════════════════════════════════════════════════════════
          // 4. v2c-114 : DYNAMIQUES (notations)
          // ──────────────────────────────────────────────────────────────────
          // On passe `staffTopY` pour que les dynamiques soient positionnées
          // par rapport à la portée et non par rapport au pitch de la note.
          // ══════════════════════════════════════════════════════════════════
          final otherDyn = noteEvent.rawNotations['other-dynamics'];
          final bool hasStandardDyn = noteEvent.dynamicMark != DynamicType.none;
          final bool hasCustomDyn = otherDyn != null && otherDyn.isNotEmpty;

          if (hasStandardDyn || hasCustomDyn) {
            notePainter.drawNoteDynamic(
              canvas,
              hasStandardDyn ? noteEvent.dynamicMark : DynamicType.none,
              hasCustomDyn ? otherDyn : null,
              xPx,
              staffTopY, // <--- v2c-114 : changement clé ici
              false,
            );
          }
        }

        // ══════════════════════════════════════════════════════════════════════
        // v2c-32e : COLLECTE des ancres d'arpège (au lieu de dessiner)
        // ══════════════════════════════════════════════════════════════════════
        // Le dessin est DIFFÉRÉ au niveau SYSTÈME via _drawSystemArpeggios,
        // pour permettre les arpèges cross-staff et cross-voice (test 32e).
        // Rétrocompatible avec 32d : chaque chord forme son propre groupe
        // (même tp, même number par défaut = 1), et le span reste celui des
        // pitches porteurs du marqueur.
        if (noteEvent.notations.arpeggiates.isNotEmpty && !layoutedNote.isChordMember) {
          final double chordXPx = measureStartX + layoutedNote.x;

          for (final arp in noteEvent.notations.arpeggiates) {
            // Trouve le LayoutedNote correspondant à ce pitchIndex
            for (final n in measure.notes) {
              if (n.eventId != layoutedNote.eventId || n.isRest) continue;
              final pi = _extractPitchIndex(n.id, layoutedNote.eventId);
              if (pi != arp.pitchIndex) continue;

              final double nyPx = staffTopY + n.yLine * lineSpacing;
              systemArpeggioAnchors.add(_ArpeggioAnchor(
                measureId: measure.source.measureNumber.toString(),
                timePosition: n.timePosition,
                number: arp.number,
                xPx: chordXPx,
                yPx: nyPx,
                type: arp.type,
                direction: arp.direction,
                placement: arp.placement,
              ));
              break;
            }
          }
        }
      }

      if (!layoutedNote.isChordMember) {
        final isBeamable = layoutedNote.event.durationType.isBeamable;
        if (isBeamable) {
          final BeamType? primaryBeam = (layoutedNote.event is NoteEvent) ? (layoutedNote.event as NoteEvent).beams[1] : null;

          if (primaryBeam == null) {
            if (beamGroupIndices.isNotEmpty) {
              beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
            }
            beamDrawer.flushBeamGroup(canvas, <int>[j], measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
          } else {
            if (primaryBeam == BeamType.start && beamGroupIndices.isNotEmpty) {
              beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
            }
            beamGroupIndices.add(j);

            if (primaryBeam == BeamType.end) {
              beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
            }
          }
        } else {
          if (beamGroupIndices.isNotEmpty) {
            beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
          }
        }
      }
    }

    for (final note in measure.notes) {
      if (note.event is NoteEvent) {
        final autoAbove = !StemDirectionResolver.shouldStemBeUp(note);
        notePainter.drawWavyLines(
          canvas, measure, notePositions, autoAbove,
          selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0,
        );
        break;
      }
    }

    if (beamGroupIndices.isNotEmpty) {
      beamDrawer.flushBeamGroup(canvas, beamGroupIndices, measure, notePositions, selectedNoteId: selectedNote?.id, dragOffsetY: dragOffsetY ?? 0.0);
    }

    tupletPainter.drawTupletsInMeasure(
      canvas: canvas, measure: measure, notePositions: notePositions,
      stemLength: stemLength, staffTopY: staffTopY, staffLineCount: measure.staffLineCount,
    );

    final anchorXsByTimePosition = <int, double>{};
    for (final n in measure.notes) {
      if (n.isChordMember) continue;
      anchorXsByTimePosition.putIfAbsent(n.timePosition, () => measureStartX + n.x);
    }

    final anchorXsByEventIndex = <int, double>{};
    int logicalIdx = 0;
    for (final n in measure.notes) {
      if (n.isChordMember) continue;
      anchorXsByEventIndex[logicalIdx] = measureStartX + n.x;
      logicalIdx++;
    }

    final double fallbackX = measure.notes.isNotEmpty ? measureStartX + measure.notes.first.x : measureStartX + 30.0;
    final double realBottomY = staffRealBottomY;

    double minVisualYLine = 0.0;
    for (final n in measure.notes) {
        if (n.isRest) continue;
        double topY = n.yLine;
        if (n.event.durationType.needsStem && StemDirectionResolver.shouldStemBeUp(n)) {
            topY -= ScoreCraftConstants.stemLengthFactor;
        }
        if (topY < minVisualYLine) { minVisualYLine = topY; }
    }
    final double realTopY = staffTopY + minVisualYLine * lineSpacing;

final double dirHeight = directionPainter.drawDirections(
  canvas: canvas,
  directions: measure.source.directions,
  measureX: measureStartX,
  staffTopY: realTopY,
  staffBottomY: realBottomY,
  staffTopLineY: staffTopY,   // ← v2c-32b : la VRAIE ligne du haut
  anchorXsByTimePosition: anchorXsByTimePosition,
  anchorXsByEventIndex: anchorXsByEventIndex,
  fallbackAnchorX: fallbackX,
  totalDivisions: measure.source.totalDivisions,
  contentWidth: measure.contentWidth,
);

    final double lyricsStartY = realBottomY + dirHeight + lineSpacing * 3.0;

    lyricPainter.drawLyrics(
      canvas: canvas,
      notes: measure.notes,
      notePositions: notePositions,
      staffTopY: staffTopY,
      belowStartY: lyricsStartY,
    );
  }

  /// v2c-32e : dessine les arpèges d'un système, groupés par (tp, number).
  /// Permet les arpèges cross-staff et cross-voice (test W3C 32e).
  /// v2c-32e : dessine les arpèges d'un système, groupés par (tp, number).
  /// Aucun décalage horizontal : alignement strict avec le chord (W3C).
  static void _drawSystemArpeggios(
    Canvas canvas,
    List<_ArpeggioAnchor> anchors,
    NotePainter notePainter,
  ) {
    if (anchors.isEmpty) return;

    // Groupement strict par (timePosition, number)
    final groups = <String, List<_ArpeggioAnchor>>{};
    for (final a in anchors) {
      final key = '${a.measureId}_${a.timePosition}_${a.number}';
      groups.putIfAbsent(key, () => []).add(a);
    }

    // 👇 AJOUTE CE PRINT POUR VOIR LES GROUPES 👇
    for (final entry in groups.entries) {
      final group = entry.value;
      print('ARPÈGE - Groupe [${entry.key}] : ${group.length} notes.');
    }
    // 👆 FIN DU PRINT 👆

    for (final group in groups.values) {
      final arpMembers = group.where((a) => a.type == 'arpeggiate').toList();
      final nonArpMembers = group.where((a) => a.type == 'non-arpeggiate').toList();

      if (arpMembers.isNotEmpty) {
        double minY = arpMembers.first.yPx;
        double maxY = arpMembers.first.yPx;
        for (final a in arpMembers) {
          if (a.yPx < minY) minY = a.yPx;
          if (a.yPx > maxY) maxY = a.yPx;
        }
        
        // Alignement strict sur le premier élément du groupe
        final double xPx = arpMembers.first.xPx;

        String? direction;
        for (final a in arpMembers) {
          if (a.direction != null) {
            direction = a.direction;
            break;
          }
        }

        notePainter.drawArpeggiateLine(
          canvas,
          xPx,
          minY,
          maxY,
          direction: direction,
        );
      } else if (nonArpMembers.isNotEmpty) {
        // ... (garde le code pour non-arpeggiate inchangé)
        final bool hasTop = nonArpMembers.any((a) => a.placement == 'top');
        final bool hasBottom = nonArpMembers.any((a) => a.placement == 'bottom');

        double minY = nonArpMembers.first.yPx;
        double maxY = nonArpMembers.first.yPx;
        for (final a in nonArpMembers) {
          if (a.yPx < minY) minY = a.yPx;
          if (a.yPx > maxY) maxY = a.yPx;
        }
        final double xPx = nonArpMembers.first.xPx;

        notePainter.drawNonArpeggiateBracket(
          canvas,
          xPx,
          minY,
          maxY,
          hasTop: hasTop,
          hasBottom: hasBottom,
        );
      }
    }
  }
  static LayoutedNote? hitTest(Offset localPosition, {double hitRadius = 12.0}) {
    for (final pos in _lastPositions) {
      final dx = localPosition.dx - pos.position.dx;
      final dy = localPosition.dy - pos.position.dy;
      if ((dx * dx + dy * dy) < (hitRadius * hitRadius)) return pos.note;
    }
    return null;
  }

  static int? _findStaffIndex(ScoreDocument document, int globalStaffIndex) {
    for (int i = 0; i < document.staves.length; i++) {
      if (document.staves[i].staffIndex == globalStaffIndex) return i;
    }
    return null;
  }

  /// v2c-32d : extrait l'index du pitch depuis le LayoutedNote.id.
  /// Miroir de EditorController._extractPitchIndexFromLayoutedNoteId.
  ///   "eventId"      → 0   (pitch primaire)
  ///   "eventId_pN"   → N   (pitch N)
  static int _extractPitchIndex(String noteId, String eventId) {
    if (noteId == eventId) return 0;
    final prefix = '${eventId}_p';
    if (noteId.startsWith(prefix)) {
      return int.tryParse(noteId.substring(prefix.length)) ?? 0;
    }
    return 0;
  }
}

class _NotePosition {
  final LayoutedNote note;
  final Offset position;
  _NotePosition(this.note, this.position);
}

/// v2c-32e : une ancre d'arpège collectée pendant le rendu des staves.
/// Le groupement par (timePosition, number) se fait après coup, au niveau
/// du système, pour permettre les arpèges cross-staff / cross-voice.
class _ArpeggioAnchor {
  final String measureId;
  final int timePosition;
  final int number;
  final double xPx;
  final double yPx;
  final String type; // 'arpeggiate' ou 'non-arpeggiate'
  final String? direction;
  final String? placement;

  const _ArpeggioAnchor({
    required this.measureId,
    required this.timePosition,
    required this.number,
    required this.xPx,
    required this.yPx,
    required this.type,
    this.direction,
    this.placement,
  });
}