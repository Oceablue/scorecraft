// lib/services/parsers/staff_parser.dart
// ============================================================================
// PARSEUR DES PORTÉES (MUSICXML) — v2c-79
// ============================================================================
// v2c-79 : StaffLines (enum) → int. On accepte désormais n'importe quelle
//          valeur >= 1 pour <staff-lines> (test W3C 14a).
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/enums/music_enums.dart';
import '../../models/score/staff.dart';
import '../../models/score/measure.dart';
import 'common.dart';

/// Représente les détails d'une portée parsés depuis staff-details.
class ParsedStaffDetails {
  /// Clef de la portée (null si pas de changement)
  final ClefType? clef;

  /// Armure en fifths (null si pas de changement)
  final KeySignature? keySignature;

  /// v2c-79 : nombre de lignes (5 = standard, 1 = percussion, N >= 1).
  final int lineCount;

  /// Indique si la portée a une clef de percussion
  final bool isPercussion;

  const ParsedStaffDetails({
    this.clef,
    this.keySignature,
    this.lineCount = 5,
    this.isPercussion = false,
  });

  /// Copie modifiable
  ParsedStaffDetails copyWith({
    ClefType? clef,
    KeySignature? keySignature,
    int? lineCount,
    bool? isPercussion,
  }) {
    return ParsedStaffDetails(
      clef: clef ?? this.clef,
      keySignature: keySignature ?? this.keySignature,
      lineCount: lineCount ?? this.lineCount,
      isPercussion: isPercussion ?? this.isPercussion,
    );
  }
}

/// Parseur des éléments liés aux portées.
class StaffParser {
  // ==========================================================================
  // PARSEUR DE <STAFF> (NUMÉRO DE PORTÉE)
  // ==========================================================================

  /// Parse un nœud staff et retourne le numéro de portée.
  /// Retourne null si le nœud n'existe pas.
  static int? parseStaffNumber(xml.XmlElement? staffNode) {
    if (staffNode == null) return null;
    final value = staffNode.innerText.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  // ==========================================================================
  // PARSEUR DE <STAFF-DETAILS> (DÉTAILS DE LA PORTÉE)
  // ==========================================================================

  /// Parse un nœud staff-details et retourne un ParsedStaffDetails.
  static ParsedStaffDetails parseStaffDetails(xml.XmlElement detailsNode) {
    ClefType? clef;
    KeySignature? keySignature;
    // v2c-79 : défaut = 5 lignes.
    int lineCount = 5;
    bool isPercussion = false;

    // ---- Clef ----
    final clefNode = detailsNode.findElements('clef').firstOrNull;
    if (clefNode != null) {
      final sign = clefNode.findElements('sign').firstOrNull?.innerText ?? 'G';
      final lineStr = clefNode.findElements('line').firstOrNull?.innerText;
      final line = lineStr != null ? int.parse(lineStr) : 2;
      final octaveNode =
          clefNode.findElements('clef-octave-change').firstOrNull;
      int octaveChange = 0;
      if (octaveNode != null) {
        final octStr = octaveNode.innerText;
        if (octStr.isNotEmpty) octaveChange = int.parse(octStr);
      }
      clef = CommonParserHelpers.parseClef(
        sign: sign,
        line: line,
        octaveChange: octaveChange,
      );
    }

    // ---- Armure ----
    final keyNode = detailsNode.findElements('key').firstOrNull;
    if (keyNode != null) {
      final fifthsStr = keyNode.findElements('fifths').firstOrNull?.innerText;
      final fifths = fifthsStr != null ? int.parse(fifthsStr) : 0;
      keySignature = KeySignature(fifths: fifths);
    }

    // ---- v2c-79 : nombre de lignes ----
    // On accepte n'importe quelle valeur >= 1.
    //   1  → portée de percussion
    //   4  → tablature 4 cordes
    //   5  → portée standard
    //   6  → tablature
    //   N  → autres (tests W3C, portées expérimentales)
    final staffLinesNode = detailsNode.findElements('staff-lines').firstOrNull;
    if (staffLinesNode != null) {
      final linesStr = staffLinesNode.innerText;
      if (linesStr.isNotEmpty) {
        final lines = int.tryParse(linesStr.trim());
        // ═══════════════════════════════════════════════════════════════
        // v2c-93z : accepte maintenant 0 (test W3C 22b).
        // AVANT : `lines >= 1` — même bug que dans AttributesParser.
        // APRÈS : 0 = portée sans lignes.
        //
        // ⚠️ Ce parser (StaffParser) n'est PAS utilisé par le pipeline
        //    principal (qui passe par AttributesParser). Il reste pour
        //    compatibilité API. On applique le même fix par cohérence.
        // ═══════════════════════════════════════════════════════════════
        if (lines != null && lines >= 0) {
          lineCount = lines;
          // Cas particulier : 1 ligne = portée de percussion.
          if (lines == 1) isPercussion = true;
        }
      }
    }

    return ParsedStaffDetails(
      clef: clef,
      keySignature: keySignature,
      lineCount: lineCount,
      isPercussion: isPercussion,
    );
  }

  // ==========================================================================
  // UTILITAIRE : CRÉATION D'UN STAFF À PARTIR D'UN STAFF-DETAILS
  // ==========================================================================

  /// Crée un objet Staff à partir d'un ParsedStaffDetails.
  static Staff createStaffFromDetails({
    required int staffIndex,
    required ParsedStaffDetails details,
    String instrumentName = 'Instrument',
    String instrumentAbbreviation = 'Inst.',
  }) {
    return Staff(
      staffIndex: staffIndex,
      instrumentName: instrumentName,
      instrumentAbbreviation: instrumentAbbreviation,
      clef: details.clef ?? ClefType.treble,
      keySignature: details.keySignature ?? const KeySignature(),
      lineCount: details.lineCount,   // v2c-79 : int
      isMuted: false,
      isSolo: false,
    );
  }
}