// lib/services/parsers/attributes_parser.dart
// ============================================================================
// PARSEUR DES ATTRIBUTS MUSICAUX — v2c-93z
// ============================================================================
// v2c-58 : multi-<time> avec number + print-object.
// v2c-59..65 : composites, fractions, single-number, senza-misura, interchange.
// v2c-66 : <sign>none</sign>.
// v2c-74 : key signatures non traditionnelles (key-step/key-alter/key-octave).
// v2c-75 : alter lu en `double` (microtons fractionnaires -1.5, -0.5...).
// v2c-79 : <staff-details>/<staff-lines> et <line-detail>.
// v2c-93z: <measure-style><slash type="start|stop" use-stems="yes|no">.
//          Retourne une ParsedSlashDirective (start/stop + useStems).
//          C'est MeasureParser qui gère la PERSISTANCE cross-mesure.
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/enums/music_enums.dart';
import '../../models/score/measure.dart';

class ParsedTimeSignature {
  final int? staffNumber;
  final TimeSignature timeSignature;
  final bool shouldPrint;

  const ParsedTimeSignature({
    required this.staffNumber,
    required this.timeSignature,
    required this.shouldPrint,
  });
}

// ============================================================================
// v2c-93z : DIRECTIVE DE SLASH (notation rythmique)
// ============================================================================
// Représente un <measure-style><slash> rencontré dans un <attributes>.
//
// C'est une DIRECTIVE, pas encore un état "résolu" :
//   - type="start" → on active le mode slash à partir d'ici.
//   - type="stop"  → on désactive le mode slash à partir d'ici.
//
// La persistance cross-mesure (mesure A start, mesure B stop → mesures A..B
// en mode slash) est gérée par MeasureParser, pas ici.
class ParsedSlashDirective {
  /// 'start' ou 'stop'. Obligatoire dans le XML.
  final String type;

  /// use-stems : "yes" / "no". Défaut = "yes" (spec MusicXML).
  final bool useStems;

  /// slash-type> : 'quarter', 'eighth', '16th'…
  /// Défaut = 'quarter' (spec MusicXML).
  /// ⚠️ Tous les types partagent le même glyphe visuel dans SMuFL pour
  ///    l'instant (voir SlashNotation.slashType).
  final String slashType;

  const ParsedSlashDirective({
    required this.type,
    this.useStems = true,
    this.slashType = 'quarter',
  });

  bool get isStart => type == 'start';
  bool get isStop => type == 'stop';

  @override
  String toString() =>
      'ParsedSlashDirective(type: $type, useStems: $useStems, '
      'slashType: $slashType)';
}

class ParsedAttributes {
  final int? staves;
  final Map<int, ClefType> clefs;
  final Map<int, KeySignature> keys;

  /// v2c-78 : `print-object` de chaque `<key>` par portée.
  /// false si `print-object="no"` → l'armure existe (fifths, custom, cancel)
  /// mais NE doit PAS être affichée.
  final Map<int, bool> keysShouldPrint;

  final List<ParsedTimeSignature> timeSignatures;
  final int? divisions;
  final int? multiRestCount;

  // ─── v2c-79 : STAFF-DETAILS ───────────────────────────────────────────────

  /// Nombre de lignes par portée (staffNumber -> lineCount).
  /// Absent de la map = pas de changement de nombre de lignes dans ce nœud.
  /// Valeurs typiques : 0 (sans lignes), 1 (percussion), 5 (standard), 6 (tab).
  final Map<int, int> staffLines;

  /// Lignes à NE PAS dessiner, par portée (scénario D du test W3C 14a).
  /// Numérotation MusicXML : 1 = ligne du bas, 5 = ligne du haut.
  /// Ex : {1: {2, 4}} masque les 2ᵉ et 4ᵉ lignes de la portée 1.
  final Map<int, Set<int>> hiddenLines;

  // ═════════════════════════════════════════════════════════════════════════
  // v2c-93z : DIRECTIVE SLASH (test W3C 22b, mesures 2-3)
  // ═════════════════════════════════════════════════════════════════════════
  //
  /// Directive slash rencontrée dans ce attributes>, ou null.
  ///
  /// ⚠️ Une seule directive slash par attributes> dans la spec MusicXML
  ///    (pas de chevauchement). Si plusieurs sont présentes, on garde la
  ///    PREMIÈRE rencontrée (comportement défensif).
  final ParsedSlashDirective? slashDirective;

