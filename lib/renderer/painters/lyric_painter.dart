// lib/renderer/painters/lyric_painter.dart
// ============================================================================
// PEINTRE DES PAROLES (LYRICS) — v2c-108
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/events/music_event.dart';
import '../../models/events/lyric.dart';
import '../../models/layout/layout_models.dart';

class LyricPainter {
  final double lineSpacing;
  final Color color;
  final double fontSize;

  LyricPainter({
    required this.lineSpacing,
    this.color = Colors.black,
    double? fontSize,
  }) : fontSize = fontSize ?? lineSpacing * 1.8;

  // ==========================================================================
  // POINT D'ENTRÉE
  // ==========================================================================

  void drawLyrics({
    required Canvas canvas,
    required List<LayoutedNote> notes,
    required List<Map<String, double>> notePositions,
    required double staffTopY,
    required double belowStartY,
  }) {
    final Map<int, double> yByVerseBelow = {};
    final Map<int, double> yByVerseAbove = {};

    // Espacement vertical entre deux versets (2.8 sp).
    final double verseSpacing = lineSpacing * 2.8;

    for (int j = 0; j < notes.length; j++) {
      final note = notes[j];
      if (note.isRest) continue;
      
      // ═══════════════════════════════════════════════════════════════════
      // v2c-108 : On ignore les notes secondaires de l'accord pour éviter 
      // que les paroles ne se dessinent plusieurs fois l'une sur l'autre.
      // ═══════════════════════════════════════════════════════════════════
      if (note.isChordMember) continue; 

      if (note.event is! NoteEvent) continue;

      final ne = note.event as NoteEvent;
      if (!ne.printLyric) continue;

      final effectiveLyrics = note.effectiveLyrics;
      if (effectiveLyrics.isEmpty) continue;

      for (final lyric in effectiveLyrics) {
        final isAbove = lyric.isAbove;
        final verse = lyric.number;

        double y;
        if (isAbove) {
          y = yByVerseAbove.putIfAbsent(
            verse,
            () => staffTopY - lineSpacing * 2.0 - (verse - 1) * verseSpacing,
          );
        } else {
          y = yByVerseBelow.putIfAbsent(
            verse,
            () => belowStartY + (verse - 1) * verseSpacing,
          );
        }

        final xPx = notePositions[j]['x']!;
        
        // --- DESSIN DU TEXTE ---
        final textPainter = _layoutText(lyric.fullText);
        
        // v2c-97 : ALIGNEMENT DYNAMIQUE (W3C MusicXML)
        double drawX;
        double textRightX;

        final bool alignLeft = lyric.justify == 'left' || 
            (lyric.extend && lyric.justify == null); // Mélisme auto-left

        if (alignLeft) {
          // Aligné à gauche : le texte commence à la note.
          drawX = xPx; 
          textRightX = drawX + textPainter.width;
        } else if (lyric.justify == 'right') {
          // Aligné à droite : le texte finit à la note.
          drawX = xPx - textPainter.width;
          textRightX = xPx;
        } else {
          // Par défaut : centré.
          drawX = xPx - textPainter.width / 2;
          textRightX = xPx + textPainter.width / 2;
        }

        textPainter.paint(
          canvas,
          Offset(drawX, y - textPainter.height / 2),
        );

        // --- DESSIN DES TRAITS (Hyphen / Melisma) ---
        _drawSyllabicLines(
          canvas: canvas,
          notes: notes,
          notePositions: notePositions,
          currentIndex: j,
          lyric: lyric,
          yCenter: y,
          textRightX: textRightX,
          isAbove: isAbove,
        );
      }
    }
  }

  // ==========================================================================
  // DESSIN DES TRAITS (CESURE & MELISMA)
  // ==========================================================================

  void _drawSyllabicLines({
    required Canvas canvas,
    required List<LayoutedNote> notes,
    required List<Map<String, double>> notePositions,
    required int currentIndex,
    required Lyric lyric,
    required double yCenter,
    required double textRightX,
    required bool isAbove,
  }) {
    final bool needsHyphen = lyric.isBegin || lyric.syllabic == 'middle';
    final bool needsMelisma = lyric.extend;

    if (!needsHyphen && !needsMelisma) return;

    // Chercher la prochaine note (en ignorant les notes d'accords)
    int? nextNoteIndex;
    for (int i = currentIndex + 1; i < notes.length; i++) {
      if (!notes[i].isRest && !notes[i].isChordMember) {
        nextNoteIndex = i;
        break;
      }
    }

    if (nextNoteIndex == null) return;

    final double nextX = notePositions[nextNoteIndex]['x']!;

    // Point de départ du trait (bord droit du texte + petite marge)
    final double startX = textRightX + lineSpacing * 0.3;
    // Point d'arrivée du trait (centre de la note suivante - marge)
    final double endX = nextX - lineSpacing * 0.5;

    if (endX <= startX) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (needsHyphen) {
      // Césure : petit tiret au milieu de l'espace
      final double midX = (startX + endX) / 2;
      final double hyphenWidth = lineSpacing * 0.8;
      canvas.drawLine(
        Offset(midX - hyphenWidth / 2, yCenter),
        Offset(midX + hyphenWidth / 2, yCenter),
        paint,
      );
    } else if (needsMelisma) {
      // Mélisme : trait continu
      canvas.drawLine(
        Offset(startX, yCenter),
        Offset(endX, yCenter),
        paint,
      );
    }
  }

  // ==========================================================================
  // HELPER TEXTE
  // ==========================================================================

  TextPainter _layoutText(String text) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'LelandText',
          // Le fallback vers Arial permet aux tests golden de trouver les lettres.
          fontFamilyFallback: const ['Arial', 'Roboto', 'sans-serif'],
          fontSize: fontSize,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}