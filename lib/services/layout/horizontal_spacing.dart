// lib/services/layout/horizontal_spacing.dart
// ============================================================================
// ESPACEMENT HORIZONTAL DES NOTES
// ============================================================================
// Ce fichier contient les algorithmes de calcul des espacements horizontaux
// entre les notes en fonction de leur durée, des altérations, etc.
// ============================================================================

import 'dart:math' as math;
import '../../models/events/music_event.dart';

/// Calcul des espacements horizontaux pour une liste d'événements musicaux.
class HorizontalSpacing {
  // ==========================================================================
  // PARAMÈTRES DE CONFIGURATION
  // ==========================================================================

  /// Espace de base pour une noire (en dixièmes ou pixels)
  final double baseSpace;

  /// Facteur d'échelle logarithmique (spacing ratio)
  final double ratio;

  /// Padding à gauche de la mesure
  final double paddingLeft;

  /// Padding à droite de la mesure
  final double paddingRight;

  /// Largeur minimale d'une tête de note (avec altération)
  final double minNoteWidth;

  /// Largeur supplémentaire pour une altération (dièse, bémol)
  final double accidentalExtraWidth;

  // ==========================================================================
  // CONSTRUCTEUR
  // ==========================================================================

  HorizontalSpacing({
    this.baseSpace = 36.0,
    this.ratio = 0.58,
    this.paddingLeft = 16.0,
    this.paddingRight = 16.0,
    this.minNoteWidth = 14.0,
    this.accidentalExtraWidth = 12.0,
  });

  // ==========================================================================
  // MÉTHODE PRINCIPALE
  // ==========================================================================

  /// Calcule les positions X pour une liste d'événements.
  ///
  /// Retourne une liste de (positionX, largeur) pour chaque événement.
  List<({double x, double width})> computePositions(
    List<MusicEvent> events,
  ) {
    final List<({double x, double width})> result = [];
    double currentX = paddingLeft;

    for (final event in events) {
      final double spacing = _computeSpacing(event);
      final double width = _computeWidth(event, spacing);
      result.add((x: currentX, width: width));
      currentX += width;
    }

    return result;
  }

  /// Calcule la largeur totale de la mesure (padding inclus).
  double computeTotalWidth(List<MusicEvent> events) {
    final positions = computePositions(events);
    if (positions.isEmpty) return paddingLeft + paddingRight;
    final last = positions.last;
    return last.x + last.width + paddingRight;
  }

  // ==========================================================================
  // MÉTHODES PRIVÉES
  // ==========================================================================

  /// Calcule l'espacement de base pour un événement (sans largeur minimale).
  double _computeSpacing(MusicEvent event) {
    final double durationValue = event.durationFraction;
    // L'espacement est proportionnel à la durée relative (noire = 0.25)
    final double spacing = baseSpace * math.pow(durationValue / 0.25, ratio);
    return spacing;
  }

  /// Calcule la largeur réelle d'un événement (espacement + ajustements).
  double _computeWidth(MusicEvent event, double spacing) {
    double width = spacing;

    // Largeur minimale pour une tête de note
    if (width < minNoteWidth) {
      width = minNoteWidth;
    }

    // Si c'est une NoteEvent avec altération, on ajoute de l'espace
    if (event is NoteEvent) {
      final pitch = event.primaryPitch;
      if (pitch.alter != 0) {
        width += accidentalExtraWidth;
      }
    }

    return width;
  }

  // ==========================================================================
  // MÉTHODE DE COPIE
  // ==========================================================================

  HorizontalSpacing copyWith({
    double? baseSpace,
    double? ratio,
    double? paddingLeft,
    double? paddingRight,
    double? minNoteWidth,
    double? accidentalExtraWidth,
  }) {
    return HorizontalSpacing(
      baseSpace: baseSpace ?? this.baseSpace,
      ratio: ratio ?? this.ratio,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      minNoteWidth: minNoteWidth ?? this.minNoteWidth,
      accidentalExtraWidth: accidentalExtraWidth ?? this.accidentalExtraWidth,
    );
  }
}