// lib/models/enums/music_enums.dart
// ============================================================================
// ÉNUMÉRATIONS DE BASE POUR LE DÉCODAGE & LE RENDU MUSICAL (SCORECRAFT)
// ============================================================================
// v2c-3a : durées 512th et 1024th + AccidentalCategory, BarlineCategory.
// v2c-63 : TimeSignatureType.singleNumber (afficher uniquement le numérateur).
// ============================================================================

// ============================================================================
// 1. CLEFS MUSICALES
// ============================================================================

enum ClefType {
  treble, frenchViolin,
  soprano, mezzoSoprano, alto, tenor, baritoneUt,
  baritoneFa, bass, subbass,
  treble8vb, treble8va, treble15ma, treble15mb,
  bass8vb, bass8va, bass15mb,
  percussion, tab, none,
}

// ============================================================================
// 2. DURÉES RYTHMIQUES
// ============================================================================

enum DurationType {
  maxima,
  longa,
  doubleWhole,
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
  sixtyFourth,
  oneHundredTwentyEighth,
  twoHundredFiftySixth,
  fiveHundredTwelfth,
  oneThousandTwentyFourth,
}

extension DurationTypeExtension on DurationType {
  double get relativeValue {
    switch (this) {
      case DurationType.maxima:                 return 8.0;
      case DurationType.longa:                  return 4.0;
      case DurationType.doubleWhole:            return 2.0;
      case DurationType.whole:                  return 1.0;
      case DurationType.half:                   return 0.5;
      case DurationType.quarter:                return 0.25;
      case DurationType.eighth:                 return 0.125;
      case DurationType.sixteenth:              return 0.0625;
      case DurationType.thirtySecond:           return 0.03125;
      case DurationType.sixtyFourth:            return 0.015625;
      case DurationType.oneHundredTwentyEighth: return 0.0078125;
      case DurationType.twoHundredFiftySixth:   return 0.00390625;
      case DurationType.fiveHundredTwelfth:     return 0.001953125;
      case DurationType.oneThousandTwentyFourth:return 0.0009765625;
    }
  }

  int get flagCount {
    switch (this) {
      case DurationType.maxima:
      case DurationType.longa:
      case DurationType.doubleWhole:
      case DurationType.whole:
      case DurationType.half:
      case DurationType.quarter:
        return 0;
      case DurationType.eighth:                 return 1;
      case DurationType.sixteenth:              return 2;
      case DurationType.thirtySecond:           return 3;
      case DurationType.sixtyFourth:            return 4;
      case DurationType.oneHundredTwentyEighth: return 5;
      case DurationType.twoHundredFiftySixth:   return 6;
      case DurationType.fiveHundredTwelfth:     return 7;
      case DurationType.oneThousandTwentyFourth:return 8;
    }
  }

  bool get needsStem {
    switch (this) {
      case DurationType.maxima:
      case DurationType.longa:
      case DurationType.doubleWhole:
      case DurationType.whole:
        return false;
      default:
        return true;
    }
  }

  bool get isBeamable => flagCount >= 1;
}

// ============================================================================
// 3. ALTÉRATIONS
// ============================================================================

enum Accidental {
  none,
  sharp,
  flat,
  natural,
  doubleSharp,
  doubleFlat,
  quarterSharp,
  threeQuarterSharp,
  quarterFlat,
  threeQuarterFlat,
  flatUp, flatDown,
  naturalUp, naturalDown,
  sharpUp, sharpDown,
  doubleSharpUp, doubleSharpDown,
  doubleFlatUp, doubleFlatDown,
  arrowUp, arrowDown, arrowBoth,
  slashQuarterSharp, slashSharp, slashFlat, doubleSlashFlat,
  sharp1, sharp2, sharp3, sharp5,
  flat1, flat2, flat3, flat4,
  sori, koron,
}

extension AccidentalCategory on Accidental {
  bool get isStandard {
    switch (this) {
      case Accidental.sharp:
      case Accidental.flat:
      case Accidental.natural:
      case Accidental.doubleSharp:
      case Accidental.doubleFlat:
        return true;
      default:
        return false;
    }
  }

  bool get isMicrotonal {
    switch (this) {
      case Accidental.quarterSharp:
      case Accidental.threeQuarterSharp:
      case Accidental.quarterFlat:
      case Accidental.threeQuarterFlat:
      case Accidental.flatUp:
      case Accidental.flatDown:
      case Accidental.naturalUp:
      case Accidental.naturalDown:
      case Accidental.sharpUp:
      case Accidental.sharpDown:
      case Accidental.doubleSharpUp:
      case Accidental.doubleSharpDown:
      case Accidental.doubleFlatUp:
      case Accidental.doubleFlatDown:
      case Accidental.arrowUp:
      case Accidental.arrowDown:
      case Accidental.arrowBoth:
        return true;
      default:
        return false;
    }
  }

