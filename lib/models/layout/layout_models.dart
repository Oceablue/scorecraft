// lib/models/layout/layout_models.dart
// ============================================================================
// MODÈLES DE MISE EN PAGE (LAYOUT) — v2c-93z
// ============================================================================
// v2c-48  : ajout de `isInMultiVoiceMeasure` sur LayoutedNote.
// v2c-79  : staffLineCount, hiddenLines, midMeasureStaffLineChanges.
// v2c-90r : accidentalOffsetX (décalage colonne des altérations d'accord).
// v2c-93z : slashNotation sur LayoutedMeasure (test W3C 22b).
//           + getter effectiveLyrics sur LayoutedNote — SOURCE UNIQUE DE
//             VÉRITÉ pour la sélection des paroles (pitch.lyrics si non-vide,
//             sinon event.lyrics). Utilisé par LayoutEngine.computeBottomOverhang
//             ET LyricPainter.drawLyrics. AVANT v2c-93z, cette logique était
//             dupliquée dans les 2 fichiers, avec un risque de désynchronisation
//             (réservation ≠ dessin → débordement sur la portée suivante).
// ============================================================================

import '../events/music_event.dart';
import '../events/lyric.dart';
import '../events/pitch.dart';
import '../score/measure.dart';
import '../enums/music_enums.dart';

// ============================================================================
// NOTE MISE EN PAGE
// ============================================================================

class LayoutedNote {
  final String id;
  final String eventId;
  final MusicEvent event;
  final double x;
  final double yLine;
  final Pitch? pitch;
  final bool isChordMember;
  final bool isRest;
  final Accidental? displayAccidental;
  final bool accidentalCautionary;
  final bool accidentalEditorial;
  final int voiceIndex;
  final int timePosition;
  final int duration;
  final bool isGrace;

  /// v2c-48 : vrai si la mesure contient plusieurs voix actives.
  final bool isInMultiVoiceMeasure;

  /// v2c-90r : décalage horizontal de l'ALTÉRATION (en pixels).
  /// - 0.0 : position normale (à gauche de la tête)
  /// - Négatif : décalé plus à GAUCHE
  /// Permet d'empiler les altérations en COLONNE dans les accords
  /// (convention Behind Bars : la plus aiguë va le plus à gauche).
  final double accidentalOffsetX;

  const LayoutedNote({
    required this.id,
    required this.event,
    required this.x,
    required this.yLine,
    this.eventId = '',
    this.pitch,
    this.isChordMember = false,
    this.isRest = false,
    this.displayAccidental,
    this.accidentalCautionary = false,
    this.accidentalEditorial = false,
    this.voiceIndex = 1,
    this.timePosition = 0,
    this.duration = 0,
    this.isGrace = false,
    this.isInMultiVoiceMeasure = false,
    // v2c-90r
    this.accidentalOffsetX = 0.0,
  });

