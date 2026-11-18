# ScoreCraft — État du projet

*Dernière mise à jour : fin v2c-2j (microtons) + test suite W3C en cours*

---

## Vue d'ensemble

**ScoreCraft** = éditeur de partitions MusicXML en Flutter.

**Stack** : Flutter / Dart, police SMuFL **Leland**, packages `xml`, `archive`, `file_picker`, `uuid`.

---

## Architecture

| Dossier | Rôle |
|---|---|
| `lib/models/` | Modèle musical pur (sans dépendance Flutter) |
| `lib/services/parsers/` | Import MusicXML (partwise 4.0, 3.1 toléré) |
| `lib/services/layout/` | Calcul X/Y (LayoutEngine + spatialisation) |
| `lib/renderer/` | Dessin (CustomPainter) + painters spécialisés |
| `lib/views/`, `lib/widgets/` | UI Flutter (dashboard, editor, toolbars) |

---

## Étapes TERMINÉES

### Étape 1 — IDs déterministes

- `Measure.id` : `m_{globalStaffIndex}_{measureNumber}`
- `Staff.id` : `staff_{globalStaffIndex}`
- `ScoreDocument.id` : `score_1`
- `NoteEvent.id` : `n_{measureId}_{eventIndex}`
- `LayoutedNote.id` : `eventId` pour pitch principal, `eventId_pN` pour membres d'accord
- `LayoutedNote.eventId` : pointeur stable vers `NoteEvent.id`

### Étape 2a — Multi-portée

- `<staves>N</staves>` → N Staff par partie
- `<clef number="X">` par portée
- `<staff>N</staff>` sur chaque note
- Merge des accords `<chord/>` dans `MeasureParser`
- `Staff` porte : `id`, `partId`, `partStaffIndex`, `staffIndex`

### Étape 2b — Layout multi-portée + header séparé

- `LayoutEngine` réécrit (alignement MD/MG)
- `LayoutedSystem.staves: List<LayoutedStaff>`
- `LayoutedStaff` porte `yTopLine`, `partId`, `globalStaffIndex`
- `PitchPositioner` : source unique pitch → Y
- Séparation header/partition (`_HeaderPainter` + `_ScorePainter`)

### Étape 2c-1 — Fixes visuels

- `LayoutedSystem.startBlockWidth` + `LayoutedMeasure.x`
- `_drawStartBlock` propre
- Barres de mesure traversant tout le système
- `_drawFinalBarline` : light-heavy sur dernier système uniquement
- Taille notes : 4 × interligne ; hampes : 3.5 × interligne
- Ronde sans hampe (`_needsStem`)
- Hampes correctes (`_shouldStemBeUp` → `yLine > 2.0`)
- Silences : `_restYLine` + `isMeasureRest`
- Padding : `contentPadding = 16`, `systemEndPadding = 0`
- Justification : `realMins` avec 2 × contentPadding
- Hampes d'accords allongées : + (nbPitches - 1) × interligne
- Points de prolongation : `_drawDots` (décalage demi-interligne si sur ligne)
- 3 fixes fin de palier : barre finale + hampe accord + dots

### Étape 2c-2a — Curseur temporel

- `MusicEvent.timePosition` (int, en divisions MusicXML)
- `Measure.divisions` + `Measure.totalDivisions`
- `MeasureParser` : curseur par portée, gère `backup`, `forward`, `grace`, `chord`
- `PartParser` : met à jour `currentDivisions` **après chaque mesure** (fix critique)
- `LayoutEngine._layoutNotesInsideMeasure` : X calculé à partir de `timePosition` (alignement multi-voix parfait)

### Étape 2c-2b — Tuplets (parser)

- `time-modification` → `tupletsNumerator` / `tupletsDenominator`
- `tuplet type="start|stop" number bracket show-number` → `tupletStart`, `tupletStop`, `tupletNumber`, `tupletBracket`, `tupletShowNumber`

### Étape 2c-2c — Grace notes (parser)

