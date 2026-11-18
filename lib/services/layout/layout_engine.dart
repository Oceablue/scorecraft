// lib/services/layout/layout_engine.dart
// ============================================================================
// MOTEUR DE LAYOUT — v2c-32b
// ============================================================================
// v2c-31a-1h: FIX « VIDE AU-DESSUS DU ♩=60 » ET « TEXTES EN GRAS
//            TROP PROCHE DE LEUR PORTÉE ».
// v2c-32b  : Option A — la portée n'est plus rétractée pour les textes
//            avec default-x. La musique garde sa justification symétrique,
//            et le texte s'affiche par-dessus (comportement MuseScore).
// ============================================================================

import 'dart:math' as math;

import '../../models/score/score_document.dart';
import '../../models/score/measure.dart';
import '../../models/events/music_event.dart';
import '../../models/events/pitch.dart';
import '../../models/events/direction.dart';
import '../../models/enums/music_enums.dart';
import '../../models/layout/layout_models.dart';
import '../../utils/constants.dart';
import 'justification.dart';
import 'pitch_positioner.dart';
import '../../renderer/stem_direction_resolver.dart';

class LayoutEngine {
  static const double systemStartPadding = 12.0;
  static const double systemEndPadding = 0.0;

  static const double contentPaddingLeft = 22.0;
  static const double contentPaddingRight = 12.0;
  static const double minInterStaffSpacing = 24.0;
  static const double collisionMargin = 8.0;

  static const double interSystemSpacing = 40.0;
  static const double defaultTopMargin = 60.0;
  static const double firstSystemIndent = 60.0;

  static const double minEventSpacingSp = 1.5;
  static const double trailingPaddingSp = 0.4;
  static const double _minRedistributionFactor = 0.55;

  static bool _isDrawableDirection(DirectionEvent d) {
    switch (d.type) {
      case DirectionType.dynamic:
        return d.dynamicName != null && d.dynamicName!.isNotEmpty;
      case DirectionType.words:
        return d.text != null && d.text!.isNotEmpty;
      case DirectionType.metronome:
        return d.beatUnit != null;
      case DirectionType.wedge:
        return d.wedgeType != null;
      case DirectionType.rehearsal:
        return d.text != null && d.text!.isNotEmpty;
      case DirectionType.segno:
      case DirectionType.coda:
      case DirectionType.symbol:
      case DirectionType.dashes:
      case DirectionType.bracket:
      case DirectionType.octaveShift:
      case DirectionType.pedal:
      case DirectionType.scordatura:
      case DirectionType.harpPedals:
      case DirectionType.damp:
      case DirectionType.stringMute:
      case DirectionType.eyeglasses:
      case DirectionType.percussion:
      case DirectionType.staffDivide:
      case DirectionType.principalVoice:
      case DirectionType.accordion:
      case DirectionType.image:
      case DirectionType.generic:
        return true;
    }
  }

  static double _baseWeight(DurationType type) {
    switch (type) {
      case DurationType.maxima:                  return 14.0;
      case DurationType.longa:                   return 10.0;
      case DurationType.doubleWhole:             return 8.0;
      case DurationType.whole:                   return 7.0;
      case DurationType.half:                    return 5.0;
      case DurationType.quarter:                 return 3.5;
      case DurationType.eighth:                  return 2.5;
      case DurationType.sixteenth:               return 2.0;
      case DurationType.thirtySecond:            return 1.5;
      case DurationType.sixtyFourth:             return 1.25;
      case DurationType.oneHundredTwentyEighth:  return 1.0;
      case DurationType.twoHundredFiftySixth:    return 0.75;
      case DurationType.fiveHundredTwelfth:      return 0.6;
      case DurationType.oneThousandTwentyFourth: return 0.5;
    }
  }

  static double _eventWeight(MusicEvent event) {
    final double dotPenaltySp = event.dotType.count * 1.5;
    double w = _baseWeight(event.durationType) + dotPenaltySp;

    if (event.tupletsNumerator > 1) {
      w *= (event.tupletsDenominator / event.tupletsNumerator);
    }

    if (event is NoteEvent && event.pitches.isNotEmpty) {
      final p = event.pitches.first;
      if (p.accidentalDisplay != Accidental.none) w *= 1.3;
    }

    if (event is NoteEvent && event.pitches.length > 1) {
      w *= 1.0 + 0.5 * (event.pitches.length - 1);
    }

    if (event is NoteEvent) {
      int maxTextLength = 0;
      bool hasHyphen = false;

      void checkLyrics(List<dynamic> lyrics) {
        for (final l in lyrics) {
          if (l.fullText.length > maxTextLength) {
            maxTextLength = l.fullText.length;
          }
          if (l.syllabic == 'begin' || l.syllabic == 'middle') {
            hasHyphen = true;
          }
        }
      }

      checkLyrics(event.lyrics);
      for (final p in event.pitches) {
        checkLyrics(p.lyrics);
      }
      
      if (maxTextLength > 0) {
        double lyricWidthSp = maxTextLength * 1.0;
        if (hasHyphen) lyricWidthSp += 1.5;
        if (lyricWidthSp > w) w = lyricWidthSp;
      }
    }

    final double footprint = _minVisualFootprintSp(event);
    if (w < footprint) w = footprint;
    return w;
  }

  static double _minVisualFootprintSp(MusicEvent event) {
    double fp = 0.0;
    switch (event.durationType) {
      case DurationType.maxima:
      case DurationType.longa:
      case DurationType.doubleWhole:
        fp += 1.8; break;
      case DurationType.whole:
      case DurationType.half:
        fp += 1.4; break;
      default:
        fp += 1.1;
    }
    fp += event.dotType.count * 0.6;
    if (event is NoteEvent && event.pitches.isNotEmpty) {
      final p = event.pitches.first;
      if (p.accidentalDisplay != Accidental.none) fp += 1.4;
    }
    fp += 0.3;
    return fp;
  }

  static double _visualRightHalfWidthSp(MusicEvent event) {
    double w = 0.6;
    w += 0.35;
    w += event.dotType.count * 0.75;
    w += 0.3;
    return w;
  }

  static double _visualLeftHalfWidthSp(MusicEvent event) {
    double w = 0.6;
    if (event is NoteEvent && event.pitches.isNotEmpty) {
      final p = event.pitches.first;
      if (p.accidentalDisplay != Accidental.none) w += 1.4;
    }
    w += 0.2;
    return w;
  }

  static NoteLetter? _stepToNoteLetter(String step) {
    switch (step.toUpperCase()) {
      case 'C': return NoteLetter.C;
      case 'D': return NoteLetter.D;
      case 'E': return NoteLetter.E;
      case 'F': return NoteLetter.F;
      case 'G': return NoteLetter.G;
      case 'A': return NoteLetter.A;
      case 'B': return NoteLetter.B;
      default:  return null;
    }
  }

  static int _keySignatureAlterForLetter(NoteLetter letter, int fifths) {
    const sharpOrder = [
      NoteLetter.F, NoteLetter.C, NoteLetter.G, NoteLetter.D,
      NoteLetter.A, NoteLetter.E, NoteLetter.B,
    ];
    const flatOrder = [
      NoteLetter.B, NoteLetter.E, NoteLetter.A, NoteLetter.D,
      NoteLetter.G, NoteLetter.C, NoteLetter.F,
    ];

    if (fifths > 0) {
      final idx = sharpOrder.indexOf(letter);
      if (idx >= 0 && idx < fifths) return 1;
      return 0;
    } else if (fifths < 0) {
      final idx = flatOrder.indexOf(letter);
      if (idx >= 0 && idx < -fifths) return -1;
      return 0;
    }
    return 0;
  }

