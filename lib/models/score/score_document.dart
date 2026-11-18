// lib/models/score/score_document.dart
// ============================================================================
// MODÈLE MAÎTRE : REPRÉSENTE UNE PARTITION COMPLÈTE — v2c-2
// ============================================================================
// Ce fichier définit la structure complète d'une partition musicale :
//   - Métadonnées (header)
//   - Mise en page (pageLayout)
//   - Liste des portées (staves)
//   - Connexions résolues : slurs, ties (v2c-2)
// ============================================================================

import 'staff.dart';
import 'measure.dart';
import 'voice.dart';
import 'page_layout.dart';
import '../events/pitch.dart';
import '../events/music_event.dart';
import '../events/slur_connection.dart';
import '../enums/music_enums.dart';

// ============================================================================
// 1. MÉTADONNÉES DE LA PARTITION (HEADER)
// ============================================================================

/// Métadonnées de la partition (titre, compositeur, etc.)
class ScoreHeader {
  final String title;
  final String subtitle;
  final String composer;
  final String lyricist;
  final String arranger;
  final String copyright;
  final String software;
  final String creationDate;
  final int initialTempoBpm;

  const ScoreHeader({
    this.title = 'Sans titre',
    this.subtitle = '',
    this.composer = '',
    this.lyricist = '',
    this.arranger = '',
    this.copyright = '',
    this.software = '',
    this.creationDate = '',
    this.initialTempoBpm = 120,
  });

  ScoreHeader copyWith({
    String? title,
    String? subtitle,
    String? composer,
    String? lyricist,
    String? arranger,
    String? copyright,
    String? software,
    String? creationDate,
    int? initialTempoBpm,
  }) {
    return ScoreHeader(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      composer: composer ?? this.composer,
      lyricist: lyricist ?? this.lyricist,
      arranger: arranger ?? this.arranger,
      copyright: copyright ?? this.copyright,
      software: software ?? this.software,
      creationDate: creationDate ?? this.creationDate,
      initialTempoBpm: initialTempoBpm ?? this.initialTempoBpm,
    );
  }

  @override
  String toString() {
    return 'ScoreHeader(title: "$title", composer: "$composer")';
  }
}

// ============================================================================
// 2. DOCUMENT COMPLET (CONTENEUR PRINCIPAL)
// ============================================================================

/// Document complet d'une partition.
///
/// Contient les métadonnées, la mise en page, toutes les portées,
/// et les connexions résolues (slurs/ties).
class ScoreDocument {
  // ==========================================================================
  // CONSTANTES STATIQUES
  // ==========================================================================

  static const PageLayout _defaultPageLayout = PageLayout(
    dimensions: PageDimensions(),
  );

  static int _idCounter = 0;

  // ==========================================================================
  // CHAMPS D'INSTANCE
  // ==========================================================================

  /// Identifiant unique du document (ex: "score_1").
  final String id;

  /// Métadonnées de la partition.
  final ScoreHeader header;

  /// Configuration complète de la mise en page.
  final PageLayout pageLayout;

  /// Liste des portées (au moins une).
  final List<Staff> staves;

  /// v2c-2 : connexions résolues (slurs, ties) en 2e passe du parser.
  ///
  /// ⚠️ Null tant que le resolver n'a pas tourné (ex: ScoreDocument créé
  ///    manuellement pour un test). Le renderer doit tolérer `null`.
  final ResolvedConnections? connections;

  // ==========================================================================
  // CONSTRUCTEURS
  // ==========================================================================

  const ScoreDocument({
    this.id = '',
    this.header = const ScoreHeader(),
    PageLayout? pageLayout,
    this.staves = const [],
    this.connections,
  }) : pageLayout = pageLayout ?? _defaultPageLayout;

