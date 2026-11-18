// lib/views/editor/editor_controller.dart
// ============================================================================
// CONTRÔLEUR DE L'ÉDITEUR — v2c-84
// ============================================================================
// v2c-57 : auto-transposition des notes liées par tie.
// v2c-84 : drag PAR PITCH (accord). Seul le pitch cliqué est transposé,
//          et ses partenaires de tie du MÊME pitch. Conforme MuseScore.
// ============================================================================

import 'package:flutter/material.dart';

import '../../models/layout/layout_models.dart';
import '../../models/events/pitch.dart';
import '../../models/enums/music_enums.dart';
import '../../models/score/score_document.dart';
import '../../models/score/staff.dart';
import '../../models/score/measure.dart';
import '../../models/score/voice.dart';
import '../../models/events/music_event.dart';
import '../../utils/constants.dart';

class EditorController extends ChangeNotifier {
  // ==========================================================================
  // CHAMPS PRIVÉS
  // ==========================================================================

  LayoutedNote? _selectedNote;
  String? _selectedEventId;
  /// v2c-84 : index du pitch sélectionné dans son accord.
  /// 0 = pitch primaire, 1+ = membres d'accord.
  int _selectedPitchIndex = 0;

  double? _dragStartY;
  double? _dragOffsetY;
  Offset? _lastDragPosition;

  ScoreDocument? _document;
  VoidCallback? _onLayoutRequested;

  bool _isEndingDrag = false;

  // ==========================================================================
  // GETTERS PUBLICS
  // ==========================================================================

  LayoutedNote? get selectedNote => _selectedNote;
  double? get dragOffsetY => _dragOffsetY;
  ScoreDocument? get document => _document;
  bool get hasSelection => _selectedNote != null;

  // ==========================================================================
  // CONSTANTES
  // ==========================================================================

  static const double staffLineSpacing = ScoreCraftConstants.staffLineSpacing;
  static const double pixelsPerHalfStep = ScoreCraftConstants.pixelsPerSemitone;

  // ==========================================================================
  // MÉTHODES PUBLIQUES
  // ==========================================================================

  void setDocument(ScoreDocument doc) {
    if (_document != doc) {
      _document = doc;
      notifyListeners();
    }
  }

  void setOnLayoutRequested(VoidCallback callback) {
    _onLayoutRequested = callback;
  }

  void selectNote(LayoutedNote? note) {
    if (_selectedNote == note) return;
    _selectedNote = note;
    _selectedEventId = note?.eventId;

    // v2c-84 : extraction de l'index du pitch sélectionné.
    // LayoutedNote.id vaut :
    //   - "eventId"       → pitch index 0
    //   - "eventId_p1"    → pitch index 1
    //   - "eventId_p2"    → pitch index 2, etc.
    _selectedPitchIndex = 0;
    if (note != null && note.event is NoteEvent) {
      final ne = note.event as NoteEvent;
      if (ne.pitches.length > 1) {
        _selectedPitchIndex = _extractPitchIndexFromLayoutedNoteId(
          note.id,
          note.eventId,
        );
      }
    }

    _resetDrag();
    notifyListeners();
  }

  void clearSelection() {
    _selectedNote = null;
    _selectedEventId = null;
    _selectedPitchIndex = 0;
    _resetDrag();
    notifyListeners();
  }

  void startDrag(Offset position) {
    if (_selectedNote == null) return;
    _dragStartY = position.dy;
    _dragOffsetY = 0.0;
    _lastDragPosition = position;
  }

  void updateDrag(Offset currentPosition) {
    if (_selectedNote == null || _dragStartY == null) return;

    _lastDragPosition = currentPosition;

    final double rawDeltaY = currentPosition.dy - _dragStartY!;
    final int halfSteps = (rawDeltaY / pixelsPerHalfStep).round();
    _dragOffsetY = halfSteps * pixelsPerHalfStep;

    notifyListeners();
  }

