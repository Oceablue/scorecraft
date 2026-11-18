// lib/services/smufl/smufl.dart
// ============================================================================
// CHARGEMENT DES NOMS SMuFL (glyphnames.json) — v2c-31a-1
// ============================================================================
// Ce fichier élimine DÉFINITIVEMENT les codepoints hardcodés.
// Toutes les références à un glyphe SMuFL passent par son NOM officiel
// (ex: 'noteheadBlack', 'gClef', 'articStaccatoAbove').
//
// Le mapping nom → codepoint est chargé une fois au démarrage depuis
// l'asset `assets/smufl/glyphnames.json` (fichier officiel W3C/SMuFL).
//
// AVANTAGES :
//   1. Plus de risque de taper un mauvais U+XXXX à la main.
//   2. Compatible avec n'importe quelle police SMuFL (Leland, Bravura,
//      Petaluma, Sebastian...). On change de police → rien à modifier.
//   3. Les glyphes absents sont loggués → on sait immédiatement quoi
//      mettre en TODO.
//
// UTILISATION :
//   await Smufl.load();                      // au démarrage
//   final glyph = Smufl.glyph('noteheadBlack');
//   Smufl.findGlyphs('arrow');               // diagnostic par nom
//   Smufl.dumpRange(0xE0F0, 0xE0FF);         // diagnostic par plage
//
// v2c-93  : ajout de findGlyphs() pour chercher des noms par sous-chaîne.
// v2c-93b : ajout de dumpRange() pour identifier les glyphes par plage
//           Unicode (utile quand on ne connaît pas le nom exact).
// v2c-93z : ajout de digits() / timeSignatureNumber() / tupletNumber()
//           pour centraliser la génération de nombres SMuFL (le code
//           était dupliqué entre NotePainter et StructurePainter).
// v2c-31a-1: ajout de metNoteGlyphName() — extrait de
//            TupletPainter._metNoteGlyphName pour que DirectionPainter
//            puisse dessiner le métronome sans dupliquer la table.
// ============================================================================

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/enums/music_enums.dart';

class Smufl {
  Smufl._();

  static final Map<String, int> _codepoints = {};
  static bool _loaded = false;

  /// Ensemble des noms manquants déjà loggués (anti-spam logs).
  static final Set<String> _missing = {};

  /// Vrai après un appel réussi à [load].
  static bool get isLoaded => _loaded;

  /// Nombre de glyphes chargés.
  static int get glyphCount => _codepoints.length;

  // ==========================================================================
  // CHARGEMENT
  // ==========================================================================

  /// Charge le fichier `glyphnames.json` depuis les assets.
  ///
  /// Idempotent : si déjà chargé, retourne immédiatement.
  /// À appeler une seule fois dans `main()` APRÈS `WidgetsFlutterBinding`.
  static Future<void> load({
    String assetPath = 'assets/smufl/glyphnames.json',
  }) async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(assetPath);
    final dynamic decoded = json.decode(raw);

    if (decoded is! Map) {
      throw StateError(
        '[Smufl] Format inattendu : glyphnames.json doit être un objet JSON.',
      );
    }

    _codepoints.clear();
    decoded.forEach((key, value) {
      if (value is! Map) return;
      final cp = value['codepoint'];
      if (cp is! String) return;

      // Le format officiel est "U+E0A4" (parfois sans le "U+").
      final hex = cp.startsWith('U+') ? cp.substring(2) : cp;
      final code = int.tryParse(hex, radix: 16);
      if (code != null) {
        _codepoints[key as String] = code;
      }
    });

    _loaded = true;

