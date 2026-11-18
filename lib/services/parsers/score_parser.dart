// lib/services/parsers/score_parser.dart
// ============================================================================
// PARSEUR PRINCIPAL DE LA PARTITION (MUSICXML) — v2c-2
// ============================================================================
// Ce fichier parse <score-partwise> et coordonne les sous-parseurs.
//
// PIPELINE :
//   1. MetadataParser  → header, pageLayout, partList
//   2. PartParser      → pour chaque <part>, une liste de <Staff>
//   3. SlurTieResolver → 2e passe : résolution des slurs/ties
//
// ⚠️ Le resolver est ESSENTIEL : un slur peut traverser plusieurs mesures.
//    On ne peut PAS le résoudre mesure par mesure.
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/score/score_document.dart';
import '../../models/score/staff.dart';
import 'metadata_parser.dart';
import 'part_parser.dart';
import 'slur_tie_resolver.dart';

/// Parseur principal de la partition MusicXML.
class ScoreParser {
  // ==========================================================================
  // PARSEUR PRINCIPAL
  // ==========================================================================

  /// Parse un document MusicXML complet et retourne un ScoreDocument.
  ///
  /// Lance [FormatException] si le fichier n'est pas un score-partwise valide.
  /// Lance [UnsupportedError] si le fichier est en score-timewise.
  static ScoreDocument parse(xml.XmlDocument document) {
    final root = document.rootElement;

    // ─── 0. VÉRIFICATION DU TYPE DE DOCUMENT ────────────────────────────────
    if (root.name.local != 'score-partwise' &&
        root.name.local != 'score-timewise') {
      throw FormatException(
        'Le fichier XML n\'est pas un score-partwise ou score-timewise valide. '
        'Root element: ${root.name.local}',
      );
    }

    if (root.name.local == 'score-timewise') {
      // TODO v3 : supporter le score-timewise (transposition en partwise).
      throw UnsupportedError(
        'Le format score-timewise n\'est pas encore supporté. '
        'Veuillez utiliser un fichier score-partwise.',
      );
    }

    // ─── 1. MÉTADONNÉES ────────────────────────────────────────────────────
    final header = MetadataParser.parseHeader(root);

    // ─── 2. MISE EN PAGE ───────────────────────────────────────────────────
    final pageLayout = MetadataParser.parsePageLayout(root);

    // ─── 3. PART-LIST (NOMS DES INSTRUMENTS) ───────────────────────────────
    final partInfos = MetadataParser.parsePartList(root);

    // ─── 4. PARTIES (STAVES) ───────────────────────────────────────────────
    // Une <part> peut contenir 1 à N portées (ex: piano = 2).
    // PartParser retourne une LISTE de Staff par partie.
    // On maintient un index global pour les IDs de portée et de mesure.
    final List<Staff> staves = [];
    int nextGlobalStaffIndex = 1;

    for (final partNode in root.findAllElements('part')) {
      final partStaves = PartParser.parsePartWithInfo(
        partNode,
        nextGlobalStaffIndex,
        partInfos,
      );
      staves.addAll(partStaves);
      nextGlobalStaffIndex += partStaves.length;
    }

    if (staves.isEmpty) {
      throw FormatException(
        'Aucune portée (part) trouvée dans le fichier MusicXML.',
      );
    }

    // ─── 5. CRÉATION DU DOCUMENT (SANS CONNEXIONS) ─────────────────────────
    final documentWithoutConnections = ScoreDocument(
      id: 'score_1',
      header: header,
      pageLayout: pageLayout,
      staves: staves,
      connections: null,
    );

    // ─── 6. 2e PASSE : RÉSOLUTION DES SLURS / TIES ─────────────────────────
    // ⚠️ Cette passe parcourt TOUT le document pour apparier les
    //    <slur type="start"> avec les <slur type="stop"> correspondants,
    //    même s'ils sont dans des mesures différentes.
    final connections = SlurTieResolver.resolve(documentWithoutConnections);

    // ─── 7. RETOUR DU DOCUMENT COMPLET ─────────────────────────────────────
    return documentWithoutConnections.copyWith(connections: connections);
  }

  // ==========================================================================
  // MÉTHODE UTILITAIRE : PARSE DEPUIS UNE CHAÎNE
  // ==========================================================================

  /// Parse une chaîne XML et retourne un ScoreDocument.
  static ScoreDocument parseString(String xmlString) {
    final document = xml.XmlDocument.parse(xmlString);
    return parse(document);
  }
}