- `grace slash="yes"` → `isGrace`, `graceSlash`
- `cue` → `isCue`
- Le curseur n'avance pas sur les grâces (`duration = 0`)

### Étape 2c-2d — Slurs / Ties (2e passe)

- `SlurTieResolver` : balayage global, apparie start/stop par pile LIFO
- `SlurConnection` + `TieConnection` + `ResolvedConnections`
- `ScoreDocument.connections` porte les connexions résolues
- `NoteEvent.slursStarted/Stopped`, `tiesStarted/Stopped` (Set<int>)
- Renderer : `_drawConnections` dessine les arcs en cherchant par `eventId` dans une map d'ancres

### Étape 2c-2e — Tuplets (rendu)

- `_drawTupletsInMeasure` : scan → groupes → dessin
- `_drawTupletGroup` : crochet horizontal + chiffre "3" au milieu
- Direction du crochet selon hampe (`above = stemUp`)
- `_drawTupletBracket` : crochets verticaux aux extrémités (dirigés vers la note)
- Paramètre `drawBrackets` pour honorer `bracket="no"`

### Étape 2c-2f — Directions + Paroles

- `DirectionPainter` : `mf`, `pp`, etc. en glyphes SMuFL (E520–E526)
- `LyricPainter` : paroles sous la portée, une ligne par vers
- Chaînage vertical : `drawDirections` retourne la hauteur consommée, `drawLyrics` reçoit un `startY`
- Overhang (`LayoutEngine.computeBottomOverhang`) : espace réservé sous la portée
- Fix spacing : entre 2 portées, `max(spacing, overhang)` au lieu de la somme

### Étape 2c-2g — Articulations (Path Canvas)

- Mapping SMuFL corrigé : articulations `E4A0/E4A2/E4A4/E4A8/E4AC`
- **Articulations dessinées à la main (Path Canvas)** pour staccato / accent / tenuto / marcato / staccatissimo : indépendance totale vis-à-vis de Leland
- Accents : chevron `>` horizontal
- Règle universelle : articulation du côté **opposé à la hampe**
- Les ornements complexes (fermata, trille, mordent) restent en glyphes SMuFL

### Étape 2c-2h — Symboles C/C barré + indentation + altérations

