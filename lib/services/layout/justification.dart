// lib/services/layout/justification.dart
// ============================================================================
// JUSTIFICATION - PARAMÈTRES DE CONFIGURATION
// ============================================================================
//
// ARCHITECTURE :
// ---------------
// Depuis le refactor "multi-portée + alignement", la LOGIQUE de justification
// horizontale (comment étirer/compresser les mesures pour remplir la largeur
// du système) est entièrement gérée par `LayoutEngine._justifyWidths()`.
//
// Cette classe ne contient plus que les PARAMÈTRES de configuration utilisés
// par le LayoutEngine. Elle sert de "sac de config" que l'on peut tuner.
//
// Les anciennes méthodes `justifySystem` et `justifySystemComplete` ont été
// SUPPRIMÉES car :
// 1. Elles utilisaient l'ancienne API (`staffMeasures`) qui n'existe plus.
// 2. Elles étaient redondantes avec `LayoutEngine._justifyWidths()`.
// 3. Elles n'étaient plus appelées nulle part.
//
// Si tu as besoin un jour de tuner la justification, modifie ces paramètres
// (et le LayoutEngine les prendra en compte).
// ============================================================================

/// Paramètres de configuration pour la justification horizontale.
class Justification {
  /// Facteur d'expansion maximal d'une mesure (ex: 1.5 = +50% max).
  final double maxExpansionFactor;

  /// Facteur de compression minimal d'une mesure (ex: 0.7 = -30% max).
  final double minCompressionFactor;

  /// Indique si on pondère la justification par la durée des notes.
  /// (true = les mesures denses prennent plus de place)
  final bool useDurationWeighting;

  const Justification({
    this.maxExpansionFactor = 1.5,
    this.minCompressionFactor = 0.7,
    this.useDurationWeighting = true,
  });

  Justification copyWith({
    double? maxExpansionFactor,
    double? minCompressionFactor,
    bool? useDurationWeighting,
  }) {
    return Justification(
      maxExpansionFactor: maxExpansionFactor ?? this.maxExpansionFactor,
      minCompressionFactor: minCompressionFactor ?? this.minCompressionFactor,
      useDurationWeighting: useDurationWeighting ?? this.useDurationWeighting,
    );
  }

  @override
  String toString() {
    return 'Justification(max: $maxExpansionFactor, min: $minCompressionFactor, '
        'weighted: $useDurationWeighting)';
  }
}