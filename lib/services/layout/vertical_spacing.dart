// lib/services/layout/vertical_spacing.dart
// ============================================================================
// ESPACEMENT VERTICAL - UTILITAIRE DE DIMENSIONNEMENT
// ============================================================================
//
// ARCHITECTURE :
// ---------------
// Depuis le refactor "multi-portée + adaptatif", la LOGIQUE de calcul
// vertical (positions des portées, espacement adaptatif entre portées d'un
// même système, sauts de système) est centralisée dans `LayoutEngine`.
//
// Ce fichier ne fait plus que du DIMENSIONNEMENT : il calcule la hauteur
// totale du canvas pour que le ScrollView sache jusqu'où descendre.
//
// POURQUOI CE CHOIX ?
// -------------------
// 1. Source de vérité unique : le LayoutEngine calcule TOUT le Y, à un seul
//    endroit. Plus de risque de désynchronisation entre deux fichiers.
// 2. Testabilité : on peut tester le layout complet en isolant le moteur.
// 3. Cohérence : les Y retournés par LayoutEngine (yTop, yBottom) sont
//    directement utilisés par le renderer et le hit-test.
//
// UTILISATION :
// -------------
// `VerticalSpacing.computeTotalHeight(systems)` : hauteur totale du canvas.
// `VerticalSpacing.fromPageLayout(pageLayout)` : fabrique depuis PageLayout.
//
// Les méthodes `computeSystemTopY` et `computeStaffBaseY` sont CONSERVÉES
// pour compatibilité avec du code existant, mais elles délèguent désormais
// aux valeurs déjà calculées par le LayoutEngine (source de vérité).
// ============================================================================

import '../../models/layout/layout_models.dart';
import '../../models/score/page_layout.dart';

/// Utilitaires de dimensionnement vertical.
///
/// ⚠️ Cette classe ne CALCULE PLUS les positions des portées.
/// C'est le `LayoutEngine` qui s'en occupe. Cette classe sert uniquement à :
/// - Connaître la hauteur totale du canvas
/// - Fournir une API compatible avec l'ancien code
class VerticalSpacing {
  // ==========================================================================
  // PARAMÈTRES DE CONFIGURATION
  // ==========================================================================

  /// Marge haute de la page (avant le premier système).
  final double topMargin;

  /// Marge basse de la page (après le dernier système).
  final double bottomMargin;

  /// Espace supplémentaire ajouté après le dernier système
  /// (pour éviter que le contenu soit collé au bord).
  final double extraBottomPadding;

  // ==========================================================================
  // CONSTRUCTEUR
  // ==========================================================================

  const VerticalSpacing({
    this.topMargin = 85.7143,
    this.bottomMargin = 85.7143,
    this.extraBottomPadding = 40.0,
  });

  // ==========================================================================
  // CALCUL DE LA HAUTEUR TOTALE DU CANVAS
  // ==========================================================================

  /// Calcule la hauteur totale du canvas à partir des systèmes layoutés.
  ///
  /// Utilise `LayoutedSystem.yBottom` (source de vérité : position du bas
  /// du dernier système, calculée par le LayoutEngine).
  double computeTotalHeight(List<LayoutedSystem> systems) {
    if (systems.isEmpty) return topMargin + bottomMargin;

    final lastSystem = systems.last;
    return lastSystem.yBottom + bottomMargin + extraBottomPadding;
  }

  // ==========================================================================
  // ACCESSEURS Y (compatibilité avec l'ancien code)
  // ==========================================================================
  // ⚠️ Ces méthodes sont conservées pour ne pas casser du code existant.
  // Elles délèguent aux valeurs calculées par le LayoutEngine.

  /// Récupère le Y du haut du système d'index [systemIndex].
  /// Délègue à `LayoutedSystem.yTop` (calculé par LayoutEngine).
  double computeSystemTopY(
    List<LayoutedSystem> systems,
    int systemIndex,
  ) {
    if (systemIndex < 0 || systemIndex >= systems.length) return topMargin;
    return systems[systemIndex].yTop;
  }

  /// Récupère le Y du haut de la portée [globalStaffIndex] dans le système
  /// d'index [systemIndex].
  /// Délègue à `LayoutedStaff.yTopLine` (calculé par LayoutEngine).
  double computeStaffBaseY(
    List<LayoutedSystem> systems,
    int systemIndex,
    int globalStaffIndex,
  ) {
    if (systemIndex < 0 || systemIndex >= systems.length) return topMargin;
    final system = systems[systemIndex];
    for (final staff in system.staves) {
      if (staff.globalStaffIndex == globalStaffIndex) {
        return staff.yTopLine;
      }
    }
    return system.yTop;
  }

  // ==========================================================================
  // FABRIQUE DEPUIS PageLayout
  // ==========================================================================

  /// Crée une instance à partir d'un PageLayout.
  factory VerticalSpacing.fromPageLayout(PageLayout pageLayout) {
    return VerticalSpacing(
      topMargin: pageLayout.marginTop,
      bottomMargin: pageLayout.marginBottom,
      extraBottomPadding: 40.0,
    );
  }

  // ==========================================================================
  // COPIE
  // ==========================================================================

  VerticalSpacing copyWith({
    double? topMargin,
    double? bottomMargin,
    double? extraBottomPadding,
  }) {
    return VerticalSpacing(
      topMargin: topMargin ?? this.topMargin,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      extraBottomPadding: extraBottomPadding ?? this.extraBottomPadding,
    );
  }
}