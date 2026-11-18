// lib/renderer/stem_anchor.dart
// ============================================================================
// ANCRAGE DE HAMPE UNIFIÉ — v2c-96
// ============================================================================
// v2c-93z : centralisation de StemAnchorResolver (fini les doublons
//           NotePainter._StemAnchor / BeamDrawer._Anchor).
// v2c-96  : la tête "normal" est maintenant résolue DYNAMIQUEMENT via
//           Leland.json (bbox + anchors stemUpSE / stemDownNW).
//           Les autres formes (slash, triangle, etc.) restent hardcodées
//           pour l'instant (TODO v2c-96c : migrer pareil).
//
// ⚠ CONVENTIONS StemAnchor (v2c-93z, préservées) :
//   - xSp : offset horizontal du point d'attache de la hampe, TOUJOURS
//           positif (le sens up/down est géré par _drawStem).
//   - ySp : offset vertical, POSITIF = vers le BAS de l'écran.
//   - Pour une note "normal" avec stemUpSE SMuFL = (1.3, 0.2) :
//       xSp = |1.3 - center.dx| = |1.3 - 0.65| = 0.65
//       ySp = -(0.2 - 0) = -0.2  (0.2 sp au-dessus du centre)
// ============================================================================

import 'dart:ui' show Offset;

import '../models/enums/music_enums.dart';
import '../models/events/music_event.dart';
import '../models/events/pitch.dart';
import '../services/smufl/smufl_metrics.dart';   // v2c-96

/// Point d'attache de la hampe sur une tête de note.
///
/// Coordonnées en espaces (sp) relatives au CENTRE de la tête :
///   - xSp : décalage X (positif = vers la droite de la note)
///   - ySp : décalage Y (positif = vers le BAS en pixels écran)
class StemAnchor {
  final double xSp;
  final double ySp;

  const StemAnchor({required this.xSp, required this.ySp});

  @override
  String toString() => 'StemAnchor(xSp: $xSp, ySp: $ySp)';
}

/// Résolution des ancres de hampe selon la forme de tête.
class StemAnchorResolver {
  StemAnchorResolver._();

  // ==========================================================================
  // ANCRAGE PRINCIPAL
  // ==========================================================================

  /// Retourne l'ancre (x, y) en sp pour une tête donnée.
  ///
  /// [shape]    : forme de la tête (normal, slash, triangle, etc.)
  /// [duration] : durée de la note — utilisée UNIQUEMENT pour différencier
  ///              les largeurs de notehead normal (ronde, brève, maxime).
  /// [stemUp]   : direction de la hampe.
  /// [filled]   : tête pleine (true) ou vide (false).
  static StemAnchor forNotehead(
    NoteheadShape shape,
    DurationType duration,
    bool stemUp,
    bool filled,
  ) {
    switch (shape) {
      // ── v2c-96 : tête "normal" résolue via Leland.json ──────────────
      case NoteheadShape.normal:
        return _normalAnchor(duration, stemUp, filled);

      // ── Les autres formes restent hardcodées (v2c-93h) ──────────────
      //    TODO v2c-96c : migrer pareil (bbox + anchor SMuFL).
      case NoteheadShape.slash:
        // v2c-93r : unfilled poussé plus à droite (0.95 → 1.15).
        final double xSp = filled ? 0.70 : 1.45;
        return stemUp
            ? StemAnchor(xSp: xSp, ySp: -0.90)
            : StemAnchor(xSp: xSp, ySp: 0.90);

      case NoteheadShape.triangle:
        return const StemAnchor(xSp: 0.50, ySp: 0.50);

      case NoteheadShape.invertedTriangle:
        return const StemAnchor(xSp: 0.50, ySp: -0.50);

      case NoteheadShape.x:
        return const StemAnchor(xSp: 0.60, ySp: 0);

      case NoteheadShape.cross:
        return const StemAnchor(xSp: 0.65, ySp: 0);

      case NoteheadShape.circleX:
        return const StemAnchor(xSp: 0.65, ySp: 0);

      case NoteheadShape.circleDot:
        return const StemAnchor(xSp: 0.65, ySp: 0);

      case NoteheadShape.diamond:
        return const StemAnchor(xSp: 0.67, ySp: 0);

      case NoteheadShape.square:
        return const StemAnchor(xSp: 0.62, ySp: 0);

      case NoteheadShape.arrowUp:
        return const StemAnchor(xSp: 0.0, ySp: 0.45);

      case NoteheadShape.arrowDown:
        return stemUp
            ? const StemAnchor(xSp: 0.0, ySp: -0.45)
            : const StemAnchor(xSp: 0.0, ySp: 0.70);

      case NoteheadShape.slashed:
      case NoteheadShape.backSlashed:
        return const StemAnchor(xSp: 0.65, ySp: 0);

      case NoteheadShape.cluster:
        return stemUp
            ? const StemAnchor(xSp: 0.65, ySp: -1.55)
            : const StemAnchor(xSp: 0.65, ySp: 0.55);

      case NoteheadShape.none:
        return const StemAnchor(xSp: 0.6, ySp: 0);
    }
  }

