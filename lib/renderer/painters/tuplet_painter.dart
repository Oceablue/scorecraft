// lib/renderer/painters/tuplet_painter.dart
// ============================================================================
// PEINTRE DES TUPLETS — v2c-31a-1
// ============================================================================
// v2c-93ze : extraction depuis StaffRenderer (responsabilité unique).
// v2c-94y  : migration vers StemDirectionResolver.shouldStemBeUp.
//            ⚠ Fix comportemental inclus : la règle « grâce → toujours up »
//              n'était PAS appliquée ici avant. Conséquence possible sur
//              les tuplets de grâces (23e si concerné) : le bracket peut
//              se décaler vers une position plus correcte (above si les
//              hampes sont up).
//            _diatonicDiffForRenderer SUPPRIMÉ (utilisé uniquement par
//            _shouldStemBeUp, il est maintenant dans StemDirectionResolver).
// v2c-31a-1: _metNoteGlyphName SUPPRIMÉ (déplacé dans Smufl.metNoteGlyphName
//            pour être partagé avec DirectionPainter.drawMetronome).
//            Le call site dans _buildSideSpans pointe désormais vers
//            Smufl.metNoteGlyphName.
//
// Gère :
//   - L'ouverture/fermeture de la pile de tuplets (start/stop)
//   - L'auto-détection des beams pour décider du bracket
//   - Le dessin des crochets (lignes droites ou courbes)
//   - Le positionnement (placement XML > auto > alternance selon depth)
//   - Les tuplets d'une seule note (largeur artificielle)
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../models/layout/layout_models.dart';
import '../../models/events/music_event.dart';
import '../../models/enums/music_enums.dart';
import '../../services/smufl/smufl.dart';
import '../../utils/music_text_style.dart';
import '../stem_direction_resolver.dart';   // v2c-94y

class TupletPainter {
  final double lineSpacing;

  TupletPainter({required this.lineSpacing});

  // ==========================================================================
  // POINT D'ENTRÉE
  // ==========================================================================

  void drawTupletsInMeasure({
    required Canvas canvas,
    required LayoutedMeasure measure,
    required List<Map<String, double>> notePositions,
    required double stemLength,
    required double staffTopY,
    required int staffLineCount,
  }) {
    final List<_OpenTuplet> openStack = [];
    final List<_TupletGroup> groups = [];

    for (int j = 0; j < measure.notes.length; j++) {
      final event = measure.notes[j].event;
      if (event is! NoteEvent) continue;

      // Ouvrir AVANT de fermer (pour les tuplets d'une seule note)
      for (final number in event.tupletStarts) {
        final metadata = event.tupletMetadata[number];
        if (metadata == null) continue;
        openStack.add(_OpenTuplet(
          number: number,
          startIndex: j,
          metadata: metadata,
          depth: openStack.length,
        ));
      }

      for (final number in event.tupletStops) {
        final idx = openStack.indexWhere((t) => t.number == number);
        if (idx >= 0) {
          final openTuplet = openStack.removeAt(idx);
          groups.add(_buildTupletGroup(
            startIdx: openTuplet.startIndex,
            endIdx: j,
            metadata: openTuplet.metadata,
            depth: openTuplet.depth,
            measure: measure,
          ));
        }
      }
    }

    for (final openTuplet in openStack) {
      groups.add(_buildTupletGroup(
        startIdx: openTuplet.startIndex,
        endIdx: measure.notes.length - 1,
        metadata: openTuplet.metadata,
        depth: openTuplet.depth,
        measure: measure,
      ));
    }

    groups.sort((a, b) => b.depth.compareTo(a.depth));

    for (final group in groups) {
      _drawTupletGroup(
        canvas: canvas,
        group: group,
        measure: measure,
        notePositions: notePositions,
        stemLength: stemLength,
        staffTopY: staffTopY,
        staffLineCount: staffLineCount,
      );
    }
  }

  // ==========================================================================
  // LOGIQUE INTERNE
  // ==========================================================================

  bool _isSingleBeamGroup(
    LayoutedMeasure measure,
    int startIdx,
    int endIdx,
  ) {
    if (startIdx < 0 || endIdx >= measure.notes.length) return false;
    if (startIdx >= endIdx) return false;

    final firstEv = measure.notes[startIdx].event;
    if (firstEv is! NoteEvent) return false;
    if (firstEv.beams[1] != BeamType.start) return false;

    final lastEv = measure.notes[endIdx].event;
    if (lastEv is! NoteEvent) return false;
    if (lastEv.beams[1] != BeamType.end) return false;

    for (int i = startIdx; i <= endIdx; i++) {
      final ev = measure.notes[i].event;
      if (ev is! NoteEvent) return false;
      if (!ev.durationType.isBeamable) return false;
      final b = ev.beams[1];
      if (b == null || b == BeamType.none) return false;
      if (i > startIdx && i < endIdx) {
        if (b == BeamType.start || b == BeamType.end) return false;
      }
    }
    return true;
  }

