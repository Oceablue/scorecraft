// lib/services/parsers/common.dart
// ============================================================================
// FONCTIONS UTILITAIRES PARTAGÉES ENTRE LES PARSEURS
// ============================================================================
// v2c-2l : ajout des Gould arrow quartertones (W3C 01g).
// v2c-112 : ajout du DynamicTypeParser exhaustif (sfp, sffz, etc.)
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/enums/music_enums.dart';

/// Fonctions utilitaires communes pour le parsing MusicXML.
class CommonParserHelpers {
  // ==========================================================================
  // 1. CONVERSIONS DE DURÉE
  // ==========================================================================

  static DurationType parseDurationType(String type) {
    switch (type) {
      case 'maxima':
        return DurationType.maxima;
      case 'long':
      case 'longa':
        return DurationType.longa;
      case 'breve':
      case 'double-whole':
        return DurationType.doubleWhole;
      case 'whole':
        return DurationType.whole;
      case 'half':
        return DurationType.half;
      case 'quarter':
        return DurationType.quarter;
      case 'eighth':
        return DurationType.eighth;
      case '16th':
        return DurationType.sixteenth;
      case '32nd':
        return DurationType.thirtySecond;
      case '64th':
        return DurationType.sixtyFourth;
      case '128th':
        return DurationType.oneHundredTwentyEighth;
      case '256th':
        return DurationType.twoHundredFiftySixth;
      case '512th':
        return DurationType.fiveHundredTwelfth;
      case '1024th':
        return DurationType.oneThousandTwentyFourth;
      default:
        // ignore: avoid_print
        print('[parseDurationType] Type non géré : "$type" → quarter');
        return DurationType.quarter;
    }
  }

  // ==========================================================================
  // 2. CONVERSIONS D'ALTÉRATIONS
  // ==========================================================================

  static Accidental parseAccidental(String value) {
    final v = value.trim().toLowerCase();

    switch (v) {
      // ─── Standard ─────────────────────────────────────────────────────────
      case 'sharp':
        return Accidental.sharp;
      case 'flat':
        return Accidental.flat;
      case 'natural':
        return Accidental.natural;

      // ─── Doubles ──────────────────────────────────────────────────────────
      case 'double-sharp':
      case 'sharp-sharp':
      case 'double-sharp-sharp':
        return Accidental.doubleSharp;

      case 'flat-flat':
      case 'double-flat':
        return Accidental.doubleFlat;

      // ─── Microtons quart de ton ───────────────────────────────────────────
      case 'quarter-sharp':
      case 'half-sharp':
      case 'quartertone-sharp':
        return Accidental.quarterSharp;

      case 'quarter-flat':
      case 'half-flat':
      case 'quartertone-flat':
        return Accidental.quarterFlat;

      // ─── Microtons trois quarts de ton ────────────────────────────────────
      case 'three-quarters-sharp':
      case 'three-quarter-sharp':
      case 'one-and-a-half-sharp':
        return Accidental.threeQuarterSharp;

      case 'three-quarters-flat':
      case 'three-quarter-flat':
      case 'one-and-a-half-flat':
        return Accidental.threeQuarterFlat;

      // ─── Gould arrow quartertones (avec symbole de base) ──────────────────
      case 'flat-up':
        return Accidental.flatUp;
      case 'flat-down':
        return Accidental.flatDown;

      case 'natural-up':
        return Accidental.naturalUp;
      case 'natural-down':
        return Accidental.naturalDown;

      case 'sharp-up':
        return Accidental.sharpUp;
      case 'sharp-down':
        return Accidental.sharpDown;

      case 'double-sharp-up':
      case 'sharp-sharp-up':
        return Accidental.doubleSharpUp;
      case 'double-sharp-down':
      case 'sharp-sharp-down':
        return Accidental.doubleSharpDown;

      case 'flat-flat-up':
      case 'double-flat-up':
        return Accidental.doubleFlatUp;
      case 'flat-flat-down':
      case 'double-flat-down':
        return Accidental.doubleFlatDown;

      // ─── arrow purs (sans symbole de base) ────────────────────────────────
      case 'arrow-up':
      case 'arrowup':
        return Accidental.arrowUp;
      case 'arrow-down':
      case 'arrowdown':
        return Accidental.arrowDown;
      case 'arrow-both':
      case 'arrowboth':
        return Accidental.arrowBoth;

      // ─── Turc / Persan / Arabe (W3C 01h) ──────────────────────────────────
      case 'slash-quarter-sharp': return Accidental.slashQuarterSharp;
      case 'slash-sharp':         return Accidental.slashSharp;
      case 'slash-flat':          return Accidental.slashFlat;
      case 'double-slash-flat':   return Accidental.doubleSlashFlat;

      case 'sharp-1':             return Accidental.sharp1;
      case 'sharp-2':             return Accidental.sharp2;
      case 'sharp-3':             return Accidental.sharp3;
      case 'sharp-5':             return Accidental.sharp5;

      case 'flat-1':              return Accidental.flat1;
      case 'flat-2':              return Accidental.flat2;
      case 'flat-3':              return Accidental.flat3;
      case 'flat-4':              return Accidental.flat4;

      case 'sori':                return Accidental.sori;
      case 'koron':               return Accidental.koron;

      // ─── Cas non gérés ────────────────────────────────────────────────────
      default:
        // ignore: avoid_print
        print('[parseAccidental] Valeur non gérée : "$value" → none');
        return Accidental.none;
    }
  }

