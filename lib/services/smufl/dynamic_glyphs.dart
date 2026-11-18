// lib/services/smufl/dynamic_glyphs.dart
// ============================================================================
// RÉSOLUTION DES DYNAMIQUES → GLYPHES SMuFL
// ============================================================================
// Source UNIQUE de vérité pour la conversion :
//   - DynamicType (cas standard)     → glyphe composite ou assemblage
//   - String custom (other-dynamics) → assemblage lettre par lettre
//   - String XML brut ('f', 'sfp')   → via DynamicType
//
// Utilisé par :
//   - NotePainter.drawNoteDynamic       (<notations><dynamics>)
//   - DirectionPainter._drawDynamic     (<direction><dynamics>)
//
// ─── STRATÉGIE ─────────────────────────────────────────────────────────────
// 1. Si SMuFL expose un glyphe COMPOSITE dédié (dynamicPP, dynamicSforzato,
//    dynamicSforzatoFF…), on l'utilise : le composite a un kerning optimal
//    et un alignement vertical correct par lettre (f plus grand que p).
//
// 2. Sinon (cas 'sf', ou other-dynamics 'sfffz'), on assemble lettre par
//    lettre avec les glyphes MONOLITHIQUES :
//        dynamicPiano (p), dynamicForte (f), dynamicMezzo (m),
//        dynamicSforzando (s), dynamicRinforzando (r),
//        dynamicZ (z), dynamicNiente (n).
//
// 3. other-dynamics peut contenir du texte NON musical ('cresc.', 'smorz.').
//    Dans ce cas resolveCustom() retourne `null` et l'appelant doit
//    fallback sur du texte italique. Le test se fait sur "tous les
//    caractères (hors espaces) sont des lettres musicales".
// ============================================================================

import '../../models/enums/music_enums.dart';
import 'smufl.dart';

class DynamicGlyphs {
  DynamicGlyphs._();

  // ─── MAP : DynamicType → glyphe SMuFL COMPOSITE ────────────────────────
  //
  // ⚠ Uniquement les cas où SMuFL fournit un glyphe composite dédié.
  //   'sf' n'en a PAS → traité par assembleLetters().
  static const Map<DynamicType, String> _composite = {
    // ─ piano ─────────────────────────────────────────────────────────
    DynamicType.p:      'dynamicPiano',
    DynamicType.pp:     'dynamicPP',
    DynamicType.ppp:    'dynamicPPP',
    DynamicType.pppp:   'dynamicPPPP',
    DynamicType.ppppp:  'dynamicPPPPP',
    DynamicType.pppppp: 'dynamicPPPPPP',

    // ─ forte ─────────────────────────────────────────────────────────
    DynamicType.f:      'dynamicForte',
    DynamicType.ff:     'dynamicFF',
    DynamicType.fff:    'dynamicFFF',
    DynamicType.ffff:   'dynamicFFFF',
    DynamicType.fffff:  'dynamicFFFFF',
    DynamicType.ffffff: 'dynamicFFFFFF',

    // ─ mezzo ─────────────────────────────────────────────────────────
    DynamicType.mp:     'dynamicMP',
    DynamicType.mf:     'dynamicMF',

    // ─ combinés ──────────────────────────────────────────────────────
    DynamicType.fp:     'dynamicFortePiano',
    DynamicType.pf:     'dynamicPF',
    DynamicType.fz:     'dynamicForzando',

    // ─ sforzando ─────────────────────────────────────────────────────
    DynamicType.sfz:    'dynamicSforzato',
    DynamicType.sfp:    'dynamicSforzandoPiano',
    DynamicType.sfpp:   'dynamicSforzandoPianissimo',
    DynamicType.sfzp:   'dynamicSforzatoPiano',
    DynamicType.sffz:   'dynamicSforzatoFF',

    // ─ rinforzando ───────────────────────────────────────────────────
    DynamicType.rf:     'dynamicRinforzando1',
    DynamicType.rfz:    'dynamicRinforzando2',

    // ─ niente ────────────────────────────────────────────────────────
    DynamicType.niente: 'dynamicNiente',
  };