  _TupletGroup _buildTupletGroup({
    required int startIdx,
    required int endIdx,
    required TupletMetadata metadata,
    required int depth,
    required LayoutedMeasure measure,
  }) {
    final TupletDisplaySide displayActual =
        metadata.displayActual ?? TupletDisplaySide(number: metadata.number);
    final TupletDisplaySide displayNormal =
        metadata.displayNormal ?? TupletDisplaySide(number: metadata.number);

    final bool effectiveBracket;
    if (metadata.bracketExplicit) {
      effectiveBracket = metadata.bracket;
    } else {
      final bool singleBeam = _isSingleBeamGroup(measure, startIdx, endIdx);
      effectiveBracket = !singleBeam;
    }

    return _TupletGroup(
      startIndex: startIdx,
      endIndex: endIdx,
      displayActual: displayActual,
      displayNormal: displayNormal,
      showNumber: metadata.showNumber,
      showType: metadata.showType,
      lineShape: metadata.lineShape,
      bracket: effectiveBracket,
      placement: metadata.placement,
      depth: depth,
    );
  }

  void _drawTupletGroup({
    required Canvas canvas,
    required _TupletGroup group,
    required LayoutedMeasure measure,
    required List<Map<String, double>> notePositions,
    required double stemLength,
    required double staffTopY,
    required int staffLineCount,
  }) {
    if (group.startIndex > group.endIndex) return;
    if (group.startIndex < 0) return;
    if (group.endIndex >= measure.notes.length) return;

    double leftX = notePositions[group.startIndex]['x']!;
    double rightX = notePositions[group.endIndex]['x']!;

    // Largeur artificielle pour tuplet d'une seule note (test 23e).
    if (group.startIndex == group.endIndex) {
      final double center = leftX;
      final double width = lineSpacing * 3.5;
      leftX = center - width / 2;
      rightX = center + width / 2;
    }

    if (rightX <= leftX) return;

    final firstNote = measure.notes[group.startIndex];

    // ═══════════════════════════════════════════════════════════════════════
    // v2c-94y : direction de hampe via StemDirectionResolver
    // (fix grace-up inclus — voir en-tête du fichier).
    // ═══════════════════════════════════════════════════════════════════════
    final bool stemUp = StemDirectionResolver.shouldStemBeUp(firstNote);

    bool above;
    if (group.placement == 'above') {
      above = true;
    } else if (group.placement == 'below') {
      above = false;
    } else {
      above = !stemUp;
      if (group.depth % 2 == 1) {
        above = !above;
      }
    }

    double topOfStems = double.infinity;
    double bottomOfStems = double.negativeInfinity;

    for (int j = group.startIndex; j <= group.endIndex; j++) {
      final note = measure.notes[j];
      if (note.isRest || note.isChordMember) continue;

      final double yPx = notePositions[j]['y']!;
      // v2c-94y : direction de hampe via StemDirectionResolver.
      final bool noteStemUp = StemDirectionResolver.shouldStemBeUp(note);

      // Prise en compte du trémolo dans la longueur de hampe.
      double effectiveStemLength = stemLength;
      if (note.event is NoteEvent) {
        final ne = note.event as NoteEvent;
        if (ne.tremoloType != TremoloType.none) {
          if (ne.tremoloType == TremoloType.unmeasured) {
            effectiveStemLength += lineSpacing * 0.5;
          } else {
            final int cnt = ne.tremoloCount <= 0 ? 1 : ne.tremoloCount;
            final bool isBeamable = ne.durationType.isBeamable;
            final bool hasFlag = isBeamable && ne.beams.isEmpty;
            if (hasFlag) {
              effectiveStemLength += (1.8 + (cnt - 1) * 1.05 + 0.3) * lineSpacing;
            } else {
              effectiveStemLength += (cnt * 0.6 + 0.4) * lineSpacing;
            }
          }
        }
      }

      if (noteStemUp) {
        final double stemTop = yPx - effectiveStemLength;
        if (stemTop < topOfStems) topOfStems = stemTop;
      } else {
        final double stemBottom = yPx + effectiveStemLength;
        if (stemBottom > bottomOfStems) bottomOfStems = stemBottom;
      }
    }

    if (topOfStems == double.infinity) {
      topOfStems = notePositions[group.startIndex]['y']!;
    }
    if (bottomOfStems == double.negativeInfinity) {
      bottomOfStems = notePositions[group.startIndex]['y']!;
    }

    double extraMargin = 0.0;
    for (int j = group.startIndex; j <= group.endIndex; j++) {
      final note = measure.notes[j];
      if (note.event is NoteEvent) {
        final ne = note.event as NoteEvent;
        for (final art in ne.articulations) {
          final bool isBelow = art.placement == 'below' || (art.placement == null && !stemUp);
          final bool isAbove = art.placement == 'above' || (art.placement == null && stemUp);
          if (above && isAbove) {
            extraMargin = math.max(extraMargin, lineSpacing * 1.5);
          } else if (!above && isBelow) {
            extraMargin = math.max(extraMargin, lineSpacing * 1.5);
          }
        }
      }
    }
    final double margin = lineSpacing * 1.2 + extraMargin;

    final double staffTopLineY = staffTopY;
    final double staffBottomLineY = staffTopY + (staffLineCount - 1) * lineSpacing;

    final double depthOffset;
    if (group.placement.isNotEmpty) {
      depthOffset = 0.0;
    } else {
      depthOffset = above ? (group.depth * lineSpacing * 1.8) : 0.0;
    }

    final double bracketY;
    if (above) {
      final double aboveStems = topOfStems - margin;
      final double aboveStaff = staffTopLineY - margin;
      bracketY = math.min(aboveStems, aboveStaff) + depthOffset;
    } else {
      final double belowStems = bottomOfStems + margin;
      final double belowStaff = staffBottomLineY + margin;
      bracketY = math.max(belowStems, belowStaff) - depthOffset;
    }

    _drawTupletBracket(
      canvas: canvas,
      leftX: leftX,
      rightX: rightX,
      y: bracketY,
      above: above,
      group: group,
    );
  }