  LayoutedNote copyWith({
    String? id,
    String? eventId,
    MusicEvent? event,
    double? x,
    double? yLine,
    Pitch? pitch,
    bool? isChordMember,
    bool? isRest,
    Accidental? displayAccidental,
    bool? accidentalCautionary,
    bool? accidentalEditorial,
    int? voiceIndex,
    int? timePosition,
    int? duration,
    bool? isGrace,
    bool? isInMultiVoiceMeasure,
    double? accidentalOffsetX,
  }) {
    return LayoutedNote(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      event: event ?? this.event,
      x: x ?? this.x,
      yLine: yLine ?? this.yLine,
      pitch: pitch ?? this.pitch,
      isChordMember: isChordMember ?? this.isChordMember,
      isRest: isRest ?? this.isRest,
      displayAccidental: displayAccidental ?? this.displayAccidental,
      accidentalCautionary: accidentalCautionary ?? this.accidentalCautionary,
      accidentalEditorial: accidentalEditorial ?? this.accidentalEditorial,
      voiceIndex: voiceIndex ?? this.voiceIndex,
      timePosition: timePosition ?? this.timePosition,
      duration: duration ?? this.duration,
      isGrace: isGrace ?? this.isGrace,
      isInMultiVoiceMeasure:
          isInMultiVoiceMeasure ?? this.isInMultiVoiceMeasure,
      accidentalOffsetX: accidentalOffsetX ?? this.accidentalOffsetX,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // v2c-93z : SÉLECTION DES PAROLES EFFECTIVES
  // ═════════════════════════════════════════════════════════════════════════
  //
  /// Retourne les paroles à afficher pour cette note.
  ///
  /// Priorité :
  ///   1. `pitch.lyrics` (test W3C 22c — chaque membre d'un accord peut
  ///      porter son propre vers).
  ///   2. `event.lyrics` (fallback mono-pitch, ou quand l'accord entier
  ///      partage les paroles).
  ///   3. Liste vide.
  ///
  /// ⚠️ SOURCE UNIQUE DE VÉRITÉ — utilisée par :
  ///    - LayoutEngine.computeBottomOverhang (réservation de place)
  ///    - LyricPainter.drawLyrics (dessin)
  ///    AVANT v2c-93z, cette logique était dupliquée dans les 2 fichiers,
  ///    avec un risque de désynchronisation (réservation ≠ dessin → débor-
  ///    dement sur la portée suivante).
  List<Lyric> get effectiveLyrics {
    if (pitch != null && pitch!.lyrics.isNotEmpty) {
      return pitch!.lyrics;
    }
    if (event is NoteEvent) {
      return (event as NoteEvent).lyrics;
    }
    return const [];
  }

  @override
  String toString() {
    return 'LayoutedNote($id, v$voiceIndex@$timePosition, '
        'x=${x.toStringAsFixed(1)}, yLine=${yLine.toStringAsFixed(2)}'
        '${accidentalOffsetX != 0 ? ", accOff=${accidentalOffsetX.toStringAsFixed(1)}" : ""})';
  }
}

// ============================================================================
// MESURE MISE EN PAGE
// ============================================================================

class LayoutedMeasure {
  final Measure source;
  final List<LayoutedNote> notes;
  final int keySignature;
  final double x;
  final double contentWidth;
  final double finalWidth;
  final int divisions;
  final int totalDivisions;

  final int multiRestCount;
  final bool isMultiRestBar;
  final BarlineType? endBarline;

  /// v2c-79 : nombre de lignes effectif de la portée dans cette mesure.
  final int staffLineCount;

  /// v2c-79 : lignes masquées via line-detail print-object="no">.
  final Set<int> hiddenLines;

  /// v2c-79 : changements mid-mesure du nombre de lignes.
  final List<MidMeasureStaffLineChange> midMeasureStaffLineChanges;

  // ═════════════════════════════════════════════════════════════════════════
  // v2c-93z : MODE SLASH (notation rythmique) — test W3C 22b
  // ═════════════════════════════════════════════════════════════════════════
  //
  /// Mode slash actif sur cette mesure (recopié depuis Measure.slashNotation).
  ///
  ///   - null : mode normal, têtes de notes standard.
  ///   - non-null : toutes les notes de la mesure s'affichent en slash.
  ///
  /// ⚠️ Recopié du Measure source pour éviter que le painter ait à
  ///    remonter la chaîne LayoutedMeasure -> Measure à chaque note.
  final SlashNotation? slashNotation;

  const LayoutedMeasure({
    required this.source,
    required this.notes,
    required this.keySignature,
    required this.x,
    required this.contentWidth,
    required this.finalWidth,
    this.divisions = 1,
    this.totalDivisions = 1,
    this.multiRestCount = 1,
    this.isMultiRestBar = false,
    this.endBarline,
    this.staffLineCount = 5,
    this.hiddenLines = const {},
    this.midMeasureStaffLineChanges = const [],
    // v2c-93z
    this.slashNotation,
  });

  List<LayoutedNote> notesForVoice(int voiceIndex) =>
      notes.where((n) => n.voiceIndex == voiceIndex).toList();

  int get activeVoiceCount =>
      notes.map((n) => n.voiceIndex).toSet().length;

  bool get isMultiRest => multiRestCount > 1;

  /// v2c-93z : la mesure affiche-t-elle en mode slash ?
  bool get hasSlashNotation => slashNotation != null;

  LayoutedMeasure copyWith({
    Measure? source,
    List<LayoutedNote>? notes,
    int? keySignature,
    double? x,
    double? contentWidth,
    double? finalWidth,
    int? divisions,
    int? totalDivisions,
    int? multiRestCount,
    bool? isMultiRestBar,
    BarlineType? endBarline,
    int? staffLineCount,
    Set<int>? hiddenLines,
    List<MidMeasureStaffLineChange>? midMeasureStaffLineChanges,
    // v2c-93z
    SlashNotation? slashNotation,
  }) {
    return LayoutedMeasure(
      source: source ?? this.source,
      notes: notes ?? this.notes,
      keySignature: keySignature ?? this.keySignature,
      x: x ?? this.x,
      contentWidth: contentWidth ?? this.contentWidth,
      finalWidth: finalWidth ?? this.finalWidth,
      divisions: divisions ?? this.divisions,
      totalDivisions: totalDivisions ?? this.totalDivisions,
      multiRestCount: multiRestCount ?? this.multiRestCount,
      isMultiRestBar: isMultiRestBar ?? this.isMultiRestBar,
      endBarline: endBarline ?? this.endBarline,
      staffLineCount: staffLineCount ?? this.staffLineCount,
      hiddenLines: hiddenLines ?? this.hiddenLines,
      midMeasureStaffLineChanges:
          midMeasureStaffLineChanges ?? this.midMeasureStaffLineChanges,
      // v2c-93z
      slashNotation: slashNotation ?? this.slashNotation,
    );
  }
}

// ============================================================================
// PORTÉE MISE EN PAGE
// ============================================================================

class LayoutedStaff {
  final int globalStaffIndex;
  final int partStaffIndex;
  final String partId;
  final List<LayoutedMeasure> measures;
  final double yTopLine;
  final double lineSpacing;

  /// v2c-79 : nombre de lignes effectif de la portée dans ce système.
  final int lineCount;

  const LayoutedStaff({
    required this.globalStaffIndex,
    required this.partStaffIndex,
    required this.partId,
    required this.measures,
    required this.yTopLine,
    required this.lineSpacing,
    this.lineCount = 5,
  });

  LayoutedStaff copyWith({
    int? globalStaffIndex,
    int? partStaffIndex,
    String? partId,
    List<LayoutedMeasure>? measures,
    double? yTopLine,
    double? lineSpacing,
    int? lineCount,
  }) {
    return LayoutedStaff(
      globalStaffIndex: globalStaffIndex ?? this.globalStaffIndex,
      partStaffIndex: partStaffIndex ?? this.partStaffIndex,
      partId: partId ?? this.partId,
      measures: measures ?? this.measures,
      yTopLine: yTopLine ?? this.yTopLine,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      lineCount: lineCount ?? this.lineCount,
    );
  }
}

// ============================================================================
// SYSTÈME MISE EN PAGE
// ============================================================================

class LayoutedSystem {
  final List<LayoutedStaff> staves;
  final double startBlockWidth;
  final double yTop;
  final double yBottom;

  /// v2c-3p : largeur EFFECTIVE du contenu (bloc de départ + mesures).
  final double effectiveWidth;

  const LayoutedSystem({
    required this.staves,
    required this.startBlockWidth,
    required this.yTop,
    required this.yBottom,
    this.effectiveWidth = 0.0,
  });

  int get staffCount => staves.length;
  int get measureCount =>
      staves.isNotEmpty ? staves.first.measures.length : 0;

  LayoutedSystem copyWith({
    List<LayoutedStaff>? staves,
    double? startBlockWidth,
    double? yTop,
    double? yBottom,
    double? effectiveWidth,
  }) {
    return LayoutedSystem(
      staves: staves ?? this.staves,
      startBlockWidth: startBlockWidth ?? this.startBlockWidth,
      yTop: yTop ?? this.yTop,
      yBottom: yBottom ?? this.yBottom,
      effectiveWidth: effectiveWidth ?? this.effectiveWidth,
    );
  }
}