  /// Dérive l'altération d'affichage depuis la valeur brute de alter>.
  /// (Utilisé quand accidental> est absent du XML.)
  static Accidental accidentalFromAlter(double alter) {
    if (alter == alter.roundToDouble()) return Accidental.none;

    if (alter ==  0.5) return Accidental.quarterSharp;
    if (alter ==  1.5) return Accidental.threeQuarterSharp;
    if (alter == -0.5) return Accidental.quarterFlat;
    if (alter == -1.5) return Accidental.threeQuarterFlat;

    // ignore: avoid_print
    print('[accidentalFromAlter] Alter non géré : $alter → none');
    return Accidental.none;
  }

  // ==========================================================================
  // 3. CONVERSIONS DE LETTRES DE NOTES
  // ==========================================================================

  static NoteLetter parseNoteLetter(String step) {
    switch (step.toUpperCase()) {
      case 'C': return NoteLetter.C;
      case 'D': return NoteLetter.D;
      case 'E': return NoteLetter.E;
      case 'F': return NoteLetter.F;
      case 'G': return NoteLetter.G;
      case 'A': return NoteLetter.A;
      case 'B': return NoteLetter.B;
      default:
        // ignore: avoid_print
        print('[parseNoteLetter] Step non géré : "$step" → C');
        return NoteLetter.C;
    }
  }

  // ==========================================================================
  // 4. CONVERSIONS D'ARTICULATIONS
  // ==========================================================================

  static ArticulationType parseArticulation(String name) {
    switch (name) {
      case 'staccato': return ArticulationType.staccato;
      case 'staccatissimo': return ArticulationType.staccatissimo;
      case 'spiccato': return ArticulationType.spiccato;
      case 'tenuto':
      case 'detached-legato': return ArticulationType.tenuto;
      case 'accent': return ArticulationType.accent;
      case 'strong-accent': return ArticulationType.marcato;
      case 'soft-accent': return ArticulationType.softAccent;
      case 'stress': return ArticulationType.stress;
      case 'unstress': return ArticulationType.unstress;
      case 'scoop': return ArticulationType.scoop;
      case 'plop': return ArticulationType.plop;
      case 'doit': return ArticulationType.doit;
      case 'falloff': return ArticulationType.falloff;
      case 'breath-mark': return ArticulationType.breathMark;
      case 'caesura': return ArticulationType.caesura;
      case 'fermata': return ArticulationType.fermata;
      case 'short-fermata': return ArticulationType.shortFermata;
      case 'long-fermata': return ArticulationType.longFermata;
      default: return ArticulationType.none;
    }
  }

  // ==========================================================================
  // 5. CONVERSIONS DE BARRES DE MESURE
  // ==========================================================================

  static BarlineType parseBarlineType(String value) {
    switch (value) {
      case 'single': return BarlineType.single;
      case 'double':
      case 'light-light': return BarlineType.doubleBar;
      case 'light-heavy': return BarlineType.lightHeavy;
      case 'heavy-light': return BarlineType.heavyLight;
      case 'heavy-heavy': return BarlineType.heavyHeavy;
      case 'heavy': return BarlineType.heavy;
      case 'dashed': return BarlineType.dashed;
      case 'dotted': return BarlineType.dotted;
      case 'tick':
      case 'short': return BarlineType.tick;
      case 'none': return BarlineType.none;
      default: return BarlineType.single;
    }
  }

