// lib/models/score/staff.dart
// ============================================================================
// PORTÉE INDIVIDUELLE — v2c-79
// ============================================================================
// v2c-79 : `lineCount` passe de `StaffLines` (enum) à `int`.
//          Valeurs typiques : 5 (standard), 1 (percussion), 6 (tab), 4 (tab4).
//          Le nombre de lignes peut changer en cours de morceau : voir
//          `Measure.staffLines` (v2c-79).
// ============================================================================

import '../enums/music_enums.dart';
import 'measure.dart';

/// Représente une portée individuelle dans la partition.
/// Plusieurs Staff peuvent partager le même [partId] (ex: piano avec MD/MG).
class Staff {
  // ─── IDENTIFICATION ────────────────────────────────────────────────────────

  /// Identifiant unique et stable de la portée (ex: "staff_1", "staff_2").
  /// Global à tout le document.
  final String id;

  /// Identifiant de la partie MusicXML d'origine (ex: "P1", "P2").
  /// Tous les Staff d'un même piano partagent le même partId.
  final String partId;

  /// Index de cette portée DANS SA PARTIE (1, 2, 3...).
  /// Pour un piano : MD = 1, MG = 2.
  final int partStaffIndex;

  /// Index GLOBAL de cette portée dans tout le document (1, 2, 3...).
  /// Pour un piano suivi d'un violon : MD = 1, MG = 2, Violon = 3.
  final int staffIndex;

  /// Nom complet de l'instrument (ex: "Piano", "Violon", "Flûte")
  final String instrumentName;

  /// Abréviation de l'instrument (ex: "Pno.", "Vln.", "Fl.")
  final String instrumentAbbreviation;

  // ─── CLEF ET ARMURE ────────────────────────────────────────────────────────

  /// Clef initiale de la portée (treble, bass, alto, etc.)
  /// C'est la clef au DÉBUT du morceau. Les changements sont dans Measure.clef.
  final ClefType clef;

  /// Armure initiale de la portée (dièses ou bémols exprimés en fifths)
  final KeySignature keySignature;

  /// v2c-79 : nombre de lignes de la portée.
  /// - 5 = portée standard (valeur par défaut).
  /// - 1 = portée de percussion.
  /// - 6 = tablature.
  /// - 4 = tablature 4 cordes.
  /// - N'importe quelle valeur >= 1 pour les tests W3C (ex: 3, 7).
  /// ⚠️ Peut être modifié en cours de morceau via `Measure.staffLines`.
  final int lineCount;

  // ─── CONTENU MUSICAL ───────────────────────────────────────────────────────

  /// Suite séquentielle de toutes les mesures de cette portée
  final List<Measure> measures;

  // ─── LECTURE AUDIO ─────────────────────────────────────────────────────────

  /// Indique si la portée est muette (pour la lecture audio)
  final bool isMuted;

  /// Indique si la portée est en solo (pour la lecture audio)
  final bool isSolo;

  // ==========================================================================
  // CONSTRUCTEUR
  // ==========================================================================

  const Staff({
    required this.staffIndex,
    this.id = '',
    this.partId = 'P1',
    this.partStaffIndex = 1,
    this.instrumentName = 'Instrument',
    this.instrumentAbbreviation = 'Inst.',
    this.clef = ClefType.treble,
    this.keySignature = const KeySignature(),
    // v2c-79 : défaut = 5 lignes (portée standard).
    this.lineCount = 5,
    this.measures = const [],
    this.isMuted = false,
    this.isSolo = false,
  });

  // ==========================================================================
  // GETTERS UTILITAIRES
  // ==========================================================================

  bool get hasSharps => keySignature.hasSharps;
  bool get hasFlats => keySignature.hasFlats;
  int get alterationCount => keySignature.alterationCount;
  int get fifths => keySignature.fifths;

  /// Indique si cette portée est la première de sa partie.
  bool get isFirstOfPart => partStaffIndex == 1;

  /// v2c-79 : getter utilitaire — nombre d'interlignes (= lineCount - 1).
  int get staffSpaceCount => lineCount - 1;

  // ==========================================================================
  // COPY WITH (IMMUTABILITÉ)
  // ==========================================================================

  Staff copyWith({
    String? id,
    String? partId,
    int? partStaffIndex,
    int? staffIndex,
    String? instrumentName,
    String? instrumentAbbreviation,
    ClefType? clef,
    KeySignature? keySignature,
    int? lineCount,
    List<Measure>? measures,
    bool? isMuted,
    bool? isSolo,
  }) {
    return Staff(
      id: id ?? this.id,
      partId: partId ?? this.partId,
      partStaffIndex: partStaffIndex ?? this.partStaffIndex,
      staffIndex: staffIndex ?? this.staffIndex,
      instrumentName: instrumentName ?? this.instrumentName,
      instrumentAbbreviation:
          instrumentAbbreviation ?? this.instrumentAbbreviation,
      clef: clef ?? this.clef,
      keySignature: keySignature ?? this.keySignature,
      lineCount: lineCount ?? this.lineCount,
      measures: measures ?? this.measures,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }

  // ==========================================================================
  // TO STRING
  // ==========================================================================

  @override
  String toString() {
    return 'Staff($id, part: $partId/$partStaffIndex, global: $staffIndex, '
        '"$instrumentName", clef: $clef, lines: $lineCount, '
        'measures: ${measures.length})';
  }
}