  bool get isTurkishPersian {
    switch (this) {
      case Accidental.slashQuarterSharp:
      case Accidental.slashSharp:
      case Accidental.slashFlat:
      case Accidental.doubleSlashFlat:
      case Accidental.sharp1:
      case Accidental.sharp2:
      case Accidental.sharp3:
      case Accidental.sharp5:
      case Accidental.flat1:
      case Accidental.flat2:
      case Accidental.flat3:
      case Accidental.flat4:
      case Accidental.sori:
      case Accidental.koron:
        return true;
      default:
        return false;
    }
  }

  bool get needsCustomGlyph => this != Accidental.none && !isStandard;
}

// ============================================================================
// 4. LETTRES DES NOTES DIATONIQUES
// ============================================================================

enum NoteLetter { C, D, E, F, G, A, B }

// ============================================================================
// 5. BARRES DE MESURE
// ============================================================================

enum BarlineType {
  single,
  doubleBar,
  end,
  repeatStart,
  repeatEnd,
  repeatBoth,
  dashed,
  dotted,
  tick,
  heavy,
  none,
  lightHeavy,
  heavyLight,
  heavyHeavy,
}

extension BarlineCategory on BarlineType {
  bool get isRepeat {
    switch (this) {
      case BarlineType.repeatStart:
      case BarlineType.repeatEnd:
      case BarlineType.repeatBoth:
        return true;
      default:
        return false;
    }
  }

  bool get isFinal {
    switch (this) {
      case BarlineType.end:
      case BarlineType.lightHeavy:
        return true;
      default:
        return false;
    }
  }

  bool get hasHeavyLine {
    switch (this) {
      case BarlineType.end:
      case BarlineType.lightHeavy:
      case BarlineType.heavyLight:
      case BarlineType.heavyHeavy:
      case BarlineType.heavy:
        return true;
      default:
        return false;
    }
  }

  bool get hasThinLine {
    switch (this) {
      case BarlineType.single:
      case BarlineType.doubleBar:
      case BarlineType.end:
      case BarlineType.repeatStart:
      case BarlineType.repeatEnd:
      case BarlineType.repeatBoth:
      case BarlineType.lightHeavy:
      case BarlineType.heavyLight:
      case BarlineType.heavyHeavy:
        return true;
      default:
        return false;
    }
  }
}

// ============================================================================
// 6. CHIFFRAGE DE MESURE
// ============================================================================

enum TimeSignatureType {
  standard,
  common,
  cut,
  senzaMisura,

  /// v2c-63 : `symbol="single-number"` — afficher UNIQUEMENT le numérateurs
  /// (ex: `3` pour 3/8, `3+2` pour 3+2/8).
  singleNumber,
}

// ============================================================================
// 7. HAMPES
// ============================================================================

enum StemDirection { auto, up, down, none }

// ============================================================================
// 8. POINTS DE PROLONGATION
// ============================================================================

enum DotType { none, single, double, triple }

extension DotTypeMultiplier on DotType {
  double get multiplier {
    switch (this) {
      case DotType.none:   return 1.0;
      case DotType.single: return 1.5;
      case DotType.double: return 1.75;
      case DotType.triple: return 1.875;
    }
  }

  int get count {
    switch (this) {
      case DotType.none:   return 0;
      case DotType.single: return 1;
      case DotType.double: return 2;
      case DotType.triple: return 3;
    }
  }
}

// ============================================================================
// 9. ARTICULATIONS & ORNEMENTS
// ============================================================================

enum ArticulationType {
  none,
  staccato,
  staccatissimo,
  tenuto,
  accent,
  marcato,
  fermata,
  shortFermata,
  longFermata,
  trill,
  mordent,
  turn,
  spiccato,
  softAccent,
  stress,
  unstress,
  scoop,
  plop,
  doit,
  falloff,
  breathMark,
  caesura,
}

// ============================================================================
// 10. NUANCES & DYNAMIQUES
// ============================================================================

enum DynamicType {
  none,
  p, pp, ppp, pppp, ppppp, pppppp,
  f, ff, fff, ffff, fffff, ffffff,
  mp, mf,
  sf, sfp, sfpp, fp, pf,
  rf, rfz, fz,
  sfz, sffz, sfzp,
  niente,
  crescendoLine,
  decrescendoLine,
}

