// lib/services/parsers/slur_tie_resolver.dart
// ============================================================================
// RÉSOLVEUR DE CONNEXIONS (SLURS / TIES) — v2c-81
// ============================================================================
// v2c-2  : version initiale.
// v2c-81 : ties résolus PAR PITCH (accords supportés).
//          Chaque pitch d'un accord peut avoir son propre tie.
// ============================================================================

import '../../models/events/music_event.dart';
import '../../models/events/slur_connection.dart';
import '../../models/score/score_document.dart';

class SlurTieResolver {
  /// Parcourt tout le document et produit les connexions.
  static ResolvedConnections resolve(ScoreDocument document) {
    final slurs = <SlurConnection>[];
    final ties = <TieConnection>[];

    // Piles ouvertes pour les slurs (inchangé).
    final openSlurs = <String, List<_PendingSlur>>{};
    // v2c-81 : piles par pitch pour les ties.
    final openTies = <String, List<_PendingTie>>{};

    for (final staff in document.staves) {
      for (final measure in staff.measures) {
        for (final voice in measure.voices) {
          for (final event in voice.events) {
            if (event is! NoteEvent) continue;

            final keyBase = '${staff.staffIndex}_${voice.voiceIndex}';

            // ─── SLURS : restent au niveau NoteEvent ──────────────────────
            // (les slurs s'appliquent à la note entière, pas par pitch)
            for (final number in event.slursStarted) {
              final key = '${keyBase}_slur$number';
              openSlurs.putIfAbsent(key, () => []).add(_PendingSlur(
                startNoteId: event.id,
                staffIndex: staff.staffIndex,
                number: number,
              ));
            }
            for (final number in event.slursStopped) {
              final key = '${keyBase}_slur$number';
              final stack = openSlurs[key];
              if (stack != null && stack.isNotEmpty) {
                final pending = stack.removeLast();
                slurs.add(SlurConnection(
                  startNoteId: pending.startNoteId,
                  endNoteId: event.id,
                  number: number,
                  staffIndex: staff.staffIndex,
                ));
              }
            }

            // ─── TIES : v2c-81 — on itère sur CHAQUE pitch ────────────────
            // Le chord part n'est PLUS ignoré.
            for (int pIdx = 0; pIdx < event.pitches.length; pIdx++) {
              final pitch = event.pitches[pIdx];
              final pitchKey = '${keyBase}_p$pIdx';

              // ═══ v2c-82b : STOP AVANT START ═══════════════════════════
              // Un pitch peut porter SIMULTANÉMENT un tied start et stop
              // (cas du "tie du milieu" : ferme le tie précédent + en ouvre
              // un nouveau). Si on traite START en premier, le STOP qui
              // suit referme immédiatement le tie qu'on vient d'ouvrir →
              // self-tie + tie suivant orphelin.
              // → On ferme D'ABORD les ties en attente, PUIS on en ouvre
              //   un nouveau. L'ordre XML n'a pas d'importance ici.
              // ═══════════════════════════════════════════════════════════

              for (final number in pitch.tiesStopped) {
                final key = '${pitchKey}_tie$number';
                final stack = openTies[key];
                if (stack != null && stack.isNotEmpty) {
                  final pending = stack.removeLast();
                  ties.add(TieConnection(
                    startNoteId: pending.startNoteId,
                    startPitchIndex: pending.startPitchIndex,
                    endNoteId: event.id,
                    endPitchIndex: pIdx,
                    number: number,
                    staffIndex: staff.staffIndex,
                    direction: pending.direction,
                  ));
                }
              }

              for (final number in pitch.tiesStarted) {
                final key = '${pitchKey}_tie$number';
                openTies.putIfAbsent(key, () => []).add(_PendingTie(
                  startNoteId: event.id,
                  startPitchIndex: pIdx,
                  staffIndex: staff.staffIndex,
                  number: number,
                  direction: pitch.tieStartDirection,
                ));
              }
            }
          }
        }
      }
    }

    return ResolvedConnections(slurs: slurs, ties: ties);
  }
}

class _PendingSlur {
  final String startNoteId;
  final int staffIndex;
  final int number;
  _PendingSlur({
    required this.startNoteId,
    required this.staffIndex,
    required this.number,
  });
}

class _PendingTie {
  final String startNoteId;
  final int startPitchIndex;
  final int staffIndex;
  final int number;
  final String? direction;
  _PendingTie({
    required this.startNoteId,
    required this.startPitchIndex,
    required this.staffIndex,
    required this.number,
    this.direction,
  });
}