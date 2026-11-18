// lib/services/parsers/music_xml_parser.dart
// ============================================================================
// PARSEUR MUSICXML (POINT D'ENTRÉE PRINCIPAL)
// ============================================================================
// Ce fichier est le point d'entrée principal pour le parsing MusicXML.
// Il délègue le travail à :
// - XmlReader : lecture des fichiers XML/MXL
// - ScoreParser : parsing du document XML
//
// Il supporte :
// - Les fichiers .xml (XML standard)
// - Les fichiers .mxl (MusicXML compressé via ZIP)
// - Les chaînes XML directes
// ============================================================================

import 'dart:typed_data';

import '../../models/score/score_document.dart';
import 'xml_reader.dart';
import 'score_parser.dart';

/// Parseur MusicXML principal.
///
/// Point d'entrée unique pour le parsing de fichiers MusicXML.
/// Supporte les formats .xml et .mxl.
class MusicXmlParser {
  // ==========================================================================
  // PARSE DEPUIS UNE CHAÎNE
  // ==========================================================================

  /// Parse une chaîne XML et retourne un ScoreDocument.
  ///
  /// [xmlString] : le contenu XML à parser.
  ///
  /// Exemple :
  /// ```dart
  /// final score = MusicXmlParser.parseString('<score-partwise>...</score-partwise>');
  /// ```
  static ScoreDocument parseString(String xmlString) {
    final doc = XmlReader.parseString(xmlString);
    return ScoreParser.parse(doc);
  }

  // ==========================================================================
  // PARSE DEPUIS UN FICHIER
  // ==========================================================================

  /// Parse un fichier XML ou MXL et retourne un ScoreDocument.
  ///
  /// [path] : chemin vers le fichier (.xml ou .mxl).
  ///
  /// Exemple :
  /// ```dart
  /// final score = await MusicXmlParser.parseFile('partition.mxl');
  /// ```
  static Future<ScoreDocument> parseFile(String path) async {
    final doc = await XmlReader.readFile(path);
    return ScoreParser.parse(doc);
  }

  // ==========================================================================
  // PARSE DEPUIS DES BYTES
  // ==========================================================================

  /// Parse des bytes XML ou MXL et retourne un ScoreDocument.
  ///
  /// [bytes] : les bytes du fichier (XML ou MXL).
  ///
  /// Exemple :
  /// ```dart
  /// final bytes = await File('partition.mxl').readAsBytes();
  /// final score = MusicXmlParser.parseBytes(bytes);
  /// ```
  static ScoreDocument parseBytes(Uint8List bytes) {
    final doc = XmlReader.readBytes(bytes);
    return ScoreParser.parse(doc);
  }

  // ==========================================================================
  // PARSE AVEC DÉTECTION AUTOMATIQUE (UTILITAIRE)
  // ==========================================================================

  /// Parse une source en détectant automatiquement son type.
  ///
  /// [source] : peut être :
  /// - une chaîne XML (ex: 'score-partwise>...</score-partwise')
  /// - un chemin de fichier (ex: 'partition.mxl' ou 'partition.xml')
  /// - des bytes (Uint8List)
  ///
  /// Retourne un ScoreDocument.
  ///
  /// Exemple :
  /// ```dart
  /// final score = await MusicXmlParser.parseAuto('partition.mxl');
  /// final score2 = await MusicXmlParser.parseAuto('<score-partwise>...</score-partwise>');
  /// final score3 = MusicXmlParser.parseAuto(bytes);
  /// ```
  static Future<ScoreDocument> parseAuto(dynamic source) async {
    if (source is String) {
      // Si c'est un chemin de fichier (contient '/' ou '\' ou se termine par .xml/.mxl)
       if (source.contains('/') || source.contains('\\') ||
        source.endsWith('.xml') ||
        source.endsWith('.musicxml') ||
        source.endsWith('.mxl')) {
        return await parseFile(source);
      }
      // Sinon c'est une chaîne XML
      return parseString(source);
    } else if (source is Uint8List) {
      return parseBytes(source);
    } else {
      throw ArgumentError(
        'source doit être une String (XML ou chemin) ou Uint8List. '
        'Type reçu : ${source.runtimeType}',
      );
    }
  }
}