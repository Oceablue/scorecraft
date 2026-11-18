// lib/models/score/voice.dart
// ============================================================================
// VOIX POLYPHONIQUE
// ============================================================================
// Ce fichier définit une voix polyphonique au sein d'une mesure.
// Une voix contient une séquence d'événements musicaux (notes, silences, accords).
// ============================================================================

import '../events/music_event.dart';

/// Représente une voix polyphonique au sein d'une mesure (Voix 1, Voix 2, etc.).
/// Chaque voix est indépendante et peut avoir sa propre séquence d'événements.
class Voice {
  // ――― IDENTIFIANT DE LA VOIX ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  /// Identifiant de la voix (ex: 1 pour Voix principale, 2 pour Voix secondaire).
  /// Les voix sont numérotées à partir de 1.
  final int voiceIndex;

  // ――― ÉVÉNEMENTS MUSICAUX ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  /// Liste séquentielle des événements (Notes, Accords, Silences) de cette voix.
  final List<MusicEvent> events;

  // ==========================================================================
  // CONSTRUCTEUR
  // ==========================================================================

  const Voice({
    required this.voiceIndex,
    this.events = const [],
  }) : assert(voiceIndex >= 1, 'voiceIndex doit être >= 1');

  // ==========================================================================
  // GETTERS UTILITAIRES
  // ==========================================================================

  /// Nombre d'événements dans cette voix
  int get eventCount => events.length;

  /// Indique si la voix est vide (aucun événement)
  bool get isEmpty => events.isEmpty;

  /// Indique si la voix contient au moins un événement
  bool get isNotEmpty => events.isNotEmpty;

  /// Calcule la durée totale occupée par les événements de cette voix (en fractions de ronde)
  double get totalDurationFraction {
    double total = 0.0;
    for (final event in events) {
      total += event.durationFraction;
    }
    return total;
  }

  // ==========================================================================
  // COPY WITH (IMMUTABILITÉ)
  // ==========================================================================

  /// Permet de copier et modifier la voix de manière immuable
  Voice copyWith({
    int? voiceIndex,
    List<MusicEvent>? events,
  }) {
    return Voice(
      voiceIndex: voiceIndex ?? this.voiceIndex,
      events: events ?? this.events,
    );
  }

  // ==========================================================================
  // TO STRING
  // ==========================================================================

  @override
  String toString() {
    return 'Voice($voiceIndex, ${events.length} events, '
        'totalDuration: ${totalDurationFraction.toStringAsFixed(4)})';
  }
}