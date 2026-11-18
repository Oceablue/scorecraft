// lib/services/parsers/xml_reader.dart
// ============================================================================
// LECTURE DE FICHIERS XML / MXL (MUSICXML COMPRESSÉ)
// ============================================================================
// Ce fichier fournit des helpers pour lire les fichiers MusicXML :
// - Fichiers .xml (XML standard)
// - Fichiers .mxl (MusicXML compressé via ZIP)
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:xml/xml.dart' as xml;
import 'package:archive/archive.dart';

/// Exception levée lors d'une erreur de lecture de fichier.
class XmlReaderException implements Exception {
  final String message;
  const XmlReaderException(this.message);
  @override
  String toString() => 'XmlReaderException: $message';
}

/// Helpers pour la lecture de fichiers MusicXML.
class XmlReader {
  // ==========================================================================
  // LECTURE DEPUIS UN FICHIER
  // ==========================================================================

  /// Lit un fichier XML ou MXL et retourne un XmlDocument.
  ///
  /// [path] : chemin vers le fichier (.xml ou .mxl).
  static Future<xml.XmlDocument> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw XmlReaderException('Fichier introuvable : $path');
    }

    final extension = path.split('.').last.toLowerCase();
    final bytes = await file.readAsBytes();

      if (extension == 'mxl') {
      return readMxlBytes(bytes);
    } else if (extension == 'xml' || extension == 'musicxml') {
      return readXmlBytes(bytes);
    } else {
      throw XmlReaderException(
        'Extension non supportée : $extension. '
        'Utilisez .xml, .musicxml ou .mxl.',
      );
    }
  }

  // ==========================================================================
  // LECTURE DEPUIS DES BYTES
  // ==========================================================================

  /// Lit des bytes XML et retourne un XmlDocument.
  static xml.XmlDocument readXmlBytes(Uint8List bytes) {
    try {
      final xmlString = utf8.decode(bytes);
      return xml.XmlDocument.parse(xmlString);
    } catch (e) {
      throw XmlReaderException('Erreur lors du parsing XML : $e');
    }
  }

  /// Lit des bytes MXL (compressé) et retourne un XmlDocument.
  static xml.XmlDocument readMxlBytes(Uint8List bytes) {
    try {
      // Décompression du fichier ZIP
      final archive = ZipDecoder().decodeBytes(bytes);

      // Lecture du fichier container.xml pour trouver le chemin du score
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile == null) {
        throw XmlReaderException('container.xml introuvable dans l\'archive MXL.');
      }

      final containerXml = utf8.decode(containerFile.content as List<int>);
      final containerDoc = xml.XmlDocument.parse(containerXml);
      final root = containerDoc.rootElement;

      // Recherche du chemin du score principal
      final rootfile = root.findAllElements('rootfile').firstOrNull;
      if (rootfile == null) {
        throw XmlReaderException('Aucun élément <rootfile> trouvé dans container.xml.');
      }

      final fullPath = rootfile.getAttribute('full-path');
      if (fullPath == null || fullPath.isEmpty) {
        throw XmlReaderException('Attribut full-path manquant dans container.xml.');
      }

      // Extraction du fichier score
      final scoreFile = archive.findFile(fullPath);
      if (scoreFile == null) {
        throw XmlReaderException('Fichier score introuvable : $fullPath');
      }

      final scoreXml = utf8.decode(scoreFile.content as List<int>);
      return xml.XmlDocument.parse(scoreXml);
    } catch (e) {
      if (e is XmlReaderException) rethrow;
      throw XmlReaderException('Erreur lors du parsing MXL : $e');
    }
  }

  // ==========================================================================
  // LECTURE DEPUIS UNE CHAÎNE
  // ==========================================================================

  /// Parse une chaîne XML directement.
  static xml.XmlDocument parseString(String xmlString) {
    try {
      return xml.XmlDocument.parse(xmlString);
    } catch (e) {
      throw XmlReaderException('Erreur lors du parsing de la chaîne XML : $e');
    }
  }

  // ==========================================================================
  // DÉTECTION DE FORMAT
  // ==========================================================================

  /// Détecte si les bytes sont du XML ou du MXL.
  static String detectFormat(Uint8List bytes) {
    // Un fichier ZIP commence par les signatures 'PK' (0x50 0x4B)
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return 'mxl';
    }
    // Sinon on suppose que c'est du XML
    return 'xml';
  }

  /// Lit des bytes en détectant automatiquement le format.
  static xml.XmlDocument readBytes(Uint8List bytes) {
    final format = detectFormat(bytes);
    if (format == 'mxl') {
      return readMxlBytes(bytes);
    } else {
      return readXmlBytes(bytes);
    }
  }

  // ==========================================================================
  // HELPERS POUR L'EXTRACTION D'ATTRIBUTS
  // ==========================================================================

  /// Extrait la valeur d'un attribut d'un nœud, ou retourne une valeur par défaut.
  static String getAttributeSafe(
    xml.XmlElement node,
    String attrName, {
    String defaultValue = '',
  }) {
    return node.getAttribute(attrName) ?? defaultValue;
  }

  /// Extrait la valeur d'un élément enfant, ou retourne une valeur par défaut.
  static String getChildValueSafe(
    xml.XmlElement parent,
    String childName, {
    String defaultValue = '',
  }) {
    final child = parent.findElements(childName).firstOrNull;
    return child?.innerText ?? defaultValue;
  }

  /// Extrait la valeur d'un élément enfant en int, ou retourne une valeur par défaut.
  static int getChildIntSafe(
    xml.XmlElement parent,
    String childName, {
    int defaultValue = 0,
  }) {
    final child = parent.findElements(childName).firstOrNull;
    if (child == null) return defaultValue;
    final value = child.innerText.trim();
    if (value.isEmpty) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Extrait la valeur d'un élément enfant en double, ou retourne une valeur par défaut.
  static double getChildDoubleSafe(
    xml.XmlElement parent,
    String childName, {
    double defaultValue = 0.0,
  }) {
    final child = parent.findElements(childName).firstOrNull;
    if (child == null) return defaultValue;
    final value = child.innerText.trim();
    if (value.isEmpty) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }
}