  void endDrag() {
    if (_isEndingDrag) return;
    _isEndingDrag = true;

    if (_selectedNote == null || _document == null) {
      _resetDrag();
      _isEndingDrag = false;
      notifyListeners();
      return;
    }

    // Recalcul du décalage final.
    double? finalOffsetY = _dragOffsetY;
    if (_lastDragPosition != null && _dragStartY != null) {
      final rawDeltaY = _lastDragPosition!.dy - _dragStartY!;
      final int halfSteps = (rawDeltaY / pixelsPerHalfStep).round();
      finalOffsetY = halfSteps * pixelsPerHalfStep;
    }

    if (finalOffsetY == null) {
      _resetDrag();
      _isEndingDrag = false;
      notifyListeners();
      return;
    }

    final int deltaDegree = (finalOffsetY / pixelsPerHalfStep).round();
    _resetDrag();

    if (deltaDegree == 0) {
      _isEndingDrag = false;
      notifyListeners();
      return;
    }

    final int pitchShift = -deltaDegree;

    // ─── v2c-84 : identification du pitch à déplacer ─────────────────────
    final Pitch? pitch = _selectedNote!.pitch;
    if (pitch == null) {
      _isEndingDrag = false;
      notifyListeners();
      return;
    }

    final newPitch = _shiftPitchDiatonically(pitch, pitchShift);
    final doc = _document!;
    final selectedEventId = _selectedEventId ?? _selectedNote!.eventId;
    final selectedPitchIndex = _selectedPitchIndex;

    // ─── v2c-84 : collecte des locations à mettre à jour ─────────────────
    // On cible :
    //   1. La note elle-même, pitch [selectedPitchIndex]
    //   2. Ses partenaires de tie DU MÊME PITCH uniquement
    final updates = <_NotePitchUpdate>[];

    final selfLoc = _locateNote(doc, selectedEventId);
    if (selfLoc == null) {
      _isEndingDrag = false;
      notifyListeners();
      return;
    }

    updates.add(_NotePitchUpdate(
      location: selfLoc,
      pitchIndex: selectedPitchIndex,
    ));

    // Partenaires de tie du MÊME pitch.
    final partners = _findTiePartners(
      doc,
      selectedEventId,
      selectedPitchIndex,
    );
    updates.addAll(partners);

    // Application séquentielle (document immuable, on reconstruit à chaque étape).
    ScoreDocument updated = doc;
    for (final u in updates) {
      updated = _applyPitchAt(
        updated,
        u.location,
        u.pitchIndex,
        newPitch,
      );
    }

    _document = updated;

    _isEndingDrag = false;
    _onLayoutRequested?.call();
  }

  void restoreSelectionAfterLayout(List<LayoutedSystem> systems) {
    _resetDrag();

    if (_selectedEventId == null) {
      _selectedNote = null;
      notifyListeners();
      return;
    }

    // v2c-84 : on cherche la note dont l'ID correspond EXACTEMENT à
    // celui qui était sélectionné (eventId ou eventId_pN).
    final targetId = _selectedNote?.id;

    for (final system in systems) {
      for (final layoutedStaff in system.staves) {
        for (final measure in layoutedStaff.measures) {
          for (final note in measure.notes) {
            if (targetId != null && note.id == targetId) {
              _selectedNote = note;
              notifyListeners();
              return;
            }
          }
        }
      }
    }

    // Fallback : si l'ID exact n'est plus là (cas rare), on prend le
    // premier avec le même eventId (pitch 0).
    for (final system in systems) {
      for (final layoutedStaff in system.staves) {
        for (final measure in layoutedStaff.measures) {
          for (final note in measure.notes) {
            if (note.eventId == _selectedEventId) {
              _selectedNote = note;
              _selectedPitchIndex = 0;
              notifyListeners();
              return;
            }
          }
        }
      }
    }

    _selectedNote = null;
    _selectedEventId = null;
    _selectedPitchIndex = 0;
    notifyListeners();
  }

  // ==========================================================================
  // HELPERS PRIVÉS
  // ==========================================================================

  void _resetDrag() {
    _dragOffsetY = null;
    _dragStartY = null;
    _lastDragPosition = null;
  }

  /// v2c-84 : extrait l'index du pitch depuis le `LayoutedNote.id`.
  /// Retourne 0 si l'ID correspond au pitch primaire (pas de suffixe `_pN`).
  static int _extractPitchIndexFromLayoutedNoteId(String id, String eventId) {
    if (id == eventId) return 0;
    final prefix = '${eventId}_p';
    if (id.startsWith(prefix)) {
      final suffix = id.substring(prefix.length);
      final n = int.tryParse(suffix);
      if (n != null && n >= 1) return n;
    }
    return 0; // fallback
  }

  Pitch _shiftPitchDiatonically(Pitch pitch, int degreeShift) {
    const letters = [
      NoteLetter.C,
      NoteLetter.D,
      NoteLetter.E,
      NoteLetter.F,
      NoteLetter.G,
      NoteLetter.A,
      NoteLetter.B,
    ];

    int currentIndex = pitch.octave * 7 + letters.indexOf(pitch.letter);
    int newIndex = currentIndex + degreeShift;

    int newOctave = (newIndex / 7).floor();
    int newLetterIndex = ((newIndex % 7) + 7) % 7;

    return Pitch(
      letter: letters[newLetterIndex],
      octave: newOctave,
      alter: pitch.alter,
      accidentalDisplay: pitch.accidentalDisplay,
      isCautionary: pitch.isCautionary,
      isEditorial: pitch.isEditorial,
      // v2c-84 : on conserve les ties attachés au pitch.
      tiesStarted: pitch.tiesStarted,
      tiesStopped: pitch.tiesStopped,
      tieStartDirection: pitch.tieStartDirection,
      tieStopDirection: pitch.tieStopDirection,
      // ═══════════════════════════════════════════════════════════════════
      // v2c-93z : FIX — préserver notehead + lyrics à la transposition.
      //
      // AVANT : ces 3 champs étaient perdus à chaque drag, car
      //         _shiftPitchDiatonically reconstruisait le Pitch sans eux.
      //         Résultat visible : le pitch perdait sa forme de tête ET
      //         ses paroles (fallback silencieux sur event.notehead /
      //         event.lyrics).
      // APRÈS : le pitch garde sa forme et ses paroles après transposition.
      //
      // C'est un fix "transparent" : seule la hauteur change, le reste est
      // identique au pitch source (cohérent avec le modèle immutable).
      // ═══════════════════════════════════════════════════════════════════
      notehead: pitch.notehead,
      noteheadFilled: pitch.noteheadFilled,
      lyrics: pitch.lyrics,
    );
  }

