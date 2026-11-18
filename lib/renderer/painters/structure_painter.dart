// lib/renderer/painters/structure_painter.dart
// ============================================================================
// PAINTEUR DES ÉLÉMENTS STRUCTURELS — v2c-93z
// ============================================================================
// v2c-69  : glyphes SMuFL pour clefs octaviées (table W3C SMuFL 1.4).
// v2c-70  : key signatures extrêmes (fifths ±11 avec doubles).
// v2c-70c : convention LilyPond/W3C — groupé par niveau.
// v2c-70e : compensation optique.
// v2c-74  : key signatures non traditionnelles (key-step/key-alter/key-octave).
// v2c-75  : support des altérations microtonales fractionnaires (Stein).
// v2c-93  : passage à Smufl.glyph() + MusicTextStyle (fallback Bravura).
//           Plus de codepoints hardcodés dans ce fichier.
// v2c-93z : smuflTimeSig() locale SUPPRIMÉE → centralisée dans
//           Smufl.timeSignatureNumber() (source unique, plus de duplication
//           avec NotePainter.smuflTimeSig — qui a aussi été supprimée).
// ============================================================================

import 'package:flutter/material.dart';

import '../../models/enums/music_enums.dart';
import '../../models/score/measure.dart';
import '../../models/score/page_layout.dart';
import '../../services/smufl/smufl.dart';
import '../../utils/music_text_style.dart';

class StructurePainter {
  final double scale;
  final double staffLineSpacing;
  final TextStyle clefStyle;
  final TextStyle timeSigStyle;
  final Paint linePaint;

  StructurePainter({
    required this.scale,
    required this.staffLineSpacing,
    required this.clefStyle,
    required this.timeSigStyle,
    required this.linePaint,
  });

  // ==========================================================================
  // v2c-93 : HELPERS DE RÉSOLUTION SMuFL
  // ==========================================================================

  /// Clef → nom SMuFL officiel.
  static String? _clefName(ClefType clef) {
    switch (clef) {
      case ClefType.treble:        return 'gClef';
      case ClefType.treble8vb:     return 'gClef8vb';
      case ClefType.treble8va:     return 'gClef8va';
      case ClefType.treble15ma:    return 'gClef15ma';
      case ClefType.treble15mb:    return 'gClef15mb';
      case ClefType.frenchViolin:  return 'gClef';
      case ClefType.soprano:
      case ClefType.mezzoSoprano:
      case ClefType.alto:
      case ClefType.tenor:
      case ClefType.baritoneUt:    return 'cClef';
      case ClefType.bass:          return 'fClef';
      case ClefType.bass8vb:       return 'fClef8vb';
      case ClefType.bass8va:       return 'fClef8va';
      case ClefType.bass15mb:      return 'fClef15mb';
      case ClefType.baritoneFa:
      case ClefType.subbass:       return 'fClef';
      case ClefType.percussion:    return 'unpitchedPercussionClef1';
      case ClefType.tab:           return '6stringTabClef';
      case ClefType.none:          return null;
    }
  }

  /// Altération (niveau 1/2/3) → nom SMuFL.
  static String _keyGlyphName(bool isSharp, int level) {
    if (isSharp) {
      switch (level) {
        case 1: return 'accidentalSharp';
        case 2: return 'accidentalSharpSharp';
        case 3: return 'accidentalTripleSharp';
        default: return 'accidentalSharp';
      }
    } else {
      switch (level) {
        case 1: return 'accidentalFlat';
        case 2: return 'accidentalDoubleFlat';
        case 3: return 'accidentalTripleFlat';
        default: return 'accidentalFlat';
      }
    }
  }