  const ParsedAttributes({
    this.staves,
    this.clefs = const {},
    this.keys = const {},
    this.keysShouldPrint = const {},
    this.timeSignatures = const [],
    this.divisions,
    this.multiRestCount,
    // v2c-79
    this.staffLines = const {},
    this.hiddenLines = const {},
    // v2c-93z
    this.slashDirective,
  });
}

class AttributesParser {
  static ParsedAttributes parse(xml.XmlElement attributesNode) {
    // ---- Staves ----
    int? staves;
    final stavesNode = attributesNode.findElements('staves').firstOrNull;
    if (stavesNode != null) {
      final value = int.tryParse(stavesNode.innerText.trim());
      if (value != null && value > 0) staves = value;
    }

    // ---- Clefs ----
    final clefs = <int, ClefType>{};
    for (final clefNode in attributesNode.findElements('clef')) {
      final numberStr = clefNode.getAttribute('number') ?? '1';
      final staffNumber = int.tryParse(numberStr) ?? 1;
      clefs[staffNumber] = _parseClef(clefNode);
    }

    // ---- v2c-79 : STAFF-DETAILS (nombre de lignes + lignes masquées) ----
    //
    // Structure MusicXML :
    //   <staff-details number="1">
    //     <staff-lines>5</staff-lines>
    //     <line-detail line="2" print-object="no"/>
    //     <line-detail line="4" print-object="no"/>
    //   </staff-details>
    //
    // ⚠️ `number` sur <staff-details> est optionnel ; défaut = 1.
    // ⚠️ `staff-lines` et `line-detail` sont indépendants.
    final staffLines = <int, int>{};
    final hiddenLines = <int, Set<int>>{};

    for (final detailNode in attributesNode.findElements('staff-details')) {
      final numberStr = detailNode.getAttribute('number') ?? '1';
      final staffNumber = int.tryParse(numberStr) ?? 1;

      // --- Nombre de lignes ---
      final linesStr =
          detailNode.findElements('staff-lines').firstOrNull?.innerText;
      if (linesStr != null) {
        final lines = int.tryParse(linesStr.trim());
        // ═══════════════════════════════════════════════════════════════
        // v2c-93z : accepte maintenant 0 (test W3C 22b, mesure 5).
        //
        // AVANT : `lines >= 1` — rejetait silencieusement 0, qui devenait
        //         une mesure normale à 5 lignes. Résultat : `<staff-lines>0`
        //         était invisible pour le rendu.
        // APRÈS : `lines >= 0` — 0 est une valeur valide = portée SANS
        //         lignes (les notes peuvent rester visibles, ce qui est
        //         utilisé pour afficher un rythme sans portée).
        //
        // Le rendu gère déjà 0 : StructurePainter.drawStaffLines() boucle
        // `for (line = 0; line < lineCount; line++)` → 0 itération → rien
        // n'est dessiné. Aucun changement nécessaire côté painter.
        // ═══════════════════════════════════════════════════════════════
        if (lines != null && lines >= 0) {
          staffLines[staffNumber] = lines;
        }
      }

      // --- Lignes masquées ---
      // <line-detail line="N" print-object="no"/>
      // ⚠️ Si print-object n'est pas "no", la ligne reste visible.
      final hidden = <int>{};
      for (final ld in detailNode.findElements('line-detail')) {
        if (ld.getAttribute('print-object') == 'no') {
          final lineNumStr = ld.getAttribute('line');
          final lineNum = lineNumStr != null ? int.tryParse(lineNumStr) : null;
          if (lineNum != null && lineNum >= 1) {
            hidden.add(lineNum);
          }
        }
      }
      if (hidden.isNotEmpty) {
        hiddenLines[staffNumber] = hidden;
      }
    }

    // ---- Armures ----
    final keys = <int, KeySignature>{};
    // v2c-78 : flag print-object par portée.
    final keysShouldPrint = <int, bool>{};
    for (final keyNode in attributesNode.findElements('key')) {
      final numberStr = keyNode.getAttribute('number') ?? '1';
      final staffNumber = int.tryParse(numberStr) ?? 1;

      // v2c-78 : lire print-object="no".
      final printObj = keyNode.getAttribute('print-object');
      keysShouldPrint[staffNumber] = printObj != 'no';

      // v2c-74 : détection key signature NON TRADITIONNELLE
      final keySteps = keyNode.findElements('key-step').toList();
      final keyAlters = keyNode.findElements('key-alter').toList();
      final keyOctaves = keyNode.findElements('key-octave').toList();

      if (keySteps.isNotEmpty && keySteps.length == keyAlters.length) {
        final alterations = <KeyAlteration>[];

        // Première passe : step + alter
        // v2c-75 : alter en double (supporte -1.5, -0.5, +0.5, +1.5).
        for (int i = 0; i < keySteps.length; i++) {
          final step = _parseNoteLetter(keySteps[i].innerText.trim());
          final alter =
              double.tryParse(keyAlters[i].innerText.trim()) ?? 0.0;
          alterations.add(KeyAlteration(step: step, alter: alter));
        }

        // Deuxième passe : associer les <key-octave number="N">
        for (final octNode in keyOctaves) {
          final numberAttr = octNode.getAttribute('number');
          final octNum = int.tryParse(numberAttr ?? '') ?? 0;
          final octVal = int.tryParse(octNode.innerText.trim()) ?? 0;
          if (octNum >= 1 && octNum <= alterations.length) {
            final orig = alterations[octNum - 1];
            alterations[octNum - 1] = KeyAlteration(
              step: orig.step,
              alter: orig.alter,
              octave: octVal,
            );
          }
        }

        keys[staffNumber] = KeySignature(
          fifths: 0,
          customAlterations: alterations,
        );
        continue;
      }

      // Key sig standard
      final fifthsStr =
          keyNode.findElements('fifths').firstOrNull?.innerText;
      final fifths = fifthsStr != null ? int.tryParse(fifthsStr) ?? 0 : 0;

      // v2c-76 : <cancel> (annulation partielle)
      KeyCancel? cancel;
      final cancelNode = keyNode.findElements('cancel').firstOrNull;
      if (cancelNode != null) {
        final cancelFifths = int.tryParse(cancelNode.innerText.trim());
        final cancelLocation =
            cancelNode.getAttribute('location') ?? 'left';
        if (cancelFifths != null && cancelFifths != 0) {
          cancel = KeyCancel(
            fifths: cancelFifths,
            location: cancelLocation,
          );
        }
      }

      keys[staffNumber] = KeySignature(
        fifths: fifths,
        cancel: cancel,
      );
    }

    // ---- Time signatures ----
    final timeSignatures = <ParsedTimeSignature>[];
    for (final timeNode in attributesNode.findElements('time')) {
      final numberStr = timeNode.getAttribute('number');
      final staffNumber = numberStr != null ? int.tryParse(numberStr) : null;

      final printObj = timeNode.getAttribute('print-object');
      final shouldPrint = printObj != 'no';

      // <senza-misura>
      final senzaMisuraNode =
          timeNode.findElements('senza-misura').firstOrNull;
      if (senzaMisuraNode != null) {
        final rawText = senzaMisuraNode.innerText.trim();
        final text = rawText.isEmpty ? null : rawText;

        timeSignatures.add(ParsedTimeSignature(
          staffNumber: staffNumber,
          timeSignature: TimeSignature(
            display: TimeSignatureType.senzaMisura,
            senzaMisuraText: text,
          ),
          shouldPrint: shouldPrint,
        ));
        continue;
      }

      final beatsNodes = timeNode.findElements('beats').toList();
      final beatTypeNodes = timeNode.findElements('beat-type').toList();

      final pairsCount = beatsNodes.length < beatTypeNodes.length
          ? beatsNodes.length
          : beatTypeNodes.length;

      final interchangeable = _parseInterchangeable(timeNode);

      final symbol = timeNode.getAttribute('symbol');
      TimeSignatureType display = TimeSignatureType.standard;

      if (symbol == 'single-number') {
        display = TimeSignatureType.singleNumber;
      } else if (pairsCount == 1) {
        final n = int.tryParse(beatsNodes[0].innerText.trim()) ?? 0;
        final d = int.tryParse(beatTypeNodes[0].innerText.trim()) ?? 0;

        if (symbol == 'common' && n == 4 && d == 4) {
          display = TimeSignatureType.common;
        } else if (symbol == 'cut' && n == 2 && d == 2) {
          display = TimeSignatureType.cut;
        }
      }

      // Cas 1 : plusieurs paires → fractions composites
      if (pairsCount > 1) {
        final fractions = <TimeFraction>[];
        for (int i = 0; i < pairsCount; i++) {
          final beatsStr = beatsNodes[i].innerText.trim();
          final d = int.tryParse(beatTypeNodes[i].innerText.trim()) ?? 4;
          if (d <= 0) continue;

          if (beatsStr.contains('+')) {
            final subGroups = beatsStr
                .split('+')
                .map((s) => int.tryParse(s.trim()) ?? 0)
                .where((n) => n > 0)
                .toList();
            if (subGroups.isEmpty) continue;

            final sum = subGroups.fold(0, (a, b) => a + b);
            fractions.add(TimeFraction(
              numerator: sum,
              denominator: d,
              subGroups: subGroups,
            ));
          } else {
            final n = int.tryParse(beatsStr) ?? 0;
            if (n > 0) {
              fractions.add(TimeFraction(numerator: n, denominator: d));
            }
          }
        }

        final int aggDenom = _lcmAll(fractions.map((f) => f.denominator));
        int aggBeats = 0;
        for (final f in fractions) {
          aggBeats += f.numerator * (aggDenom ~/ f.denominator);
        }

        timeSignatures.add(ParsedTimeSignature(
          staffNumber: staffNumber,
          timeSignature: TimeSignature(
            beats: aggBeats,
            beatType: aggDenom,
            display: display,
            fractions: fractions,
            interchangeable: interchangeable,
          ),
          shouldPrint: shouldPrint,
        ));
        continue;
      }

      // Cas 2 : une seule paire
      if (pairsCount == 1) {
        final beatsStr = beatsNodes[0].innerText.trim();
        final beatTypeStr = beatTypeNodes[0].innerText.trim();

        List<int>? beatGroups;
        int beats = 4;
        if (beatsStr.contains('+')) {
          beatGroups = beatsStr
              .split('+')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .where((n) => n > 0)
              .toList();
          beats = beatGroups.fold(0, (a, b) => a + b);
        } else {
          beats = int.tryParse(beatsStr) ?? 4;
        }
        final beatType = int.tryParse(beatTypeStr) ?? 4;

        timeSignatures.add(ParsedTimeSignature(
          staffNumber: staffNumber,
          timeSignature: TimeSignature(
            beats: beats,
            beatType: beatType,
            display: display,
            beatGroups: beatGroups,
            interchangeable: interchangeable,
          ),
          shouldPrint: shouldPrint,
        ));
        continue;
      }

      // Cas 3 : aucun <beats>
      timeSignatures.add(ParsedTimeSignature(
        staffNumber: staffNumber,
        timeSignature: TimeSignature(
          display: display,
          interchangeable: interchangeable,
        ),
        shouldPrint: shouldPrint,
      ));
    }

    // ---- Divisions ----
    int? divisions;
    final divisionsNode =
        attributesNode.findElements('divisions').firstOrNull;
    if (divisionsNode != null) {
      final divStr = divisionsNode.innerText.trim();
      if (divStr.isNotEmpty) divisions = int.tryParse(divStr);
    }

    // ---- v2c-79 / v2c-93z : MEASURE-STYLE ----
    // ═══════════════════════════════════════════════════════════════════════
    // Le <measure-style> peut contenir PLUSIEURS directives simultanées :
    //   - <multiple-rest>N</multiple-rest>      (v2c-79)
    //   - <slash type="..." use-stems="..."/>   (v2c-93z)
    //   - <measure-repeat>...                   (non implémenté)
    //
    // On itère sur TOUS les <measure-style> et on extrait ce qui nous
    // intéresse, sans court-circuiter (contrairement à l'ancienne version
    // qui ne prenait que le PREMIER <measure-style>).
    // ═══════════════════════════════════════════════════════════════════════
    int? multiRestCount;
    ParsedSlashDirective? slashDirective;

    for (final measureStyleNode
        in attributesNode.findElements('measure-style')) {
      // --- multiple-rest ---
      if (multiRestCount == null) {
        final mrNode =
            measureStyleNode.findElements('multiple-rest').firstOrNull;
        if (mrNode != null) {
          final value = int.tryParse(mrNode.innerText.trim());
          if (value != null && value > 1) multiRestCount = value;
        }
      }

      // --- v2c-93z : slash (notation rythmique) ---
      if (slashDirective == null) {
        final slashNode =
            measureStyleNode.findElements('slash').firstOrNull;
        if (slashNode != null) {
          final type = slashNode.getAttribute('type') ?? 'start';
          final useStemsAttr = slashNode.getAttribute('use-stems');
          // use-stems : "yes" → true, "no" → false, absent → true (défaut).
          final useStems = useStemsAttr != 'no';

          final slashTypeText =
              slashNode.findElements('slash-type').firstOrNull?.innerText;
          final slashType =
              (slashTypeText != null && slashTypeText.trim().isNotEmpty)
                  ? slashTypeText.trim()
                  : 'quarter';

          slashDirective = ParsedSlashDirective(
            type: type,
            useStems: useStems,
            slashType: slashType,
          );
        }
      }
    }

    return ParsedAttributes(
      staves: staves,
      clefs: clefs,
      keys: keys,
      keysShouldPrint: keysShouldPrint,
      timeSignatures: timeSignatures,
      divisions: divisions,
      multiRestCount: multiRestCount,
      // v2c-79
      staffLines: staffLines,
      hiddenLines: hiddenLines,
      // v2c-93z
      slashDirective: slashDirective,
    );
  }

