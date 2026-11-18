// lib/models/events/music_event.dart
// ============================================================================
// ÉVÉNEMENTS MUSICAUX (Notes, Silences, Accords) — v2c-93z
// ============================================================================
// v2c-93z : printObject/printLyric, noteheadParentheses, tuplets complets.
//           + MULTIPLE TUPLETS PAR NOTE (test W3C 23d).
//           + bracketExplicit (distinction explicite vs défaut implicite).
//             Le renderer peut ainsi auto-détecter un "beam group unique"
//             pour décider si un bracket implicite doit être dessiné ou non.
// + v1.0 : ajout des Notations (Fermata, Arpeggio)
// ============================================================================

import '../enums/music_enums.dart';
import 'pitch.dart';
import 'lyric.dart';
import 'notations.dart'; // <-- NOUVEL IMPORT

// ============================================================================
// v2c-84 : ARTICULATION AVEC PLACEMENT
// ============================================================================

class Articulation {
  final ArticulationType type;
  final String? placement;

  const Articulation({
    required this.type,
    this.placement,
  });

  bool get isAbove => placement == 'above';
  bool get isBelow => placement == 'below';
  bool get isAuto => placement == null;

  Articulation copyWith({
    ArticulationType? type,
    String? placement,
  }) {
    return Articulation(
      type: type ?? this.type,
      placement: placement ?? this.placement,
    );
  }

  @override
  String toString() => 'Articulation(${type.name}'
      '${placement != null ? ", $placement" : ", auto"})';
}

// ============================================================================
// v2c-93z : TUPLET DISPLAY SIDE (test W3C 23c)
// ============================================================================

class TupletDisplaySide {
  final int? number;
  final DurationType? type;
  final int dots;

  const TupletDisplaySide({
    this.number,
    this.type,
    this.dots = 0,
  });

  bool get isEmpty => number == null && type == null && dots == 0;

  TupletDisplaySide copyWith({
    int? number,
    DurationType? type,
    int? dots,
  }) {
    return TupletDisplaySide(
      number: number ?? this.number,
      type: type ?? this.type,
      dots: dots ?? this.dots,
    );
  }

  @override
  String toString() =>
      'TupletDisplaySide(number: $number, type: $type, dots: $dots)';
}

// ============================================================================
// v2c-93z : TUPLET METADATA (test W3C 23d — tuplets imbriqués)
// ============================================================================

class TupletMetadata {
  final int number;
  final String placement;
  final bool bracket;
  final bool bracketExplicit;
  final String showNumber;   // 'actual' / 'both' / 'none'
  final String showType;     // '' / 'actual' / 'both'
  final String lineShape;    // 'straight' / 'curved'
  final TupletDisplaySide? displayActual;
  final TupletDisplaySide? displayNormal;

  const TupletMetadata({
    required this.number,
    this.placement = '',
    this.bracket = true,
    this.bracketExplicit = false,
    this.showNumber = 'actual',
    this.showType = '',
    this.lineShape = 'straight',
    this.displayActual,
    this.displayNormal,
  });

  @override
  String toString() => 'TupletMetadata(n=$number, placement="$placement", '
      'bracket=$bracket, show=$showNumber/$showType, '
      'shape=$lineShape)';
}

// ============================================================================
// ÉVÉNEMENT MUSICAL ABSTRAIT
// ============================================================================

abstract class MusicEvent {
  final int duration;
  final int timePosition;
  final DurationType durationType;
  final DotType dotType;
  final int tupletsNumerator;
  final int tupletsDenominator;
  final int voiceIndex;
  final int staffNumber;
  final double? defaultX;
  final double? defaultY;

  const MusicEvent({
    required this.durationType,
    this.duration = 0,
    this.timePosition = 0,
    this.dotType = DotType.none,
    this.tupletsNumerator = 1,
    this.tupletsDenominator = 1,
    this.voiceIndex = 1,
    this.staffNumber = 1,
    this.defaultX,
    this.defaultY,
  });

  double get durationFraction {
    double base = durationType.relativeValue;
    switch (dotType) {
      case DotType.none: break;
      case DotType.single: base *= 1.5; break;
      case DotType.double: base *= 1.75; break;
      case DotType.triple: base *= 1.875; break;
    }
    if (tupletsNumerator > 1) {
      base *= (tupletsDenominator / tupletsNumerator);
    }
    return base;
  }

  bool get hasTie => false;
  bool get isSlurStart => false;
  bool get isRest => false;

  MusicEvent copyWithBase({
    int? duration,
    int? timePosition,
    DurationType? durationType,
    DotType? dotType,
    int? tupletsNumerator,
    int? tupletsDenominator,
    int? voiceIndex,
    int? staffNumber,
    double? defaultX,
    double? defaultY,
  });
}

// ============================================================================
// SILENCE
// ============================================================================