- **Time sig** : support `symbol="common"` et `symbol="cut"` → glyphes C et C barré
- **Time sig** : n'apparaît qu'au 1er système (fix `isFirstSystem`)
- **Indentation 1er système** : `LayoutEngine.firstSystemIndent = 60` (place pour le nom d'instrument)
- **Altérations cautionary / editorial** : parenthèses `()` et crochets `[]`
  - Glyphes SMuFL `E26A..E26D` (jamais les caractères texte)
  - `Pitch.isCautionary`, `Pitch.isEditorial`, `LayoutedNote.accidentalCautionary`, `LayoutedNote.accidentalEditorial`
- **Offset des altérations** : réduit de `2.4` à `1.5` interlignes (colle à la note)
- **Lignes supplémentaires asymétriques** : raccourcies à gauche quand une altération est présente
- **Lignes de portée** : commencent après le bloc de départ (clef/armure/time sig), traversent toute la largeur
- **Taille de clef** : `clefFontSize = staffLineSpacing * 4.5` (au lieu de 5.5)
- **StartBlock resserré** : 26/16/20 au lieu de 30/20/30

### Étape 2c-2i — Découpage optimal + trailing + overhang

- **Découpage optimal des systèmes** (DP type Knuth-Plass) : minimise le coût global (pénalité quadratique sur l'espace vide)
  - Respecte les sauts forcés (`new-system` du XML)
  - Dernier système moins pénalisé s'il est court
- **Compression du trailing** de la dernière note (`trailingCompression = 0.5`) : la dernière note se rapproche de la barline
- **Padding asymétrique** : `contentPaddingLeft = 22` (air après la barline), `contentPaddingRight = 12` (serré pour laisser le trailing agir)
- **Overhang système top/bottom** :
  - Top = overhang de la **1re portée uniquement** (+ clef, 2 interlignes)
  - Bottom = overhang de la **dernière portée uniquement** (+ clef, 1 interligne)
  - Entre portées : `max(minInterStaffSpacing, overhangBas + overhangHaut + collisionMargin)`
  - `interSystemSpacing = 40` (marge minimum garantie)
- **Fix spacing entre portées** : `lowestYUpper` initialisé à 4, `highestYLower` à 0 (pas de fausse détection de collision)

### Étape 2c-2j — Microtons

- 4 nouveaux glyphes SMuFL : `E280-E283` (quarter-sharp, quarter-flat, three-quarter-sharp, three-quarter-flat)
- 4 nouveaux cases dans le switch de `_drawAccidental`
- Parser enrichi : `sharp-sharp` (synonyme de double-sharp), `three-quarter-*`, `quarter-*`

### Support fichiers

- Extensions supportées : `.xml`, `.musicxml`, `.mxl`
- `XmlReader` : `readFile` gère les 3 extensions
- `MusicXmlParser.parseAuto` : gère les 3 extensions
- Picker : `allowedExtensions: ['xml', 'musicxml', 'mxl']`

---

## Tests en cours — Suite W3C

Corpus de test : [github.com/w3c-cg/musicxmlTestSuite](https://github.com/w3c-cg/musicxmlTestSuite)

**Fichiers testés avec succès** :
- `01a-Pitches-Pitches.musicxml` ✅ (notes G2 à C7, altérations variées)
- `01d-Pitches-Microtones.musicxml` ✅ (microtons)

**Fichiers à tester** (catégories prioritaires) :
- 01–03 : hauteurs, silences, rythme
- 11–14 : armures, clefs, chiffrages
- 21–24 : notes, accords, triolets, grâces
- 31–34 : notations et articulations
- 41–43 : parties, multi-voix, multi-portées
- 45–46 : reprises, barres de mesure
- 61 : paroles

**Compléments recommandés** :
- OpenScore Lieder (vraie musique, paroles, polyphonie)
- MuseScore test files (cas limites réels)

---

## Étapes SUIVANTES

### Polish restant

1. **Crédits** : titre + compositeur positionnés via `valign` du MusicXML (fix structurel)
2. **Espace inter-système** : ajuster si nécessaire
3. **Ligatures penchées** : actuellement horizontales, à incliner selon la pente mélodique
4. **Multi-voix** : couleurs différenciées voix 1/voix 2 (optionnel)
5. **`pitch_positioner.dart`** : corriger `tenor` et `baritoneFa` (valeurs yLine fausses)
6. **Factoriser `_shouldStemBeUp`** (dupliqué dans 3 fichiers)
7. **Capper la taille des microtons** si trop gros visuellement

### Étape 2d — Notation avancée

- Notes de grâce : rendu en petite taille, décalées à gauche (parser OK, renderer à finir)
- Cue notes : idem
- Ornements (trille, mordent) : glyphes OK, à câbler proprement
- Barres de reprise stylées (`repeatStart`, `repeatEnd`)
- Silences multi-mesures (`multi-measure-rest`)
- Altérations contextuelles (`AccidentalResolver` : tient compte de l'armure et de l'historique de mesure)

### Étape 3 — Undo/Redo

- Pattern Command ou Memento (à trancher)
- Patches/diffs plutôt que snapshots complets (RAM)
- Branchement menu Édition

### Étape 4 — Édition

- Insertion / suppression de notes
- Drag & drop vertical (partiel : OK, reste à valider sur accords)
- Drag horizontal (`default-x` manuel, sans changer timePosition)
- Transposition
- Sélection multiple
- Copier/coller

### Étape 5 — Layout professionnel

- **Spacing par intervalles** (au lieu du `timePosition` proportionnel)
- BBox réelles pour la détection de collisions
- Spacing optique (MuseScore-like)

### Phase ultérieure — Export / MIDI

- Export MusicXML fidèle (round-trip)
- Export MIDI (validation audio du parser)
- Export PDF (via `PictureRecorder`)

---

## BUGS CONNUS

- Espace après dernière note de mesure (atténué par `trailingCompression`, pourrait être affiné)
- Titre au milieu au lieu de droite (crédits valign)
- `pitch_positioner.dart` : `tenor` et `baritoneFa` avec valeurs yLine fausses
- `_shouldStemBeUp` dupliqué dans 3 fichiers
- Notes de grâce non rendues en petit (parser OK, renderer à finir)
- Pas d'undo/redo

---

## Fichiers clés

### Modèle (`lib/models/`)

- `enums/music_enums.dart` — complet v2c-2 (avec `NoteheadShape`, `TremoloType`, `GlissandoType`, `BreathType`)
- `events/music_event.dart` — `MusicEvent`, `NoteEvent`, `RestEvent` (v2c-2 : `timePosition`, `beams`, `slurs*`, `ties*`, `isGrace`, `tuplet*`)
- `events/pitch.dart` — `Pitch` (+ `isCautionary`, `isEditorial`)
- `events/lyric.dart` — `Lyric` (text, syllabic, number, elision, extend, placement)
- `events/direction.dart` — `DirectionEvent`
- `events/slur_connection.dart` — `SlurConnection`, `TieConnection`, `ResolvedConnections`
- `score/measure.dart` — `Measure` + `TimeSignature` + `KeySignature` + `divisions` + `totalDivisions`
- `score/staff.dart` — `Staff`
- `score/voice.dart` — `Voice`
- `score/score_document.dart` — `ScoreDocument` + `ScoreHeader` + `connections`
- `score/page_layout.dart` — `PageLayout`, `PageDimensions`
- `layout/layout_models.dart` — `LayoutedNote` (eventId, voiceIndex, timePosition, duration, isGrace, accidentalCautionary, accidentalEditorial), `LayoutedMeasure`, `LayoutedStaff`, `LayoutedSystem`

### Parsers (`lib/services/parsers/`)

- `music_xml_parser.dart` — point d'entrée (parseFile, parseString, parseBytes, parseAuto)
- `xml_reader.dart` — lecture XML/MXL (.xml, .musicxml, .mxl)
- `score_parser.dart` — orchestre : header → pageLayout → partList → staves → resolver
- `metadata_parser.dart` — header, pageLayout, credits, part-list
- `part_parser.dart` — boucle sur les mesures, maintient l'état (clefs, armures, divisions)
- `measure_parser.dart` — curseur temporel par portée, merge chords, directions
- `note_parser.dart` — parse une note : pitch, durée, tuplet, grace, slurs, ties, beams, lyrics, articulations, cautionary/editorial
- `attributes_parser.dart` — clefs, armures, chiffrage, divisions
- `direction_parser.dart` — dynamiques, mots, métronome, wedges
- `slur_tie_resolver.dart` — 2e passe : apparie les slurs/ties globaux
- `common.dart` — helpers de conversion (duration, accidental avec microtons, clef, barline, articulation)
- `staff_parser.dart` — parseStaffDetails (peu utilisé)

### Layout (`lib/services/layout/`)

- `layout_engine.dart` — moteur principal :
  - DP type Knuth-Plass pour le découpage optimal
  - Overhang dynamique (notes hors portée + clef)
  - Padding asymétrique (gauche/droite)
  - Compression du trailing de la dernière note
  - Indentation du 1er système
- `pitch_positioner.dart` — pitch → yLine selon clef
- `justification.dart` — paramètres de justification
- `vertical_spacing.dart` — utilitaires de dimensionnement
- `horizontal_spacing.dart` — utilitaires (peu utilisés actuellement)

### Renderer (`lib/renderer/`)

- `staff_renderer.dart` — orchestrateur : boucle systèmes → mesures → notes, puis connexions
- `beam_drawer.dart` — ligatures et drapeaux (legacy, peu utilisé)
- `painters/structure_painter.dart` — lignes de portée, clefs, armures, chiffrages, accolades, crédits
- `painters/note_painter.dart` — notes, silences, altérations (avec microtons + cautionary/editorial), articulations (Path Canvas), ligatures
- `painters/expression_painter.dart` — slurs, ties
- `painters/direction_painter.dart` — dynamiques (mf, pp) + mots
- `painters/lyric_painter.dart` — paroles

### UI (`lib/views/`, `lib/widgets/`)

- `views/dashboard/dashboard_view.dart` — accueil, import fichier (xml/musicxml/mxl)
- `views/editor/editor_view.dart` — affichage partition + interaction
- `views/editor/editor_controller.dart` — sélection, drag vertical
- `widgets/top_menu_bar.dart` — barre de menus
- `widgets/main_toolbar.dart` — barre d'outils
- `widgets/note_palette.dart` — palette de notes flottante
- `utils/constants.dart` — `ScoreCraftConstants.scale`, `staffLineSpacing`

### Fichiers de test

- `test_scorecraft.musicxml` — 6 mesures, 2 portées piano
- Corpus W3C dans `test/` (à organiser par catégories)

---

## Prochaine action immédiate

**Deux options** :

**A. Continuer les tests W3C** (recommandé pour valider le parser) :
- Tester les catégories 01-03, 11-14, 21-24, 41-43, 61
- Noter les échecs dans un `TESTS.md`
- Fixer les bugs au fur et à mesure

**B. Attaquer l'édition** (le cœur du projet) :
- Undo/Redo (Phase 3)
- Insertion/suppression de notes (Phase 4)

**Recommandation** : continuer les tests W3C pour stabiliser le parser, puis édition.

---

## Notes techniques importantes

### Règle d'or

**Le DOM est la source de vérité**. Les `default-x/y` du MusicXML sont des caches éphémères. Toutes les coordonnées sont **recalculées** par le LayoutEngine, jamais stockées dans le modèle.

### Règles de notation (Behind Bars)

- Articulations : du côté **opposé à la hampe**.
- Time signature : 1er système uniquement, sauf changement explicite.
- Tuplet bracket : du côté de la hampe.
- Dynamiques : sous la portée par défaut.
- Lignes supplémentaires : asymétriques si altération présente.
- Altérations : collées à la note (`1.5` interlignes).

### SMuFL / Leland

- **Jamais** utiliser les glyphes "Below" pour les articulations (chevrons inversés dans Leland).
- **Jamais** utiliser les caractères texte `(`, `)`, `[`, `]` avec Leland → fallback vers police système, décalage vertical.
- Toujours utiliser les glyphes SMuFL dédiés : `E26A..E26D` pour parenthèses/crochets.
- Les 5 articulations de base (staccato, accent, tenuto, marcato, staccatissimo) sont **tracées avec Path Canvas**.
- Microtons : `E280-E283`.

### Performance

- `_lastPositions` est static → OK pour un seul renderer, à instance-scoper si multi-vue.
- `_drawConnections` fait un lookup par ID → O(n) sur les slurs, acceptable.
- Golden tests à prévoir en Phase 3+.

### Layout

- Découpage : DP type Knuth-Plass (`_computeOptimalSystemBreaks` + `_dpSegment`).
- Overhang système : top = 1re portée, bottom = dernière portée (les débordements internes sont gérés par `_computeSpacingBetweenStaves`).
- Inter-système : `max(40, bottomOverhang + 14.4 + 8)`.
- Trailing compression : `0.5` (tune entre 0.3 et 0.8).
- Padding : gauche 22, droite 12 (asymétrique).

---

## Objectif global

Éditeur MusicXML capable de lire et écrire, avec interaction type MuseScore.

## 01e — ParenthesizedAccidentals
✅ CONFORME spec MusicXML 4.0
⚠️ Différence avec MuseScore : MS n'implémente pas bracket/parentheses
   sur les altérations doubles (♭♭, 𝄪). C'est une limitation MS.
   Notre rendu est correct (cf. description W3C du fichier).