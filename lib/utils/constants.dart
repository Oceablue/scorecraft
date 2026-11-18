// lib/utils/constants.dart
// ============================================================================
// CONSTANTES GLOBALES DU RENDU — v2c-93z
// ============================================================================
// v2c-93z : ajout de stemLengthFactor + stemLength (centralisation).
//           AVANT : 3.5 était hardcodé à 2 endroits :
//             - staff_renderer.dart    : stemLength = staffLineSpacing * 3.5
//             - layout_engine.dart     : const stemLengthSp = 3.5
//           Ces deux valeurs DOIVENT rester synchronisées, sinon :
//             - le layout réserve trop/pas assez d'espace vertical
//             - les hampes dessinées ne collent plus à la prédiction
//           → source unique de vérité ici.
// ============================================================================

class ScoreCraftConstants {
  // ─── Échelle et portée ──────────────────────────────────────────────────
  static const double scale = 1.2;
  static const double staffLineSpacing = 6.0 * scale; // = 7.2

  // ─── Hampe — v2c-93z : centralisé ───────────────────────────────────────
  /// Facteur multiplicateur de la longueur d'une hampe, en sp (espaces).
  /// Utilisé par :
  ///   - StaffRenderer.drawScore (pour dessiner les hampes)
  ///   - LayoutEngine._predictSystemTopOverhang (pour réserver l'espace)
  ///   - BeamDrawer (pour dessiner les hampes de beam)
  static const double stemLengthFactor = 3.5;

  /// Longueur effective d'une hampe en pixels.
  /// Dérivé du facteur ci-dessus × interligne.
  static const double stemLength = staffLineSpacing * stemLengthFactor;

  // ─── Microtonalité ──────────────────────────────────────────────────────
  /// Distance en pixels pour un demi-ton (un interligne).
  static const double pixelsPerSemitone = staffLineSpacing / 2; // = 3.6
}