  static Accidental _accidentalForAlter(double alter) {
    if (alter ==  2.0) return Accidental.doubleSharp;
    if (alter ==  1.5) return Accidental.threeQuarterSharp;
    if (alter ==  1.0) return Accidental.sharp;
    if (alter ==  0.5) return Accidental.quarterSharp;
    if (alter ==  0.0) return Accidental.natural;
    if (alter == -0.5) return Accidental.quarterFlat;
    if (alter == -1.0) return Accidental.flat;
    if (alter == -1.5) return Accidental.threeQuarterFlat;
    if (alter == -2.0) return Accidental.doubleFlat;
    return Accidental.none;
  }

  static double _keySignatureWidth(int alterationCount) {
    if (alterationCount <= 0) return 0.0;
    final double sp = ScoreCraftConstants.staffLineSpacing;
    return alterationCount * sp * 1.45 + 8.0;
  }

  static int _maxLineCountOfStaff({
    required List<LayoutedMeasure> measures,
    required int defaultCount,
  }) {
    int maxCount = defaultCount;
    for (final m in measures) {
      if (m.staffLineCount > maxCount) maxCount = m.staffLineCount;
    }
    return maxCount;
  }

  static bool _shouldStemBeUpForLayout(
    NoteEvent event,
    ClefType clef,
    int lineCount,
  ) {
    switch (event.stemDirection) {
      case StemDirection.up:   return true;
      case StemDirection.down: return false;
      case StemDirection.none: return false;
      case StemDirection.auto: break;
    }

    if (event.pitches.isEmpty) return false;

    double sumYLine = 0.0;
    for (final p in event.pitches) {
      sumYLine += PitchPositioner.pitchToYLine(p, clef, lineCount: lineCount);
    }
    final double avg = sumYLine / event.pitches.length;
    return avg > 2.0;
  }

  static void _normalizeToTarget(List<double> widths, double targetWidth) {
    if (widths.isEmpty) return;
    final sum = widths.fold<double>(0, (s, w) => s + w);
    if (sum <= 0) return;
    if ((sum - targetWidth).abs() < 0.5) return;

    final ratio = targetWidth / sum;
    for (int i = 0; i < widths.length; i++) {
      widths[i] *= ratio;
    }
  }
  static double _getArticulationHeightSp(ArticulationType type) {
    switch (type) {
      case ArticulationType.scoop:
      case ArticulationType.plop:
      case ArticulationType.doit:
      case ArticulationType.falloff:
        return 3.2; 
      case ArticulationType.breathMark:
      case ArticulationType.caesura:
        return 2.5;
      case ArticulationType.marcato:
      case ArticulationType.softAccent:
        return 2.0;
      default:
        return 1.7; 
    }
  }

  static double _predictSystemTopOverhang({
    required ScoreDocument document,
    required List<int> indices,
    required Map<int, List<ClefType>> effectiveClefsByStaff,
  }) {
    double maxOverhang = 0.0;
    const double lineSpacing = ScoreCraftConstants.staffLineSpacing;
    const double stemLengthSp = ScoreCraftConstants.stemLengthFactor;

    for (int s = 0; s < document.staves.length; s++) {
      final staff = document.staves[s];
      final clefs = effectiveClefsByStaff[s];
      final int lineCount = staff.lineCount;

      for (final i in indices) {
        if (i >= staff.measures.length) continue;
        final measure = staff.measures[i];
        final ClefType clef = (clefs != null && i < clefs.length) ? clefs[i] : staff.clef;

        for (final voice in measure.voices) {
          for (final event in voice.events) {
            if (event is! NoteEvent) continue;
            if (event.pitches.isEmpty) continue;

            double minYLine = double.infinity;
            double maxYLine = double.negativeInfinity;
            for (final p in event.pitches) {
              final double yl = PitchPositioner.pitchToYLine(p, clef, lineCount: lineCount);
              if (yl < minYLine) minYLine = yl;
              if (yl > maxYLine) maxYLine = yl;
            }

            bool stemUp;
            switch (event.stemDirection) {
              case StemDirection.up: stemUp = true; break;
              case StemDirection.down:
              case StemDirection.none: stemUp = false; break;
              case StemDirection.auto:
                final double center = (minYLine + maxYLine) / 2;
                stemUp = center > 2.0; break;
            }

            double topYLine;
            if (stemUp) {
              topYLine = minYLine - stemLengthSp;
            } else {
              topYLine = minYLine;
            }

            double maxArtHeight = 0.0;
            int aboveArtsCount = 0; // v2c-32c
            for (final art in event.articulations) {
              bool isAbove = art.placement == 'above' || 
                             (art.placement == null && !stemUp);
              if (isAbove) {
                aboveArtsCount++;
                final h = _getArticulationHeightSp(art.type);
                if (h > maxArtHeight) maxArtHeight = h;
              }
            }
            int aboveNotationsCount = 0;
            
            for (final o in event.notations.ornaments) {
              if (o.type != 'wavy-line' && (o.placement == 'above' || (o.placement != 'below' && !stemUp))) {
                aboveNotationsCount++;
              }
            }
            
            final textTypes = ['fingering', 'pluck', 'fret', 'string'];
            final techs = event.notations.technicals;
            final glyphsAbove = techs.where((t) => !textTypes.contains(t.type) && (t.placement == 'above' || (t.placement != 'below' && !stemUp))).length;
            final hasTextAbove = techs.any((t) => textTypes.contains(t.type) && (t.placement == 'above' || (t.placement != 'below' && !stemUp)));
            aboveNotationsCount += glyphsAbove + (hasTextAbove ? 1 : 0);

            for (final m in event.notations.accidentalMarks) {
              if (m.placement == 'above' || (m.placement != 'below' && !stemUp)) {
                aboveNotationsCount++;
              }
            }

            double notationsHeight = aboveNotationsCount > 0 
                ? (3.2 + (aboveNotationsCount - 1) * 2.8) 
                : 0.0;
            
            // v2c-32c : On empile les articulations (1.4 sp par niveau)
            final double artsStackOffset = aboveArtsCount > 1 ? (aboveArtsCount - 1) * 1.4 : 0.0;
            topYLine -= (maxArtHeight + notationsHeight + artsStackOffset);

            if (topYLine < 0) {
              final double oh = (-topYLine) * lineSpacing;
              if (oh > maxOverhang) maxOverhang = oh;
            }
          }
        }

        int aboveMetronomeCount = 0;
        int aboveOtherCount = 0;
        for (final d in measure.directions) {
          if (d.placement == 'above' && _isDrawableDirection(d)) {
            if (d.type == DirectionType.metronome) {
              aboveMetronomeCount++;
            } else {
              aboveOtherCount++;
            }
          }
        }
        if (aboveMetronomeCount > 0) {
          final double metroHeight = lineSpacing * (1.8 + (aboveMetronomeCount - 1) * 1.6 + 2.1);
          if (metroHeight > maxOverhang) maxOverhang = metroHeight;
        }
        if (aboveOtherCount > 0) {
          final double otherHeight = lineSpacing * (3.4 + (aboveOtherCount - 1) * 1.6 + 1.9);
          if (otherHeight > maxOverhang) maxOverhang = otherHeight;
        }

        int maxVerseAbove = 0;
        for (final voice in measure.voices) {
          for (final event in voice.events) {
            if (event is NoteEvent) {
              for (final l in event.lyrics) {
                if (l.placement == 'above' && l.number > maxVerseAbove) maxVerseAbove = l.number;
              }
              for (final p in event.pitches) {
                for (final l in p.lyrics) {
                  if (l.placement == 'above' && l.number > maxVerseAbove) maxVerseAbove = l.number;
                }
              }
            }
          }
        }
        if (maxVerseAbove > 0) {
           final double lyricsHeight = lineSpacing * (2.0 + (maxVerseAbove - 1) * 2.8 + 1.5);
           if (lyricsHeight > maxOverhang) maxOverhang = lyricsHeight;
        }
      }
    }

    return maxOverhang;
  }
  static Map<int, double> _computeCrossStaffGridFraction({
    required ScoreDocument document,
    required int measureIdx,
    required double usableWidthRef,
  }) {
    if (usableWidthRef <= 0) return {};

    final eventsAtTp = <int, List<MusicEvent>>{};
    for (final staff in document.staves) {
      if (measureIdx >= staff.measures.length) continue;
      for (final voice in staff.measures[measureIdx].voices) {
        for (final event in voice.events) {
          if (event is RestEvent && event.isMeasureRest) continue;
          eventsAtTp.putIfAbsent(event.timePosition, () => []).add(event);
        }
      }
    }

    if (eventsAtTp.isEmpty) return {};

    final weightAtTp = <int, double>{};
    for (final entry in eventsAtTp.entries) {
      double maxW = 0.0;
      for (final event in entry.value) {
        final w = _eventWeight(event);
        if (w > maxW) maxW = w;
      }
      weightAtTp[entry.key] = maxW;
    }

    final sortedTps = weightAtTp.keys.toList()..sort();
    final totalWeight = weightAtTp.values.fold<double>(0, (s, w) => s + w);
    if (totalWeight <= 0) return {};

    final fractions = <int, double>{};
    double cumulative = 0.0;
    for (final tp in sortedTps) {
      final w = weightAtTp[tp]!;
      fractions[tp] = (cumulative + w / 2) / totalWeight;
      cumulative += w;
    }

    final double pixelsPerSp = ScoreCraftConstants.staffLineSpacing;
    final double minSpacingPx = minEventSpacingSp * pixelsPerSp;
    final double minSpacingFraction = minSpacingPx / usableWidthRef;

    for (int i = 1; i < sortedTps.length; i++) {
      final prev = sortedTps[i - 1];
      final curr = sortedTps[i];
      final required = fractions[prev]! + minSpacingFraction;
      if (fractions[curr]! < required) {
        fractions[curr] = required;
      }
    }

    if (sortedTps.isNotEmpty) {
      final double maxF = fractions[sortedTps.last]!;
      if (maxF > 1.0 && maxF > 0) {
        for (final tp in sortedTps) {
          fractions[tp] = fractions[tp]! / maxF;
        }
      }
    }

    return fractions;
  }

