// lib/services/parsers/part_parser.dart
// ============================================================================
// PARSEUR DE PARTIE MUSICALE — v2c-31a-30
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/score/staff.dart';
import '../../models/score/measure.dart';
import '../../models/enums/music_enums.dart';
import 'measure_parser.dart'; // <── L'IMPORT MANQUANT EST ICI

class PartParser {
  static List<Staff> parsePart(
    xml.XmlElement partNode,
    int firstStaffGlobalIndex,
    String instrumentName,
    String instrumentAbbreviation,
  ) {
    final partId = partNode.getAttribute('id') ?? 'P1';

    final measureNodes = partNode.findElements('measure').toList();
    if (measureNodes.isEmpty) return [];

    int stavesInPart = 1;
    for (final measureNode in measureNodes) {
      final attributesNode =
          measureNode.findElements('attributes').firstOrNull;
      if (attributesNode != null) {
        final stavesNode = attributesNode.findElements('staves').firstOrNull;
        if (stavesNode != null) {
          final value = int.tryParse(stavesNode.innerText.trim());
          if (value != null && value > 0) {
            stavesInPart = value;
            break;
          }
        }
      }
    }

    final currentClefs = <int, ClefType>{};
    final currentKeys = <int, KeySignature>{};
    // v2c-58 : time signature PAR PORTÉE.
    final currentTimes = <int, TimeSignature>{};
    // v2c-79 : nombre de lignes PAR PORTÉE (défaut = 5).
    // ⚠️ Muté EN PLACE par MeasureParser.parseMultiStaff, comme currentTimes.
    final currentStaffLines = <int, int>{};

    // ══════════════════════════════════════════════════════════════════════════
    // v2c-93z : état du mode SLASH (notation rythmique).
    // Persistant cross-mesure (comme currentClefs/currentKeys). Créé ici
    // une seule fois par partie, muté en place par MeasureParser à chaque
    // mesure rencontrant un <measure-style><slash>.
    // ⚠️ Démarre à `null` = aucune mesure en mode slash par défaut.
    // ══════════════════════════════════════════════════════════════════════════
    final currentSlash = SlashNotationState();

    for (int s = 1; s <= stavesInPart; s++) {
      currentClefs[s] = ClefType.treble;
      currentKeys[s] = const KeySignature();
      currentTimes[s] = const TimeSignature();
      currentStaffLines[s] = 5;
    }

    int currentDivisions = 1;

    final measuresByStaff = <int, List<Measure>>{};
    for (int s = 1; s <= stavesInPart; s++) {
      measuresByStaff[s] = [];
    }

    // v2c-82 : compteur séquentiel pour garantir l'unicité des IDs.
    // ⚠️ Le <measure number="N"> de MusicXML peut se répéter (reprises,
    //    cas de test W3C 21b) et ne doit PAS servir de clé d'ID.
    int measureUniqueIndex = 0;

    for (final measureNode in measureNodes) {
      final numberAttr = measureNode.getAttribute('number');
      final measureNumber =
          numberAttr != null ? int.tryParse(numberAttr) ?? 1 : 1;

      final parsedMeasures = MeasureParser.parseMultiStaff(
        measureNode: measureNode,
        measureNumber: measureNumber,
        measureUniqueIndex: measureUniqueIndex,
        firstStaffGlobalIndex: firstStaffGlobalIndex,
        stavesInPart: stavesInPart,
        currentClefs: currentClefs,
        currentKeys: currentKeys,
        currentTimes: currentTimes,
        currentStaffLines: currentStaffLines,
        currentDivisions: currentDivisions,
        currentSlash: currentSlash,
      );

      measureUniqueIndex++;

      if (parsedMeasures.isNotEmpty) {
        final firstMeasure = parsedMeasures.values.first;
        currentDivisions = firstMeasure.divisions;
      }

      for (int s = 1; s <= stavesInPart; s++) {
        final measure = parsedMeasures[s];
        if (measure != null) {
          measuresByStaff[s]!.add(measure);
        }
      }
    }

    final result = <Staff>[];
    for (int s = 1; s <= stavesInPart; s++) {
      final globalStaffIndex = firstStaffGlobalIndex + s - 1;
      final measures = measuresByStaff[s] ?? [];

      final initialClef = measures.isNotEmpty
          ? (measures.first.clef ?? currentClefs[s] ?? ClefType.treble)
          : (currentClefs[s] ?? ClefType.treble);

      final initialKey = measures.isNotEmpty
          ? measures.first.keySignature
          : (currentKeys[s] ?? const KeySignature());

      final int initialLineCount =
          (measures.isNotEmpty && measures.first.staffLines != null)
              ? measures.first.staffLines!
              : 5;

      result.add(Staff(
        id: 'staff_$globalStaffIndex',
        partId: partId,
        partStaffIndex: s,
        staffIndex: globalStaffIndex,
        instrumentName: instrumentName,
        instrumentAbbreviation: instrumentAbbreviation,
        clef: initialClef,
        keySignature: initialKey,
        lineCount: initialLineCount,
        measures: measures,
      ));
    }

    return result;
  }

  static List<Staff> parsePartWithInfo(
    xml.XmlElement partNode,
    int firstStaffGlobalIndex,
    Map<String, Map<String, String>> partInfos,
  ) {
    final partId = partNode.getAttribute('id');
    String instrumentName = 'Instrument $firstStaffGlobalIndex';
    String instrumentAbbreviation = 'Inst.';

    if (partId != null && partInfos.containsKey(partId)) {
      instrumentName = partInfos[partId]?['name'] ?? instrumentName;
      instrumentAbbreviation =
          partInfos[partId]?['abbreviation'] ?? instrumentAbbreviation;
    }

    return parsePart(
      partNode,
      firstStaffGlobalIndex,
      instrumentName,
      instrumentAbbreviation,
    );
  }
}