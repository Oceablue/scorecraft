// lib/models/events/slur_connection.dart
// ============================================================================
// CONNEXIONS SLURS / TIES (résolues en 2e passe) — v2c-81
// ============================================================================
// v2c-2  : version initiale.
// v2c-81 : TieConnection porte startPitchIndex / endPitchIndex (pour les
//          accords) et un champ `direction` (direction forcée du tie).
// ============================================================================

class SlurConnection {
  /// NoteEvent.id de la note de départ.
  final String startNoteId;

  /// NoteEvent.id de la note d'arrivée.
  final String endNoteId;

  /// Numéro du slur (MusicXML `number`, 1 par défaut).
  final int number;

  /// Index global de la portée.
  final int staffIndex;

  const SlurConnection({
    required this.startNoteId,
    required this.endNoteId,
    required this.number,
    required this.staffIndex,
  });
}

class TieConnection {
  /// NoteEvent.id de la note de départ.
  final String startNoteId;

  /// v2c-81 : index du pitch dans `NoteEvent.pitches` de la note de départ.
  /// 0 = pitch principal, 1+ = membres d'accord.
  final int startPitchIndex;

  /// NoteEvent.id de la note d'arrivée.
  final String endNoteId;

  /// v2c-81 : index du pitch dans `NoteEvent.pitches` de la note d'arrivée.
  final int endPitchIndex;

  /// Numéro du tie (toujours 1 pour l'instant).
  final int number;

  /// Index global de la portée.
  final int staffIndex;

  /// v2c-81 : direction forcée du tie.
  /// "above" / "below" / null (auto = "away from chord center").
  final String? direction;

  const TieConnection({
    required this.startNoteId,
    this.startPitchIndex = 0,
    required this.endNoteId,
    this.endPitchIndex = 0,
    required this.number,
    required this.staffIndex,
    this.direction,
  });

  @override
  String toString() => 'TieConnection('
      '$startNoteId[$startPitchIndex] → '
      '$endNoteId[$endPitchIndex], '
      'dir=$direction)';
}

class ResolvedConnections {
  final List<SlurConnection> slurs;
  final List<TieConnection> ties;

  const ResolvedConnections({
    required this.slurs,
    required this.ties,
  });
}