  static List<LayoutedSystem> computeLayout(
    ScoreDocument document,
    double usableWidth, {
    double startY = 0,
  }) {
    if (document.staves.isEmpty || usableWidth <= 0) return [];

    final int maxMeasures = document.staves
        .map((s) => s.measures.length)
        .fold<int>(0, (max, l) => math.max(max, l));

    if (maxMeasures == 0) return [];

    final minWidths = List<double>.filled(maxMeasures, 0.0);
    final preferredWidths = List<double>.filled(maxMeasures, 0.0);

    for (int i = 0; i < maxMeasures; i++) {
      double minW = 60.0;
      double prefW = 60.0;

      for (final staff in document.staves) {
        if (i >= staff.measures.length) continue;
        final measure = staff.measures[i];
        final estimated = _estimateMeasureWidth(measure);

        final double minFactor = measure.showKeySignature ? 0.85 : 0.7;
        minW = math.max(minW, estimated * minFactor);
        prefW = math.max(prefW, estimated);
      }

      minWidths[i] = minW;
      preferredWidths[i] = prefW;
    }

    final firstMeasure = document.staves.first.measures.isNotEmpty
        ? document.staves.first.measures.first
        : null;

    final double startBlockWidth = _computeStartBlockWidth(
      firstMeasure: firstMeasure,
      isFirstSystem: false,
    );

    final double firstSystemUsableWidth = usableWidth - firstSystemIndent - startBlockWidth - systemEndPadding;
    final double otherSystemUsableWidth = usableWidth - startBlockWidth - systemEndPadding;

    final forcedBreakSet = <int>{};
    for (int i = 0; i < maxMeasures; i++) {
      final hasBreak = document.staves.any((staff) {
        if (i >= staff.measures.length) return false;
        return staff.measures[i].hasSystemBreak;
      });
      if (hasBreak && i > 0) forcedBreakSet.add(i);
    }

    final multiRestCounts = List<int>.filled(maxMeasures, 1);
    for (int i = 0; i < maxMeasures; i++) {
      for (final staff in document.staves) {
        if (i >= staff.measures.length) continue;
        final mrc = staff.measures[i].multiRestCount;
        if (mrc > multiRestCounts[i]) multiRestCounts[i] = mrc;
      }
    }

    final eventCounts = List<int>.filled(maxMeasures, 1);
    for (int i = 0; i < maxMeasures; i++) {
      int maxCount = 1;
      for (final staff in document.staves) {
        if (i >= staff.measures.length) continue;
        final m = staff.measures[i];
        int count;
        if (m.multiRestCount > 1) {
          count = m.multiRestCount;
        } else {
          count = 0;
          for (final voice in m.voices) {
            count += voice.events.length;
          }
          if (count == 0) count = 1;
        }
        if (count > maxCount) maxCount = count;
      }
      eventCounts[i] = maxCount;
    }

    final effectiveClefsByStaff = <int, List<ClefType>>{};
    for (int s = 0; s < document.staves.length; s++) {
      final staff = document.staves[s];
      final clefs = <ClefType>[];
      ClefType running = staff.clef;
      for (final m in staff.measures) {
        if (m.clef != null) running = m.clef!;
        clefs.add(running);
      }
      effectiveClefsByStaff[s] = clefs;
    }

    final systemIndices = _collectSystemSequential(
      totalMeasures: maxMeasures,
      measureWidths: preferredWidths,
      multiRestCounts: multiRestCounts,
      firstSystemUsableWidth: firstSystemUsableWidth,
      otherSystemUsableWidth: otherSystemUsableWidth,
      forcedBreaks: forcedBreakSet,
    );

    final justification = Justification(
      maxExpansionFactor: 1.5,
      minCompressionFactor: 0.7,
      useDurationWeighting: true,
    );

    final systems = <LayoutedSystem>[];
    double currentY = startY;

    for (int sysIdx = 0; sysIdx < systemIndices.length; sysIdx++) {
      final indices = systemIndices[sysIdx];

      final firstMeasureOfSystem = _getFirstMeasureOfSystem(
        document: document,
        indices: indices,
      );

      final bool isFirstSystem = systems.isEmpty;
      final double firstIndent = isFirstSystem ? firstSystemIndent : 0.0;

      final double sBlockWidth = firstIndent +
          _computeStartBlockWidth(
            firstMeasure: firstMeasureOfSystem,
            isFirstSystem: isFirstSystem,
          );

      final double targetWidth = usableWidth - sBlockWidth - systemEndPadding;

      bool hasDenseMeasure = false;
      bool hasRealNote = false;

      for (final i in indices) {
        final int mrc = (i < multiRestCounts.length) ? multiRestCounts[i] : 1;
        if (mrc > 1) continue;

        int measureEvents = 0;
        bool measureHasNote = false;

        for (final staff in document.staves) {
          if (i >= staff.measures.length) continue;
          for (final voice in staff.measures[i].voices) {
            measureEvents += voice.events.length;
            for (final event in voice.events) {
              if (event is! RestEvent) measureHasNote = true;
            }
          }
        }

        if (measureEvents >= 2) hasDenseMeasure = true;
        if (measureHasNote) hasRealNote = true;
      }

      final bool systemHasDenseContent = hasDenseMeasure || hasRealNote;

      final visibleIndices = <int>[];
      int scanIdx = 0;
      while (scanIdx < indices.length) {
        final i = indices[scanIdx];
        final int mrc = (i < multiRestCounts.length) ? multiRestCounts[i] : 1;
        visibleIndices.add(i);
        scanIdx += (mrc > 1) ? mrc : 1;
      }

      final finalWidths = _justifyWidths(
        indices: visibleIndices,
        preferredWidths: preferredWidths,
        minWidths: minWidths,
        targetWidth: targetWidth, // Option A : on garde la largeur naturelle
        justification: justification,
        eventCounts: eventCounts,
        shouldStretch: systemHasDenseContent,
      );

      final crossStaffGridsByMeasure = <int, Map<int, double>>{};
      for (int k = 0; k < visibleIndices.length; k++) {
        final measureIdx = visibleIndices[k];
        final usableWidthRef =
            finalWidths[k] - contentPaddingLeft - contentPaddingRight;
        crossStaffGridsByMeasure[measureIdx] =
            _computeCrossStaffGridFraction(
          document: document,
          measureIdx: measureIdx,
          usableWidthRef: usableWidthRef,
        );
      }

      final measuresByStaff = <int, List<LayoutedMeasure>>{};

      for (int s = 0; s < document.staves.length; s++) {
        final staff = document.staves[s];
        final staffMeasures = <LayoutedMeasure>[];

        double runningX = sBlockWidth;
        int k = 0;
        int vk = 0;

        int runningLineCount = staff.lineCount;

        while (k < indices.length) {
          final measureIdx = indices[k];
          if (measureIdx >= staff.measures.length) {
            k++;
            continue;
          }

          final sourceMeasure = staff.measures[measureIdx];

          if (sourceMeasure.staffLines != null) {
            runningLineCount = sourceMeasure.staffLines!;
          }
          int effectiveLineCount = runningLineCount;
          for (final ch in sourceMeasure.midMeasureStaffLineChanges) {
            if (ch.lineCount > effectiveLineCount) {
              effectiveLineCount = ch.lineCount;
            }
          }

          final multiRestCount = sourceMeasure.multiRestCount;

          final int measuresToConsume = (multiRestCount > 1)
              ? math.min(multiRestCount, indices.length - k)
              : 1;

          if (multiRestCount > 1) {
            final double totalBlockWidth = finalWidths[vk];
            final int lastIdxInBlock = measureIdx + measuresToConsume - 1;
            final Measure lastSource =
                (lastIdxInBlock < staff.measures.length)
                    ? staff.measures[lastIdxInBlock]
                    : sourceMeasure;

            staffMeasures.add(LayoutedMeasure(
              source: sourceMeasure,
              notes: <LayoutedNote>[],
              keySignature: sourceMeasure.keySignature.fifths,
              x: runningX,
              contentWidth: totalBlockWidth,
              finalWidth: totalBlockWidth,
              divisions: sourceMeasure.divisions,
              totalDivisions: sourceMeasure.totalDivisions,
              multiRestCount: multiRestCount,
              isMultiRestBar: true,
              endBarline: lastSource.rightBarline,
              staffLineCount: effectiveLineCount,
              hiddenLines: sourceMeasure.hiddenLines,
              midMeasureStaffLineChanges:
                  sourceMeasure.midMeasureStaffLineChanges,
              slashNotation: sourceMeasure.slashNotation,
            ));

            runningX += totalBlockWidth;
            k += measuresToConsume;
            vk += 1;
            continue;
          }

          final finalWidth = finalWidths[vk];

          double dynamicLeftPadding = contentPaddingLeft;
          if (sourceMeasure.showKeySignature) {
            dynamicLeftPadding += _keySignatureWidth(
              sourceMeasure.keySignature.alterationCount,
            );
          }

          double midKeysigReserved = 0.0;
          for (final kc in sourceMeasure.midMeasureKeyChanges) {
            midKeysigReserved += _keySignatureWidth(
              kc.keySignature.alterationCount,
            );
            if (kc.keySignature.cancel != null) {
              midKeysigReserved +=
                  kc.keySignature.cancel!.count *
                      ScoreCraftConstants.staffLineSpacing *
                      1.45;
            }
            midKeysigReserved += 12.0;
          }

          final contentWidth = finalWidth -
              dynamicLeftPadding -
              contentPaddingRight -
              midKeysigReserved;
          final divisions = sourceMeasure.divisions;

          final clefList = effectiveClefsByStaff[s];
          final ClefType effectiveClef =
              (clefList != null && measureIdx < clefList.length)
                  ? clefList[measureIdx]
                  : staff.clef;

          final notes = _layoutNotesInsideMeasure(
            measure: sourceMeasure,
            contentWidth: contentWidth,
            contentPaddingLeft: dynamicLeftPadding,
            staffClef: effectiveClef,
            divisions: divisions,
            keySignatureFifths: sourceMeasure.keySignature.fifths,
            lineCount: effectiveLineCount,
            crossStaffGrid: crossStaffGridsByMeasure[measureIdx],
          );

          staffMeasures.add(LayoutedMeasure(
            source: sourceMeasure,
            notes: notes,
            keySignature: sourceMeasure.keySignature.fifths,
            x: runningX,
            contentWidth: contentWidth,
            finalWidth: finalWidth,
            divisions: divisions,
            totalDivisions: sourceMeasure.totalDivisions,
            multiRestCount: 1,
            isMultiRestBar: false,
            staffLineCount: effectiveLineCount,
            hiddenLines: sourceMeasure.hiddenLines,
            midMeasureStaffLineChanges:
                sourceMeasure.midMeasureStaffLineChanges,
            slashNotation: sourceMeasure.slashNotation,
          ));

          runningX += finalWidth;
          k += 1;
          vk += 1;
        }

        measuresByStaff[s] = staffMeasures;
      }

      final double topOverhang = _predictSystemTopOverhang(
        document: document,
        indices: indices,
        effectiveClefsByStaff: effectiveClefsByStaff,
      );
      final double bottomOverhang = _computeSystemBottomOverhang(
        measuresByStaff: measuresByStaff,
        lineSpacing: ScoreCraftConstants.staffLineSpacing,
      );

      final yLayout = _computeAdaptiveStaffPositions(
        document: document,
        measuresByStaff: measuresByStaff,
        systemTopY: currentY + topOverhang,
      );

      final layoutedStaves = <LayoutedStaff>[];
      for (int s = 0; s < document.staves.length; s++) {
        final staff = document.staves[s];

        final int staffLineCount = _maxLineCountOfStaff(
          measures: measuresByStaff[s] ?? [],
          defaultCount: staff.lineCount,
        );

        layoutedStaves.add(LayoutedStaff(
          globalStaffIndex: staff.staffIndex,
          partStaffIndex: staff.partStaffIndex,
          partId: staff.partId,
          measures: measuresByStaff[s] ?? [],
          yTopLine: yLayout.staffTopLines[s] ?? (currentY + topOverhang),
          lineSpacing: ScoreCraftConstants.staffLineSpacing,
          lineCount: staffLineCount,
        ));
      }

      final double visualTop = currentY;
      final double visualBottom = yLayout.systemBottomY + bottomOverhang;

      double maxRunningX = sBlockWidth;
      for (final measures in measuresByStaff.values) {
        if (measures.isEmpty) continue;
        final last = measures.last;
        final double endX = last.x + last.finalWidth;
        if (endX > maxRunningX) maxRunningX = endX;
      }
      final double effectiveWidth = maxRunningX;

      systems.add(LayoutedSystem(
        staves: layoutedStaves,
        startBlockWidth: sBlockWidth,
        yTop: visualTop,
        yBottom: visualBottom,
        effectiveWidth: effectiveWidth,
      ));

      const double airBuffer = 0.0;
      const double minSystemSpacing = 20.0;

      double nextTopOverhang = 0.0;
      if (sysIdx + 1 < systemIndices.length) {
        nextTopOverhang = _predictSystemTopOverhang(
          document: document,
          indices: systemIndices[sysIdx + 1],
          effectiveClefsByStaff: effectiveClefsByStaff,
        );
      }

      final double espaceEntrePortees = math.max(
        minSystemSpacing,
        bottomOverhang + nextTopOverhang + airBuffer,
      );

      currentY = yLayout.systemBottomY +
          espaceEntrePortees -
          nextTopOverhang;
    }

    return systems;
  }