class RestEvent extends MusicEvent {
  final bool isHidden;
  final String? displayStep;
  final int? displayOctave;
  final bool isMeasureRest;
  final bool noteheadParentheses;
  final NoteheadShape? notehead;
  
  // Ajout des notations pour les silences (ex: fermata sur silence)
  final NoteNotations notations;

  const RestEvent({
    required super.durationType,
    super.duration,
    super.timePosition,
    super.dotType,
    super.tupletsNumerator,
    super.tupletsDenominator,
    super.voiceIndex,
    super.staffNumber,
    super.defaultX,
    super.defaultY,
    this.isHidden = false,
    this.displayStep,
    this.displayOctave,
    this.isMeasureRest = false,
    this.noteheadParentheses = false,
    this.notehead,
    this.notations = const NoteNotations(),
  });

  @override
  bool get isRest => true;

  @override
  RestEvent copyWithBase({
    int? duration,
    int? timePosition,
    DurationType? durationType,
    DotType? dotType,
    int? tupletsNumerator,
    int? tupletsDenominator,
    int? voiceIndex,
    int? staffNumber,
    double? defaultX,
    double? defaultY,
  }) {
    return copyWith(
      duration: duration,
      timePosition: timePosition,
      durationType: durationType,
      dotType: dotType,
      tupletsNumerator: tupletsNumerator,
      tupletsDenominator: tupletsDenominator,
      voiceIndex: voiceIndex,
      staffNumber: staffNumber,
      defaultX: defaultX,
      defaultY: defaultY,
    );
  }

  RestEvent copyWith({
    DurationType? durationType,
    int? duration,
    int? timePosition,
    DotType? dotType,
    int? tupletsNumerator,
    int? tupletsDenominator,
    int? voiceIndex,
    int? staffNumber,
    double? defaultX,
    double? defaultY,
    bool? isHidden,
    String? displayStep,
    int? displayOctave,
    bool? isMeasureRest,
    bool? noteheadParentheses,
    NoteheadShape? notehead,
    NoteNotations? notations,
  }) {
    return RestEvent(
      durationType: durationType ?? this.durationType,
      duration: duration ?? this.duration,
      timePosition: timePosition ?? this.timePosition,
      dotType: dotType ?? this.dotType,
      tupletsNumerator: tupletsNumerator ?? this.tupletsNumerator,
      tupletsDenominator: tupletsDenominator ?? this.tupletsDenominator,
      voiceIndex: voiceIndex ?? this.voiceIndex,
      staffNumber: staffNumber ?? this.staffNumber,
      defaultX: defaultX ?? this.defaultX,
      defaultY: defaultY ?? this.defaultY,
      isHidden: isHidden ?? this.isHidden,
      displayStep: displayStep ?? this.displayStep,
      displayOctave: displayOctave ?? this.displayOctave,
      isMeasureRest: isMeasureRest ?? this.isMeasureRest,
      noteheadParentheses: noteheadParentheses ?? this.noteheadParentheses,
      notehead: notehead ?? this.notehead,
      notations: notations ?? this.notations,
    );
  }
}

// ============================================================================
// NOTE OU ACCORD
// ============================================================================

class NoteEvent extends MusicEvent {
  final String id;
  final List<Pitch> pitches;
  final StemDirection stemDirection;
  final List<Articulation> articulations;
  final DynamicType dynamicMark;
  final double? positionX;
  final String? stem;
  final List<Lyric> lyrics;
  final bool isChordPart;

  final bool isGrace;
  final bool graceSlash;
  final bool isCue;

  final Set<int> slursStarted;
  final Set<int> slursStopped;

  final Map<int, BeamType> beams;

  final Set<int> tupletStarts;
  final Set<int> tupletStops;
  final Map<int, TupletMetadata> tupletMetadata;

  final Map<String, String> rawNotations;

  final TremoloType tremoloType;
  final int tremoloCount;

  final NoteheadShape notehead;
  final bool? noteheadFilled;

  final bool printObject;
  final bool printLyric;
  final bool noteheadParentheses;
  
  // AJOUT : Le conteneur des notations (Fermata, Arpeggio...)
  final NoteNotations notations;

  NoteEvent({
    required this.id,
    required this.pitches,
    required super.durationType,
    super.duration,
    super.timePosition,
    super.dotType,
    super.tupletsNumerator,
    super.tupletsDenominator,
    super.voiceIndex,
    super.staffNumber,
    super.defaultX,
    super.defaultY,
    this.stemDirection = StemDirection.auto,
    this.articulations = const [],
    this.dynamicMark = DynamicType.none,
    this.positionX,
    this.stem,
    this.lyrics = const [],
    this.isChordPart = false,
    this.isGrace = false,
    this.graceSlash = false,
    this.isCue = false,
    this.slursStarted = const {},
    this.slursStopped = const {},
    this.beams = const {},
    this.tupletStarts = const <int>{},
    this.tupletStops = const <int>{},
    this.tupletMetadata = const <int, TupletMetadata>{},
    this.rawNotations = const {},
    this.tremoloType = TremoloType.none,
    this.tremoloCount = 0,
    this.notehead = NoteheadShape.normal,
    this.noteheadFilled,
    this.printObject = true,
    this.printLyric = true,
    this.noteheadParentheses = false,
    this.notations = const NoteNotations(), // <-- INITIALISATION
  });

