// lib/services/smufl/smufl_metrics.dart
// ============================================================================
// MÉTRIQUES DE GLYPHES SMuFL — v2c-96 (corrigé pour le format officiel)
// ============================================================================
// Charge Leland.json (format SMuFL font metadata standard) :
//   - glyphBBoxes        : name -> {bBoxNE: [x, y], bBoxSW: [x, y]}
//   - glyphsWithAnchors  : name -> {anchorName: [x, y], ...}
//   - glyphAdvanceWidths : name -> float
//
// UNITÉS :
//   - Les valeurs du JSON sont en `em`.
//   - 1 em = fontSize px à l'écran.
//   - ScoreCraft rend à fontSize = staffLineSpacing * 4.3.
//   - `pxFor(em, fontSize)` : em → pixels.
//   - `spFor(em, fontSize, sp)` : em → "sp" (multiples de staffLineSpacing).
//
// CONVENTIONS SMuFL :
//   - y positif = HAUT (opposé à l'écran où y positif = bas).
//   - Notehead par défaut : bBoxSW.x = 0 (bord gauche à l'origine),
//     bBoxNE.x = 1.18 (bord droit). Le centre visuel est à 0.59 em.
//   - `stemUpSE` = point d'attache de la hampe up (coin haut-droit).
//   - `stemDownNW` = point d'attache de la hampe down (coin bas-gauche).
//
// FALLBACK :
//   - lookup Leland → Bravura → zéro/null + warning UNE SEULE FOIS.
// ============================================================================
// UNITÉS (corrigé v2c-96)
// ============================================================================
// Les valeurs bBoxNE/bBoxSW/anchors/advanceWidths du JSON SMuFL officiel
// sont en STAFF SPACES (sp), PAS en em. C'est la convention SMuFL :
//   « All measurements are given in staff spaces. »
//
// Donc :
//   - bbox.center.dx = 0.65 → 0.65 sp
//   - Pour convertir en pixels : sp * staffLineSpacing
//   - Pas de conversion em→sp à faire, les valeurs SONT déjà en sp.
//
// SMuFL y-convention :
//   - y positif = HAUT (opposé à l'écran où y positif = bas)
//   - Pour passer en coordonnées écran : y_screen = -y_smufl
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' show Offset;

// ============================================================================
// 1. DATA CLASSES
// ============================================================================

class GlyphBBox {
  /// Coin nord-est (droite / haut) — en `em`.
  final Offset ne;

  /// Coin sud-ouest (gauche / bas) — en `em`.
  final Offset sw;

  const GlyphBBox({required this.ne, required this.sw});

  static const GlyphBBox zero = GlyphBBox(ne: Offset.zero, sw: Offset.zero);

  Offset get center => Offset((ne.dx + sw.dx) / 2, (ne.dy + sw.dy) / 2);
  double get width => ne.dx - sw.dx;
  double get height => ne.dy - sw.dy;
  bool get isEmpty => width == 0 && height == 0;

  @override
  String toString() => 'GlyphBBox(NE:$ne SW:$sw)';
}

/// Données d'une police (column-oriented, comme le JSON SMuFL).
class _FontData {
  final Map<String, GlyphBBox> bboxes = {};
  final Map<String, Map<String, Offset>> anchors = {};
  final Map<String, double> advanceWidths = {};

  int get glyphCount => bboxes.length;
}

// ============================================================================
// 2. SERVICE PRINCIPAL
// ============================================================================

class SmuflMetrics {
  SmuflMetrics._();

  static final _FontData _leland = _FontData();
  static final _FontData _bravura = _FontData();
  static final Set<String> _missingLogged = {};

  static bool _loaded = false;
  static bool get isLoaded => _loaded;
  static int get lelandCount => _leland.glyphCount;
  static int get bravuraCount => _bravura.glyphCount;

  // ==========================================================================
  // CHARGEMENT
  // ==========================================================================

  static Future<void> load({
    String lelandPath = 'assets/fonts/Leland.json',
    String bravuraPath = 'assets/fonts/Bravura.json',
  }) async {
    if (_loaded) return;

    final lelandOk = await _loadFont(_leland, lelandPath, 'Leland');
    if (!lelandOk) {
      throw StateError(
        '[SmuflMetrics] Leland.json requis mais introuvable/invalide.',
      );
    }
    // Bravura optionnel : si absent, on logue et continue avec Leland seul.
    await _loadFont(_bravura, bravuraPath, 'Bravura');

    _loaded = true;
    // ignore: avoid_print
    print('[SmuflMetrics] chargés : Leland=${_leland.glyphCount} bboxes, '
        'Bravura=${_bravura.glyphCount} bboxes');
  }

