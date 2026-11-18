// lib/models/score/measure.dart
// ============================================================================
// MESURE MUSICALE — v2c-93z
// ============================================================================
// v2c-74 : KeyAlteration + KeySignature.customAlterations.
// v2c-75 : KeyAlteration.alter devient un `double`.
// v2c-76 : KeyCancel (annulation partielle).
// v2c-77 : KeyChange (changements d'armure MID-MESURE).
// v2c-79 : staffLines + midMeasureStaffLineChanges + hiddenLines.
// v2c-93z: slashNotation (test W3C 22b, mesures 2-3).
//          <measure-style><slash type="start|stop" use-stems="yes|no">
//          Force TOUTES les notes de la mesure à s'afficher en slash
//          (notation rythmique). Voir SlashNotation.
// ============================================================================

import '../enums/music_enums.dart';
import '../events/direction.dart';
import 'voice.dart';

// ============================================================================
// 0. v2c-93z : NOTATION RYTHMIQUE (SLASH)
// ============================================================================

/// Mode "notation rythmique" déclenché par
/// `<measure-style><slash type="start" use-stems="..."` dans MusicXML.
///
/// Quand ce mode est actif sur une mesure, TOUTES les notes de la mesure
/// affichent un glyphe slash (`noteheadSlashHorizontalEnds` ou variante)
/// au lieu de la tête normale.
///
/// Utilisé en jazz, pédagogie, exercices rythmiques.
///
/// Voir test W3C 22b, mesures 2 et 3 :
///   - Mesure 2 : use-stems="no"  → slashes SANS hampe.
///   - Mesure 3 : use-stems="yes" → slashes AVEC hampe.
class SlashNotation {
  /// true  = afficher les hampes (les slash ont des hampes normales)
  /// false = cacher les hampes (slashes "nus")
  final bool useStems;

  /// Type de slash (quarter, eighth, 16th, etc.).
  /// Actuellement on supporte uniquement `quarter` (le défaut et le cas
  /// de 22b). Les autres types sont réservés pour de futurs tests.
  /// ⚠️ Dans SMuFL, les slash `quarter` et `eighth` ont le même glyphe
  ///    visuel, donc on ne différencie pas pour l'instant.
  final String slashType;

  const SlashNotation({
    this.useStems = true,
    this.slashType = 'quarter',
  });

  SlashNotation copyWith({
    bool? useStems,
    String? slashType,
  }) {
    return SlashNotation(
      useStems: useStems ?? this.useStems,
      slashType: slashType ?? this.slashType,
    );
  }

  @override
  String toString() =>
      'SlashNotation(useStems: $useStems, type: $slashType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlashNotation &&
          other.useStems == useStems &&
          other.slashType == slashType;

  @override
  int get hashCode => Object.hash(useStems, slashType);
}

// ============================================================================
// 1. CHIFFRAGE DE MESURE (TIME SIGNATURE)
// ============================================================================

class TimeFraction {
  final int numerator;
  final int denominator;
  final List<int>? subGroups;

  const TimeFraction({
    required this.numerator,
    required this.denominator,
    this.subGroups,
  });

  bool get isCompositeNumerator =>
      subGroups != null && subGroups!.length > 1;

