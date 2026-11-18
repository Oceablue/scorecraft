// lib/services/parsers/metadata_parser.dart
// ============================================================================
// PARSEUR DES MÉTADONNÉES (MUSICXML)
// ============================================================================
// Ce fichier parse les éléments suivants :
// - Métadonnées : <identification>, <work>, <movement-title>
// - Mise en page : <defaults>, <page-layout>
// - Crédits : <credit>
// - Part-list : <part-list>
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/score/score_document.dart';
import '../../models/score/page_layout.dart';


/// Parseur des métadonnées et de la mise en page.
class MetadataParser {
  // ==========================================================================
  // 1. MÉTADONNÉES (HEADER)
  // ==========================================================================

  /// Parse les métadonnées depuis l'élément racine.
  static ScoreHeader parseHeader(xml.XmlElement root) {
    String workTitle = '';
    String title = '';
    String subtitle = '';
    String composer = '';
    String lyricist = '';
    String arranger = '';
    String copyright = '';
    String software = '';
    String creationDate = '';

    // ---- Work ----
    final workNode = root.findElements('work').firstOrNull;
    if (workNode != null) {
      workTitle = workNode.findElements('work-title').firstOrNull?.innerText ?? '';
    } else {
    }

    // ---- Identification ----
    final idNode = root.findElements('identification').firstOrNull;
    if (idNode != null) {
      // Créateurs
      for (final creator in idNode.findElements('creator')) {
        final type = creator.getAttribute('type') ?? 'composer';
        final value = creator.innerText;
        switch (type) {
          case 'composer':
            composer = value;
            break;
          case 'lyricist':
            lyricist = value;
            break;
          case 'arranger':
            arranger = value;
            break;
        }
      }

      // Droits (copyright)
      copyright = idNode.findElements('rights').firstOrNull?.innerText ?? '';

      // Encodage
      final encoding = idNode.findElements('encoding').firstOrNull;
      if (encoding != null) {
        software = encoding.findElements('software').firstOrNull?.innerText ?? '';
        creationDate = encoding.findElements('encoding-date').firstOrNull?.innerText ?? '';
      }

      // Divers (subtitle)
      final misc = idNode.findElements('miscellaneous').firstOrNull;
      if (misc != null) {
        for (final field in misc.findElements('miscellaneous-field')) {
          if (field.getAttribute('name') == 'subtitle') {
            subtitle = field.innerText;
          }
        }
      }
    } else {
    }

    // ---- Movement title ----
    final movementTitle = root.findElements('movement-title').firstOrNull?.innerText ?? '';
    title = movementTitle.isNotEmpty ? movementTitle : workTitle;

    return ScoreHeader(
      title: title,
      subtitle: subtitle,
      composer: composer,
      lyricist: lyricist,
      arranger: arranger,
      copyright: copyright,
      software: software,
      creationDate: creationDate,
      initialTempoBpm: 120, // Valeur par défaut
    );
  }

  // ==========================================================================
  // 2. MISE EN PAGE (PAGE LAYOUT)
  // ==========================================================================

  /// Parse la mise en page depuis l'élément racine.
  static PageLayout parsePageLayout(xml.XmlElement root) {
    double pageWidth = 1200.33;
    double pageHeight = 1696.72;
    double marginLeft = 85.7143;
    double marginRight = 85.7143;
    double marginTop = 85.7143;
    double marginBottom = 85.7143;
    double staffSpaceMm = 1.75; // 7/40 * 10

    // ---- Defaults ----
    final defaults = root.findElements('defaults').firstOrNull;
    if (defaults != null) {
      // Scaling
      final scaling = defaults.findElements('scaling').firstOrNull;
      if (scaling != null) {
        final mmStr = scaling.findElements('millimeters').firstOrNull?.innerText;
        final tenthsStr = scaling.findElements('tenths').firstOrNull?.innerText;
        if (mmStr != null && tenthsStr != null) {
          final mm = double.parse(mmStr);
          final tenths = double.parse(tenthsStr);
          staffSpaceMm = mm / tenths * 10; // 1 interligne = 10 dixièmes
        }
      }

      // Page layout
      final pageLayoutNode = defaults.findElements('page-layout').firstOrNull;
      if (pageLayoutNode != null) {
        final pw = pageLayoutNode.findElements('page-width').firstOrNull?.innerText;
        final ph = pageLayoutNode.findElements('page-height').firstOrNull?.innerText;
        if (pw != null) pageWidth = double.parse(pw);
        if (ph != null) pageHeight = double.parse(ph);

        final marginsList = pageLayoutNode.findElements('page-margins');
        if (marginsList.isNotEmpty) {
          final margins = marginsList.first;
          final ml = margins.findElements('left-margin').firstOrNull?.innerText;
          final mr = margins.findElements('right-margin').firstOrNull?.innerText;
          final mt = margins.findElements('top-margin').firstOrNull?.innerText;
          final mb = margins.findElements('bottom-margin').firstOrNull?.innerText;
          if (ml != null) marginLeft = double.parse(ml);
          if (mr != null) marginRight = double.parse(mr);
          if (mt != null) marginTop = double.parse(mt);
          if (mb != null) marginBottom = double.parse(mb);
        }
      }

      // Fonts (optionnel)
      // final musicFont = defaults.findElements('music-font').firstOrNull?.getAttribute('font-family') ?? 'Leland';
      // final wordFont = defaults.findElements('word-font').firstOrNull?.getAttribute('font-family') ?? 'Edwin';
      // final lyricFont = defaults.findElements('lyric-font').firstOrNull?.getAttribute('font-family') ?? 'Edwin';
    }

    // ---- Crédits ----
    final credits = parseCredits(root);

    // Création des dimensions
    final dimensions = PageDimensions(
      width: pageWidth,
      height: pageHeight,
      marginLeft: marginLeft,
      marginRight: marginRight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      staffSpaceMm: staffSpaceMm,
    );

    return PageLayout(
      dimensions: dimensions,
      credits: credits,
      // Les autres paramètres (titre, compositeur, etc.) peuvent être ajustés
      // via les crédits, donc on laisse les valeurs par défaut.
    );
  }