  static List<List<int>> _collectSystemSequential({
    required int totalMeasures,
    required List<double> measureWidths,
    required List<int> multiRestCounts,
    required double firstSystemUsableWidth,
    required double otherSystemUsableWidth,
    required Set<int> forcedBreaks,
  }) {
    if (totalMeasures == 0) return [];

    final systems = <List<int>>[];
    int i = 0;
    bool isFirstSystem = true;

    while (i < totalMeasures) {
      final avail = isFirstSystem
          ? firstSystemUsableWidth
          : otherSystemUsableWidth;

      final system = <int>[];
      double width = 0.0;

      while (i < totalMeasures) {
        if (forcedBreaks.contains(i) && system.isNotEmpty) break;

        final int mrc = (i < multiRestCounts.length) ? multiRestCounts[i] : 1;
        final int measuresInBlock = (mrc > 1) ? mrc : 1;

        double blockWidth;
        if (mrc > 1) {
          blockWidth = 200.0;
        } else {
          blockWidth = 0.0;
          for (int m = 0; m < measuresInBlock && (i + m) < totalMeasures; m++) {
            blockWidth += measureWidths[i + m];
          }
        }

        final bool fits = width + blockWidth <= avail;
        if (!fits && system.isNotEmpty) break;

        for (int m = 0; m < measuresInBlock && (i + m) < totalMeasures; m++) {
          system.add(i + m);
        }
        width += blockWidth;
        i += measuresInBlock;

        if (i >= totalMeasures) break;
      }

      if (system.isEmpty) {
        system.add(i);
        i++;
      }

      systems.add(system);
      isFirstSystem = false;
    }

    return systems;
  }