  @override
  String toString() {
    if (isCompositeNumerator) return '${subGroups!.join('+')}/$denominator';
    return '$numerator/$denominator';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeFraction &&
          other.numerator == numerator &&
          other.denominator == denominator &&
          _listEq(other.subGroups, subGroups);

  @override
  int get hashCode => Object.hash(
        numerator,
        denominator,
        subGroups == null ? null : Object.hashAll(subGroups!),
      );

  static bool _listEq(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class InterchangeableTimeSignature {
  final String? relation;
  final int beats;
  final int beatType;
  final List<TimeFraction>? fractions;

  const InterchangeableTimeSignature({
    this.relation,
    this.beats = 4,
    this.beatType = 4,
    this.fractions,
  });

  bool get isComposite => fractions != null && fractions!.length > 1;

  @override
  String toString() {
    if (isComposite) {
      return fractions!.map((f) => f.toString()).join('+');
    }
    return '$beats/$beatType';
  }
}

class TimeSignature {
  final int beats;
  final int beatType;
  final TimeSignatureType display;
  final List<int>? beatGroups;
  final List<TimeFraction>? fractions;
  final String? senzaMisuraText;
  final InterchangeableTimeSignature? interchangeable;

  const TimeSignature({
    this.beats = 4,
    this.beatType = 4,
    this.display = TimeSignatureType.standard,
    this.beatGroups,
    this.fractions,
    this.senzaMisuraText,
    this.interchangeable,
  });

  bool get isCommon => display == TimeSignatureType.common;
  bool get isCut => display == TimeSignatureType.cut;
  bool get isSenzaMisura => display == TimeSignatureType.senzaMisura;

  bool get isCompositeWithSameDenom =>
      beatGroups != null && beatGroups!.length > 1;

  bool get isCompositeWithDiffDenom =>
      fractions != null && fractions!.length > 1;

  bool get isComposite =>
      isCompositeWithSameDenom || isCompositeWithDiffDenom;

  String get beatsDisplay {
    if (beatGroups == null || beatGroups!.isEmpty) return beats.toString();
    return beatGroups!.join('+');
  }

  double get totalDurationFraction => beats / beatType;

  TimeSignature copyWith({
    int? beats,
    int? beatType,
    TimeSignatureType? display,
    List<int>? beatGroups,
    List<TimeFraction>? fractions,
    String? senzaMisuraText,
    InterchangeableTimeSignature? interchangeable,
  }) {
    return TimeSignature(
      beats: beats ?? this.beats,
      beatType: beatType ?? this.beatType,
      display: display ?? this.display,
      beatGroups: beatGroups ?? this.beatGroups,
      fractions: fractions ?? this.fractions,
      senzaMisuraText: senzaMisuraText ?? this.senzaMisuraText,
      interchangeable: interchangeable ?? this.interchangeable,
    );
  }

  @override
  String toString() {
    if (isSenzaMisura) {
      return senzaMisuraText == null
          ? 'TimeSignature(senza-misura)'
          : 'TimeSignature(senza-misura: $senzaMisuraText)';
    }
    if (isCompositeWithDiffDenom) {
      return fractions!.map((f) => f.toString()).join('+');
    }
    return '$beatsDisplay/$beatType';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSignature &&
          other.beats == beats &&
          other.beatType == beatType &&
          other.display == display &&
          other.senzaMisuraText == senzaMisuraText &&
          other.interchangeable == interchangeable &&
          _listEqualsInt(other.beatGroups, beatGroups) &&
          _listEqualsFrac(other.fractions, fractions);

  @override
  int get hashCode => Object.hash(
        beats,
        beatType,
        display,
        senzaMisuraText,
        interchangeable,
        beatGroups == null ? null : Object.hashAll(beatGroups!),
        fractions == null ? null : Object.hashAll(fractions!),
      );

  static bool _listEqualsInt(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _listEqualsFrac(List<TimeFraction>? a, List<TimeFraction>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ============================================================================
// 2. ARMURE À LA CLEF
// ============================================================================

class KeyAlteration {
  final NoteLetter step;
  final double alter;
  final int? octave;

  const KeyAlteration({
    required this.step,
    required this.alter,
    this.octave,
  });

  @override
  String toString() => '${step.name}${alter >= 0 ? '+' : ''}$alter'
      '${octave != null ? '@$octave' : ''}';
}

class KeyCancel {
  final int fifths;
  final String location;

  const KeyCancel({
    required this.fifths,
    this.location = 'left',
  });

  int get count => fifths.abs().clamp(0, 7);
  bool get cancelsSharps => fifths > 0;

  @override
  String toString() => 'KeyCancel($fifths, $location)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyCancel &&
          other.fifths == fifths &&
          other.location == location;

  @override
  int get hashCode => Object.hash(fifths, location);
}

class KeySignature {
  final int fifths;
  final List<KeyAlteration>? customAlterations;
  final KeyCancel? cancel;

  const KeySignature({
    this.fifths = 0,
    this.customAlterations,
    this.cancel,
  });

  bool get hasSharps => fifths > 0;
  bool get hasFlats => fifths < 0;

  int get alterationCount {
    if (customAlterations != null && customAlterations!.isNotEmpty) {
      return customAlterations!.length;
    }
    return fifths.abs().clamp(0, 7);
  }

  bool get isCustom =>
      customAlterations != null && customAlterations!.isNotEmpty;

  KeySignature copyWith({
    int? fifths,
    List<KeyAlteration>? customAlterations,
    KeyCancel? cancel,
  }) {
    return KeySignature(
      fifths: fifths ?? this.fifths,
      customAlterations: customAlterations ?? this.customAlterations,
      cancel: cancel ?? this.cancel,
    );
  }

  @override
  String toString() {
    if (isCustom) {
      return 'KeySignature(custom: $customAlterations)';
    }
    return 'KeySignature(fifths: $fifths, cancel: $cancel)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeySignature &&
          other.fifths == fifths &&
          other.cancel == cancel &&
          _listEq(other.customAlterations, customAlterations);

  @override
  int get hashCode => Object.hash(
        fifths,
        cancel,
        customAlterations == null ? null : Object.hashAll(customAlterations!),
      );

  static bool _listEq(List<KeyAlteration>? a, List<KeyAlteration>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].step != b[i].step ||
          a[i].alter != b[i].alter ||
          a[i].octave != b[i].octave) {
        return false;
      }
    }
    return true;
  }
}

class KeyChange {
  final int timePosition;
  final KeySignature keySignature;

  const KeyChange({
    required this.timePosition,
    required this.keySignature,
  });

  @override
  String toString() => 'KeyChange(tp=$timePosition, $keySignature)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyChange &&
          other.timePosition == timePosition &&
          other.keySignature == keySignature;

  @override
  int get hashCode => Object.hash(timePosition, keySignature);
}

// ============================================================================
// 2bis. v2c-79 : CHANGEMENT MID-MESURE DU NOMBRE DE LIGNES
// ============================================================================

/// Représente un changement du nombre de lignes d'une portée EN COURS de
/// mesure (scénario C du test W3C 14a).
///
/// ⚠️ Utilisé UNIQUEMENT pour le rendu ; le lineCount "effectif" de la mesure
///    pour le layout est le MAX des valeurs rencontrées.
class MidMeasureStaffLineChange {
  /// Position temporelle (en divisions depuis le début de la mesure).
  final int timePosition;

  /// Nouveau nombre de lignes à partir de cette position.
  final int lineCount;

  const MidMeasureStaffLineChange({
    required this.timePosition,
    required this.lineCount,
  });

  @override
  String toString() =>
      'MidMeasureStaffLineChange(tp=$timePosition, lines=$lineCount)';
}

// ============================================================================
// 3. MESURE
// ============================================================================

class Measure {
  final String id;
  final int measureNumber;
  final TimeSignature timeSignature;
  final ClefType? clef;
  final bool showTimeSignature;
  final bool showKeySignature;
  final KeySignature keySignature;

  /// v2c-77 : changements d'armure MID-MESURE.
  final List<KeyChange> midMeasureKeyChanges;

  final int divisions;
  final int multiRestCount;
  final BarlineType leftBarline;
  final BarlineType rightBarline;
  final List<Voice> voices;
  final List<DirectionEvent> directions;
  final bool hasSystemBreak;
  final bool pageBreak;
  final double width;
  final bool isPickup;
  final double systemLeftMargin;
  final double systemRightMargin;
  final double systemDistance;
  final double topSystemDistance;

  // ─── v2c-79 : STAFF-LINES ────────────────────────────────────────────────

  /// Nombre de lignes de portée au DÉBUT de cette mesure.
  ///
  /// - `null` = pas de changement déclaré dans cette mesure (hériter).
  /// - `int` = valeur au début de la mesure (>= 0).
  ///
  /// ⚠️ Peut aussi contenir des changements en cours via
  ///    [midMeasureStaffLineChanges].
  final int? staffLines;

  /// Changements du nombre de lignes EN COURS de mesure (tp > 0).
  /// Trié par `timePosition` croissant.
  final List<MidMeasureStaffLineChange> midMeasureStaffLineChanges;

  /// Lignes à NE PAS dessiner (test 14a scénario D).
  /// Numérotation MusicXML : 1 = ligne du bas.
  /// Ex : `{2, 4}` masque les 2ᵉ et 4ᵉ lignes depuis le bas.
  final Set<int> hiddenLines;

  // ═════════════════════════════════════════════════════════════════════════
  // v2c-93z : NOTATION RYTHMIQUE (SLASH) — test W3C 22b
  // ═════════════════════════════════════════════════════════════════════════
  //
  /// Mode slash ACTIF sur cette mesure (au début de la mesure).
  ///
  ///   - null : mode normal, têtes de notes standard.
  ///   - non-null : toutes les notes de la mesure s'affichent en slash.
  ///
  /// ⚠️ Le mode est persistent cross-mesure : si `<slash type="start">` dans
  ///    une mesure A et `<slash type="stop">` dans une mesure B > A, alors
  ///    toutes les mesures entre A et B (incluses) ont ce champ non-null.
  ///    C'est MeasureParser qui gère la persistance (comme pour les clefs).
  final SlashNotation? slashNotation;

  const Measure({
    required this.measureNumber,
    this.id = '',
    this.timeSignature = const TimeSignature(),
    this.showTimeSignature = false,
    this.showKeySignature = false,
    this.keySignature = const KeySignature(),
    this.midMeasureKeyChanges = const [],
    this.clef,
    this.divisions = 1,
    this.multiRestCount = 1,
    this.leftBarline = BarlineType.none,
    this.rightBarline = BarlineType.single,
    this.voices = const [Voice(voiceIndex: 1)],
    this.directions = const [],
    this.hasSystemBreak = false,
    this.pageBreak = false,
    this.width = 200.0,
    this.isPickup = false,
    this.systemLeftMargin = 0.0,
    this.systemRightMargin = 0.0,
    this.systemDistance = 0.0,
    this.topSystemDistance = 0.0,
    // v2c-79
    this.staffLines,
    this.midMeasureStaffLineChanges = const [],
    this.hiddenLines = const {},
    // v2c-93z
    this.slashNotation,
  });

  Voice get primaryVoice {
    return voices.firstWhere(
      (v) => v.voiceIndex == 1,
      orElse: () =>
          voices.isNotEmpty ? voices.first : const Voice(voiceIndex: 1),
    );
  }

  Voice? getVoice(int index) {
    try {
      return voices.firstWhere((v) => v.voiceIndex == index);
    } catch (_) {
      return null;
    }
  }

  bool get hasSharps => keySignature.hasSharps;
  bool get hasFlats => keySignature.hasFlats;
  int get alterationCount => keySignature.alterationCount;

  int get timeSignatureBeats => timeSignature.beats;
  int get timeSignatureBeatType => timeSignature.beatType;
  TimeSignatureType get timeSignatureDisplay => timeSignature.display;

  int get activeVoiceCount =>
      voices.where((v) => v.events.isNotEmpty).length;

  bool get hasDirections => directions.isNotEmpty;

  bool get isMultiRest => multiRestCount > 1;

  int get totalDivisions {
    if (divisions <= 0) return 1;
    return (timeSignature.beats * 4 * divisions) ~/ timeSignature.beatType;
  }

  /// v2c-93z : raccourci — la mesure affiche-t-elle en mode slash ?
  bool get hasSlashNotation => slashNotation != null;

  Measure copyWith({
    String? id,
    int? measureNumber,
    TimeSignature? timeSignature,
    ClefType? clef,
    bool? showTimeSignature,
    bool? showKeySignature,
    KeySignature? keySignature,
    List<KeyChange>? midMeasureKeyChanges,
    int? divisions,
    int? multiRestCount,
    BarlineType? leftBarline,
    BarlineType? rightBarline,
    List<Voice>? voices,
    List<DirectionEvent>? directions,
    bool? hasSystemBreak,
    bool? pageBreak,
    double? width,
    bool? isPickup,
    double? systemLeftMargin,
    double? systemRightMargin,
    double? systemDistance,
    double? topSystemDistance,
    // v2c-79
    int? staffLines,
    List<MidMeasureStaffLineChange>? midMeasureStaffLineChanges,
    Set<int>? hiddenLines,
    // v2c-93z
    SlashNotation? slashNotation,
  }) {
    return Measure(
      id: id ?? this.id,
      measureNumber: measureNumber ?? this.measureNumber,
      timeSignature: timeSignature ?? this.timeSignature,
      clef: clef ?? this.clef,
      showTimeSignature: showTimeSignature ?? this.showTimeSignature,
      showKeySignature: showKeySignature ?? this.showKeySignature,
      keySignature: keySignature ?? this.keySignature,
      midMeasureKeyChanges:
          midMeasureKeyChanges ?? this.midMeasureKeyChanges,
      divisions: divisions ?? this.divisions,
      multiRestCount: multiRestCount ?? this.multiRestCount,
      leftBarline: leftBarline ?? this.leftBarline,
      rightBarline: rightBarline ?? this.rightBarline,
      voices: voices ?? this.voices,
      directions: directions ?? this.directions,
      hasSystemBreak: hasSystemBreak ?? this.hasSystemBreak,
      pageBreak: pageBreak ?? this.pageBreak,
      width: width ?? this.width,
      isPickup: isPickup ?? this.isPickup,
      systemLeftMargin: systemLeftMargin ?? this.systemLeftMargin,
      systemRightMargin: systemRightMargin ?? this.systemRightMargin,
      systemDistance: systemDistance ?? this.systemDistance,
      topSystemDistance: topSystemDistance ?? this.topSystemDistance,
      // v2c-79
      staffLines: staffLines ?? this.staffLines,
      midMeasureStaffLineChanges:
          midMeasureStaffLineChanges ?? this.midMeasureStaffLineChanges,
      hiddenLines: hiddenLines ?? this.hiddenLines,
      // v2c-93z
      slashNotation: slashNotation ?? this.slashNotation,
    );
  }

  @override
  String toString() {
    return 'Measure($id, num: $measureNumber, '
        '${timeSignature.beats}/${timeSignature.beatType}, '
        'div: $divisions (total: $totalDivisions), '
        'voices: ${voices.length}, directions: ${directions.length}, '
        'multiRest: $multiRestCount, showKeySig: $showKeySignature, '
        'midKeyChanges: ${midMeasureKeyChanges.length}, '
        'staffLines: $staffLines, '
        'midStaffChanges: ${midMeasureStaffLineChanges.length}, '
        'hiddenLines: $hiddenLines, '
        'slash: $slashNotation, '
        'width: $width)';
  }
}