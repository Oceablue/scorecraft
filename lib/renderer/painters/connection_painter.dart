// lib/renderer/painters/connection_painter.dart
// ============================================================================
// PEINTRE DES CONNEXIONS (SLURS & TIES) — v2c-94y
// ============================================================================
// v2c-94n : version initiale extraite de StaffRenderer.
// v2c-94y : migration vers StemDirectionResolver.shouldStemBeUp.
//           ⚠ Fix comportemental inclus : la règle « grâce → toujours up »
//             n'était PAS appliquée ici avant. Conséquence visible :
//             les slurs depuis/vers des grâces peuvent maintenant avoir
//             la courbure correcte (sous les notes, côté opposé aux
//             hampes), conforme à Behind Bars §5.6 et aux tests 24b/24g.
//           _diatonicDiff locale SUPPRIMÉE (utilisée uniquement par
//           _shouldStemBeUp, elle est maintenant dans StemDirectionResolver).
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/layout/layout_models.dart';
import '../../models/score/score_document.dart';
import '../../models/events/music_event.dart';
import '../stem_direction_resolver.dart';   // v2c-94y
import 'expression_painter.dart';

class NoteAnchor {
  final LayoutedNote note;
  final double x;
  final double y;
  final int staffIndex;
  final int systemIndex;

  NoteAnchor({
    required this.note,
    required this.x,
    required this.y,
    required this.staffIndex,
    required this.systemIndex,
  });
}

class ConnectionPainter {
  final ExpressionPainter expressionPainter;
  final Map<String, NoteAnchor> anchors;
  final Map<String, NoteAnchor> pitchAnchors;

  ConnectionPainter({
    required this.expressionPainter,
    required this.anchors,
    required this.pitchAnchors,
  });

  void drawConnections({
    required Canvas canvas,
    required ScoreDocument document,
  }) {
    // ═══════════════════════════════════════════════════════════════════════
    // SLURS
    // ═══════════════════════════════════════════════════════════════════════
    for (final slur in document.slurs) {
      final startAnchor = anchors[slur.startNoteId];
      final endAnchor = anchors[slur.endNoteId];
      if (startAnchor == null || endAnchor == null) continue;
      if (startAnchor.systemIndex != endAnchor.systemIndex) continue;

      bool curveUp;
      if (startAnchor.note.isGrace) {
        curveUp = false;
      } else {
        // v2c-94y : direction de hampe via StemDirectionResolver
        // (fix grace-up inclus — voir en-tête du fichier).
        final stemUp = StemDirectionResolver.shouldStemBeUp(startAnchor.note);
        curveUp = !stemUp;
      }

      expressionPainter.drawSlur(
        canvas,
        Offset(startAnchor.x, startAnchor.y),
        Offset(endAnchor.x, endAnchor.y),
        curveUp: curveUp,
        startIsGrace: startAnchor.note.isGrace,
        endIsGrace: endAnchor.note.isGrace,
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TIES
    // ═══════════════════════════════════════════════════════════════════════
    for (final tie in document.ties) {
      final startKey = tie.startPitchIndex == 0
          ? tie.startNoteId
          : '${tie.startNoteId}_p${tie.startPitchIndex}';
      final endKey = tie.endPitchIndex == 0
          ? tie.endNoteId
          : '${tie.endNoteId}_p${tie.endPitchIndex}';

      final startAnchor = pitchAnchors[startKey];
      final endAnchor = pitchAnchors[endKey];
      if (startAnchor == null || endAnchor == null) continue;
      if (startAnchor.systemIndex != endAnchor.systemIndex) continue;

      bool curveUp;
      if (tie.direction == 'above') {
        curveUp = true;
      } else if (tie.direction == 'below') {
        curveUp = false;
      } else {
        final event = startAnchor.note.event;
        if (event is NoteEvent && event.pitches.length > 1) {
          // ─── TIE DANS UN ACCORD ────────────────────────────────────────
          // Direction "away from chord center" : si le pitch est
          // au-dessus de la moyenne des pitchs de l'accord, la courbe
          // va vers le HAUT ; sinon vers le BAS.
          double sumY = 0.0;
          int count = 0;
          for (int p = 0; p < event.pitches.length; p++) {
            final key = p == 0 ? event.id : '${event.id}_p$p';
            final a = pitchAnchors[key];
            if (a != null) {
              sumY += a.y;
              count++;
            }
          }
          if (count > 0) {
            final double avgY = sumY / count;
            curveUp = startAnchor.y < avgY;
          } else {
            // v2c-94y : fallback via StemDirectionResolver.
            curveUp = !StemDirectionResolver.shouldStemBeUp(startAnchor.note);
          }
        } else {
          // ─── TIE SIMPLE ────────────────────────────────────────────────
          // v2c-94y : direction de hampe via StemDirectionResolver.
          curveUp = !StemDirectionResolver.shouldStemBeUp(startAnchor.note);
        }
      }

      expressionPainter.drawTie(
        canvas,
        Offset(startAnchor.x, startAnchor.y),
        Offset(endAnchor.x, endAnchor.y),
        curveUp: curveUp,
      );
    }
  }
}