  static Measure? _getFirstMeasureOfSystem({
    required ScoreDocument document,
    required List<int> indices,
  }) {
    if (indices.isEmpty) return null;
    final firstIdx = indices.first;
    if (document.staves.isEmpty) return null;
    final firstStaff = document.staves.first;
    if (firstIdx >= firstStaff.measures.length) return null;
    return firstStaff.measures[firstIdx];
  }

  static List<double> _justifyWidths({
    required List<int> indices,
    required List<double> preferredWidths,
    required List<double> minWidths,
    required double targetWidth,
    required Justification justification,
    required List<int> eventCounts,
    required bool shouldStretch,
  }) {
    final preferred = indices.map((i) => preferredWidths[i]).toList();
    final mins = indices.map((i) => minWidths[i]).toList();
    final counts = indices.map((i) => eventCounts[i]).toList();

    final realMins = mins
        .map((m) => m + contentPaddingLeft + contentPaddingRight)
        .toList();

    if (indices.isEmpty) return [];

    final totalPref = preferred.fold<double>(0, (s, w) => s + w);
    final totalRealMin = realMins.fold<double>(0, (s, w) => s + w);

    if (totalRealMin > targetWidth) {
      final ratio = targetWidth / totalRealMin;
      final result = realMins.map((w) => w * ratio).toList();
      _normalizeToTarget(result, targetWidth);
      return result;
    }

    if (totalPref > targetWidth) {
      final factor = targetWidth / totalPref;
      final result = <double>[];
      for (int i = 0; i < indices.length; i++) {
        final compressed = preferred[i] * factor;
        result.add(math.max(compressed, realMins[i]));
      }
      _normalizeToTarget(result, targetWidth);
      return result;
    }

    final extra = targetWidth - totalPref;

    final weights = counts
        .map((c) => math.pow(c.toDouble(), 1.4).toDouble())
        .toList();
    final totalWeight = weights.fold<double>(0, (s, w) => s + w);

    final raw = <double>[];
    for (int i = 0; i < indices.length; i++) {
      final share = totalWeight > 0 ? (weights[i] / totalWeight) * extra : 0;
      raw.add(preferred[i] + share);
    }

    final capped = <double>[];
    for (int i = 0; i < indices.length; i++) {
      double w = raw[i];
      if (counts[i] <= 1) {
        if (w > 110.0) w = 110.0;
      } else if (counts[i] <= 2) {
        if (w > 180.0) w = 180.0;
      }
      capped.add(w);
    }

    final sumCapped = capped.fold<double>(0, (s, w) => s + w);
    final leftover = targetWidth - sumCapped;

    if (leftover > 0.5) {
      final eligibleIndices = <int>[];
      final eligibleWeights = <double>[];
      for (int i = 0; i < counts.length; i++) {
        if (counts[i] > 2) {
          eligibleIndices.add(i);
          eligibleWeights.add(weights[i]);
        }
      }
      final totalEligibleWeight =
          eligibleWeights.fold<double>(0, (s, w) => s + w);

      if (totalEligibleWeight > 0) {
        for (int j = 0; j < eligibleIndices.length; j++) {
          final i = eligibleIndices[j];
          capped[i] += (eligibleWeights[j] / totalEligibleWeight) * leftover;
        }
      } else {
        final totalW = weights.fold<double>(0, (s, w) => s + w);
        if (totalW > 0) {
          for (int i = 0; i < capped.length; i++) {
            capped[i] += (weights[i] / totalW) * leftover;
          }
        }
      }
    }

    _normalizeToTarget(capped, targetWidth);
    return capped;
  }

  static double _estimateMeasureWidth(Measure measure) {
    if (measure.multiRestCount > 1) return 200.0;

    final events = _allEventsOfMeasure(measure);
    if (events.isEmpty) return 80.0;

    final double pixelsPerSp = ScoreCraftConstants.staffLineSpacing;

    double totalWeight = 0.0;
    for (final event in events) {
      totalWeight += _eventWeight(event);
    }

    double width = totalWeight * pixelsPerSp + 40.0;

    if (measure.showKeySignature) {
      width += _keySignatureWidth(measure.keySignature.alterationCount);
    }

    for (final kc in measure.midMeasureKeyChanges) {
      width += _keySignatureWidth(kc.keySignature.alterationCount);
      if (kc.keySignature.cancel != null) {
        width += kc.keySignature.cancel!.count *
            ScoreCraftConstants.staffLineSpacing *
            1.45;
      }
      width += 12.0;
    }

    return width.clamp(80.0, 1200.0);
  }

  static List<MusicEvent> _allEventsOfMeasure(Measure measure) {
    final all = <MusicEvent>[];
    for (final voice in measure.voices) {
      all.addAll(voice.events);
    }
    return all;
  }