  static Future<bool> _loadFont(
    _FontData target,
    String assetPath,
    String label,
  ) async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      // ignore: avoid_print
      print('[SmuflMetrics] $label absent ($assetPath) : $e');
      return false;
    }

    final dynamic decoded = json.decode(raw);
    if (decoded is! Map) {
      // ignore: avoid_print
      print('[SmuflMetrics] $label : JSON non-objet.');
      return false;
    }

    // ─── 1. BBoxes (clé "glyphBBoxes") ──────────────────────────────────
    final bBoxes = decoded['glyphBBoxes'];
    if (bBoxes is Map) {
      bBoxes.forEach((name, v) {
        if (v is! Map) return;
        final ne = v['bBoxNE'];
        final sw = v['bBoxSW'];
        if (ne is! List || sw is! List || ne.length < 2 || sw.length < 2) {
          return;
        }
        target.bboxes[name as String] = GlyphBBox(
          ne: Offset((ne[0] as num).toDouble(), (ne[1] as num).toDouble()),
          sw: Offset((sw[0] as num).toDouble(), (sw[1] as num).toDouble()),
        );
      });
    } else {
      // ignore: avoid_print
      print('[SmuflMetrics] $label : "glyphBBoxes" absent.');
    }

    // ─── 2. Anchors (clé "glyphsWithAnchors") ──────────────────────────
    final glyphAnchors = decoded['glyphsWithAnchors'];
    if (glyphAnchors is Map) {
      glyphAnchors.forEach((name, v) {
        if (v is! Map) return;
        final map = <String, Offset>{};
        v.forEach((anchorName, coords) {
          if (coords is! List || coords.length < 2) return;
          map[anchorName as String] = Offset(
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
          );
        });
        if (map.isNotEmpty) target.anchors[name as String] = map;
      });
    } else {
      // ignore: avoid_print
      print('[SmuflMetrics] $label : "glyphsWithAnchors" absent.');
    }

    // ─── 3. Advance widths (clé "glyphAdvanceWidths") ──────────────────
    final widths = decoded['glyphAdvanceWidths'];
    if (widths is Map) {
      widths.forEach((name, v) {
        if (v is num) target.advanceWidths[name as String] = v.toDouble();
      });
    }

    // ignore: avoid_print
    print('[SmuflMetrics] $label : ${target.bboxes.length} bboxes, '
        '${target.anchors.length} anchors, '
        '${target.advanceWidths.length} advanceWidths.');
    return true;
  }

  // ==========================================================================
  // LOOKUPS
  // ==========================================================================

  static bool hasBBox(String name) =>
      _leland.bboxes.containsKey(name) || _bravura.bboxes.containsKey(name);

  static bool hasAnchor(String name, String anchorName) =>
      _leland.anchors[name]?.containsKey(anchorName) == true ||
      _bravura.anchors[name]?.containsKey(anchorName) == true;

  /// BBox en `em`. Retourne [GlyphBBox.zero] si absent.
  static GlyphBBox bbox(String name) {
    final l = _leland.bboxes[name];
    if (l != null) return l;
    final b = _bravura.bboxes[name];
    if (b != null) return b;
    _warnMissing('bbox', name);
    return GlyphBBox.zero;
  }

  /// Ancre `anchorName` pour [name] en `em` (y positif = UP SMuFL).
  static Offset? anchor(String name, String anchorName) {
    final l = _leland.anchors[name]?[anchorName];
    if (l != null) return l;
    final b = _bravura.anchors[name]?[anchorName];
    if (b != null) return b;
    _warnMissing('anchor', '$name.$anchorName');
    return null;
  }

  /// Advance width en `em`. Fallback silencieux sur bbox.width.
  static double advanceWidth(String name) {
    final l = _leland.advanceWidths[name];
    if (l != null) return l;
    final b = _bravura.advanceWidths[name];
    if (b != null) return b;
    final w = bbox(name).width;
    if (w == 0) _warnMissing('advanceWidth', name);
    return w;
  }

  // ==========================================================================
  // CONVERSIONS em → px / sp
  // ==========================================================================

  /// em → pixels pour un fontSize donné.
  static double pxFor(double em, double fontSize) => em * fontSize;

  /// em → "sp" (multiples de staffLineSpacing).
  /// `sp = em * fontSize / staffLineSpacing`.
  static double spFor(double em, double fontSize, double staffLineSpacing) =>
      (em * fontSize) / staffLineSpacing;

  // ==========================================================================
  // DIAGNOSTIC
  // ==========================================================================

  static void _warnMissing(String kind, String name) {
    final key = '$kind:$name';
    if (_missingLogged.contains(key)) return;
    _missingLogged.add(key);
    // ignore: avoid_print
    print('[SmuflMetrics] $kind manquant : $name');
  }

  static void reset() {
    _leland.bboxes.clear();
    _leland.anchors.clear();
    _leland.advanceWidths.clear();
    _bravura.bboxes.clear();
    _bravura.anchors.clear();
    _bravura.advanceWidths.clear();
    _missingLogged.clear();
    _loaded = false;
  }
}