  // ==========================================================================
  // 6. CONVERSIONS DE CLEFS
  // ==========================================================================

  static ClefType parseClef({
    required String sign,
    int line = 2,
    int octaveChange = 0,
  }) {
    if (sign == 'G') {
      if (line == 1 && octaveChange == 0) return ClefType.frenchViolin;
      if (line == 2) {
        switch (octaveChange) {
          case -1: return ClefType.treble8vb;
          case 0:  return ClefType.treble;
          case 1:  return ClefType.treble8va;
          case 2:  return ClefType.treble15ma;
          case -2: return ClefType.treble15mb;
        }
      }
      return ClefType.treble;
    }
    if (sign == 'F') {
      switch (line) {
        case 3: return ClefType.baritoneFa;
        case 4:
          switch (octaveChange) {
            case -1: return ClefType.bass8vb;
            case 1:  return ClefType.bass8va;
            case -2: return ClefType.bass15mb;
            default: return ClefType.bass;
          }
        case 5: return ClefType.subbass;
      }
      return ClefType.bass;
    }
    if (sign == 'C') {
      switch (line) {
        case 1: return ClefType.soprano;
        case 2: return ClefType.mezzoSoprano;
        case 3: return ClefType.alto;
        case 4: return ClefType.tenor;
        case 5: return ClefType.baritoneUt;
      }
      return ClefType.alto;
    }
    if (sign == 'percussion') return ClefType.percussion;
    if (sign == 'TAB' || sign == 'tab') return ClefType.tab;
    if (sign == 'none') return ClefType.none;
    return ClefType.treble;
  }

  // ==========================================================================
  // 7. HELPERS XML GÉNÉRIQUES
  // ==========================================================================

  static String getChildValue(
    dynamic parent,
    String childName, {
    String defaultValue = '',
  }) {
    try {
      if (parent is xml.XmlElement) {
        final child = parent.findElements(childName).firstOrNull;
        if (child != null) return child.innerText;
      }
    } catch (_) {}
    return defaultValue;
  }

  static String getAttribute(
    dynamic node,
    String attrName, {
    String defaultValue = '',
  }) {
    try {
      if (node is xml.XmlElement) {
        final value = node.getAttribute(attrName);
        if (value != null) return value;
      }
    } catch (_) {}
    return defaultValue;
  }

  // ==========================================================================
  // 8. HELPERS TYPÉS
  // ==========================================================================

  static int getChildInt(
    xml.XmlElement parent,
    String childName, {
    int defaultValue = 0,
  }) {
    final child = parent.findElements(childName).firstOrNull;
    if (child == null) return defaultValue;
    final txt = child.innerText.trim();
    if (txt.isEmpty) return defaultValue;
    return int.tryParse(txt) ?? defaultValue;
  }

  static double getChildDouble(
    xml.XmlElement parent,
    String childName, {
    double defaultValue = 0.0,
  }) {
    final child = parent.findElements(childName).firstOrNull;
    if (child == null) return defaultValue;
    final txt = child.innerText.trim();
    if (txt.isEmpty) return defaultValue;
    return double.tryParse(txt) ?? defaultValue;
  }

  static int getAttributeInt(
    xml.XmlElement node,
    String attrName, {
    int defaultValue = 0,
  }) {
    final v = node.getAttribute(attrName);
    if (v == null || v.isEmpty) return defaultValue;
    return int.tryParse(v) ?? defaultValue;
  }

  static double getAttributeDouble(
    xml.XmlElement node,
    String attrName, {
    double defaultValue = 0.0,
  }) {
    final v = node.getAttribute(attrName);
    if (v == null || v.isEmpty) return defaultValue;
    return double.tryParse(v) ?? defaultValue;
  }

  static bool getAttributeYesNo(
    xml.XmlElement node,
    String attrName, {
    bool defaultValue = false,
  }) {
    final v = node.getAttribute(attrName);
    if (v == null) return defaultValue;
    return v == 'yes' || v == 'true';
  }
}