  static List<LayoutedNote> _layoutNotesInsideMeasure({
    required Measure measure,
    required double contentWidth,
    required double contentPaddingLeft,
    required ClefType staffClef,
    required int divisions,
    required int keySignatureFifths,
    required int lineCount,
    Map<int, double>? crossStaffGrid,
  }) {
    final notes = <LayoutedNote>[];

    final bool isMultiVoice = measure.voices
        .where((v) => v.events.isNotEmpty)
        .length > 1;

    final allEventsWithTp = <_TimedEvent>[];
    for (final voice in measure.voices) {
      for (final event in voice.events) {
        allEventsWithTp.add(_TimedEvent(
          event: event,
          voiceIndex: voice.voiceIndex,
        ));
      }
    }

    if (allEventsWithTp.isEmpty) return notes;

    allEventsWithTp.sort(
      (a, b) => a.event.timePosition.compareTo(b.event.timePosition),
    );

    final groups = <_TpGroup>[];
    for (final te in allEventsWithTp) {
      if (groups.isEmpty ||
          groups.last.timePosition != te.event.timePosition) {
        groups.add(_TpGroup(
          timePosition: te.event.timePosition,
          events: [te],
        ));
      } else {
        groups.last.events.add(te);
      }
    }

    double totalWeight = 0.0;
    for (final g in groups) {
      double maxW = 0.0;
      for (final te in g.events) {
        final w = _eventWeight(te.event);
        if (w > maxW) maxW = w;
      }
      g.weight = maxW;
      totalWeight += maxW;
    }

    if (totalWeight <= 0) return notes;

    final double pixelsPerSp = ScoreCraftConstants.staffLineSpacing;
    final double trailingPaddingPx = trailingPaddingSp * pixelsPerSp;
    final double usableWidth = math.max(
      contentWidth - trailingPaddingPx,
      contentWidth * 0.5,
    );

    if (crossStaffGrid != null && crossStaffGrid.isNotEmpty) {
      for (final g in groups) {
        final double fraction = crossStaffGrid[g.timePosition] ?? 0.5;
        g.x = contentPaddingLeft + fraction * usableWidth;
      }
    } else {
      double cumulativeWeight = 0.0;
      for (final g in groups) {
        final double centerWeight = cumulativeWeight + g.weight / 2;
        final double xRelative = (centerWeight / totalWeight) * usableWidth;
        g.x = contentPaddingLeft + xRelative;
        cumulativeWeight += g.weight;
      }
    }

    if (measure.midMeasureKeyChanges.isNotEmpty) {
      final Map<int, double> keysigWidthAtTp = {};
      for (final kc in measure.midMeasureKeyChanges) {
        double w = _keySignatureWidth(kc.keySignature.alterationCount);
        if (kc.keySignature.cancel != null) {
          w += kc.keySignature.cancel!.count *
              ScoreCraftConstants.staffLineSpacing *
              1.45;
        }
        w += 12.0;
        keysigWidthAtTp[kc.timePosition] =
            (keysigWidthAtTp[kc.timePosition] ?? 0.0) + w;
      }

      double cumulativeShift = 0.0;
      for (final g in groups) {
        final keysigW = keysigWidthAtTp[g.timePosition];
        if (keysigW != null) cumulativeShift += keysigW;
        g.x += cumulativeShift;
      }
    }

    if (crossStaffGrid == null) {
      for (int i = 1; i < groups.length; i++) {
        double rightHalfPrev = 0.0;
        for (final te in groups[i - 1].events) {
          final h = _visualRightHalfWidthSp(te.event);
          if (h > rightHalfPrev) rightHalfPrev = h;
        }

        double leftHalfCurr = 0.0;
        for (final te in groups[i].events) {
          final h = _visualLeftHalfWidthSp(te.event);
          if (h > leftHalfCurr) leftHalfCurr = h;
        }

        final double requiredSp = math.max(
          minEventSpacingSp,
          rightHalfPrev + leftHalfCurr,
        );

        final double requiredPx = requiredSp * pixelsPerSp;
        final double minX = groups[i - 1].x + requiredPx;
        if (groups[i].x < minX) {
          groups[i].x = minX;
        }
      }

      if (groups.isNotEmpty) {
        final double startX = groups.first.x;
        final double lastX = groups.last.x;
        final double limitX =
            contentPaddingLeft + contentWidth - pixelsPerSp * 0.5;

        if (lastX > limitX) {
          final double span = lastX - startX;
          final double targetSpan = limitX - startX;
          double factor = span > 0 ? targetSpan / span : 1.0;

          if (factor < _minRedistributionFactor) {
            factor = _minRedistributionFactor;
          }

          for (final g in groups) {
            g.x = startX + (g.x - startX) * factor;
          }
        }
      }
    }

    for (final g in groups) {
      for (final te in g.events) {
        final event = te.event;
        final voiceIndex = te.voiceIndex;

        double x = g.x;

        if (event is NoteEvent && event.isGrace) {
          final graces = g.events
              .where((e) => e.event is NoteEvent && (e.event as NoteEvent).isGrace)
              .toList();
          final int graceIndex = graces.indexOf(te);

          double offsetSp = 2.5;

          for (int i = graceIndex + 1; i < graces.length; i++) {
            final nextGrace = graces[i].event as NoteEvent;
            bool hasAcc = false;
            if (nextGrace.pitches.isNotEmpty) {
              final p = nextGrace.pitches.first;
              if (p.accidentalDisplay != Accidental.none) {
                hasAcc = true;
              } else {
                final int keyAlter = _keySignatureAlterForLetter(
                    p.letter, keySignatureFifths);
                if (p.alter != keyAlter) hasAcc = true;
              }
            }

            final BeamType? beam = nextGrace.beams[1];
            final bool isBeamed = beam != null && beam != BeamType.none;
            final double baseGap = isBeamed ? 3.0 : 1.5;

            offsetSp += baseGap + (hasAcc ? 1.2 : 0.0);
          }

          x -= offsetSp * ScoreCraftConstants.staffLineSpacing;
        }

        if (event is RestEvent) {
          double yLine;

          if (event.displayStep != null && event.displayOctave != null) {
            final letter = _stepToNoteLetter(event.displayStep!);
            if (letter != null) {
              final pitch = Pitch(
                letter: letter,
                octave: event.displayOctave!,
              );
              yLine = PitchPositioner.pitchToYLine(
                pitch, staffClef,
                lineCount: lineCount,
              );

              if (event.durationType == DurationType.whole) {
                yLine -= 1.0;
              } else if (event.durationType == DurationType.half) {
                yLine -= 0.6;
              }
            } else {
              yLine = _restYLine(
                event.durationType,
                isMeasureRest: event.isMeasureRest,
                lineCount: lineCount,
              );
            }
          } else {
            yLine = _restYLine(
              event.durationType,
              isMeasureRest: event.isMeasureRest,
              lineCount: lineCount,
            );
          }

          final restId =
              'rest_${measure.id}_${voiceIndex}_${event.timePosition}';

          final double xForRest = event.isMeasureRest
              ? contentPaddingLeft + usableWidth * 0.5
              : x;

          notes.add(LayoutedNote(
            id: restId,
            eventId: restId,
            event: event,
            x: xForRest,
            yLine: yLine,
            isRest: true,
            voiceIndex: voiceIndex,
            timePosition: event.timePosition,
            duration: event.duration,
            isInMultiVoiceMeasure: isMultiVoice,
          ));
        } else if (event is NoteEvent) {
          final int nPitches = event.pitches.length;
          final List<double> xOffsets = List<double>.filled(nPitches, 0.0);

          if (nPitches > 1) {
            final List<double> yLinesTmp = [];
            for (int k = 0; k < nPitches; k++) {
              yLinesTmp.add(PitchPositioner.pitchToYLine(
                event.pitches[k], staffClef,
                lineCount: lineCount,
              ));
            }

            final List<int> sortedByYLine =
                List<int>.generate(nPitches, (i) => i);
            sortedByYLine
                .sort((a, b) => yLinesTmp[a].compareTo(yLinesTmp[b]));

            final double baseOffset =
                ScoreCraftConstants.staffLineSpacing * 1.6;
            final bool stemUpForChord = _shouldStemBeUpForLayout(
              event, staffClef, lineCount,
            );
            final double initialDir = stemUpForChord ? 1.0 : -1.0;

            int clusterCounter = 0;
            for (int k = 1; k < sortedByYLine.length; k++) {
              final int idxA = sortedByYLine[k - 1];
              final int idxB = sortedByYLine[k];
              final double diff = yLinesTmp[idxB] - yLinesTmp[idxA];
              if ((diff - 0.5).abs() < 0.01) {
                final double dir =
                    (clusterCounter % 2 == 0) ? initialDir : -initialDir;
                xOffsets[idxA] += baseOffset * dir;
                clusterCounter++;
              }
            }
          }

          final List<double> accOffsets = List<double>.filled(nPitches, 0.0);

          if (nPitches > 1) {
            final List<double> yLinesForAcc = [];
            for (int k = 0; k < nPitches; k++) {
              yLinesForAcc.add(PitchPositioner.pitchToYLine(
                event.pitches[k], staffClef,
                lineCount: lineCount,
              ));
            }

            final List<int> sortedForAcc =
                List<int>.generate(nPitches, (i) => i);
            sortedForAcc
                .sort((a, b) => yLinesForAcc[a].compareTo(yLinesForAcc[b]));

            const double stepSp = 2;
            const double thresholdSp = 2.0;

            int totalColumns = 0;
            for (int k = 1; k < sortedForAcc.length; k++) {
              final double diff = yLinesForAcc[sortedForAcc[k]] -
                  yLinesForAcc[sortedForAcc[k - 1]];
              if (diff < thresholdSp) totalColumns++;
            }

            int columnIdx = totalColumns;
            for (int k = 0; k < sortedForAcc.length; k++) {
              if (k == 0) {
                accOffsets[sortedForAcc[k]] =
                    -columnIdx * stepSp * ScoreCraftConstants.staffLineSpacing;
              } else {
                final double diff = yLinesForAcc[sortedForAcc[k]] -
                    yLinesForAcc[sortedForAcc[k - 1]];
                if (diff < thresholdSp) {
                  columnIdx--;
                }
                accOffsets[sortedForAcc[k]] =
                    -columnIdx * stepSp * ScoreCraftConstants.staffLineSpacing;
              }
            }
          }

          for (int p = 0; p < nPitches; p++) {
            final pitch = event.pitches[p];
            final yLine = PitchPositioner.pitchToYLine(
              pitch, staffClef,
              lineCount: lineCount,
            );

            Accidental? displayAccidental;
            if (pitch.accidentalDisplay != Accidental.none) {
              displayAccidental = pitch.accidentalDisplay;
            } else {
              final int keyAlter = _keySignatureAlterForLetter(
                pitch.letter,
                keySignatureFifths,
              );
              if (pitch.alter != keyAlter) {
                displayAccidental = _accidentalForAlter(pitch.alter);
              }
            }

            notes.add(LayoutedNote(
              id: p == 0 ? event.id : '${event.id}_p$p',
              eventId: event.id,
              event: event,
              x: x + xOffsets[p],
              yLine: yLine,
              pitch: pitch,
              isChordMember: p > 0,
              displayAccidental: displayAccidental,
              accidentalCautionary: pitch.isCautionary,
              accidentalEditorial: pitch.isEditorial,
              accidentalOffsetX: accOffsets[p],
              voiceIndex: voiceIndex,
              timePosition: event.timePosition,
              duration: event.duration,
              isGrace: event.isGrace,
              isInMultiVoiceMeasure: isMultiVoice,
            ));
          }
        }
      }
    }

    return notes;
  }