  ScoreDocument.withDimensions({
    String? id,
    ScoreHeader? header,
    PageDimensions? dimensions,
    List<Staff>? staves,
    ResolvedConnections? connections,
  }) : this(
          id: id ?? '',
          header: header ?? const ScoreHeader(),
          pageLayout:
              PageLayout(dimensions: dimensions ?? const PageDimensions()),
          staves: staves ?? const [],
          connections: connections,
        );

  ScoreDocument.withLayout({
    String? id,
    ScoreHeader? header,
    PageLayout? pageLayout,
    List<Staff>? staves,
    ResolvedConnections? connections,
  }) : this(
          id: id ?? '',
          header: header ?? const ScoreHeader(),
          pageLayout: pageLayout ?? _defaultPageLayout,
          staves: staves ?? const [],
          connections: connections,
        );

  // ==========================================================================
  // FACTORY : DOCUMENT DE TEST (2 PORTÉES)
  // ==========================================================================
  //
  // ⚠️ v2c-2 : les durations et timePosition sont maintenant remplies.
  //    divisions = 12 → quarter.duration = 12, half = 24, whole = 48.
  //    Le timePosition démarre à 0 et avance par duration.
  //
  // ==========================================================================

  factory ScoreDocument.withTestNotes() {
    String genId() =>
        'note_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

    // Divisions par défaut (aligné avec le fichier de test MusicXML).
    const int divisions = 12;
    const int quarter = divisions;      // 12
    // const int whole = 4 * divisions; // 48 (non utilisé ici)

    return ScoreDocument(
      id: 'score_test',
      staves: [
        // ═══════════════════════════════════════════════════════════════════
        // PORTÉE 1 : Main droite (Clé de Sol)
        // ═══════════════════════════════════════════════════════════════════
        Staff(
          id: 'staff_1',
          staffIndex: 1,
          instrumentName: 'Piano',
          clef: ClefType.treble,
          keySignature: const KeySignature(fifths: 2), // Ré Maj
          lineCount: 5,   // v2c-79 : int au lieu de StaffLines.standard
          measures: [
            // ─── Mesure 1 : Do, Fa#, Sol, Do# ──────────────────────────────
            Measure(
              id: 'm_1_1',
              measureNumber: 1,
              timeSignature: const TimeSignature(beats: 4, beatType: 4),
              showTimeSignature: true,
              keySignature: const KeySignature(fifths: 2),
              voices: [
                Voice(
                  voiceIndex: 1,
                  events: [
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.C, octave: 4)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 0,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [
                        const Pitch(letter: NoteLetter.F, octave: 4, alter: 1),
                      ],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: quarter,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.G, octave: 4)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 2 * quarter,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [
                        const Pitch(letter: NoteLetter.C, octave: 5, alter: 1),
                      ],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 3 * quarter,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                  ],
                ),
              ],
            ),
            // ─── Mesure 2 : Sib, Do, Ré, Mib (armure 2 bémols) ─────────────
            Measure(
              id: 'm_1_2',
              measureNumber: 2,
              timeSignature: const TimeSignature(beats: 4, beatType: 4),
              showTimeSignature: false,
              keySignature: const KeySignature(fifths: -2),
              voices: [
                Voice(
                  voiceIndex: 1,
                  events: [
                    NoteEvent(
                      id: genId(),
                      pitches: [
                        const Pitch(letter: NoteLetter.B, octave: 4, alter: -1),
                      ],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 0,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.C, octave: 5)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: quarter,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.D, octave: 5)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 2 * quarter,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [
                        const Pitch(letter: NoteLetter.E, octave: 5, alter: -1),
                      ],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 3 * quarter,
                      voiceIndex: 1,
                      staffNumber: 1,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // ═══════════════════════════════════════════════════════════════════
        // PORTÉE 2 : Main gauche (Clé de Fa)
        // ═══════════════════════════════════════════════════════════════════
        Staff(
          id: 'staff_2',
          staffIndex: 2,
          partId: 'P1',
          partStaffIndex: 2,
          instrumentName: 'Piano (basse)',
          clef: ClefType.bass,
          keySignature: const KeySignature(fifths: 2),
          lineCount: 5,   // v2c-79 : int au lieu de StaffLines.standard
          measures: [
            // ─── Mesure 1 : Do, Ré, Mi, Fa ─────────────────────────────────
            Measure(
              id: 'm_2_1',
              measureNumber: 1,
              timeSignature: const TimeSignature(beats: 4, beatType: 4),
              showTimeSignature: false,
              keySignature: const KeySignature(fifths: 2),
              voices: [
                Voice(
                  voiceIndex: 1,
                  events: [
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.C, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 0,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.D, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: quarter,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.E, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 2 * quarter,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.F, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 3 * quarter,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                  ],
                ),
              ],
            ),
            // ─── Mesure 2 : Sol, La, Si, Do ────────────────────────────────
            Measure(
              id: 'm_2_2',
              measureNumber: 2,
              timeSignature: const TimeSignature(beats: 4, beatType: 4),
              showTimeSignature: false,
              keySignature: const KeySignature(fifths: -2),
              voices: [
                Voice(
                  voiceIndex: 1,
                  events: [
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.G, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 0,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.A, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: quarter,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.B, octave: 3)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 2 * quarter,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                    NoteEvent(
                      id: genId(),
                      pitches: [const Pitch(letter: NoteLetter.C, octave: 4)],
                      durationType: DurationType.quarter,
                      duration: quarter,
                      timePosition: 3 * quarter,
                      voiceIndex: 1,
                      staffNumber: 2,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      // ⚠️ Pas de connexions dans le test (à générer via resolver si besoin).
      connections: null,
    );
  }

  // ==========================================================================
  // COPY WITH (IMMUTABILITÉ)
  // ==========================================================================

  ScoreDocument copyWith({
    String? id,
    ScoreHeader? header,
    PageLayout? pageLayout,
    List<Staff>? staves,
    ResolvedConnections? connections,
  }) {
    return ScoreDocument(
      id: id ?? this.id,
      header: header ?? this.header,
      pageLayout: pageLayout ?? this.pageLayout,
      staves: staves ?? this.staves,
      connections: connections ?? this.connections,
    );
  }

  // ==========================================================================
  // GETTERS UTILITAIRES
  // ==========================================================================

  /// Nombre total de mesures (basé sur la 1re portée).
  int get totalMeasures =>
      staves.isNotEmpty ? staves.first.measures.length : 0;

  /// Nombre total de systèmes (comptage des sauts de système).
  int get totalSystems {
    if (staves.isEmpty || staves.first.measures.isEmpty) return 0;
    int count = 0;
    for (final measure in staves.first.measures) {
      if (measure.hasSystemBreak) count++;
    }
    return count + 1;
  }

  /// Raccourcis vers les dimensions de la page.
  PageDimensions get dimensions => pageLayout.dimensions;
  double get pageWidth => dimensions.width;
  double get pageHeight => dimensions.height;
  double get marginLeft => dimensions.marginLeft;
  double get marginRight => dimensions.marginRight;
  double get marginTop => dimensions.marginTop;
  double get marginBottom => dimensions.marginBottom;

  /// v2c-2 : indique si le resolver a été exécuté.
  bool get hasConnections => connections != null;

  /// v2c-2 : liste des slurs (vide si resolver pas exécuté).
  List<SlurConnection> get slurs => connections?.slurs ?? const [];

  /// v2c-2 : liste des ties (vide si resolver pas exécuté).
  List<TieConnection> get ties => connections?.ties ?? const [];

  // ==========================================================================
  // TO STRING
  // ==========================================================================

  @override
  String toString() {
    return 'ScoreDocument($id, header: $header, '
        'staves: ${staves.length}, totalMeasures: $totalMeasures, '
        'slurs: ${slurs.length}, ties: ${ties.length})';
  }
}