  // ==========================================================================
  // 3. CRÉDITS
  // ==========================================================================

  /// Parse les crédits depuis l'élément racine.
  static Map<String, Map<String, dynamic>> parseCredits(xml.XmlElement root) {
    final credits = <String, Map<String, dynamic>>{};

    for (final credit in root.findAllElements('credit')) {
      final type = credit.findElements('credit-type').firstOrNull?.innerText ?? 'unknown';
      final words = credit.findElements('credit-words').firstOrNull;

      if (words != null) {
        final text = words.innerText;
        final x = double.tryParse(words.getAttribute('default-x') ?? '') ?? 0;
        final y = double.tryParse(words.getAttribute('default-y') ?? '') ?? 0;
        final justify = words.getAttribute('justify') ?? 'left';
        final valign = words.getAttribute('valign') ?? 'top';
        final fontSize = double.tryParse(words.getAttribute('font-size') ?? '') ?? 12;

        credits[type] = {
          'text': text,
          'x': x,
          'y': y,
          'justify': justify,
          'valign': valign,
          'fontSize': fontSize,
        };
      }
    }

    return credits;
  }

  // ==========================================================================
  // 4. PART-LIST (INSTRUMENTS)
  // ==========================================================================

  /// Parse le part-list et retourne une Map id -> {name, abbreviation}.
  static Map<String, Map<String, String>> parsePartList(xml.XmlElement root) {
    final partInfos = <String, Map<String, String>>{};
    final partList = root.findElements('part-list').firstOrNull;

    if (partList != null) {
      for (final part in partList.findElements('score-part')) {
        final id = part.getAttribute('id');
        if (id != null) {
          final name = part.findElements('part-name').firstOrNull?.innerText ?? 'Instrument';
          final abbreviation = part.findElements('part-abbreviation').firstOrNull?.innerText ?? name;
          partInfos[id] = {
            'name': name,
            'abbreviation': abbreviation,
          };
        }
      }
    }

    return partInfos;
  }

  // ==========================================================================
  // 5. MÉTHODES UTILITAIRES (optionnelles)
  // ==========================================================================

  /// Parse les crédits et retourne un objet structuré (version typée).
  /// Utile si on veut une version plus robuste que la Map.
  static List<Map<String, dynamic>> parseCreditsTyped(xml.XmlElement root) {
    final credits = <Map<String, dynamic>>[];

    for (final credit in root.findAllElements('credit')) {
      final type = credit.findElements('credit-type').firstOrNull?.innerText ?? 'unknown';
      final words = credit.findElements('credit-words').firstOrNull;

      if (words != null) {
        credits.add({
          'type': type,
          'text': words.innerText,
          'x': double.tryParse(words.getAttribute('default-x') ?? '') ?? 0,
          'y': double.tryParse(words.getAttribute('default-y') ?? '') ?? 0,
          'justify': words.getAttribute('justify') ?? 'left',
          'valign': words.getAttribute('valign') ?? 'top',
          'fontSize': double.tryParse(words.getAttribute('font-size') ?? '') ?? 12,
        });
      }
    }

    return credits;
  }
}