  static double _restYLine(
    DurationType type, {
    bool isMeasureRest = false,
    int lineCount = 5,
  }) {
    double baseLine;
    if (isMeasureRest) {
      baseLine = 1.0;
    } else {
      switch (type) {
        case DurationType.whole:
          baseLine = 1.0;
          break;
        case DurationType.half:
        case DurationType.quarter:
        case DurationType.eighth:
        case DurationType.sixteenth:
        case DurationType.thirtySecond:
        case DurationType.sixtyFourth:
          baseLine = 2.0;
          break;
        default:
          baseLine = 2.0;
      }
    }

    if (lineCount == 5) return baseLine;

    final double scale = (lineCount - 1) / 4.0;
    return baseLine * scale;
  }

  static _YLayout _computeAdaptiveStaffPositions({
    required ScoreDocument document,
    required Map<int, List<LayoutedMeasure>> measuresByStaff,
    required double systemTopY,
  }) {
    final n = document.staves.length;
    if (n == 0) {
      return _YLayout(staffTopLines: {}, systemBottomY: systemTopY);
    }

    const double lineSpacing = ScoreCraftConstants.staffLineSpacing;

    final lineCounts = <int, int>{};
    for (int s = 0; s < n; s++) {
      lineCounts[s] = _maxLineCountOfStaff(
        measures: measuresByStaff[s] ?? [],
        defaultCount: document.staves[s].lineCount,
      );
    }

    final staffTopLines = <int, double>{};
    double currentY = systemTopY;

    for (int s = 0; s < n; s++) {
      staffTopLines[s] = currentY;

      final int thisLineCount = lineCounts[s] ?? 5;
      final double staffHeight = (thisLineCount - 1) * lineSpacing;

      if (s < n - 1) {
        final int nextLineCount = lineCounts[s + 1] ?? 5;

        double spacing = _computeSpacingBetweenStaves(
          upperMeasures: measuresByStaff[s] ?? [],
          lowerMeasures: measuresByStaff[s + 1] ?? [],
          lineSpacing: lineSpacing,
          upperLineCount: thisLineCount,
          lowerLineCount: nextLineCount,
        );

        if (thisLineCount <= 2) {
          final double minGapForClef = lineSpacing * 5.0;
          if (spacing < minGapForClef) spacing = minGapForClef;
        }

        currentY += staffHeight + spacing;
      }
    }

    final int lastLineCount = lineCounts[n - 1] ?? 5;
    final double lastStaffHeight = (lastLineCount - 1) * lineSpacing;
    final double systemBottomY = staffTopLines[n - 1]! + lastStaffHeight;

    return _YLayout(
      staffTopLines: staffTopLines,
      systemBottomY: systemBottomY,
    );
  }

