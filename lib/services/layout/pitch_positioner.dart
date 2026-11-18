// lib/services/layout/pitch_positioner.dart
// ============================================================================
// POSITIONNEMENT VERTICAL DES PITCHES — v2c-79
// ============================================================================
// v2c-66 : table _c4LineForClef complètement revue.
// v2c-79 : support des portées à N lignes (paramètre `lineCount`).
// ============================================================================

import '../../models/events/pitch.dart';
import '../../models/enums/music_enums.dart';

class PitchPositioner {
  /// Convertit un pitch en yLine selon la clef.
  ///
  /// [lineCount] : nombre de lignes de la portée (v2c-79, défaut = 5).
  ///               - 5 → comportement STANDARD (aucune transformation).
  ///               - N ≠ 5 → compression/dilatation linéaire de l'axe vertical.
  ///
  /// ⚠️ La compression est linéaire : `yLineN = yLine5 * (N - 1) / 4`.
  ///    Ça marche parfaitement pour les notes DANS la portée.
  ///    Pour les notes hors portée (lignes supplémentaires), c'est une
  ///    approximation acceptable pour le test 14a.
  static double pitchToYLine(
    Pitch pitch,
    ClefType clef, {
    int lineCount = 5,
  }) {
    final double c4Line = _c4LineForClef(clef);
    final int diatonic = _diatonicPosition(pitch);
    final double yLine5 = c4Line - diatonic * 0.5;

    // ═══════════════════════════════════════════════════════════════════
    // v2c-93z : cas 5 lignes OU 0 lignes (portée sans lignes, test 22b).
    //
    // AVANT : seul lineCount == 5 court-circuitait le scaling. Avec
    //         lineCount == 0, on tombait dans `scale = (0-1)/4 = -0.25`,
    //         ce qui INVERSait et ÉCRASAIT les hauteurs des notes.
    //         Résultat : notes flottantes, non alignées avec les mesures
    //         voisines.
    // APRÈS : lineCount == 0 est traité comme la référence 5 lignes pour
    //         le POSITIONNEMENT VERTICAL. La portée "0 lignes" ne change
    //         que le RENDU (pas de lignes dessinées), pas la sémantique
    //         du pitch.
    // ═══════════════════════════════════════════════════════════════════
    if (lineCount == 5 || lineCount == 0) return yLine5;

    // v2c-79 : cas dynamique.
    // yLine 0 = ligne du haut, yLine 4 = ligne du bas (pour 5 lignes).
    // Pour N lignes, on veut yLine ∈ [0, N - 1].
    final double scale = (lineCount - 1) / 4.0;
    return yLine5 * scale;
  }

  /// Retourne la yLine où se trouve le Do central (C4) pour une clef donnée.
  ///
  /// Mapping de référence :
  ///   MusicXML line 1 = ligne du bas = yLine 4
  ///   MusicXML line 5 = ligne du haut = yLine 0
  ///
  /// Pour les clefs octaviées (8vb/8va/15ma/15mb), le C4 est positionné
  /// comme si on écrivait à l'octave opposée (compensation visuelle :
  /// une clef 8vb fait sonner 1 octave plus bas, donc la note C4 est
  /// écrite 1 octave plus haut).
  static double _c4LineForClef(ClefType clef) {
    switch (clef) {
      // ─── G clefs (Sol) ────────────────────────────────────────────────────
      case ClefType.treble:
        return 5.0;        // C4 = 1ᵉʳ ligne suppl. SOUS la portée
      case ClefType.treble8vb:
        return 1.5;        // sonne 8vb → écrit 1 octave plus haut
      case ClefType.treble8va:
        return 8.5;        // sonne 8va → écrit 1 octave plus bas
      case ClefType.treble15ma:
        return 12.0;       // sonne 2 octaves au-dessus
      case ClefType.treble15mb:
        return -2.0;       // sonne 2 octaves en-dessous
      case ClefType.frenchViolin:
        return 6.0;        // G sur la 1ᵉʳ ligne → C4 = 2 lignes sous

      // ─── C clefs (Ut) ─────────────────────────────────────────────────────
      case ClefType.soprano:
        return 4.0;        // C4 sur la 1ᵉʳ ligne (bas)
      case ClefType.mezzoSoprano:
        return 3.0;        // C4 sur la 2ᵉ ligne
      case ClefType.alto:
        return 2.0;        // C4 sur la ligne médiane
      case ClefType.tenor:
        return 1.0;        // C4 sur la 4ᵉ ligne
      case ClefType.baritoneUt:
        return 0.0;        // C4 sur la 5ᵉ ligne (haut)

      // ─── F clefs (Fa) ─────────────────────────────────────────────────────
      case ClefType.baritoneFa:
        return 0.0;        // F3 sur la ligne médiane → C4 = 5ᵉ ligne
      case ClefType.bass:
        return -1.0;       // C4 = 1ᵉʳ ligne suppl. AU-DESSUS
      case ClefType.bass8vb:
        return -4.5;       // sonne 8vb
      case ClefType.bass8va:
        return 2.5;        // sonne 8va
      case ClefType.bass15mb:
        return -8.0;       // sonne 2 octaves en-dessous
      case ClefType.subbass:
        return -2.0;       // F3 sur la 5ᵉ ligne

      // ─── Autres ───────────────────────────────────────────────────────────
      case ClefType.percussion:
      case ClefType.tab:
      case ClefType.none:
        return 2.0;        // ligne médiane (fallback neutre)
    }
  }

  /// Position diatonique d'un pitch par rapport à C4 (C4 = 0).
  static int _diatonicPosition(Pitch pitch) {
    const letterToDiatonic = {
      NoteLetter.C: 0,
      NoteLetter.D: 1,
      NoteLetter.E: 2,
      NoteLetter.F: 3,
      NoteLetter.G: 4,
      NoteLetter.A: 5,
      NoteLetter.B: 6,
    };
    final int letter = letterToDiatonic[pitch.letter]!;
    const int c4Absolute = 4 * 7;
    return (pitch.octave * 7 + letter) - c4Absolute;
  }
}