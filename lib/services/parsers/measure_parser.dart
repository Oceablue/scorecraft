// lib/services/parsers/measure_parser.dart
// ============================================================================
// PARSEUR DE MESURE MULTI-PORTÉE — v2c-31a-31
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/score/measure.dart';
import '../../models/score/voice.dart';
import '../../models/events/music_event.dart';
import '../../models/events/direction.dart';
import '../../models/events/notations.dart';
import '../../models/enums/music_enums.dart';
import 'attributes_parser.dart';
import 'note_parser.dart';
import 'direction_parser.dart';
import 'common.dart';

// ============================================================================
// HOLDER MUTABLE POUR L'ÉTAT SLASH
// ============================================================================

class SlashNotationState {
  SlashNotation? current;

  SlashNotationState([this.current]);

  @override
  String toString() => 'SlashNotationState(current: $current)';
}

class MeasureParser {
  static Map<int, Measure> parseMultiStaff({
    required xml.XmlElement measureNode,
    required int measureNumber,
    required int measureUniqueIndex,
    required int firstStaffGlobalIndex,
    required int stavesInPart,
    required Map<int, ClefType> currentClefs,
    required Map<int, KeySignature> currentKeys,
    required Map<int, TimeSignature> currentTimes,
    required Map<int, int> currentStaffLines,
    required int currentDivisions,
    required SlashNotationState currentSlash,
  }) {
    final widthStr = measureNode.getAttribute('width');
    final width = widthStr != null ? double.tryParse(widthStr) ?? 200.0 : 200.0;

    final clefs = Map<int, ClefType>.from(currentClefs);
    final keys = Map<int, KeySignature>.from(currentKeys);
    final timesByStaff = Map<int, TimeSignature>.from(currentTimes);

    int divisions = currentDivisions;

    final explicitClefChanges = <int, ClefType>{};
    final explicitKeyChanges = <int, KeySignature>{};
    final explicitTimeChangeStaffs = <int>{};

    final midKeyChangesByStaff = <int, List<KeyChange>>{};

    final explicitStaffLineChanges = <int, int>{};
    final midStaffLineChanges = <int, List<MidMeasureStaffLineChange>>{};
    final hiddenLinesByStaff = <int, Set<int>>{};

    int multiRestCount = 1;

    SlashNotation? slashForThisMeasure = currentSlash.current;

    int cursor = 0;

    final eventsByStaffVoice = <int, Map<int, List<MusicEvent>>>{};
    final directionsByStaff = <int, List<DirectionEvent>>{};
    final lastNoteIndexByStaffVoice = <String, int>{};

    for (final child in measureNode.children) {
      if (child is! xml.XmlElement) continue;

      switch (child.name.local) {
        case 'attributes':
          final parsed = AttributesParser.parse(child);

          parsed.clefs.forEach((staffNum, clef) {
            clefs[staffNum] = clef;
            explicitClefChanges[staffNum] = clef;
          });

          parsed.staffLines.forEach((staffNum, newLineCount) {
            if (cursor > 0) {
              midStaffLineChanges
                  .putIfAbsent(staffNum, () => [])
                  .add(MidMeasureStaffLineChange(
                    timePosition: cursor,
                    lineCount: newLineCount,
                  ));
            } else {
              explicitStaffLineChanges[staffNum] = newLineCount;
            }

            currentStaffLines[staffNum] = newLineCount;
          });

          parsed.hiddenLines.forEach((staffNum, hidden) {
            hiddenLinesByStaff[staffNum] = hidden;
          });

          parsed.keys.forEach((staffNum, key) {
            final shouldPrint = parsed.keysShouldPrint[staffNum] ?? true;

            final previousFifths = keys[staffNum]?.fifths ?? 0;

            if (cursor > 0) {
              final effectiveKey = (key.cancel == null &&
                      previousFifths != key.fifths)
                  ? key.copyWith(cancel: KeyCancel(fifths: previousFifths))
                  : key;

              if (shouldPrint) {
                midKeyChangesByStaff
                    .putIfAbsent(staffNum, () => [])
                    .add(KeyChange(
                      timePosition: cursor,
                      keySignature: effectiveKey,
                    ));
              }

              keys[staffNum] = key;
            } else {
              keys[staffNum] = key;

              if (shouldPrint) {
                explicitKeyChanges[staffNum] = key;
              }
            }
          });

          for (final pts in parsed.timeSignatures) {
            if (pts.staffNumber != null) {
              timesByStaff[pts.staffNumber!] = pts.timeSignature;
              if (pts.shouldPrint) {
                explicitTimeChangeStaffs.add(pts.staffNumber!);
              }
            } else {
              for (int s = 1; s <= stavesInPart; s++) {
                timesByStaff[s] = pts.timeSignature;
                if (pts.shouldPrint) {
                  explicitTimeChangeStaffs.add(s);
                }
              }
            }
          }

          if (parsed.divisions != null && parsed.divisions! > 0) {
            divisions = parsed.divisions!;
          }
          if (parsed.multiRestCount != null) {
            multiRestCount = parsed.multiRestCount!;
          }

          if (parsed.slashDirective != null) {
            final dir = parsed.slashDirective!;

            if (dir.isStart) {
              final newNotation = SlashNotation(
                useStems: dir.useStems,
                slashType: dir.slashType,
              );
              slashForThisMeasure = newNotation;
              currentSlash.current = newNotation;
            } else if (dir.isStop) {
              currentSlash.current = null;
            }
          }
          break;

        case 'note':
          final isChord = child.findElements('chord').isNotEmpty;
          final isGrace = child.findElements('grace').isNotEmpty;

          final totalEvents = eventsByStaffVoice.values.fold<int>(
            0,
            (sum, voices) =>
                sum + voices.values.fold<int>(0, (s, l) => s + l.length),
          );
          final measureId = 'm_${firstStaffGlobalIndex}_$measureUniqueIndex';
          final noteId = 'n_${measureId}_$totalEvents';

          final note = NoteParser.parse(child, 1, forcedId: noteId);
          if (note == null) break;

          final staffNum = note.staffNumber;
          final voiceIdx = note.voiceIndex;
          final currentCursor = cursor;
          final timedNote = note.copyWithBase(timePosition: currentCursor);

          if (timedNote is NoteEvent && isChord) {
            final key = '${staffNum}_$voiceIdx';
            final prevIndex = lastNoteIndexByStaffVoice[key];
            if (prevIndex != null) {
              final voiceList = eventsByStaffVoice[staffNum]![voiceIdx]!;
              final prev = voiceList[prevIndex];
              if (prev is NoteEvent) {
                final TremoloType mergedTremoloType =
                    prev.tremoloType != TremoloType.none
                        ? prev.tremoloType
                        : timedNote.tremoloType;
                final int mergedTremoloCount =
                    prev.tremoloType != TremoloType.none
                        ? prev.tremoloCount
                        : timedNote.tremoloCount;

                // ⬇️ FUSION DES NOTATIONS (Fermata / Arpeggio / Accidental Mark / Ornaments / Technicals) ⬇️
                final mergedFermatas = [...prev.notations.fermatas, ...timedNote.notations.fermatas];
                // v2c-32d : offset du pitchIndex lors du merge (chord parts)
                final int newPitchOffset = prev.pitches.length;
                final mergedArpeggiates = [
                  ...prev.notations.arpeggiates,
                  ...timedNote.notations.arpeggiates.map((a) => ArpeggiateNotation(
                    type: a.type,
                    direction: a.direction,
                    placement: a.placement,
                    pitchIndex: a.pitchIndex + newPitchOffset,
                    number: a.number, // v2c-32e : conserve le number
                  )),
                ];
                final mergedAccMarks = [...prev.notations.accidentalMarks, ...timedNote.notations.accidentalMarks];
                final mergedOrnaments = [...prev.notations.ornaments, ...timedNote.notations.ornaments];
                final mergedTechnicals = [...prev.notations.technicals, ...timedNote.notations.technicals];
                
                final mergedNotations = NoteNotations(
                  fermatas: mergedFermatas,
                  arpeggiates: mergedArpeggiates,
                  accidentalMarks: mergedAccMarks,
                  ornaments: mergedOrnaments,
                  technicals: mergedTechnicals,
                );

                final merged = prev.copyWith(
                  pitches: [...prev.pitches, timedNote.pitches.first],
                  tremoloType: mergedTremoloType,
                  tremoloCount: mergedTremoloCount,
                  notations: mergedNotations,
                );
                voiceList[prevIndex] = merged;
              }
              break;
            }
          }

          eventsByStaffVoice
              .putIfAbsent(staffNum, () => {})
              .putIfAbsent(voiceIdx, () => [])
              .add(timedNote);

          if (timedNote is NoteEvent) {
            final key = '${staffNum}_$voiceIdx';
            lastNoteIndexByStaffVoice[key] =
                eventsByStaffVoice[staffNum]![voiceIdx]!.length - 1;
          }

          if (!isGrace && !isChord) {
            cursor = currentCursor + timedNote.duration;
          }
          break;

        case 'backup':
          cursor = _applyCursorDelta(
            node: child,
            cursor: cursor,
            isBackup: true,
          );
          break;

        case 'forward':
          cursor = _applyCursorDelta(
            node: child,
            cursor: cursor,
            isBackup: false,
          );
          break;

        case 'direction':
          final String? staffStrDir =
              child.findElements('staff').firstOrNull?.innerText;
          final int staffNumDir = int.tryParse(staffStrDir ?? '1') ?? 1;
          final int eventCountForDir =
              eventsByStaffVoice[staffNumDir]?[1]?.length ?? 0;

          final dirs = DirectionParser.parseList(
            child,
            timePosition: cursor,
            eventIndexInVoice: eventCountForDir,
          );
          
          if (dirs.isNotEmpty) {
            directionsByStaff.putIfAbsent(staffNumDir, () => []).addAll(dirs);
          }
          break;

        case 'barline':
        case 'print':
        case 'sound':
        case 'harmony':
        case 'figured-bass':
          break;
      }
    }

    BarlineType leftBarline = BarlineType.none;
    BarlineType rightBarline = BarlineType.single;
    for (final barlineNode in measureNode.findElements('barline')) {
      final location = barlineNode.getAttribute('location') ?? 'right';
      final barStyleNode = barlineNode.findElements('bar-style').firstOrNull;
      if (barStyleNode != null) {
        final barType =
            CommonParserHelpers.parseBarlineType(barStyleNode.innerText);
        if (location == 'left') {
          leftBarline = barType;
        } else if (location == 'right') {
          rightBarline = barType;
        }
      }
    }

    bool hasSystemBreak = false;
    bool pageBreak = false;
    for (final printNode in measureNode.findElements('print')) {
      if (printNode.getAttribute('new-system') == 'yes') hasSystemBreak = true;
      if (printNode.getAttribute('new-page') == 'yes') pageBreak = true;
    }

    final result = <int, Measure>{};

    for (int staffNum = 1; staffNum <= stavesInPart; staffNum++) {
      final globalStaffIndex = firstStaffGlobalIndex + staffNum - 1;
      final measureId = 'm_${globalStaffIndex}_$measureUniqueIndex';

      final voicesForStaff = <Voice>[];
      final staffEvents = eventsByStaffVoice[staffNum];
      if (staffEvents != null) {
        staffEvents.forEach((voiceIdx, events) {
          final sorted = List<MusicEvent>.from(events)
            ..sort((a, b) {
              final tp = a.timePosition.compareTo(b.timePosition);
              if (tp != 0) return tp;
              final aGrace = (a is NoteEvent && a.isGrace) ? 0 : 1;
              final bGrace = (b is NoteEvent && b.isGrace) ? 0 : 1;
              return aGrace.compareTo(bGrace);
            });
          voicesForStaff.add(Voice(voiceIndex: voiceIdx, events: sorted));
        });
      }
      if (voicesForStaff.isEmpty) {
        voicesForStaff.add(const Voice(voiceIndex: 1, events: []));
      }

      final measureClef = explicitClefChanges[staffNum];
      final measureKey =
          explicitKeyChanges[staffNum] ?? keys[staffNum] ?? const KeySignature();
      final measureTime =
          timesByStaff[staffNum] ?? const TimeSignature();

      final int previousFifths = currentKeys[staffNum]?.fifths ?? 0;
      final bool prevCustom = currentKeys[staffNum]?.isCustom ?? false;
      final bool nowCustom = measureKey.isCustom;

      final bool showKeySig = explicitKeyChanges.containsKey(staffNum) &&
          (measureKey.fifths != previousFifths ||
              nowCustom ||
              prevCustom != nowCustom);

      result[staffNum] = Measure(
        id: measureId,
        measureNumber: measureNumber,
        timeSignature: measureTime,
        showTimeSignature: explicitTimeChangeStaffs.contains(staffNum),
        showKeySignature: showKeySig,
        keySignature: measureKey,
        midMeasureKeyChanges:
            midKeyChangesByStaff[staffNum] ?? const [],
        clef: measureClef,
        divisions: divisions,
        multiRestCount: multiRestCount,
        leftBarline: leftBarline,
        rightBarline: rightBarline,
        voices: voicesForStaff,
        directions: directionsByStaff[staffNum] ?? const [],
        hasSystemBreak: hasSystemBreak,
        pageBreak: pageBreak,
        width: width,
        isPickup: false,
        staffLines: explicitStaffLineChanges[staffNum],
        midMeasureStaffLineChanges:
            midStaffLineChanges[staffNum] ?? const [],
        hiddenLines: hiddenLinesByStaff[staffNum] ?? const {},
        slashNotation: slashForThisMeasure,
      );
    }

    currentClefs
      ..clear()
      ..addAll(clefs);
    currentKeys
      ..clear()
      ..addAll(keys);
    for (final entry in midKeyChangesByStaff.entries) {
      final staffNum = entry.key;
      final changes = entry.value;
      if (changes.isNotEmpty) {
        currentKeys[staffNum] = changes.last.keySignature;
      }
    }
    currentTimes
      ..clear()
      ..addAll(timesByStaff);

    return result;
  }
  static int _applyCursorDelta({
    required xml.XmlElement node,
    required int cursor,
    required bool isBackup,
  }) {
    final durationStr = node.findElements('duration').firstOrNull?.innerText;
    final duration = int.tryParse(durationStr ?? '0') ?? 0;

    final newValue = isBackup ? cursor - duration : cursor + duration;
    return newValue < 0 ? 0 : newValue;
  }
}