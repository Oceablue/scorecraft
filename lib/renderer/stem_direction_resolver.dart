// lib/renderer/stem_direction_resolver.dart
// ============================================================================
// RÉSOLUTION DE LA DIRECTION DE HAMPE (centralisée) — v2c-94y
// ============================================================================
// Ce fichier remplace 5 copies quasi-identiques de `_shouldStemBeUp` :
//   - NotePainter._shouldStemBeUp(note, yLine)
//   - BeamDrawer._shouldStemBeUpWithYLine(note, effectiveYLine)
//   - ConnectionPainter._shouldStemBeUp(note)
//   - TupletPainter._shouldStemBeUp(note)
//   - StaffRenderer._shouldStemBeUp(note)
//
// AVANTAGES de la centralisation :
//   1. Une seule source de vérité (la règle « grâce → up » n'est plus
//      répétée dans 3 fichiers différents).
//   2. Le prochain tunage (ex: règle pour les accords de grâces
//      non-beâmés, cf. v2c-94y2) ne demandera qu'un patch, pas cinq.
//   3. Cohérence garantie entre le rendu des hampes (NotePainter /
//      BeamDrawer) et le placement des éléments qui en dépendent
//      (articulations, tuplet brackets, slurs, ties).
//
// ⚠ FIX COMPORTEMENTAL INCLUS (silencieux avant v2c-94y) :
//   Les versions de ConnectionPainter, TupletPainter et StaffRenderer ne
//   géraient PAS la règle « grâce → toujours up ». Cette règle est
//   maintenant appliquée partout. Impact attendu :
//     - TupletPainter : placement des brackets sur grâces tupletées
//       (test 23e) — possible décalage léger, à valider visuellement.
//     - StaffRenderer : placement des articulations sur grâces
//       (autoAbove = !stemUp → avant, elles tombaient below par erreur).
//     - ConnectionPainter : courbure des slurs depuis/vers des grâces
//       (aligné sur NotePainter, plus de divergence possible).
//
// ⚠ NON INCLUS :
//   LayoutEngine._shouldStemBeUpForLayout a une signature différente
//   (pre-layout, sans LayoutedNote, avec clef + lineCount explicites).
//   Il reste séparé — TODO v2c-94y-bis pour extraire un helper commun
//   sur les NoteEvent bruts.
// ============================================================================

import '../models/enums/music_enums.dart';
import '../models/events/music_event.dart';
import '../models/events/pitch.dart';
import '../models/layout/layout_models.dart';

class StemDirectionResolver {
  StemDirectionResolver._();

  // ==========================================================================
  // POINT D'ENTRÉE UNIQUE
  // ==========================================================================

  /// Résout la direction de hampe pour une note layoutée.
  ///
  /// [effectiveYLine] permet d'intégrer un drag offset (utilisé par
  /// NotePainter et BeamDrawer pendant l'édition interactive). Si null,
  /// utilise `note.yLine`.
  ///
  /// Règles dans l'ordre de priorité :
  ///   1. Grâce → toujours up (sauf multi-voice : suit la voix)
  ///   2. Direction explicite dans le XML (up / down / none)
  ///   3. Multi-voice → voix 1 up, autres down
  ///   4. Accord → moyenne des yLine des pitches
  ///   5. Note simple → yLine > 2 (au-dessus de la ligne médiane)
  static bool shouldStemBeUp(
    LayoutedNote note, {
    double? effectiveYLine,
  }) {
    final double yLine = effectiveYLine ?? note.yLine;

    // ── 1. Grâce : toujours up (sauf multi-voice) ─────────────────────
    //    Behind Bars §5.6 : les grâces ont TOUJOURS la hampe vers le
    //    haut, quelle que soit leur hauteur sur la portée. Exception
    //    multi-voice : si plusieurs voix coexistent, on respecte la
    //    convention voix 1 = up / autres = down pour éviter les
    //    collisions de hampes.
    if (note.isGrace) {
      if (note.isInMultiVoiceMeasure) {
        return note.voiceIndex == 1;
      }
      return true;
    }

    // ── 2. Direction explicite du XML ─────────────────────────────────
    //    <stem>up</stem> / <stem>down</stem> / <stem>none</stem> ont
    //    toujours priorité sur l'auto-détection.
    if (note.event is NoteEvent) {
      final ne = note.event as NoteEvent;
      switch (ne.stemDirection) {
        case StemDirection.up:   return true;
        case StemDirection.down: return false;
        case StemDirection.none: return false;
        case StemDirection.auto: break;
      }
    }

    // ── 3. Multi-voice : voix 1 up, autres down ───────────────────────
    //    Behind Bars §5.5 : dans une mesure polyphonique, la voix
    //    supérieure a toujours les hampes vers le haut et la voix
    //    inférieure vers le bas, indépendamment des hauteurs.
    if (note.isInMultiVoiceMeasure) {
      return note.voiceIndex == 1;
    }

    // ── 4. Accord : moyenne des yLine des pitches ─────────────────────
    //    Pour un accord, la position "moyenne" (et non le pitch
    //    primaire) détermine la direction, pour éviter qu'une note
    //    extrême tire la hampe dans le mauvais sens.
    if (note.event is NoteEvent) {
      final ne = note.event as NoteEvent;
      if (ne.pitches.length > 1) {
        final Pitch primary = ne.pitches.first;
        double sumYLine = 0.0;
        for (final p in ne.pitches) {
          final int diff = diatonicDiff(primary, p);
          final double yl = yLine - diff * 0.5;
          sumYLine += yl;
        }
        return (sumYLine / ne.pitches.length) > 2.0;
      }
    }

    // ── 5. Note simple ────────────────────────────────────────────────
    //    yLine 0 = ligne du haut, 4 = ligne du bas. La ligne médiane
    //    (2) sépare les hampes up (notes sous la médiane) des hampes
    //    down (notes au-dessus).
    return yLine > 2.0;
  }

  // ==========================================================================
  // HELPERS PARTAGÉS
  // ==========================================================================

  /// Différence diatonique entre 2 pitchs (en demi-degrés).
  ///
  /// Utilisé pour calculer les offsets Y des membres d'accords (une
  /// note à la seconde = décalage de 0.5 sp, une octave = 3.5 sp, etc.).
  ///
  /// Renvoie `d2 - d1` :
  ///   - positif → p2 est plus AIGU que p1
  ///   - négatif → p2 est plus GRAVE que p1
  static int diatonicDiff(Pitch p1, Pitch p2) {
    int letterIdx(NoteLetter l) {
      switch (l) {
        case NoteLetter.C: return 0;
        case NoteLetter.D: return 1;
        case NoteLetter.E: return 2;
        case NoteLetter.F: return 3;
        case NoteLetter.G: return 4;
        case NoteLetter.A: return 5;
        case NoteLetter.B: return 6;
      }
    }
    final int d1 = p1.octave * 7 + letterIdx(p1.letter);
    final int d2 = p2.octave * 7 + letterIdx(p2.letter);
    return d2 - d1;
  }
}