  static double _computeSpacingBetweenStaves({
    required List<LayoutedMeasure> upperMeasures,
    required List<LayoutedMeasure> lowerMeasures,
    required double lineSpacing,
    int upperLineCount = 5,
    int lowerLineCount = 5,
  }) {
    int belowDirsCount = 0;
    for (final measure in upperMeasures) {
      for (final d in measure.source.directions) {
        if (d.placement == 'below' && _isDrawableDirection(d)) {
          belowDirsCount++;
        }
      }
    }

    double spacingFromDirections = 0.0;
    if (belowDirsCount > 0) {
      spacingFromDirections =
          lineSpacing * (3.0 + (belowDirsCount - 1) * 1.6 + 1.5);
    }

    double spacing = math.max(minInterStaffSpacing, spacingFromDirections);

    final double upperBottomYLine = (upperLineCount - 1).toDouble();

    double lowestYUpper = upperBottomYLine;
    for (final measure in upperMeasures) {
      for (final note in measure.notes) {
        if (note.isRest) continue;
        if (note.yLine > lowestYUpper) lowestYUpper = note.yLine;
      }
    }
    final upperBottomPx =
        math.max(0.0, lowestYUpper - upperBottomYLine) * lineSpacing;

    final double upperLyricsHeight = computeBottomOverhang(
      measures: upperMeasures,
      lineSpacing: lineSpacing,
    );

    double highestYLower = 0.0;
    for (final measure in lowerMeasures) {
      for (final note in measure.notes) {
        if (note.isRest) continue;
        if (note.yLine < highestYLower) highestYLower = note.yLine;
      }
    }
    final lowerTopPx = math.max(0.0, -highestYLower) * lineSpacing;

    const double safeMargin = 25.0;
    final needed = upperBottomPx + upperLyricsHeight + lowerTopPx + safeMargin;

    if (needed > spacing) spacing = needed;

    return spacing;
  }
  static double computeBottomOverhang({
    required List<LayoutedMeasure> measures,
    required double lineSpacing,
  }) {
    int maxVerse = 0;
    int directionsBelow = 0;
    double maxNotationDepth = 0.0;

    for (final measure in measures) {
      for (final note in measure.notes) {
        if (note.isRest) continue;
        if (note.event is! NoteEvent) continue;
        final ne = note.event as NoteEvent;

        for (final lyric in note.effectiveLyrics) {
          if (!lyric.isAbove && lyric.number > maxVerse) {
            maxVerse = lyric.number;
          }
        }

        double localNotationDepth = 0.0;
        for (final f in ne.notations.fermatas) {
          if (f.type == 'inverted' || f.type == 'below') {
            localNotationDepth = math.max(localNotationDepth, 3.0);
          }
        }
        for (final m in ne.notations.accidentalMarks) {
          if (m.placement == 'below') {
            localNotationDepth = math.max(localNotationDepth, 2.0);
          }
        }

        for (final art in ne.articulations) {
          bool isBelow = art.placement == 'below';
          if (art.placement == null) {
            isBelow = !StemDirectionResolver.shouldStemBeUp(note);
          }
          if (isBelow) {
             localNotationDepth = math.max(localNotationDepth, 2.0);
          }
        }

        final textTypes = ['fingering', 'pluck', 'fret', 'string'];
        int belowTechsCount = 0;
        for (final tech in ne.notations.technicals) {
          final isBelow = tech.placement == 'below' || 
                          (tech.placement != 'above' && !StemDirectionResolver.shouldStemBeUp(note));
          if (isBelow) {
            if (textTypes.contains(tech.type)) {
              if (belowTechsCount == 0) belowTechsCount++; 
            } else {
              belowTechsCount++;
            }
          }
        }
        if (belowTechsCount > 0) {
          localNotationDepth = math.max(localNotationDepth, 3.2 + (belowTechsCount - 1) * 2.8);
        }

        if (localNotationDepth * lineSpacing > maxNotationDepth) {
          maxNotationDepth = localNotationDepth * lineSpacing;
        }
      }

      final List<DirectionEvent> dirs = measure.source.directions;
      int countBelow = 0;
      for (final d in dirs) {
        if (d.placement == 'below' && _isDrawableDirection(d)) countBelow++;
      }
      if (countBelow > directionsBelow) directionsBelow = countBelow;
    }

    final dirHeight = directionsBelow > 0
        ? lineSpacing * (3.0 + directionsBelow * 1.6) + lineSpacing * 0.3
        : 0.0;

    final verseHeight = maxVerse > 0
        ? lineSpacing * 3.5 + (maxVerse - 1) * lineSpacing * 3.0 + lineSpacing * 2.0
        : 0.0;

    return maxNotationDepth + verseHeight + dirHeight;
  }
  static double _computeTupletBottomOverhang({
    required List<LayoutedMeasure> measures,
    required double lineSpacing,
  }) {
    const double tupletReservedSp = 4.0;

    bool hasStemDownTuplet = false;

    for (final measure in measures) {
      for (final event in measure.source.voices
          .expand((v) => v.events)) {
        if (event is! NoteEvent) continue;
        if (!event.tupletStart) continue;

        bool stemUp;
        switch (event.stemDirection) {
          case StemDirection.up:
            stemUp = true;
            break;
          case StemDirection.down:
          case StemDirection.none:
            stemUp = false;
            break;
          case StemDirection.auto:
            if (event.pitches.isEmpty) {
              stemUp = false;
            } else {
              final p = event.pitches.first;
              final int diatonic = p.octave * 7 +
                  'CDEFGAB'.indexOf(p.letter.name);
              stemUp = diatonic < 31;
            }
            break;
        }

        if (!stemUp) {
          hasStemDownTuplet = true;
          break;
        }
      }
      if (hasStemDownTuplet) break;
    }

    return hasStemDownTuplet
        ? lineSpacing * tupletReservedSp
        : 0.0;
  }

  static double _computeSystemBottomOverhang({
    required Map<int, List<LayoutedMeasure>> measuresByStaff,
    required double lineSpacing,
  }) {
    if (measuresByStaff.isEmpty) return 0.0;

    const double clefOverhangFactor = 0.4;
    double maxOverhang = clefOverhangFactor * lineSpacing;

    for (final entry in measuresByStaff.entries) {
      final measures = entry.value;
      if (measures.isEmpty) continue;

      final int lastLineCount = measures.last.staffLineCount;
      final double bottomLineYLine = (lastLineCount - 1).toDouble();

      double maxVisualYLine = bottomLineYLine;
      for (final measure in measures) {
        for (final note in measure.notes) {
          if (note.isRest) continue;
          
          double noteBottom = note.yLine;
          
          if (note.event.durationType.needsStem) {
            final stemUp = StemDirectionResolver.shouldStemBeUp(note);
            if (!stemUp) {
              noteBottom += ScoreCraftConstants.stemLengthFactor;
            }
          }
          
          if (noteBottom > maxVisualYLine) maxVisualYLine = noteBottom;
        }
      }

      final noteOverhang = maxVisualYLine > bottomLineYLine
          ? (maxVisualYLine - bottomLineYLine) * lineSpacing
          : 0.0;

      final lyricsHeight = computeBottomOverhang(
        measures: measures,
        lineSpacing: lineSpacing,
      );

      final tupletHeight = _computeTupletBottomOverhang(
        measures: measures,
        lineSpacing: lineSpacing,
      );

      final total = noteOverhang + lyricsHeight + tupletHeight;
      if (total > maxOverhang) maxOverhang = total;
    }

    return maxOverhang;
  }
  static double _computeStartBlockWidth({
    Measure? firstMeasure,
    bool isFirstSystem = false,
  }) {
    const double scale = ScoreCraftConstants.scale;
    if (firstMeasure == null) return 80.0;

    double width = 0;
    width += 26.0 * scale + 4;

    final displayCount = firstMeasure.keySignature.alterationCount;
    if (displayCount > 0) {
      width += ScoreCraftConstants.staffLineSpacing * 1.45 * displayCount + 8.0;
    }

    final bool needsTime =
        isFirstSystem || firstMeasure.showTimeSignature;
    if (needsTime) {
      width += 20.0 * scale;
    }

    width += 8.0;
    return width;
  }
}

class _YLayout {
  final Map<int, double> staffTopLines;
  final double systemBottomY;

  _YLayout({
    required this.staffTopLines,
    required this.systemBottomY,
  });
}

class _TimedEvent {
  final MusicEvent event;
  final int voiceIndex;
  _TimedEvent({required this.event, required this.voiceIndex});
}

class _TpGroup {
  final int timePosition;
  final List<_TimedEvent> events;
  double weight = 0.0;
  double x = 0.0;
  _TpGroup({required this.timePosition, required this.events});
}