  void _drawTupletBracket({
    required Canvas canvas,
    required double leftX,
    required double rightX,
    required double y,
    required bool above,
    required _TupletGroup group,
  }) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double tickDir = above ? 1.0 : -1.0;
    final double tickHeight = lineSpacing * 0.7;
    final double centerX = (leftX + rightX) / 2;

    const double bracketExtendSp = 0.5;
    final double extendPx = lineSpacing * bracketExtendSp;
    final double extendedLeftX = leftX - extendPx;
    final double extendedRightX = rightX + extendPx;

    const double digitFontSizeFactor  = 3.0;
    const double symbolFontSizeFactor = 2.5;
    const double dotFontSizeFactor    = 3.5;

    final TextStyle digitStyle = MusicTextStyle.music(
      fontSize: lineSpacing * digitFontSizeFactor,
      color: Colors.black,
      height: 1.0,
    );
    final TextStyle symbolStyle = MusicTextStyle.music(
      fontSize: lineSpacing * symbolFontSizeFactor,
      color: Colors.black,
      height: 1.0,
    );
    final TextStyle dotStyle = MusicTextStyle.music(
      fontSize: lineSpacing * dotFontSizeFactor,
      color: Colors.black,
      height: 1.0,
    );

    final String colonGlyph = Smufl.has('tupletColon')
        ? Smufl.glyph('tupletColon')
        : ':';
    final String colonWithSpaces = '\u2009$colonGlyph\u2009';

    final List<InlineSpan> labelSpans = [];

    if (group.showNumber == 'actual') {
      final bool showSym = group.showType == 'actual' || group.showType == 'both';
      labelSpans.addAll(_buildSideSpans(
        side: group.displayActual,
        showSymbol: showSym,
        digitStyle: digitStyle,
        symbolStyle: symbolStyle,
        dotStyle: dotStyle,
      ));
    } else if (group.showNumber == 'both') {
      final bool showActualSym = group.showType == 'both';
      final bool showNormalSym = group.showType == 'actual' || group.showType == 'both';

      labelSpans.addAll(_buildSideSpans(
        side: group.displayActual,
        showSymbol: showActualSym,
        digitStyle: digitStyle,
        symbolStyle: symbolStyle,
        dotStyle: dotStyle,
      ));
      labelSpans.add(TextSpan(text: colonWithSpaces, style: digitStyle));
      labelSpans.addAll(_buildSideSpans(
        side: group.displayNormal,
        showSymbol: showNormalSym,
        digitStyle: digitStyle,
        symbolStyle: symbolStyle,
        dotStyle: dotStyle,
      ));
    }