  // ==========================================================================
  // HELPERS DE RÉSOLUTION
  // ==========================================================================

  /// Détermine si une tête est "pleine" selon duration + override explicite.
  static bool isFilled(NoteEvent ne) {
    return ne.noteheadFilled ??
        (ne.durationType != DurationType.whole &&
         ne.durationType != DurationType.half &&
         ne.durationType != DurationType.doubleWhole &&
         ne.durationType != DurationType.longa &&
         ne.durationType != DurationType.maxima);
  }

  /// Helper : ancre d'un événement complet (NoteEvent).
  static StemAnchor forEvent(NoteEvent ne, bool stemUp) {
    return forPitchOrEvent(null, ne, stemUp);
  }

  /// Résout l'ancre en tenant compte d'un éventuel `notehead` porté par le
  /// PITCH plutôt que par l'événement (cas 22c : chaque membre d'un accord
  /// peut avoir sa propre forme de tête).
  static StemAnchor forPitchOrEvent(
    Pitch? pitch,
    NoteEvent ne,
    bool stemUp,
  ) {
    final NoteheadShape shape = pitch?.notehead ?? ne.notehead;
    final bool filled = pitch?.noteheadFilled ?? isFilled(ne);
    return forNotehead(shape, ne.durationType, stemUp, filled);
  }

  // ==========================================================================
  // v2c-96 : TÊTE "NORMAL" — RÉSOLUTION DYNAMIQUE VIA Leland.json
  // ==========================================================================

  /// Résout l'ancre d'une tête "normal" à partir de Leland.json.
  ///
  /// Comportement identique à v2c-93h pour les valeurs xSp (0.65 / 0.75) ;
  /// SEUL ajout : `ySp` passe de 0 à ±0.2 sp (conforme à stemUpSE/stemDownNW
  /// du JSON SMuFL). Delta visuel : 1.44 px sur une hampe de 25 px.
  ///
  /// ⚠ Fallback hardcodé si Leland.json absent ou glyphe inconnu (par ex.
  ///    noteheadWholeFilled qui peut ne pas exister dans Leland v0.80).
  static StemAnchor _normalAnchor(
    DurationType duration,
    bool stemUp,
    bool filled,
  ) {
    // ── Brève family : glyphes CUSTOM, pas SMuFL ──────────────────────
    //    (maxima/longa/doubleWhole sont dessinées par
    //     NotePainter._drawBreveHead sous forme de rectangles vectoriels).
    //    Les ancres DOIVENT rester hardcodées pour rester alignées sur
    //    _drawBreveHead, PAS sur un bbox SMuFL qui n'existe pas.
    if (duration == DurationType.maxima) {
      return const StemAnchor(xSp: 1.5, ySp: 0);
    }
    if (duration == DurationType.longa ||
        duration == DurationType.doubleWhole) {
      return const StemAnchor(xSp: 0.5, ySp: 0);
    }

    // ── Fallback historique v2c-93h ──────────────────────────────────
    //    Utilisé si bbox absent de Leland.json (glyphe custom / manquant).
    final double fallbackXSp =
        (duration == DurationType.whole) ? 0.75 : 0.65;

    final String glyphName = _normalNoteheadName(duration, filled);
    final GlyphBBox bbox = SmuflMetrics.bbox(glyphName);

    if (bbox.isEmpty) {
      return StemAnchor(xSp: fallbackXSp, ySp: 0);
    }

    // ── Anchor SMuFL (stemUpSE / stemDownNW) ────────────────────────
    final String anchorName = stemUp ? 'stemUpSE' : 'stemDownNW';
    final Offset? anchorPt = SmuflMetrics.anchor(glyphName, anchorName);

    if (anchorPt == null) {
      // Pas d'ancre dans le JSON (ex : noteheadWhole dans Leland.json) :
      // on prend le half-width du bbox (v2c-93h préservé : 0.75 pour whole).
      return StemAnchor(xSp: bbox.center.dx, ySp: 0);
    }

    // ── Conversion SMuFL (y-up) → StemAnchor (y-down) ───────────────
    //   xSp = |anchor.dx - center.dx|  (toujours positif)
    //   ySp = -(anchor.dy - center.dy)  (inversion y SMuFL → écran)
    final double dxSp = (anchorPt.dx - bbox.center.dx).abs();
    final double dySp = -(anchorPt.dy - bbox.center.dy);
    return StemAnchor(xSp: dxSp, ySp: dySp);
  }

  /// Résolution du nom de glyphe SMuFL pour une tête "normal".
  /// ⚠ Duplique NotePainter._normalNoteheadName — à unifier dans un futur
  ///   refactor avec StemDirectionResolver (v2c-94y).
  static String _normalNoteheadName(DurationType dur, bool filled) {
    if (dur == DurationType.whole) {
      return filled ? 'noteheadWholeFilled' : 'noteheadWhole';
    }
    if (dur == DurationType.half) {
      return filled ? 'noteheadHalfFilled' : 'noteheadHalf';
    }
    return filled ? 'noteheadBlack' : 'noteheadHalf';
  }
}