// lib/models/events/direction.dart
// ============================================================================
// ÉVÉNEMENTS DE DIRECTION — v2c-31a-29
// ============================================================================

import '../enums/music_enums.dart';

enum DirectionType {
  dynamic, words, metronome, wedge, segno,
  rehearsal, coda, symbol, dashes, bracket,
  octaveShift, pedal, scordatura,
  harpPedals, damp, stringMute, eyeglasses,
  percussion, staffDivide, principalVoice,
  accordion, image, generic,
}

class DirectionEvent {
  final DirectionType type;
  final String? dynamicName;
  final String? text;
  final String? wedgeType;
  final String placement;
  final int staffNumber;
  final int timePosition;
  final int eventIndexInVoice;
  final DurationType? beatUnit;
  final int beatUnitDots;
  final DurationType? beatUnit2;
  final int beatUnit2Dots;
  final String? perMinute;
  final bool metronomeParentheses;
  final String? enclosure;
  final String? smuflGlyphName;
  final String? subType;
  final Map<String, int>? harpPedalTunings;
  final double offset;
  final int groupId;

  final String? fontWeight;
  final String? fontStyle;

  // ─── v2c-32b : Text markup (W3C 32b) ─────────────────────────────
  /// Offset horizontal en tenths (1/10 staff space). Positif = droite.
  final double? defaultX;

  /// Position verticale en tenths, relative à la LIGNE DU HAUT de la portée.
  /// Positif = AU-DESSUS de la ligne du haut, négatif = EN DESSOUS.
  final double? defaultY;

  /// 'small' / 'medium' / 'large' / 'x-large'... ou numérique en points.
  final String? fontSize;

  /// Couleur ARGB (0xFFRRGGBB), null = couleur par défaut du painter.
  final int? colorValue;

  const DirectionEvent({
    required this.type,
    this.dynamicName,
    this.text,
    this.wedgeType,
    this.placement = 'above',
    this.staffNumber = 1,
    this.timePosition = 0,
    this.eventIndexInVoice = -1,
    this.beatUnit,
    this.beatUnitDots = 0,
    this.beatUnit2,
    this.beatUnit2Dots = 0,
    this.perMinute,
    this.metronomeParentheses = false,
    this.enclosure,
    this.smuflGlyphName,
    this.subType,
    this.harpPedalTunings,
    this.offset = 0.0,
    this.groupId = 0,
    this.fontWeight,
    this.fontStyle,
    // v2c-32b
    this.defaultX,
    this.defaultY,
    this.fontSize,
    this.colorValue,
  });

  @override
  String toString() => 'DirectionEvent($type, text: $text, group: $groupId)';
}