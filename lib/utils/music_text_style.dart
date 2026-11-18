// lib/utils/music_text_style.dart
// ============================================================================
// STYLE DE TEXTE MUSICAL AVEC FALLBACK SMuFL — v2c-93z
// ============================================================================
// v2c-93  : version initiale (fallback Bravura).
// v2c-93z : FIX fallback redondant — 'Leland' était listé en double
//           (fontFamily ET fontFamilyFallback[0]). Flutter ignore le
//           doublon, mais on retire pour que la liste reflète la réalité.
//           Le fallback effectif = ['Bravura'] uniquement.
// ============================================================================

import 'package:flutter/material.dart';

class MusicTextStyle {
  MusicTextStyle._();

  /// Familles de polices musicales de SECOURS uniquement.
  /// ⚠️ 'Leland' n'est PAS dans cette liste : il est déjà en `fontFamily`
  ///    principal de `music()`. Ce fallback ne sert qu'aux glyphes SMuFL
  ///    absents de Leland v0.80 (arrow, slash, triangle-down, cluster, etc.).
  static const List<String> _fallback = <String>[
    'Bravura',
  ];

  /// Construit un TextStyle musical avec fallback SMuFL.
  static TextStyle music({
    double fontSize = 24,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Leland',
      fontFamilyFallback: _fallback,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: height,
    );
  }
}