    // ignore: avoid_print
    print('[Smufl] ${_codepoints.length} glyphes chargés depuis $assetPath');
  }

  // ==========================================================================
  // LOOKUP PAR NOM
  // ==========================================================================

  /// Retourne la String UTF-16 correspondant au glyphe SMuFL [name].
  ///
  /// Si le nom est inconnu, retourne `\uFFFD` (replacement character) et
  /// loggue une erreur — une seule fois par nom manquant.
  static String glyph(String name) {
    final cp = _codepoints[name];
    if (cp == null) {
      if (!_missing.contains(name)) {
        _missing.add(name);
        // ignore: avoid_print
        print('[Smufl] glyphe inconnu : "$name"');
      }
      return '\uFFFD';
    }
    return String.fromCharCode(cp);
  }

  /// Retourne le codepoint brut (int) pour un nom SMuFL, ou null.
  static int? codepoint(String name) => _codepoints[name];

  /// Vrai si le glyphe [name] existe dans la table chargée.
  static bool has(String name) => _codepoints.containsKey(name);

  /// Sélectionne [preferred] si présent, sinon [fallback].
  static String pick(String preferred, String fallback) =>
      has(preferred) ? glyph(preferred) : glyph(fallback);

  // ==========================================================================
  // GÉNÉRATION DE NOMBRES SMuFL — v2c-93z
  // ==========================================================================
  // SMuFL définit des glyphes dédiés pour les chiffres, organisés en
  // "familles" par préfixe :
  //   - timeSig0..timeSig9 : chiffres de chiffrage de mesure
  //   - tuplet0..tuplet9   : chiffres de tuplet (3, 5, 7…)
  //   - tupletColon        : séparateur pour les ratios (3:2)
  //
  // ⚠ NE PAS utiliser du texte brut ("$number") pour ces chiffres :
  //    les glyphes SMuFL sont dessinés avec un alignement vertical et une
  //    épaisseur spécifiques au contexte musical. Un chiffre texte tombe
  //    décalé ou trop fin.
  //
  // AVANT v2c-93z : deux copies de la même logique existaient dans
  // NotePainter.smuflTimeSig() et StructurePainter.smuflTimeSig().
  // Centralisé ici pour garantir une seule source de vérité.
  // ==========================================================================

  /// Retourne la chaîne de glyphes SMuFL pour un entier, en utilisant la
  /// famille [prefix] ('timeSig' ou 'tuplet').
  ///
  /// Exemple :
  ///   Smufl.digits(4)                       → glyphes timeSig4
  ///   Smufl.digits(12)                      → glyphes timeSig1 + timeSig2
  ///   Smufl.digits(3, prefix: 'tuplet')     → glyphes tuplet3
  ///   Smufl.digits(7, prefix: 'tuplet')     → glyphes tuplet7
  static String digits(int value, {String prefix = 'timeSig'}) {
    final buffer = StringBuffer();
    if (value < 0) {
      buffer.write('-');
      value = -value;
    }
    for (final c in value.toString().split('')) {
      final digit = int.tryParse(c);
      if (digit != null) {
        buffer.write(glyph('$prefix$digit'));
      }
    }
    return buffer.toString();
  }

  /// v2c-93z : raccourci pour le chiffrage de mesure.
  static String timeSignatureNumber(int value) =>
      digits(value, prefix: 'timeSig');

  /// v2c-93z : raccourci pour les chiffres de tuplet.
  static String tupletNumber(int value) =>
      digits(value, prefix: 'tuplet');

  // ==========================================================================
  // v2c-31a-1 : MÉTRONOME (glyphes metNote*)
  // ==========================================================================
  // SMuFL définit toute une famille de glyphes pour le métronome :
  //   metNoteWhole, metNoteHalfUp, metNoteQuarterUp, metNote8thUp…
  // ⚠ Il n'y a PAS de metNoteLonga ni metNoteMaxima dans la spec.
  //   On les mappe sur metNoteDoubleWhole (couvre longa/breve/maxima).
  //
  // ⚠ Les glyphes metNote* sont des notes avec hampe up + flag éventuel,
  //   positionnées sur une baseline alphabétique comme des caractères
  //   de texte. Voir TupletPainter pour le rendu des ratios de tuplet.
  //
  // Extrait de TupletPainter._metNoteGlyphName (v2c-93ze) pour éviter
  // une duplication quand DirectionPainter dessine le métronome.
  // ==========================================================================

  static String metNoteGlyphName(DurationType type) {
    switch (type) {
      case DurationType.doubleWhole:            return 'metNoteDoubleWhole';
      case DurationType.whole:                  return 'metNoteWhole';
      case DurationType.half:                   return 'metNoteHalfUp';
      case DurationType.quarter:                return 'metNoteQuarterUp';
      case DurationType.eighth:                 return 'metNote8thUp';
      case DurationType.sixteenth:              return 'metNote16thUp';
      case DurationType.thirtySecond:           return 'metNote32ndUp';
      case DurationType.sixtyFourth:            return 'metNote64thUp';
      case DurationType.oneHundredTwentyEighth: return 'metNote128thUp';
      case DurationType.twoHundredFiftySixth:   return 'metNote256thUp';
      case DurationType.fiveHundredTwelfth:     return 'metNote512thUp';
      case DurationType.oneThousandTwentyFourth:return 'metNote1024thUp';
      case DurationType.maxima:
      case DurationType.longa:
        return 'metNoteDoubleWhole';
    }
  }

  // ==========================================================================
  // DIAGNOSTIC
  // ==========================================================================

  /// v2c-93 : liste tous les noms SMuFL contenant [substring].
  static void findGlyphs(String substring) {
    final needle = substring.toLowerCase();
    final matches = _codepoints.keys
        .where((k) => k.toLowerCase().contains(needle))
        .toList()
      ..sort();

    // ignore: avoid_print
    print('[Smufl] ${matches.length} noms contiennent "$substring" :');
    for (final m in matches) {
      final cp = _codepoints[m]!;
      final hex = 'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}';
      // ignore: avoid_print
      print('  $m = $hex');
    }
  }

  /// v2c-93b : dump tous les noms dont le codepoint est dans [start]..[end].
  static void dumpRange(int startHex, int endHex) {
    final matches = <MapEntry<String, int>>[];
    _codepoints.forEach((name, cp) {
      if (cp >= startHex && cp <= endHex) {
        matches.add(MapEntry(name, cp));
      }
    });
    matches.sort((a, b) => a.value.compareTo(b.value));

    // ignore: avoid_print
    print('[Smufl] ${matches.length} glyphes dans la plage '
        'U+${startHex.toRadixString(16).toUpperCase()}..'
        'U+${endHex.toRadixString(16).toUpperCase()} :');
    for (final m in matches) {
      final hex = 'U+${m.value.toRadixString(16).toUpperCase().padLeft(4, '0')}';
      // ignore: avoid_print
      print('  ${m.key} = $hex');
    }
  }

  /// v2c-92 : dump complet (déjà utilisé, conservé pour compat).
  static void dumpDiagnostics() {
    // ignore: avoid_print
    print('=== SMuFL DIAGNOSTIC ===');
    // ignore: avoid_print
    print('Total glyphs: ${_codepoints.length}');
    // ignore: avoid_print
    print('========================');
  }

  /// Reset complet (utile pour les tests unitaires).
  static void reset() {
    _codepoints.clear();
    _missing.clear();
    _loaded = false;
  }
}