  /// Valeur alter fractionnaire → nom SMuFL.
  static String? _glyphNameForAlterValue(double alter) {
    if (alter == -2.0) return 'accidentalDoubleFlat';
    if (alter == -1.5) return 'accidentalThreeQuarterTonesFlatZimmermann';
    if (alter == -1.0) return 'accidentalFlat';
    if (alter == -0.5) return 'accidentalQuarterToneFlatStein';
    if (alter ==  0.0) return 'accidentalNatural';
    if (alter ==  0.5) return 'accidentalQuarterToneSharpStein';
    if (alter ==  1.0) return 'accidentalSharp';
    if (alter ==  1.5) return 'accidentalThreeQuarterTonesSharpStein';
    if (alter ==  2.0) return 'accidentalSharpSharp';
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // v2c-93z : la méthode locale `smuflTimeSig()` a été SUPPRIMÉE.
  // Elle est désormais centralisée dans `Smufl.timeSignatureNumber()`.
  //
  // AVANT : deux copies identiques existaient dans NotePainter et
  //         StructurePainter (risque de désynchronisation si on modifiait
  //         la logique dans l'un sans l'autre).
  // APRÈS : source unique de vérité dans Smufl.
  // ══════════════════════════════════════════════════════════════════════════

  // ==========================================================================
  // 1. LIGNES DE PORTÉE
  // ==========================================================================

  /// Dessine les lignes d'une portée.
  ///
  /// [lineCount]   : nombre de lignes (défaut = 5 = standard).
  /// [hiddenLines] : lignes à NE PAS dessiner.
  ///                 Numérotation MusicXML : 1 = ligne du BAS.
  void drawStaffLines(
    Canvas canvas,
    double x,
    double width,
    double staffBaseY, {
    int lineCount = 5,
    Set<int> hiddenLines = const {},
  }) {
    for (int line = 0; line < lineCount; line++) {
      final int musicXmlLine = lineCount - line;
      if (hiddenLines.contains(musicXmlLine)) continue;

      final y = staffBaseY + line * staffLineSpacing;
      canvas.drawLine(Offset(x, y), Offset(x + width, y), linePaint);
    }
  }

  // ==========================================================================
  // 2. CLEFS
  // ==========================================================================

  void drawClef(Canvas canvas, ClefType clef, double x, double staffBaseY) {
    if (clef == ClefType.none) return;

    final String? glyphName = _clefName(clef);
    if (glyphName == null) return;

    final clefPainter = TextPainter(
      text: TextSpan(
        text: Smufl.glyph(glyphName),
        style: clefStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double yOffset = _clefYOffset(clef);
    final double clefY = staffBaseY + yOffset - clefPainter.height / 2;
    clefPainter.paint(canvas, Offset(x, clefY));
  }

  double _clefYOffset(ClefType clef) {
    switch (clef) {
      case ClefType.treble:
      case ClefType.treble8vb:
      case ClefType.treble8va:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return 3.0 * staffLineSpacing;
      case ClefType.frenchViolin:
        return 4.0 * staffLineSpacing;
      case ClefType.soprano:
        return 4.0 * staffLineSpacing;
      case ClefType.mezzoSoprano:
        return 3.0 * staffLineSpacing;
      case ClefType.alto:
        return 2.0 * staffLineSpacing;
      case ClefType.tenor:
        return 1.0 * staffLineSpacing;
      case ClefType.baritoneUt:
        return 0.0 * staffLineSpacing;
      case ClefType.bass:
      case ClefType.bass8vb:
      case ClefType.bass8va:
      case ClefType.bass15mb:
        return 1.0 * staffLineSpacing;
      case ClefType.baritoneFa:
        return 2.0 * staffLineSpacing;
      case ClefType.subbass:
        return 0.0 * staffLineSpacing;
      case ClefType.percussion:
      case ClefType.tab:
      case ClefType.none:
        return 2.0 * staffLineSpacing;
    }
  }

  // ==========================================================================
  // 3. ARMURES
  // ==========================================================================

  void drawKeySignature(
    Canvas canvas,
    double x,
    double staffBaseY,
    KeySignature keySig,
    ClefType clef,
  ) {
    // v2c-74 : custom key signature
    if (keySig.customAlterations != null &&
        keySig.customAlterations!.isNotEmpty) {
      _drawCustomKeySignature(
        canvas, keySig.customAlterations!, x, staffBaseY, clef);
      return;
    }

    final int fifths = keySig.fifths;
    if (fifths == 0) return;

    final double keySize = staffLineSpacing * 3.4;
    final TextStyle keyStyle = MusicTextStyle.music(
      fontSize: keySize,
      color: Colors.black,
    );

    final List<double> sharpYOffsetsTreble = [0.0, 1.5, -0.5, 1.0, 2.5, 0.5, 2.0];
    final List<double> flatYOffsetsTreble  = [2.0, 0.5, 2.5, 1.0, 3.0, 1.5, 3.5];
    final List<double> sharpYOffsetsBass   = [1.0, 2.5, 4.0, 2.0, 0.0, 1.5, 3.0];
    final List<double> flatYOffsetsBass    = [3.0, 1.5, 3.5, 2.0, 4.0, 2.5, 1.0];

    final bool isTreble = (clef == ClefType.treble ||
        clef == ClefType.treble8vb ||
        clef == ClefType.treble8va);
    final bool isSharp = fifths > 0;
    final List<double> offsets = isSharp
        ? (isTreble ? sharpYOffsetsTreble : sharpYOffsetsBass)
        : (isTreble ? flatYOffsetsTreble : flatYOffsetsBass);

    final int absFifths = fifths.abs();

    double currentX = x;

    // v2c-70c : GROUPEMENT PAR NIVEAU
    for (int level = 1; level <= 4; level++) {
      for (int i = 0; i < 7; i++) {
        final int relativeFifths = absFifths - i;
        if (relativeFifths <= 0) break;

        final int thisLevel = ((relativeFifths - 1) ~/ 7) + 1;
        if (thisLevel != level) continue;

        final String glyphName = _keyGlyphName(isSharp, level);

        final painter = TextPainter(
          text: TextSpan(
            text: Smufl.glyph(glyphName),
            style: keyStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // v2c-70e : compensation optique
        final double opticalOffset =
            isSharp ? staffLineSpacing * 0.15 : staffLineSpacing * 0.21;

        final double y =
            staffBaseY + (offsets[i] * staffLineSpacing) - painter.height / 2 +
            opticalOffset;
        painter.paint(canvas, Offset(currentX, y));

        final double advance;
        switch (level) {
          case 1: advance = staffLineSpacing * 1.45; break;
          case 2: advance = staffLineSpacing * 1.85; break;
          case 3: advance = staffLineSpacing * 2.20; break;
          default: advance = staffLineSpacing * 2.5;
        }
        currentX += advance;
      }
    }
  }

  // ==========================================================================
  // 3bis. ARMURE — ANNULATION
  // ==========================================================================

  /// v2c-76 : dessine les bécarres d'annulation d'une armure précédente.
  double drawKeyCancel(
    Canvas canvas,
    double x,
    double staffBaseY,
    KeyCancel cancel,
    ClefType clef,
  ) {
    final int displayCount = cancel.count;
    if (displayCount == 0) return 0.0;

    final double keySize = staffLineSpacing * 3.4;
    final TextStyle keyStyle = MusicTextStyle.music(
      fontSize: keySize,
      color: Colors.black,
    );

    final List<double> sharpYOffsetsTreble =
        [0.0, 1.5, -0.5, 1.0, 2.5, 0.5, 2.0];
    final List<double> flatYOffsetsTreble =
        [2.0, 0.5, 2.5, 1.0, 3.0, 1.5, 3.5];
    final List<double> sharpYOffsetsBass =
        [1.0, 2.5, 4.0, 2.0, 0.0, 1.5, 3.0];
    final List<double> flatYOffsetsBass =
        [3.0, 1.5, 3.5, 2.0, 4.0, 2.5, 1.0];

    final bool isTreble = (clef == ClefType.treble ||
        clef == ClefType.treble8vb ||
        clef == ClefType.treble8va);
    final bool isSharp = cancel.cancelsSharps;

    final List<double> offsets = isSharp
        ? (isTreble ? sharpYOffsetsTreble : sharpYOffsetsBass)
        : (isTreble ? flatYOffsetsTreble : flatYOffsetsBass);

    final String naturalGlyph = Smufl.glyph('accidentalNatural');

    double currentX = x;
    for (int i = 0; i < displayCount && i < offsets.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: naturalGlyph, style: keyStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final double opticalOffset = staffLineSpacing * 0.15;
      final double y =
          staffBaseY + offsets[i] * staffLineSpacing - painter.height / 2 +
          opticalOffset;
      painter.paint(canvas, Offset(currentX, y));

      currentX += staffLineSpacing * 1.45;
    }

    return currentX - x;
  }

  /// v2c-76 : largeur réservée pour une annulation.
  double keyCancelWidth(KeyCancel cancel) {
    return cancel.count * staffLineSpacing * 1.45;
  }

  /// v2c-74 : dessine une key sig non traditionnelle.
  /// v2c-75 : supporte les altérations fractionnaires.
  void _drawCustomKeySignature(
    Canvas canvas,
    List<KeyAlteration> alterations,
    double x,
    double staffBaseY,
    ClefType clef,
  ) {
    final double keySize = staffLineSpacing * 3.4;
    final TextStyle keyStyle = MusicTextStyle.music(
      fontSize: keySize,
      color: Colors.black,
    );

    final bool isTreble = (clef == ClefType.treble ||
        clef == ClefType.treble8vb ||
        clef == ClefType.treble8va);

    double currentX = x;
    for (final alt in alterations) {
      final double yLine = _yLineForAlteration(alt, isTreble);

      final String? glyphName = _glyphNameForAlterValue(alt.alter);
      if (glyphName == null) continue;

      final painter = TextPainter(
        text: TextSpan(
          text: Smufl.glyph(glyphName),
          style: keyStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double opticalOffset =
          alt.alter >= 0 ? staffLineSpacing * 0.15 : staffLineSpacing * 0.21;

      final double y = staffBaseY + yLine * staffLineSpacing;
      painter.paint(
        canvas,
        Offset(currentX, y - painter.height / 2 + opticalOffset),
      );

      currentX += staffLineSpacing * 1.45;
    }
  }

  /// Retourne la yLine où dessiner une altération custom.
  double _yLineForAlteration(KeyAlteration alt, bool isTreble) {
    if (alt.octave != null) {
      final double c4Line = isTreble ? 5.0 : -1.0;
      final int letterIdx = _letterToDiatonic(alt.step);
      final int diatonic = alt.octave! * 7 + letterIdx - 28;
      return c4Line - diatonic * 0.5;
    }

    final List<NoteLetter> order = alt.alter >= 0
        ? const [NoteLetter.F, NoteLetter.C, NoteLetter.G, NoteLetter.D,
                 NoteLetter.A, NoteLetter.E, NoteLetter.B]
        : const [NoteLetter.B, NoteLetter.E, NoteLetter.A, NoteLetter.D,
                 NoteLetter.G, NoteLetter.C, NoteLetter.F];
    final int idx = order.indexOf(alt.step);

    final List<double> offsets;
    if (isTreble) {
      offsets = alt.alter >= 0
          ? const [0.0, 1.5, -0.5, 1.0, 2.5, 0.5, 2.0]
          : const [2.0, 0.5, 2.5, 1.0, 3.0, 1.5, 3.5];
    } else {
      offsets = alt.alter >= 0
          ? const [1.0, 2.5, 4.0, 2.0, 0.0, 1.5, 3.0]
          : const [3.0, 1.5, 3.5, 2.0, 4.0, 2.5, 1.0];
    }

    if (idx < 0 || idx >= offsets.length) return 2.0;
    return offsets[idx];
  }

  static int _letterToDiatonic(NoteLetter l) {
    switch (l) {
      case NoteLetter.C: return 0;
      case NoteLetter.D: return 1;
      case NoteLetter.E: return 2;
      case NoteLetter.F: return 3;
      case NoteLetter.G: return 4;
      case NoteLetter.A: return 5;
      case NoteLetter.B: return 6;
    }
  }

  // ==========================================================================
  // 4. CHIFFRAGES
  // ==========================================================================

  void drawTimeSignature(
    Canvas canvas,
    int beats,
    int beatType,
    double x,
    double staffBaseY, {
    List<int>? beatGroups,
    List<TimeFraction>? fractions,
    bool singleNumber = false,
    InterchangeableTimeSignature? interchangeable,
  }) {
    if (interchangeable != null) {
      _drawInterchangeable(
        canvas,
        beats, beatType, x, staffBaseY,
        beatGroups: beatGroups,
        fractions: fractions,
        singleNumber: singleNumber,
        alt: interchangeable,
      );
      return;
    }

    _drawTimeSignatureBody(
      canvas,
      beats, beatType, x, staffBaseY,
      beatGroups: beatGroups,
      fractions: fractions,
      singleNumber: singleNumber,
    );
  }

  double _drawTimeSignatureBody(
    Canvas canvas,
    int beats,
    int beatType,
    double x,
    double staffBaseY, {
    List<int>? beatGroups,
    List<TimeFraction>? fractions,
    bool singleNumber = false,
  }) {
    if (fractions != null && fractions.length > 1) {
      return _drawFractionComposite(
        canvas, fractions, x, staffBaseY,
        singleNumber: singleNumber,
      );
    }

    final digitStyle = timeSigStyle.copyWith(
      fontSize: staffLineSpacing * 3.8,
      fontWeight: FontWeight.normal,
    );

    final bool composite = beatGroups != null && beatGroups.length > 1;
    // ═══ v2c-93z : appel centralisé via Smufl.timeSignatureNumber() ═══
    final String topText = composite
        ? beatGroups.map(Smufl.timeSignatureNumber).join(Smufl.glyph('timeSigPlus'))
        : Smufl.timeSignatureNumber(beats);

    final topPainter = TextPainter(
      text: TextSpan(text: topText, style: digitStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    if (singleNumber) {
      final double centerY = staffBaseY + 2.0 * staffLineSpacing;
      topPainter.paint(canvas, Offset(x, centerY - topPainter.height / 2));
      return topPainter.width;
    }

    // ═══ v2c-93z : appel centralisé ═══
    final bottomPainter = TextPainter(
      text: TextSpan(text: Smufl.timeSignatureNumber(beatType), style: digitStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final double groupWidth = topPainter.width > bottomPainter.width
        ? topPainter.width
        : bottomPainter.width;

    final double topX = x + (groupWidth - topPainter.width) / 2;
    final double bottomX = x + (groupWidth - bottomPainter.width) / 2;

    final double topY =
        staffBaseY + 0.9 * staffLineSpacing - topPainter.height / 2;
    final double bottomY =
        staffBaseY + 3.1 * staffLineSpacing - bottomPainter.height / 2;

    topPainter.paint(canvas, Offset(topX, topY));
    bottomPainter.paint(canvas, Offset(bottomX, bottomY));

    return groupWidth;
  }

  void _drawInterchangeable(
    Canvas canvas,
    int beats,
    int beatType,
    double x,
    double staffBaseY, {
    List<int>? beatGroups,
    List<TimeFraction>? fractions,
    bool singleNumber = false,
    required InterchangeableTimeSignature alt,
  }) {
    final relation = alt.relation ?? 'space';

    String openGlyph = '';
    String closeGlyph = '';
    double gapBefore = 6.0;

    switch (relation) {
      case 'parentheses':
        openGlyph = '(';
        closeGlyph = ')';
        break;
      case 'bracket':
        openGlyph = '[';
        closeGlyph = ']';
        break;
      case 'equals':
        openGlyph = '=';
        break;
      case 'hyphen':
        openGlyph = '–';
        break;
      case 'slash':
        openGlyph = '/';
        break;
      case 'space':
        gapBefore = 14.0;
        break;
    }

    double curX = x;

    final mainW = _drawTimeSignatureBody(
      canvas, beats, beatType, curX, staffBaseY,
      beatGroups: beatGroups,
      fractions: fractions,
      singleNumber: singleNumber,
    );
    curX += mainW + gapBefore;

    if (openGlyph.isNotEmpty) {
      curX += _drawSeparator(
        canvas, openGlyph, curX, staffBaseY,
        tall: relation == 'parentheses' || relation == 'bracket',
      );
      curX += 1.5;
    }

    final altW = _drawTimeSignatureBody(
      canvas, alt.beats, alt.beatType, curX, staffBaseY,
      fractions: alt.fractions,
    );
    curX += altW;

    if (closeGlyph.isNotEmpty) {
      curX += 1.5;
      _drawSeparator(
        canvas, closeGlyph, curX, staffBaseY,
        tall: relation == 'parentheses' || relation == 'bracket',
      );
    }
  }

  double _drawSeparator(
    Canvas canvas,
    String glyph,
    double x,
    double staffBaseY, {
    bool tall = false,
  }) {
    final double tallFontSize   = staffLineSpacing * 5.5;
    final double normalFontSize = staffLineSpacing * 3.0;

    final fontSize = tall ? tallFontSize : normalFontSize;

    // v2c-93 : séparateurs (parenthèses, crochets) → police texte,
    // pas SMuFL. On garde le fontFamily par défaut.
    final style = TextStyle(
      fontFamily: null,
      fontSize: fontSize,
      color: Colors.black,
    );

    final painter = TextPainter(
      text: TextSpan(text: glyph, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final centerY = staffBaseY + 2.0 * staffLineSpacing;
    painter.paint(canvas, Offset(x, centerY - painter.height / 2));

    return painter.width;
  }

  void drawSenzaMisuraText(
    Canvas canvas,
    String text,
    double x,
    double staffBaseY,
  ) {
    // v2c-93 : texte libre → police texte (LelandText).
    final style = TextStyle(
      fontFamily: 'LelandText',
      fontSize: staffLineSpacing * 3.0,
      color: Colors.black,
      fontStyle: FontStyle.italic,
    );

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final centerY = staffBaseY + 2.0 * staffLineSpacing;
    painter.paint(canvas, Offset(x, centerY - painter.height / 2));
  }

  double _drawFractionComposite(
    Canvas canvas,
    List<TimeFraction> fractions,
    double x,
    double staffBaseY, {
    bool singleNumber = false,
  }) {
    final double fracFontSize = staffLineSpacing * 3.2;

    final digitStyle = timeSigStyle.copyWith(
      fontSize: fracFontSize,
      fontWeight: FontWeight.normal,
      height: 1.0,
    );

    final String plusGlyph = Smufl.glyph('timeSigPlus');

    final List<TextPainter> numPainters = [];
    final List<TextPainter> denPainters = [];
    final List<TextPainter> plusPainters = [];

    for (final f in fractions) {
      // ═══ v2c-93z : appels centralisés ═══
      final String numText = f.isCompositeNumerator
          ? f.subGroups!.map(Smufl.timeSignatureNumber).join(plusGlyph)
          : Smufl.timeSignatureNumber(f.numerator);

      numPainters.add(TextPainter(
        text: TextSpan(text: numText, style: digitStyle),
        textDirection: TextDirection.ltr,
      )..layout());
      // ═══ v2c-93z : appel centralisé ═══
      denPainters.add(TextPainter(
        text: TextSpan(text: Smufl.timeSignatureNumber(f.denominator), style: digitStyle),
        textDirection: TextDirection.ltr,
      )..layout());
    }

    for (int i = 0; i < fractions.length - 1; i++) {
      plusPainters.add(TextPainter(
        text: TextSpan(text: plusGlyph, style: digitStyle),
        textDirection: TextDirection.ltr,
      )..layout());
    }

    final double numeratorCenterY = singleNumber
        ? staffBaseY + 2.0 * staffLineSpacing
        : staffBaseY + 0.9 * staffLineSpacing;
    final double plusCenterY = staffBaseY + 2.0 * staffLineSpacing;
    final double denominatorCenterY = staffBaseY + 3.1 * staffLineSpacing;

    final double startX = x;
    double curX = x;

    for (int i = 0; i < fractions.length; i++) {
      final double numW = numPainters[i].width;
      final double denW = singleNumber ? 0.0 : denPainters[i].width;
      final double fracW = numW > denW ? numW : denW;

      final double numX = curX + (fracW - numW) / 2;
      final double denX = curX + (fracW - denW) / 2;

      numPainters[i].paint(
        canvas,
        Offset(numX, numeratorCenterY - numPainters[i].height / 2),
      );

      if (!singleNumber) {
        denPainters[i].paint(
          canvas,
          Offset(denX, denominatorCenterY - denPainters[i].height / 2),
        );
      }

      curX += fracW;

      if (i < fractions.length - 1) {
        const double plusPadding = 2.0;
        curX += plusPadding;

        final plusP = plusPainters[i];
        plusP.paint(
          canvas,
          Offset(curX, plusCenterY - plusP.height / 2),
        );
        curX += plusP.width;
        curX += plusPadding;
      }
    }

    return curX - startX;
  }

  void drawTimeSignatureSymbol(
    Canvas canvas,
    String symbol,
    double x,
    double staffBaseY,
  ) {
    final String glyphName =
        (symbol == 'cut') ? 'timeSigCutCommon' : 'timeSigCommon';

    final symbolStyle = timeSigStyle.copyWith(
      fontSize: staffLineSpacing * 4.2,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: Smufl.glyph(glyphName),
        style: symbolStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double y = staffBaseY + 2.0 * staffLineSpacing - painter.height / 2;
    painter.paint(canvas, Offset(x, y));
  }

  // ==========================================================================
  // 5. BARRES
  // ==========================================================================

  void drawBarline(Canvas canvas, double x, double staffBaseY) {
    canvas.drawLine(
      Offset(x, staffBaseY),
      Offset(x, staffBaseY + 4 * staffLineSpacing),
      linePaint,
    );
  }

  void drawBarlineWithStyle(
    Canvas canvas,
    double x,
    double staffBaseY,
    BarlineType style,
  ) {
    drawBarline(canvas, x, staffBaseY);
  }

  // ==========================================================================
  // 6. ACCOLADES
  // ==========================================================================

  void drawBrace(Canvas canvas, double x, double topY, double bottomY) {
    final double h = bottomY - topY;
    if (h <= 0) return;

    const double bboxFactor = 0.95;
    const double yOffsetRatio = 0.12;
    const double xOffset = 0.0;

    final double targetFontSize = h * bboxFactor;

    // v2c-93 : glyphe 'brace' (U+E000) résolu via Smufl.
    final bracePainter = TextPainter(
      text: TextSpan(
        text: Smufl.glyph('brace'),
        style: MusicTextStyle.music(
          fontSize: targetFontSize,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double centerY = (topY + bottomY) / 2;
    final double braceY =
        centerY - bracePainter.height / 2 + bracePainter.height * yOffsetRatio;

    final double braceX = x - bracePainter.width + xOffset;

    bracePainter.paint(canvas, Offset(braceX, braceY));
  }

  // ==========================================================================
  // 7. CRÉDITS
  // ==========================================================================

  void drawCredits(Canvas canvas, PageLayout pageLayout) {
    for (final entry in pageLayout.credits.entries) {
      final data = entry.value;
      final text = data['text'] as String;
      final double x = data['x'] as double;
      final double y = _adjustCreditY(entry.key, data['y'] as double);
      final double fontSize = data['fontSize'] as double;
      final String justify = data['justify'] as String;

      // v2c-93 : crédits (titre, compositeur) → police TEXTE, pas SMuFL.
      final style = TextStyle(
        fontFamily: 'LelandText',
        fontSize: fontSize,
        color: Colors.black,
      );

      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      double offsetX = x;
      if (justify == 'center') {
        offsetX = x - painter.width / 2;
      } else if (justify == 'right') {
        offsetX = x - painter.width;
      }

      final String valign = data['valign'] as String? ?? 'top';
      final double baselineY = pageLayout.pageHeight - y;

      double offsetY;
      switch (valign) {
        case 'top': offsetY = baselineY; break;
        case 'bottom': offsetY = baselineY - painter.height; break;
        default: offsetY = baselineY - painter.height / 2; break;
      }

      painter.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  static double _adjustCreditY(String type, double y) => y;

  // ==========================================================================
  // 8. HEADER HELPERS
  // ==========================================================================

  static double computeHeaderBottomY(PageLayout pageLayout, double scale) {
    double headerBottom = pageLayout.marginTop;

    for (final entry in pageLayout.credits.entries) {
      final data = entry.value;
      final double y = _adjustCreditY(entry.key, data['y'] as double);
      final double fontSize = data['fontSize'] as double;

      if (y > pageLayout.pageHeight / 2) {
        double offsetY = pageLayout.pageHeight - y;
        double textHeight = fontSize * 1.5;
        double bottom = offsetY + textHeight + 10 * scale;
        if (bottom > headerBottom) headerBottom = bottom;
      }
    }

    return headerBottom + 20 * scale;
  }

  static double computeHeaderHeight(PageLayout pageLayout) {
    double maxBottom = pageLayout.marginTop;

    for (final entry in pageLayout.credits.entries) {
      final data = entry.value;
      final double y = _adjustCreditY(entry.key, data['y'] as double);
      final double fontSize = data['fontSize'] as double;

      if (y > pageLayout.pageHeight / 2) {
        final double offsetY = pageLayout.pageHeight - y;
        final double textHeight = fontSize * 1.5;
        final double bottom = offsetY + textHeight + 10;
        if (bottom > maxBottom) maxBottom = bottom;
      }
    }

    return maxBottom + 30;
  }

  // ==========================================================================
  // 9. COPIE
  // ==========================================================================

  StructurePainter copyWith({
    double? scale,
    double? staffLineSpacing,
    TextStyle? clefStyle,
    TextStyle? timeSigStyle,
    Paint? linePaint,
  }) {
    return StructurePainter(
      scale: scale ?? this.scale,
      staffLineSpacing: staffLineSpacing ?? this.staffLineSpacing,
      clefStyle: clefStyle ?? this.clefStyle,
      timeSigStyle: timeSigStyle ?? this.timeSigStyle,
      linePaint: linePaint ?? this.linePaint,
    );
  }
}