  /// v2c-84 : localise un NoteEvent par son ID dans la structure complète.
  _NoteLocation? _locateNote(ScoreDocument doc, String eventId) {
    for (int s = 0; s < doc.staves.length; s++) {
      final staff = doc.staves[s];
      for (int m = 0; m < staff.measures.length; m++) {
        final measure = staff.measures[m];
        for (int v = 0; v < measure.voices.length; v++) {
          final voice = measure.voices[v];
          for (int e = 0; e < voice.events.length; e++) {
            final event = voice.events[e];
            if (event is NoteEvent && event.id == eventId) {
              return _NoteLocation(
                staffIdx: s,
                measureIdx: m,
                voiceIdx: v,
                eventIdx: e,
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// v2c-84 : trouve les partenaires de tie DU PITCH SPÉCIFIÉ.
  ///
  /// On ne suit QUE les ties dont l'index de pitch correspond à
  /// [movedPitchIndex]. Les autres pitches de l'accord ne bougent PAS.
  List<_NotePitchUpdate> _findTiePartners(
    ScoreDocument doc,
    String movedEventId,
    int movedPitchIndex,
  ) {
    final result = <_NotePitchUpdate>[];

    final connections = doc.connections;
    if (connections == null) return result;

    for (final tie in connections.ties) {
      String? partnerId;
      int? partnerPitchIndex;

      // Cas 1 : la note bougée est le START du tie.
      if (tie.startNoteId == movedEventId &&
          tie.startPitchIndex == movedPitchIndex) {
        partnerId = tie.endNoteId;
        partnerPitchIndex = tie.endPitchIndex;
      }
      // Cas 2 : la note bougée est le STOP du tie.
      else if (tie.endNoteId == movedEventId &&
          tie.endPitchIndex == movedPitchIndex) {
        partnerId = tie.startNoteId;
        partnerPitchIndex = tie.startPitchIndex;
      }

      if (partnerId == null || partnerPitchIndex == null) continue;

      final loc = _locateNote(doc, partnerId);
      if (loc != null) {
        result.add(_NotePitchUpdate(
          location: loc,
          pitchIndex: partnerPitchIndex,
        ));
      }
    }

    return result;
  }

  /// v2c-84 : applique un nouveau pitch à L'INDEX SPÉCIFIÉ d'un accord.
  /// Les autres pitches de l'accord sont préservés.
  ScoreDocument _applyPitchAt(
    ScoreDocument doc,
    _NoteLocation loc,
    int pitchIndex,
    Pitch newPitch,
  ) {
    final staff = doc.staves[loc.staffIdx];
    final measure = staff.measures[loc.measureIdx];
    final voice = measure.voices[loc.voiceIdx];
    final event = voice.events[loc.eventIdx];

    if (event is! NoteEvent) return doc;

    // Sécurité : index valide.
    if (pitchIndex < 0 || pitchIndex >= event.pitches.length) return doc;

    // ═══ v2c-84 : on remplace UNIQUEMENT pitches[pitchIndex]. ═══════════
    final newPitches = List<Pitch>.from(event.pitches);
    newPitches[pitchIndex] = newPitch;

    final newEvent = event.copyWith(pitches: newPitches);

    final newEvents = List<MusicEvent>.from(voice.events)
      ..[loc.eventIdx] = newEvent;
    final newVoice = Voice(
      voiceIndex: voice.voiceIndex,
      events: newEvents,
    );
    final newVoices = List<Voice>.from(measure.voices)
      ..[loc.voiceIdx] = newVoice;
    final newMeasure = measure.copyWith(voices: newVoices);
    final newMeasures = List<Measure>.from(staff.measures)
      ..[loc.measureIdx] = newMeasure;
    final newStaff = staff.copyWith(measures: newMeasures);
    final newStaves = List<Staff>.from(doc.staves)
      ..[loc.staffIdx] = newStaff;

    return doc.copyWith(staves: newStaves);
  }
}

// ============================================================================
// STRUCTURES INTERNES
// ============================================================================

/// v2c-84 : localisation d'un événement dans la structure du document.
class _NoteLocation {
  final int staffIdx;
  final int measureIdx;
  final int voiceIdx;
  final int eventIdx;

  const _NoteLocation({
    required this.staffIdx,
    required this.measureIdx,
    required this.voiceIdx,
    required this.eventIdx,
  });
}

/// v2c-84 : mise à jour ciblée = (localisation, index du pitch).
class _NotePitchUpdate {
  final _NoteLocation location;
  final int pitchIndex;

  const _NotePitchUpdate({
    required this.location,
    required this.pitchIndex,
  });
}