  // ==========================================================================
  // Parsing de <interchangeable>
  // ==========================================================================

  static InterchangeableTimeSignature? _parseInterchangeable(
    xml.XmlElement timeNode,
  ) {
    final interNode = timeNode.findElements('interchangeable').firstOrNull;
    if (interNode == null) return null;

    final relation = interNode
        .findElements('time-relation')
        .firstOrNull
        ?.innerText
        .trim();

    final beatsNodes = interNode.findElements('beats').toList();
    final beatTypeNodes = interNode.findElements('beat-type').toList();
    final pairsCount = beatsNodes.length < beatTypeNodes.length
        ? beatsNodes.length
        : beatTypeNodes.length;

    if (pairsCount == 0) return null;

    if (pairsCount > 1) {
      final fractions = <TimeFraction>[];
      for (int i = 0; i < pairsCount; i++) {
        final n = int.tryParse(beatsNodes[i].innerText.trim()) ?? 0;
        final d = int.tryParse(beatTypeNodes[i].innerText.trim()) ?? 4;
        if (n > 0 && d > 0) {
          fractions.add(TimeFraction(numerator: n, denominator: d));
        }
      }
      if (fractions.isEmpty) return null;

      final int aggDenom = _lcmAll(fractions.map((f) => f.denominator));
      int aggBeats = 0;
      for (final f in fractions) {
        aggBeats += f.numerator * (aggDenom ~/ f.denominator);
      }

      return InterchangeableTimeSignature(
        relation: relation,
        beats: aggBeats,
        beatType: aggDenom,
        fractions: fractions,
      );
    }

    final n = int.tryParse(beatsNodes[0].innerText.trim()) ?? 0;
    final d = int.tryParse(beatTypeNodes[0].innerText.trim()) ?? 4;
    if (n <= 0 || d <= 0) return null;

    return InterchangeableTimeSignature(
      relation: relation,
      beats: n,
      beatType: d,
    );
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================

  static NoteLetter _parseNoteLetter(String s) {
    switch (s.toUpperCase()) {
      case 'C': return NoteLetter.C;
      case 'D': return NoteLetter.D;
      case 'E': return NoteLetter.E;
      case 'F': return NoteLetter.F;
      case 'G': return NoteLetter.G;
      case 'A': return NoteLetter.A;
      case 'B': return NoteLetter.B;
      default:  return NoteLetter.C;
    }
  }

  static ClefType _parseClef(xml.XmlElement clefNode) {
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

    if (sign == 'G') {
      if (line == 2 && octaveChange == 0) return ClefType.treble;
      if (line == 1 && octaveChange == 0) return ClefType.frenchViolin;
      if (line == 2 && octaveChange == -1) return ClefType.treble8vb;
      if (line == 2 && octaveChange == 1) return ClefType.treble8va;
      if (line == 2 && octaveChange == 2) return ClefType.treble15ma;
      if (line == 2 && octaveChange == -2) return ClefType.treble15mb;
      return ClefType.treble;
    }
    if (sign == 'F') {
      if (line == 4 && octaveChange == 0) return ClefType.bass;
      if (line == 3 && octaveChange == 0) return ClefType.baritoneFa;
      if (line == 5 && octaveChange == 0) return ClefType.subbass;
      if (line == 4 && octaveChange == -1) return ClefType.bass8vb;
      if (line == 4 && octaveChange == 1) return ClefType.bass8va;
      if (line == 4 && octaveChange == -2) return ClefType.bass15mb;
      return ClefType.bass;
    }
    if (sign == 'C') {
      if (line == 1) return ClefType.soprano;
      if (line == 2) return ClefType.mezzoSoprano;
      if (line == 3) return ClefType.alto;
      if (line == 4) return ClefType.tenor;
      if (line == 5) return ClefType.baritoneUt;
      return ClefType.alto;
    }
    if (sign == 'percussion') return ClefType.percussion;
    if (sign == 'TAB') return ClefType.tab;
    if (sign == 'none') return ClefType.none;
    return ClefType.treble;
  }

  // ==========================================================================
  // Helpers LCM
  // ==========================================================================

  static int _lcmAll(Iterable<int> values) {
    if (values.isEmpty) return 4;
    int result = 1;
    for (final v in values) {
      if (v > 0) result = _lcm(result, v);
    }
    return result == 0 ? 4 : result;
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
  static int _lcm(int a, int b) => (a ~/ _gcd(a, b)) * b;
}