  // ─── MAP : lettre ASCII → glyphe MONOLITHIQUE ──────────────────────────
  //
  // Pour l'assemblage manuel (other-dynamics, cas 'sf', fallback si un
  // composite manque dans la police chargée).
  static const Map<String, String> _letterGlyph = {
    'p': 'dynamicPiano',
    'm': 'dynamicMezzo',
    'f': 'dynamicForte',
    'r': 'dynamicRinforzando',
    's': 'dynamicSforzando',
    'z': 'dynamicZ',
    'n': 'dynamicNiente',
  };

  // ══════════════════════════════════════════════════════════════════════
  // API PUBLIQUE
  // ══════════════════════════════════════════════════════════════════════

  /// Résout une [DynamicType] en chaîne de glyphes SMuFL.
  ///
  /// Retourne `null` si [type] est `none`, `crescendoLine` ou `decrescendoLine`
  /// (ces derniers sont des wedges, pas des glyphes de dynamique).
  ///
  /// Exemples :
  ///   resolve(DynamicType.pp)   → glyphe composite 'dynamicPP'
  ///   resolve(DynamicType.sf)   → 'dynamicSforzando' + 'dynamicForte'
  ///   resolve(DynamicType.sfz)  → glyphe composite 'dynamicSforzato'
  static String? resolve(DynamicType type) {
    if (type == DynamicType.none ||
        type == DynamicType.crescendoLine ||
        type == DynamicType.decrescendoLine) {
      return null;
    }

    // 1. Composite si dispo dans la police chargée.
    final composite = _composite[type];
    if (composite != null && Smufl.has(composite)) {
      return Smufl.glyph(composite);
    }

    // 2. Fallback : assemblage lettre par lettre à partir du nom de l'enum.
    //    Ex: DynamicType.sf → 'sf' → s + f
    //        DynamicType.sfpp (si composite absent) → 's'+'f'+'p'+'p'
    return assembleLetters(type.name);
  }

  /// Résout un nom XML brut ('f', 'sfp', 'pppp', …) en glyphes SMuFL.
  ///
  /// Équivalent à `resolve(DynamicTypeParser.fromXmlName(name))`, mais
  /// retourne `null` si le nom est inconnu (au lieu de `none`).
  static String? resolveXmlName(String name) {
    final type = DynamicTypeParser.fromXmlName(name);
    if (type != DynamicType.none) return resolve(type);
    return null;
  }

  /// Résout un texte custom ('other-dynamics') en glyphes SMuFL.
  ///
  /// - Si [text] est vide → `null`.
  /// - Si TOUS les caractères (hors espaces) sont des lettres musicales
  ///   (`p`, `f`, `m`, `r`, `s`, `z`, `n`) → assemblage lettre par lettre.
  /// - Sinon ('cresc.', 'smorz.', texte libre) → `null`.
  ///   L'appelant doit fallback sur un rendu texte italique.
  ///
  /// Exemples :
  ///   resolveCustom('sfffz')  → 's'+'f'+'f'+'f'+'z'
  ///   resolveCustom('ppp')    → 'p'+'p'+'p'  (composite plus joli possible,
  ///                              mais on assemble car text brut)
  ///   resolveCustom('cresc.') → null  (fallback texte)
  static String? resolveCustom(String? text) {
    if (text == null || text.isEmpty) return null;

    final lettersOnly = text.replaceAll(RegExp(r'\s'), '');
    if (lettersOnly.isEmpty) return null;

    final allMusical = lettersOnly.split('').every(isDynamicLetter);
    if (!allMusical) return null;

    return assembleLetters(text);
  }

  /// Assemble une séquence de lettres ('sfpp', 'rfz', 'sfffz', …) en chaîne
  /// de glyphes SMuFL. Les caractères non reconnus passent en texte brut.
  static String assembleLetters(String letters) {
    final buffer = StringBuffer();
    for (final c in letters.split('')) {
      final glyphName = _letterGlyph[c.toLowerCase()];
      if (glyphName != null && Smufl.has(glyphName)) {
        buffer.write(Smufl.glyph(glyphName));
      } else {
        buffer.write(c); // espace, ponctuation, lettre non-musicale
      }
    }
    return buffer.toString();
  }

  /// Vrai si [c] est une lettre de dynamique connue (une seule lettre).
  static bool isDynamicLetter(String c) {
    if (c.isEmpty) return false;
    return _letterGlyph.containsKey(c.toLowerCase());
  }
}