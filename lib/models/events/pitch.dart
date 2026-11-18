// lib/models/events/pitch.dart
// ============================================================================
// HAUTEUR D'UNE NOTE — v2c-93z
// ============================================================================
// v2c-2h : ajout de isCautionary et isEditorial.
// v2c-81 : ajout des champs de TIE par pitch (tiesStarted, tiesStopped,
//          tieStartDirection, tieStopDirection). Permet les ties sur les
//          accords (test W3C 21b).
// v2c-92 : `alter` passe de `int` à `double` pour supporter les microtons.
// v2c-93z: AJOUT de la forme de tête + du filled AU NIVEAU DU PITCH
//          (test W3C 22c).
//          + AJOUT de `noteheadParentheses` (test W3C 22d) — quand
//            `<notehead parentheses="yes">` est présent, la tête doit être
//            entourée de parenthèses au rendu.
// ============================================================================

import '../enums/music_enums.dart';
import 'lyric.dart';

/// Représente la hauteur absolue d'une note de musique.
class Pitch {
  /// Lettre : C, D, E, F, G, A, B.
  final NoteLetter letter;

  /// Octave (4 pour le Do central C4).
  final int octave;

  /// Altération en demi-tons.
  /// v2c-92 : int → double pour supporter les microtons.
  final double alter;

  /// Altération graphique à afficher (indépendante de alter).
  final Accidental accidentalDisplay;

  /// Altération de courtoisie (cautionary). Parenthèses : (♮), (#), (b).
  final bool isCautionary;

  /// Altération éditoriale (editorial). Crochets : [♮], [#], [b].
  final bool isEditorial;

  // ─── v2c-81 : TIES PAR PITCH ─────────────────────────────────────────────

  final Set<int> tiesStarted;
  final Set<int> tiesStopped;
  final String? tieStartDirection;
  final String? tieStopDirection;

  // ─── v2c-93z : FORME DE TÊTE PAR PITCH ───────────────────────────────────

  /// Forme de la tête pour CE pitch spécifique.
  /// null → hériter de NoteEvent.notehead.
  final NoteheadShape? notehead;

  /// État rempli de la tête pour CE pitch.
  final bool? noteheadFilled;

  // ═════════════════════════════════════════════════════════════════════════
  // v2c-93z : PARENTHÈSES AUTOUR DE LA TÊTE (test W3C 22d)
  // ═════════════════════════════════════════════════════════════════════════
  //
  /// Quand `<notehead parentheses="yes">` est présent, la tête doit être
  /// entourée de parenthèses au rendu.
  ///
  /// Exemple 22d :
  ///   notehead parentheses="yes">normal/notehead>  → (tête normale)
  ///   notehead parentheses="yes">x/notehead>       → (x)
  ///
  /// ⚠️ Le rendu utilise les glyphes SMuFL :
  ///   - noteheadParenthesisLeft  (U+E0F5)
  ///   - noteheadParenthesisRight (U+E0F6)
  final bool noteheadParentheses;

  // ─── v2c-93z : PAROLES PAR PITCH ─────────────────────────────────────────

  /// Paroles attachées à CE pitch spécifique (test W3C 22c).
  final List<Lyric> lyrics;

  const Pitch({
    required this.letter,
    required this.octave,
    this.alter = 0.0,
    this.accidentalDisplay = Accidental.none,
    this.isCautionary = false,
    this.isEditorial = false,
    // v2c-81
    this.tiesStarted = const {},
    this.tiesStopped = const {},
    this.tieStartDirection,
    this.tieStopDirection,
    // v2c-93z
    this.notehead,
    this.noteheadFilled,
    this.noteheadParentheses = false,
    this.lyrics = const [],
  });

  // ─── v2c-92 : HELPERS MIDI ───────────────────────────────────────────────

  int get _semitoneForLetter {
    switch (letter) {
      case NoteLetter.C: return 0;
      case NoteLetter.D: return 2;
      case NoteLetter.E: return 4;
      case NoteLetter.F: return 5;
      case NoteLetter.G: return 7;
      case NoteLetter.A: return 9;
      case NoteLetter.B: return 11;
    }
  }

  /// v2c-92 : position exacte en demi-tons (C4 = 60.0).
  double get midiNumberExact =>
      (octave + 1) * 12 + _semitoneForLetter + alter;

  /// Numéro MIDI entier (arrondi au demi-ton le plus proche).
  int get midiNumber => midiNumberExact.round();

  Pitch copyWith({
    NoteLetter? letter,
    int? octave,
    double? alter,
    Accidental? accidentalDisplay,
    bool? isCautionary,
    bool? isEditorial,
    Set<int>? tiesStarted,
    Set<int>? tiesStopped,
    String? tieStartDirection,
    String? tieStopDirection,
    // v2c-93z
    NoteheadShape? notehead,
    bool? noteheadFilled,
    bool? noteheadParentheses,
    List<Lyric>? lyrics,
  }) {
    return Pitch(
      letter: letter ?? this.letter,
      octave: octave ?? this.octave,
      alter: alter ?? this.alter,
      accidentalDisplay: accidentalDisplay ?? this.accidentalDisplay,
      isCautionary: isCautionary ?? this.isCautionary,
      isEditorial: isEditorial ?? this.isEditorial,
      tiesStarted: tiesStarted ?? this.tiesStarted,
      tiesStopped: tiesStopped ?? this.tiesStopped,
      tieStartDirection: tieStartDirection ?? this.tieStartDirection,
      tieStopDirection: tieStopDirection ?? this.tieStopDirection,
      // v2c-93z
      notehead: notehead ?? this.notehead,
      noteheadFilled: noteheadFilled ?? this.noteheadFilled,
      noteheadParentheses: noteheadParentheses ?? this.noteheadParentheses,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  @override
  String toString() =>
      'Pitch(${letter.name}$octave, alter=$alter, '
      'display=$accidentalDisplay'
      '${isCautionary ? ", cautionary" : ""}'
      '${isEditorial ? ", editorial" : ""}'
      '${tiesStarted.isNotEmpty ? ", tieStart=$tiesStarted" : ""}'
      '${tiesStopped.isNotEmpty ? ", tieStop=$tiesStopped" : ""}'
      '${notehead != null ? ", head=$notehead" : ""}'
      '${noteheadParentheses ? ", (parens)" : ""}'
      '${lyrics.isNotEmpty ? ", ${lyrics.length} lyric(s)" : ""})';
}