    TextPainter? numberPainter;
    double numberHalfWidth = 0;
    if (labelSpans.isNotEmpty) {
      numberPainter = TextPainter(
        text: TextSpan(children: labelSpans),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      )..layout();
      numberHalfWidth = numberPainter.width / 2;
    }

    if (group.bracket || group.lineShape == 'curved') {
      if (group.lineShape == 'curved') {
        final double curveDepthSp = above ? -0.8 : 0.8;
        final double curveDepthPx = lineSpacing * curveDepthSp;

        final Path arcPath = Path()
          ..moveTo(extendedLeftX, y)
          ..quadraticBezierTo(
            (extendedLeftX + extendedRightX) / 2,
            y + curveDepthPx * 2,
            extendedRightX,
            y,
          );

        canvas.drawPath(arcPath, paint);

        if (numberPainter != null) {
          final double labelY = above
              ? y + curveDepthPx - lineSpacing * 0.8
              : y + curveDepthPx + lineSpacing * 0.8;
          numberPainter.paint(
            canvas,
            Offset(centerX - numberPainter.width / 2, labelY),
          );
        }
        return;
      }

      final double gap = lineSpacing * 0.4;
      final double leftEndX = numberPainter != null
          ? centerX - numberHalfWidth - gap
          : extendedRightX;
      final double rightStartX = numberPainter != null
          ? centerX + numberHalfWidth + gap
          : extendedRightX;

      if (leftEndX > extendedLeftX) {
        canvas.drawLine(Offset(extendedLeftX, y), Offset(leftEndX, y), paint);
      }
      if (rightStartX < extendedRightX) {
        canvas.drawLine(Offset(rightStartX, y), Offset(extendedRightX, y), paint);
      }

      canvas.drawLine(
        Offset(extendedLeftX, y),
        Offset(extendedLeftX, y + tickHeight * tickDir),
        paint,
      );
      canvas.drawLine(
        Offset(extendedRightX, y),
        Offset(extendedRightX, y + tickHeight * tickDir),
        paint,
      );
    }

    if (numberPainter != null) {
      numberPainter.paint(
        canvas,
        Offset(centerX - numberPainter.width / 2, y - numberPainter.height / 2),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // v2c-31a-1 : _metNoteGlyphName SUPPRIMÉ
  // ───────────────────────────────────────────────────────────────────────────
  // Cette méthode a été DÉPLACÉE dans Smufl.metNoteGlyphName() pour être
  // partagée avec DirectionPainter (rendu du métronome ♩ = 120), qui a
  // besoin de la même table de glyphes metNote*.
  //
  // Le call site est dans _buildSideSpans ci-dessous.
  // ═══════════════════════════════════════════════════════════════════════════

  List<InlineSpan> _buildSideSpans({
    required TupletDisplaySide side,
    required bool showSymbol,
    required TextStyle digitStyle,
    required TextStyle symbolStyle,
    required TextStyle dotStyle,
  }) {
    final spans = <InlineSpan>[];
    if (side.number != null) {
      spans.add(TextSpan(
        text: Smufl.tupletNumber(side.number!),
        style: digitStyle,
      ));
    }
    if (showSymbol && side.type != null) {
      // v2c-31a-1 : appel centralisé via Smufl.metNoteGlyphName.
      final glyphName = Smufl.metNoteGlyphName(side.type!);
      if (Smufl.has(glyphName)) {
        spans.add(TextSpan(
          text: Smufl.glyph(glyphName),
          style: symbolStyle,
        ));
        if (side.dots > 0 && Smufl.has('metAugmentationDot')) {
          final dotGlyph = Smufl.glyph('metAugmentationDot');
          for (int i = 0; i < side.dots; i++) {
            spans.add(TextSpan(text: dotGlyph, style: dotStyle));
          }
        }
      }
    }
    return spans;
  }
}

// ============================================================================
// STRUCTURES INTERNES
// ============================================================================

class _OpenTuplet {
  final int number;
  final int startIndex;
  final TupletMetadata metadata;
  final int depth;

  const _OpenTuplet({
    required this.number,
    required this.startIndex,
    required this.metadata,
    required this.depth,
  });
}

class _TupletGroup {
  final int startIndex;
  final int endIndex;
  final TupletDisplaySide displayActual;
  final TupletDisplaySide displayNormal;
  final String showNumber;
  final String showType;
  final String lineShape;
  final bool bracket;
  final String placement;
  final int depth;

  const _TupletGroup({
    required this.startIndex,
    required this.endIndex,
    required this.displayActual,
    required this.displayNormal,
    required this.showNumber,
    required this.showType,
    required this.lineShape,
    required this.bracket,
    required this.placement,
    required this.depth,
  });
}