extension DynamicTypeParser on DynamicType {
  static DynamicType fromXmlName(String name) {
    switch (name) {
      case 'p': return DynamicType.p;
      case 'pp': return DynamicType.pp;
      case 'ppp': return DynamicType.ppp;
      case 'pppp': return DynamicType.pppp;
      case 'ppppp': return DynamicType.ppppp;
      case 'pppppp': return DynamicType.pppppp;
      case 'f': return DynamicType.f;
      case 'ff': return DynamicType.ff;
      case 'fff': return DynamicType.fff;
      case 'ffff': return DynamicType.ffff;
      case 'fffff': return DynamicType.fffff;
      case 'ffffff': return DynamicType.ffffff;
      case 'mp': return DynamicType.mp;
      case 'mf': return DynamicType.mf;
      case 'sf': return DynamicType.sf;
      case 'sfp': return DynamicType.sfp;
      case 'sfpp': return DynamicType.sfpp;
      case 'fp': return DynamicType.fp;
      case 'pf': return DynamicType.pf;
      case 'rf': return DynamicType.rf;
      case 'rfz': return DynamicType.rfz;
      case 'fz': return DynamicType.fz;
      case 'sfz': return DynamicType.sfz;
      case 'sffz': return DynamicType.sffz;
      case 'sfzp': return DynamicType.sfzp;
      case 'n': return DynamicType.niente;
      default: return DynamicType.none;
    }
  }
}

// ============================================================================
// 11. DÉPLACEMENTS D'OCTAVE
// ============================================================================

enum OctaveShiftType {
  none,
  ottavaAlta,
  ottavaBassa,
  quindicesimaAlta,
  quindicesimaBassa,
}

// ============================================================================
// 12. LIGATURES (Beams)
// ============================================================================

enum BeamType {
  none,
  start,
  continue_,
  end,
  forward,
  backward,
  forwardHook,
  backwardHook,
}

// ============================================================================
// 13. LIAISONS (Ties & Slurs)
// ============================================================================

enum TieType { none, start, stop, continue_ }
enum SlurType { none, start, stop, continue_ }

// ============================================================================
// 14. SILENCES MULTI-MESURES
// ============================================================================

enum MultiRestType {
  none,
  measure,
  multiMeasure,
  hidden,
}

// ============================================================================
// 15. INDICATIONS DE TEMPO
// ============================================================================

enum TempoType { none, metronome, text, both }

// ============================================================================
// 16. PÉDALES
// ============================================================================

enum PedalType {
  none,
  start,
  stop,
  change,
  sostenuto,
  unaCorda,
  treCorde,
}

// ============================================================================
// 17. NOTATIONS GUITARE
// ============================================================================

enum GuitarNotation {
  none,
  chordDiagram,
  fretNumber,
  stringNumber,
  bend,
  slide,
  hammerOn,
  pullOff,
  vibrato,
  palmMute,
  harmonic,
}

// ============================================================================
// 18. RÉPÉTITIONS
// ============================================================================

enum RepeatType {
  none,
  volta1,
  volta2,
  volta3,
  dc,
  ds,
  alFine,
  alCoda,
  coda,
  segno,
}

// ============================================================================
// 19. STYLE DE NOTES
// ============================================================================

enum NoteStyle {
  normal,
  grace,
  cue,
  stemless,
  slash,
  ghost,
  harmonic,
  accent,
}

// ============================================================================
// 20. NUANCES ÉTENDUES
// ============================================================================

enum DynamicExtended {
  none,
  niente,
  calando,
  morendo,
  perdendosi,
  smorzando,
  sottoVoce,
  mezzaVoce,
  rinforzando,
  pocoAPoco,
}

// ============================================================================
// 21. SYSTÈMES / PORTÉES
// ============================================================================
// v2c-79 : StaffLines (enum) SUPPRIMÉ au profit d'un int brut.
// Raison : le test W3C 14a exige des valeurs arbitraires (3, 7, ...),
//          qu'un enum fermé ne peut pas représenter.
// Convention : un int >= 1. Valeur standard = 5.
//              Valeur "percussion" = 1.
//              Valeur "tablature" = 6 (ou 4 pour tab4).
// ⚠️ Aucun symbole global n'est défini : on écrit `5` en dur quand on veut
//    la portée standard (voir les usages dans staff.dart, etc.).
// ============================================================================

// ============================================================================
// 22. FORMES DE TÊTES DE NOTES
// ============================================================================

// v2c-91 : ajout de `slash` pour les têtes slash (21k).
enum NoteheadShape {
  normal,
  diamond,
  triangle,
  square,
  cross,
  x,
  circleX,
  circleDot,
  invertedTriangle,
  arrowDown,
  arrowUp,
  slashed,
  backSlashed,
  cluster,
  slash,   // v2c-91
  none,
}

// ============================================================================
// 23. TYPES DE TRÉMOLOS
// ============================================================================

enum TremoloType { none, single, start, stop, unmeasured }

// ============================================================================
// 24. TYPES DE GLISSANDO
// ============================================================================

enum GlissandoType { none, slide, glissando }

// ============================================================================
// 25. TYPES DE SOUFFLE / CÉSURE
// ============================================================================

enum BreathType { none, breathMark, caesura }