  bool get tupletStart => tupletStarts.isNotEmpty;
  bool get tupletStop => tupletStops.isNotEmpty;
  bool get isChord => pitches.length > 1;

  Pitch get primaryPitch => pitches.isNotEmpty
      ? pitches.first
      : const Pitch(letter: NoteLetter.C, octave: 4);

  @override
  bool get hasTie => pitches.any(
        (p) => p.tiesStarted.isNotEmpty || p.tiesStopped.isNotEmpty,
      );

  @override
  bool get isSlurStart => slursStarted.isNotEmpty;

  @override
  NoteEvent copyWithBase({
    int? duration,
    int? timePosition,
    DurationType? durationType,
    DotType? dotType,
    int? tupletsNumerator,
    int? tupletsDenominator,
    int? voiceIndex,
    int? staffNumber,
    double? defaultX,
    double? defaultY,
  }) {
    return copyWith(
      duration: duration,
      timePosition: timePosition,
      durationType: durationType,
      dotType: dotType,
      tupletsNumerator: tupletsNumerator,
      tupletsDenominator: tupletsDenominator,
      voiceIndex: voiceIndex,
      staffNumber: staffNumber,
      defaultX: defaultX,
      defaultY: defaultY,
    );
  }

  NoteEvent copyWith({
    String? id,
    List<Pitch>? pitches,
    DurationType? durationType,
    int? duration,
    int? timePosition,
    DotType? dotType,
    int? tupletsNumerator,
    int? tupletsDenominator,
    int? voiceIndex,
    int? staffNumber,
    double? defaultX,
    double? defaultY,
    StemDirection? stemDirection,
    List<Articulation>? articulations,
    DynamicType? dynamicMark,
    double? positionX,
    String? stem,
    List<Lyric>? lyrics,
    bool? isChordPart,
    bool? isGrace,
    bool? graceSlash,
    bool? isCue,
    Set<int>? slursStarted,
    Set<int>? slursStopped,
    Map<int, BeamType>? beams,
    Set<int>? tupletStarts,
    Set<int>? tupletStops,
    Map<int, TupletMetadata>? tupletMetadata,
    Map<String, String>? rawNotations,
    TremoloType? tremoloType,
    int? tremoloCount,
    NoteheadShape? notehead,
    bool? noteheadFilled,
    bool? printObject,
    bool? printLyric,
    bool? noteheadParentheses,
    NoteNotations? notations, // <-- AJOUT
  }) {
    return NoteEvent(
      id: id ?? this.id,
      pitches: pitches ?? this.pitches,
      durationType: durationType ?? this.durationType,
      duration: duration ?? this.duration,
      timePosition: timePosition ?? this.timePosition,
      dotType: dotType ?? this.dotType,
      tupletsNumerator: tupletsNumerator ?? this.tupletsNumerator,
      tupletsDenominator: tupletsDenominator ?? this.tupletsDenominator,
      voiceIndex: voiceIndex ?? this.voiceIndex,
      staffNumber: staffNumber ?? this.staffNumber,
      defaultX: defaultX ?? this.defaultX,
      defaultY: defaultY ?? this.defaultY,
      stemDirection: stemDirection ?? this.stemDirection,
      articulations: articulations ?? this.articulations,
      dynamicMark: dynamicMark ?? this.dynamicMark,
      positionX: positionX ?? this.positionX,
      stem: stem ?? this.stem,
      lyrics: lyrics ?? this.lyrics,
      isChordPart: isChordPart ?? this.isChordPart,
      isGrace: isGrace ?? this.isGrace,
      graceSlash: graceSlash ?? this.graceSlash,
      isCue: isCue ?? this.isCue,
      slursStarted: slursStarted ?? this.slursStarted,
      slursStopped: slursStopped ?? this.slursStopped,
      beams: beams ?? this.beams,
      tupletStarts: tupletStarts ?? this.tupletStarts,
      tupletStops: tupletStops ?? this.tupletStops,
      tupletMetadata: tupletMetadata ?? this.tupletMetadata,
      rawNotations: rawNotations ?? this.rawNotations,
      tremoloType: tremoloType ?? this.tremoloType,
      tremoloCount: tremoloCount ?? this.tremoloCount,
      notehead: notehead ?? this.notehead,
      noteheadFilled: noteheadFilled ?? this.noteheadFilled,
      printObject: printObject ?? this.printObject,
      printLyric: printLyric ?? this.printLyric,
      noteheadParentheses: noteheadParentheses ?? this.noteheadParentheses,
      notations: notations ?? this.notations, // <-- AJOUT
    );
  }
}