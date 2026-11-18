// lib/renderer/painters/direction_painter.dart
// ============================================================================
// PEINTRE DES DIRECTIONS — v2c-113-32b
// ============================================================================
// v2c-113 : DYNAMIQUES — unification avec DynamicGlyphs (source unique).
// v2c-32b : TEXT MARKUP (W3C 32b) — ajout du support de :
//   - font-size (small/medium/large/x-large... ou numérique)
//   - color (#RRGGBB → ARGB)
//   - default-x (offset horizontal en tenths, + = droite)
//   - default-y (position absolue en tenths, origine = LIGNE DU HAUT de
//                la portée, + = vers le HAUT)
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/events/direction.dart';
import '../../models/enums/music_enums.dart';
import '../../services/smufl/smufl.dart';
import '../../services/smufl/dynamic_glyphs.dart';
import '../../utils/music_text_style.dart';

class DirectionPainter {
  final double lineSpacing;
  final Color color;

  DirectionPainter({required this.lineSpacing, this.color = Colors.black});

  // ══════════════════════════════════════════════════════════════════════════
  // v2c-32b : MAPPING font-size → facteur multiplicateur de lineSpacing
  // ══════════════════════════════════════════════════════════════════════════
  // Valeurs CSS-like → multiple de lineSpacing. medium (défaut) = 2.0.
  // Un nombre brut (ex: "12") est interprété en points : 10pt = medium.
  static double _fontSizeFactor(String? fs) {
    if (fs == null || fs.isEmpty) return 2.0;
    switch (fs.toLowerCase()) {
      case 'xx-small': return 1.2;
      case 'x-small':  return 1.4;
      case 'small':    return 1.6;
      case 'medium':   return 2.0;
      case 'large':    return 2.4;
      case 'x-large':  return 2.8;
      case 'xx-large': return 3.2;
      default:
        final v = double.tryParse(fs);
        if (v == null || v <= 0) return 2.0;
        return v / 5.0; // 10pt → 2.0
    }
  }

  double drawDirections({
    required Canvas canvas,
    required List<DirectionEvent> directions,
    required double measureX,
    required double staffTopY,
    required double staffBottomY,
    // v2c-32b : vraie ligne du haut (≠ staffTopY qui inclut l'overhang)
    required double staffTopLineY,
    Map<int, double>? anchorXsByTimePosition,
    Map<int, double>? anchorXsByEventIndex,
    double? fallbackAnchorX,
    required int totalDivisions,
    required double contentWidth,
  }) {
    if (directions.isEmpty) return 0.0;

    final Map<int, List<DirectionEvent>> groups = {};
    final List<DirectionEvent> ungrouped = [];
    for (final dir in directions) {
      if (dir.groupId > 0) {
        groups.putIfAbsent(dir.groupId, () => []).add(dir);
      } else {
        ungrouped.add(dir);
      }
    }

    final List<List<DirectionEvent>> allGroups = [];
    for (final d in ungrouped) {
      allGroups.add([d]);
    }
    allGroups.addAll(groups.values);
    allGroups.sort((a, b) => a.first.timePosition.compareTo(b.first.timePosition));

    double resolveX(DirectionEvent dir) {
      final double effectiveTp = dir.timePosition + dir.offset;
      if (anchorXsByEventIndex != null &&
          anchorXsByEventIndex.isNotEmpty &&
          dir.eventIndexInVoice >= 0) {
        final exact = anchorXsByEventIndex[dir.eventIndexInVoice];
        if (exact != null) {
          if (dir.offset != 0 && totalDivisions > 0) {
            return exact + (dir.offset / totalDivisions) * contentWidth;
          }
          return exact;
        }
      }
      if (anchorXsByTimePosition != null && anchorXsByTimePosition.isNotEmpty) {
        final exact = anchorXsByTimePosition[dir.timePosition];
        if (exact != null) {
          if (dir.offset != 0 && totalDivisions > 0) {
            return exact + (dir.offset / totalDivisions) * contentWidth;
          }
          return exact;
        }
      }
      final fraction = totalDivisions > 0 ? (effectiveTp / totalDivisions) : 0.0;
      return measureX + 22.0 + fraction * contentWidth;
    }

    // Détection de collision (par niveau)
    final List<double> belowRightEdges = [];
    final List<double> aboveRightEdges = [];

    int pickLevel(List<double> rightEdges, double itemLeft, double itemRight) {
      for (int i = 0; i < rightEdges.length; i++) {
        if (itemLeft > rightEdges[i] + 5.0) {
          rightEdges[i] = itemRight;
          return i;
        }
      }
      rightEdges.add(itemRight);
      return rightEdges.length - 1;
    }

    int belowLevelsUsed = 0;
    int aboveLevelsUsed = 0;

    DirectionEvent? openWedge; double? openWedgeX;
    double? openDashesX;
    double? openBracketX;
    double? openOctaveShiftX; String openOctaveShiftText = '8';
    double? openPedalX;

    double? activeLineY;
    int? activeLineLevel;

    const double belowBaseOffsetSp = 3.0;
    const double gap = 1.0;

    for (final group in allGroups) {
      
      final first = group.first;

      print('[32b] ${first.type} "${first.text}" '
      'x=${first.defaultX} y=${first.defaultY} '
      'fs=${first.fontSize} color=${first.colorValue}');
      final below = first.placement == 'below';

      // ═══════════════════════════════════════════════════════════════════
      // v2c-32b : default-x = offset en tenths (1 tenth = 1/10 sp).
      //           Positif = droite, négatif = gauche.
      // ═══════════════════════════════════════════════════════════════════
      final double defaultXOffsetPx = first.defaultX != null
          ? (first.defaultX! / 10.0) * lineSpacing
          : 0.0;
      final baseX = resolveX(first) + defaultXOffsetPx;

      bool isLineStop = group.any((d) =>
          (d.type == DirectionType.wedge && d.wedgeType == 'stop') ||
          (d.type == DirectionType.dashes && d.subType == 'stop') ||
          (d.type == DirectionType.bracket && d.subType == 'stop') ||
          (d.type == DirectionType.octaveShift && d.subType == 'stop'));

      double totalTextWidth = 0;
      for (final dir in group) {
        if (dir.type == DirectionType.wedge ||
            dir.type == DirectionType.dashes ||
            dir.type == DirectionType.bracket ||
            dir.type == DirectionType.octaveShift) {
          continue;
        }
        final w = _measureEventWidth(dir);
        totalTextWidth += w;
        if (dir != group.last) totalTextWidth += lineSpacing * gap;
      }

      final double itemLeft = baseX - totalTextWidth / 2 - 5.0;
      final double itemRight = baseX + totalTextWidth / 2 + 5.0;

      // ═══════════════════════════════════════════════════════════════════
      // v2c-32b : default-y (tenths, origine = ligne du haut, + = vers le haut).
      // Formule : y = staffTopLineY - (defaultY / 10) * lineSpacing
      //   - defaultY = +15  → 1.5 sp AU-DESSUS de la ligne du haut
      //   - defaultY = -100 → 10 sp SOUS la ligne du haut
      // ═══════════════════════════════════════════════════════════════════
      final double? overrideY = first.defaultY != null
          ? staffTopLineY - (first.defaultY! / 10.0) * lineSpacing
          : null;

      double y;
      int level;

      if (isLineStop && activeLineY != null && activeLineLevel != null) {
        y = activeLineY;
        level = activeLineLevel;
        if (below && level < belowRightEdges.length) {
          belowRightEdges[level] = itemRight;
        } else if (!below && level < aboveRightEdges.length) {
          aboveRightEdges[level] = itemRight;
        }
      } else if (overrideY != null) {
        // v2c-32b : position explicite — pas d'auto-stacking vertical
        y = overrideY;
        level = below
            ? pickLevel(belowRightEdges, itemLeft, itemRight)
            : pickLevel(aboveRightEdges, itemLeft, itemRight);
        if (below) {
          if (level >= belowLevelsUsed) belowLevelsUsed = level + 1;
        } else {
          if (level >= aboveLevelsUsed) aboveLevelsUsed = level + 1;
        }
      } else {
        // Logique auto existante
        if (below) {
          level = pickLevel(belowRightEdges, itemLeft, itemRight);
          y = staffBottomY + lineSpacing * (belowBaseOffsetSp + level * 1.6);
          if (level >= belowLevelsUsed) belowLevelsUsed = level + 1;
        } else {
          level = pickLevel(aboveRightEdges, itemLeft, itemRight);
          y = staffTopY - lineSpacing * (3.4 + level * 1.6);
          if (level >= aboveLevelsUsed) aboveLevelsUsed = level + 1;
        }
      }

      // Hauteur max des encadrements
      double maxEnclosedHeight = 0.0;
      for (final dir in group) {
        if (dir.enclosure != null && dir.enclosure != 'none') {
          double h = lineSpacing * 3.0;
          if (dir.type == DirectionType.words && dir.text != null) {
            h = _measureText(
              dir.text!,
              fontWeight: dir.fontWeight,
              fontStyle: dir.fontStyle,
              fontSizeFactor: _fontSizeFactor(dir.fontSize),
            ).height;
          } else if (dir.type == DirectionType.rehearsal && dir.text != null) {
            h = _measureText(
              dir.text!,
              fontSizeFactor: 3.0,
              fontWeight: dir.fontWeight,
              fontStyle: dir.fontStyle,
            ).height;
          } else if (dir.type == DirectionType.dynamic) {
            h = lineSpacing * 3.8;
          }
          if (h > maxEnclosedHeight) maxEnclosedHeight = h;
        }
      }

      // v2c-32b : si position explicite, on n'ajuste PAS l'enclosure
      if (maxEnclosedHeight > 0 && overrideY == null) {
        final double padY = lineSpacing * 0.2;
        if (below) {
          final double enclosureTopY = y - maxEnclosedHeight / 2 - padY;
          final double minTopY = staffBottomY + lineSpacing * 1.5;
          if (enclosureTopY < minTopY) {
            y += (minTopY - enclosureTopY);
          }
        } else {
          final double enclosureBottomY = y + maxEnclosedHeight / 2 + padY;
          final double maxBottomY = staffTopY - lineSpacing * 1.5;
          if (enclosureBottomY > maxBottomY) {
            y -= (enclosureBottomY - maxBottomY);
          }
        }
      }

      double currentX = baseX - totalTextWidth / 2;

      String? activeEnclosure;
      double? boxStartX;
      double? boxEndX;
      double maxBoxHeight = 0.0;

      for (final dir in group) {
        double w = 0;

        double dirHeight = lineSpacing * 3.0;
        if (dir.type == DirectionType.words && dir.text != null) {
          final tp = _measureText(
            dir.text!,
            fontWeight: dir.fontWeight,
            fontStyle: dir.fontStyle,
            fontSizeFactor: _fontSizeFactor(dir.fontSize),
          );
          dirHeight = tp.height;
        } else if (dir.type == DirectionType.rehearsal && dir.text != null) {
          final tp = _measureText(
            dir.text!,
            fontSizeFactor: 3.0,
            fontWeight: dir.fontWeight,
            fontStyle: dir.fontStyle,
          );
          dirHeight = tp.height;
        } else if (dir.type == DirectionType.dynamic) {
          dirHeight = lineSpacing * 3.8;
        }

        switch (dir.type) {
          case DirectionType.dynamic:
            w = _drawDynamic(canvas, dir.dynamicName, dir.text, currentX, y);
            break;

          // ═══════════════════════════════════════════════════════════════
          // v2c-32b : WORDS avec font-size + color
          // ═══════════════════════════════════════════════════════════════
          case DirectionType.words:
            if (dir.text != null) {
              final fsFactor = _fontSizeFactor(dir.fontSize);
              final textColor = dir.colorValue != null
                  ? Color(dir.colorValue!)
                  : color;

              final textWidth = _measureText(
                dir.text!,
                fontWeight: dir.fontWeight,
                fontStyle: dir.fontStyle,
                fontSizeFactor: fsFactor,
              ).width;

              w = _drawTextWithEnclosure(
                canvas,
                dir.text!,
                currentX + textWidth / 2,
                y,
                null,
                fontWeight: dir.fontWeight,
                fontStyle: dir.fontStyle,
                fontSizeFactor: fsFactor,
                textColor: textColor,
              );
            }
            break;

          case DirectionType.rehearsal:
            if (dir.text != null) {
              w = _drawTextWithEnclosure(
                canvas,
                dir.text!,
                currentX +
                    _measureText(
                      dir.text!,
                      fontSizeFactor: 3.0,
                      fontWeight: dir.fontWeight,
                      fontStyle: dir.fontStyle,
                    ).width /
                        2,
                y,
                null,
                fontSizeFactor: 3.0,
                fontWeight: dir.fontWeight,
                fontStyle: dir.fontStyle,
              );
            }
            break;

          case DirectionType.metronome:
            if (dir.beatUnit != null) w = _drawMetronome(canvas, dir, currentX, y);
            break;

          case DirectionType.segno:
            w = _drawSymbol(canvas, 'segno', currentX, y);
            break;

          case DirectionType.coda:
          case DirectionType.symbol:
            if (dir.smuflGlyphName != null) {
              w = _drawSymbol(canvas, dir.smuflGlyphName!, currentX, y);
            }
            break;

          case DirectionType.harpPedals:
            w = _drawHarpPedals(canvas, dir, currentX, y);
            break;

          case DirectionType.damp:
            w = _drawDamp(canvas, dir, currentX, y);
            break;

          case DirectionType.eyeglasses:
            w = _drawEyeglasses(canvas, currentX, y);
            break;

          case DirectionType.stringMute:
            if (dir.text != null) {
              w = _drawTextWithEnclosure(
                canvas,
                dir.text!,
                currentX + _measureText(dir.text!).width / 2,
                y,
                null,
                italic: true,
              );
            }
            break;

          case DirectionType.percussion:
            if (dir.subType != null) {
              final text = dir.subType == 'timpani' ? 'Timp.' : dir.subType!;
              w = _drawTextWithEnclosure(
                canvas,
                text,
                currentX + _measureText(text).width / 2,
                y,
                null,
                italic: true,
              );
            }
            break;

          case DirectionType.staffDivide:
            if (dir.subType != null) {
              w = _drawTextWithEnclosure(
                canvas,
                dir.subType!,
                currentX + _measureText(dir.subType!).width / 2,
                y,
                null,
                italic: false,
              );
            }
            break;

          case DirectionType.principalVoice:
            if (dir.subType == 'start') {
              w = _drawTextWithEnclosure(
                canvas,
                '[',
                currentX + _measureText('[', fontSizeFactor: 3.0).width / 2,
                y,
                null,
                fontSizeFactor: 3.0,
              );
            } else if (dir.subType == 'stop') {
              w = _drawTextWithEnclosure(
                canvas,
                ']',
                currentX + _measureText(']', fontSizeFactor: 3.0).width / 2,
                y,
                null,
                fontSizeFactor: 3.0,
              );
            }
            break;

          case DirectionType.accordion:
            w = _drawTextWithEnclosure(
              canvas,
              '[acc]',
              currentX + _measureText('[acc]').width / 2,
              y,
              null,
              italic: true,
            );
            break;

          case DirectionType.image:
            w = _drawTextWithEnclosure(
              canvas,
              'image',
              currentX + _measureText('image').width / 2,
              y,
              null,
              italic: false,
            );
            break;

          case DirectionType.wedge:
            if (dir.wedgeType == 'crescendo' || dir.wedgeType == 'diminuendo') {
              openWedge = dir;
              openWedgeX = currentX;
              activeLineY = y;
              activeLineLevel = level;
            } else if (dir.wedgeType == 'stop' && openWedgeX != null) {
              final startX = openWedgeX + lineSpacing * 0.6;
              final endX = currentX - lineSpacing * 0.6;
              if (endX > startX && openWedge != null) {
                _drawWedge(
                  canvas,
                  startX,
                  endX,
                  y,
                  isCrescendo: openWedge.wedgeType == 'crescendo',
                );
              }
              openWedge = null;
              openWedgeX = null;
              activeLineY = null;
              activeLineLevel = null;
            }
            break;

          case DirectionType.dashes:
            if (dir.subType == 'start') {
              openDashesX = currentX;
              activeLineY = y;
              activeLineLevel = level;
            } else if (dir.subType == 'stop' && openDashesX != null) {
              final startX = openDashesX + lineSpacing * 0.5;
              final endX = currentX;
              final y2 = y;
              if (endX > startX) {
                final dashPaint = Paint()
                  ..color = color
                  ..strokeWidth = 1.0;
                double cx = startX;
                while (cx < endX) {
                  canvas.drawLine(
                    Offset(cx, y2),
                    Offset(math.min(cx + lineSpacing * 0.6, endX), y2),
                    dashPaint,
                  );
                  cx += lineSpacing * 1.2;
                }
              }
              openDashesX = null;
              activeLineY = null;
              activeLineLevel = null;
            }
            break;

          case DirectionType.bracket:
            if (dir.subType == 'start') {
              openBracketX = currentX;
              activeLineY = y;
              activeLineLevel = level;
            } else if (dir.subType == 'stop' && openBracketX != null) {
              final startX = openBracketX;
              final endX = currentX;
              final y2 = y;
              final bracketPaint = Paint()
                ..color = color
                ..strokeWidth = 1.0
                ..style = PaintingStyle.stroke;
              final tickDir = -1.0;
              final tickHeight = lineSpacing * 0.5;
              canvas.drawLine(Offset(startX, y2), Offset(endX, y2), bracketPaint);
              canvas.drawLine(
                Offset(startX, y2),
                Offset(startX, y2 + tickHeight * tickDir),
                bracketPaint,
              );
              canvas.drawLine(
                Offset(endX, y2),
                Offset(endX, y2 + tickHeight * tickDir),
                bracketPaint,
              );
              openBracketX = null;
              activeLineY = null;
              activeLineLevel = null;
            }
            break;

          case DirectionType.octaveShift:
            if (dir.subType == 'up' || dir.subType == 'down') {
              openOctaveShiftX = currentX;
              openOctaveShiftText = dir.text ?? '8';
              activeLineY = y;
              activeLineLevel = level;
            } else if (dir.subType == 'stop' && openOctaveShiftX != null) {
              final startX = openOctaveShiftX;
              final endX = currentX;
              final y2 = y;
              if (endX > startX) {
                final dashPaint = Paint()
                  ..color = color
                  ..strokeWidth = 1.0;
                double cx = startX;
                while (cx < endX) {
                  canvas.drawLine(
                    Offset(cx, y2),
                    Offset(math.min(cx + lineSpacing * 0.6, endX), y2),
                    dashPaint,
                  );
                  cx += lineSpacing * 1.2;
                }
                final tp = TextPainter(
                  text: TextSpan(
                    text: openOctaveShiftText,
                    style: TextStyle(
                      fontFamily: null,
                      fontSize: lineSpacing * 1.5,
                      fontStyle: FontStyle.italic,
                      color: color,
                    ),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout();
                tp.paint(
                  canvas,
                  Offset(startX + lineSpacing * 0.2, y2 - tp.height - 6),
                );
              }
              openOctaveShiftX = null;
              activeLineY = null;
              activeLineLevel = null;
            }
            break;

          case DirectionType.pedal:
            if (dir.subType == 'start') {
              openPedalX = currentX;
              activeLineY = y;
              activeLineLevel = level;
              _drawTextWithEnclosure(
                canvas,
                'Ped.',
                currentX + lineSpacing * 1.5,
                y,
                null,
                italic: true,
                fontSizeFactor: 1.5,
              );
            } else if (dir.subType == 'change' && openPedalX != null) {
              final cx = currentX;
              final y2 = y;
              canvas.drawLine(
                Offset(openPedalX, y2),
                Offset(cx, y2),
                Paint()
                  ..color = color
                  ..strokeWidth = 1.0,
              );
              final p = Path()
                ..moveTo(cx - 5, y2 + 2)
                ..lineTo(cx, y2 - 4)
                ..lineTo(cx + 5, y2 + 2);
              canvas.drawPath(
                p,
                Paint()
                  ..color = color
                  ..strokeWidth = 1.5
                  ..style = PaintingStyle.stroke,
              );
              openPedalX = cx;
            } else if (dir.subType == 'stop' && openPedalX != null) {
              final cx = currentX;
              final y2 = y;
              canvas.drawLine(
                Offset(openPedalX, y2),
                Offset(cx, y2),
                Paint()
                  ..color = color
                  ..strokeWidth = 1.0,
              );
              _drawTextWithEnclosure(
                canvas,
                '*',
                cx,
                y2,
                null,
                italic: false,
                fontSizeFactor: 2.0,
              );
              openPedalX = null;
              activeLineY = null;
              activeLineLevel = null;
            }
            break;

          default:
            break;
        }

        // Fusion des boîtes (enclosure)
        if (w > 0) {
          if (dir.enclosure != null && dir.enclosure != 'none') {
            if (activeEnclosure == dir.enclosure) {
              boxEndX = currentX + w;
              if (dirHeight > maxBoxHeight) maxBoxHeight = dirHeight;
            } else {
              if (activeEnclosure != null &&
                  boxStartX != null &&
                  boxEndX != null) {
                _drawEnclosureBox(
                  canvas,
                  activeEnclosure,
                  boxStartX,
                  boxEndX,
                  y,
                  maxBoxHeight,
                );
              }
              activeEnclosure = dir.enclosure;
              boxStartX = currentX;
              boxEndX = currentX + w;
              maxBoxHeight = dirHeight;
            }
          } else {
            if (activeEnclosure != null &&
                boxStartX != null &&
                boxEndX != null) {
              _drawEnclosureBox(
                canvas,
                activeEnclosure,
                boxStartX,
                boxEndX,
                y,
                maxBoxHeight,
              );
              activeEnclosure = null;
            }
          }
          currentX += w + lineSpacing * gap;
        }
      }

      if (activeEnclosure != null && boxStartX != null && boxEndX != null) {
        _drawEnclosureBox(
          canvas,
          activeEnclosure,
          boxStartX,
          boxEndX,
          y,
          maxBoxHeight,
        );
      }
    }

    if (belowLevelsUsed == 0) return 0.0;
    return lineSpacing * (belowBaseOffsetSp + belowLevelsUsed * 1.6);
  }

  void _drawEnclosureBox(
    Canvas canvas,
    String enclosure,
    double leftX,
    double rightX,
    double centerY,
    double height,
  ) {
    final double padX = lineSpacing * 0.4;
    final double padY = lineSpacing * 0.2;
    final rect = Rect.fromLTRB(
      leftX - padX,
      centerY - height / 2 - padY,
      rightX + padX,
      centerY + height / 2 + padY,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (enclosure == 'square') {
      canvas.drawRect(rect, paint);
    } else if (enclosure == 'rectangle') {
      canvas.drawRect(rect.inflate(lineSpacing * 0.2), paint);
    } else if (enclosure == 'circle') {
      canvas.drawOval(rect, paint);
    } else if (enclosure == 'oval') {
      canvas.drawOval(rect.inflate(lineSpacing * 0.2), paint);
    }
  }

  double _measureEventWidth(DirectionEvent dir) {
    if (dir.type == DirectionType.words) {
      // v2c-32b : tenir compte du font-size réel
      return _measureText(
        dir.text ?? '',
        fontWeight: dir.fontWeight,
        fontStyle: dir.fontStyle,
        fontSizeFactor: _fontSizeFactor(dir.fontSize),
      ).width;
    }
    if (dir.type == DirectionType.dynamic) {
      return _measureDynamic(dir.dynamicName, dir.text);
    }
    if (dir.type == DirectionType.metronome) return _measureMetronome(dir);
    if (dir.type == DirectionType.rehearsal) {
      return _measureText(
        dir.text ?? '',
        fontSizeFactor: 3.0,
        fontWeight: dir.fontWeight,
        fontStyle: dir.fontStyle,
      ).width;
    }
    if (dir.type == DirectionType.coda || dir.type == DirectionType.symbol) {
      return lineSpacing * 3.0;
    }
    if (dir.type == DirectionType.eyeglasses) return lineSpacing * 2.0;
    if (dir.type == DirectionType.damp) return lineSpacing * 1.5;
    if (dir.type == DirectionType.harpPedals) return lineSpacing * 3.6;
    if (dir.text != null) return _measureText(dir.text!).width;
    return 0.0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // v2c-32b : _measureText accepte désormais textColor
  // ══════════════════════════════════════════════════════════════════════════
  TextPainter _measureText(
    String text, {
    bool italic = false,
    double fontSizeFactor = 2.0,
    String? fontWeight,
    String? fontStyle,
    Color? textColor,
  }) {
    FontWeight fw = fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal;
    FontStyle fs = fontStyle == 'italic'
        ? FontStyle.italic
        : (italic ? FontStyle.italic : FontStyle.normal);

    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Arial',
          fontFamilyFallback: const ['Roboto', 'sans-serif'],
          fontSize: lineSpacing * fontSizeFactor,
          color: textColor ?? color,
          fontWeight: fw,
          fontStyle: fs,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // v2c-32b : _drawTextWithEnclosure accepte désormais textColor
  // ══════════════════════════════════════════════════════════════════════════
  double _drawTextWithEnclosure(
    Canvas canvas,
    String text,
    double xCenter,
    double y,
    String? enclosure, {
    bool italic = false,
    double fontSizeFactor = 2.0,
    String? fontWeight,
    String? fontStyle,
    Color? textColor,
  }) {
    final tp = _measureText(
      text,
      italic: italic,
      fontSizeFactor: fontSizeFactor,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textColor: textColor,
    );
    tp.paint(canvas, Offset(xCenter - tp.width / 2, y - tp.height / 2));
    return tp.width;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DYNAMIQUES — unifié avec DynamicGlyphs
  // ══════════════════════════════════════════════════════════════════════════
  double _drawDynamic(
    Canvas canvas,
    String? xmlName,
    String? otherText,
    double xStart,
    double y,
  ) {
    if (xmlName == 'other-dynamics' &&
        otherText != null &&
        otherText.isNotEmpty) {
      final musicalGlyphs = DynamicGlyphs.resolveCustom(otherText);
      if (musicalGlyphs != null && musicalGlyphs.isNotEmpty) {
        final style = MusicTextStyle.music(
          fontSize: lineSpacing * 3.8,
          color: color,
          height: 1.0,
        );
        final tp = TextPainter(
          text: TextSpan(text: musicalGlyphs, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(xStart, y - tp.height / 2));
        return tp.width;
      }
      final measuredWidth = _measureText(otherText, italic: true).width;
      return _drawTextWithEnclosure(
        canvas,
        otherText,
        xStart + measuredWidth / 2,
        y,
        null,
        italic: true,
      );
    }

    final name = xmlName;
    if (name == null) return 0.0;

    final glyphs = DynamicGlyphs.resolveXmlName(name);
    if (glyphs == null || glyphs.isEmpty) {
      return _drawTextWithEnclosure(
        canvas,
        name,
        xStart,
        y,
        null,
        italic: true,
        fontSizeFactor: 2.2,
      );
    }

    final style = MusicTextStyle.music(
      fontSize: lineSpacing * 3.8,
      color: color,
      height: 1.0,
    );
    final tp = TextPainter(
      text: TextSpan(text: glyphs, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(xStart, y - tp.height / 2));
    return tp.width;
  }

  double _drawSymbol(Canvas canvas, String glyphName, double xStart, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: Smufl.glyph(glyphName),
        style: MusicTextStyle.music(fontSize: lineSpacing * 3.0, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(xStart, y - tp.height / 2));
    return tp.width;
  }

  void _drawWedge(
    Canvas canvas,
    double startX,
    double endX,
    double y, {
    required bool isCrescendo,
  }) {
    if (endX <= startX) return;
    final halfOpen = lineSpacing * 0.7;
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineSpacing * 0.14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (isCrescendo) {
      canvas.drawLine(Offset(startX, y), Offset(endX, y - halfOpen), paint);
      canvas.drawLine(Offset(startX, y), Offset(endX, y + halfOpen), paint);
    } else {
      canvas.drawLine(Offset(startX, y - halfOpen), Offset(endX, y), paint);
      canvas.drawLine(Offset(startX, y + halfOpen), Offset(endX, y), paint);
    }
  }

  double _drawMetronome(
    Canvas canvas,
    DirectionEvent dir,
    double xStart,
    double y,
  ) {
    if (dir.beatUnit == null) return 0.0;

    final noteStyle = MusicTextStyle.music(
      fontSize: lineSpacing * 2.4,
      color: color,
      height: 1.0,
    );
    final textStyle = TextStyle(
      fontFamily: 'Arial',
      fontFamilyFallback: const ['Roboto'],
      fontSize: lineSpacing * 2.0,
      color: color,
      height: 1.0,
    );

    TextPainter makePainter(String text, TextStyle style) {
      return TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    double measureNoteWithDots(DurationType type, int dots) {
      final notePainter =
          makePainter(Smufl.glyph(Smufl.metNoteGlyphName(type)), noteStyle);
      double w = notePainter.width;
      if (dots > 0) {
        w += lineSpacing * 0.3;
        w += dots * lineSpacing * 0.6;
      }
      return w;
    }

    double drawNoteWithDots(
      Canvas canvas,
      double startX,
      DurationType type,
      int dots,
      double baselineY,
    ) {
      double curX = startX;
      final notePainter =
          makePainter(Smufl.glyph(Smufl.metNoteGlyphName(type)), noteStyle);
      final noteAscent =
          notePainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      notePainter.paint(canvas, Offset(curX, baselineY - noteAscent));
      curX += notePainter.width;

      if (dots > 0) {
        curX += lineSpacing * 0.3;
        final dotRadius = lineSpacing * 0.25;
        final dotY = baselineY - lineSpacing * 0.10;
        final paint = Paint()..color = color;
        for (int i = 0; i < dots; i++) {
          canvas.drawCircle(Offset(curX, dotY), dotRadius, paint);
          curX += lineSpacing * 0.6;
        }
      }
      return curX - startX;
    }

    double totalWidth = 0;
    TextPainter? leftParen;
    TextPainter? rightParen;
    if (dir.metronomeParentheses) {
      final parenStyle = textStyle.copyWith(fontSize: lineSpacing * 2.6);
      leftParen = makePainter('(', parenStyle);
      rightParen = makePainter(')', parenStyle);
      totalWidth += leftParen.width + rightParen.width;
    }

    totalWidth += measureNoteWithDots(dir.beatUnit!, dir.beatUnitDots);
    final eqPainter = makePainter(' = ', textStyle);
    totalWidth += eqPainter.width;

    if (dir.perMinute != null) {
      totalWidth += makePainter(dir.perMinute!, textStyle).width;
    } else if (dir.beatUnit2 != null) {
      totalWidth += measureNoteWithDots(dir.beatUnit2!, dir.beatUnit2Dots);
    }

    double curX = xStart;
    final double baselineY = y;

    if (leftParen != null) {
      final ascent =
          leftParen.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      leftParen.paint(canvas, Offset(curX, baselineY - ascent));
      curX += leftParen.width;
    }

    curX += drawNoteWithDots(
      canvas,
      curX,
      dir.beatUnit!,
      dir.beatUnitDots,
      baselineY,
    );

    final eqAscent =
        eqPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    eqPainter.paint(canvas, Offset(curX, baselineY - eqAscent));
    curX += eqPainter.width;

    if (dir.perMinute != null) {
      final p = makePainter(dir.perMinute!, textStyle);
      final ascent = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      p.paint(canvas, Offset(curX, baselineY - ascent));
      curX += p.width;
    } else if (dir.beatUnit2 != null) {
      curX += drawNoteWithDots(
        canvas,
        curX,
        dir.beatUnit2!,
        dir.beatUnit2Dots,
        baselineY,
      );
    }

    if (rightParen != null) {
      final ascent =
          rightParen.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      rightParen.paint(canvas, Offset(curX, baselineY - ascent));
    }

    return totalWidth;
  }

  double _drawHarpPedals(
    Canvas canvas,
    DirectionEvent dir,
    double xStart,
    double y,
  ) {
    final radius = lineSpacing * 1.8;
    final center = Offset(xStart + radius, y);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    if (dir.harpPedalTunings != null) {
      final keys = ['D', 'C', 'B', 'E', 'F', 'G', 'A'];
      for (int i = 0; i < keys.length; i++) {
        final key = keys[i];
        final alter = dir.harpPedalTunings![key] ?? 0;
        final sym = alter == 1 ? '♯' : alter == -1 ? '♭' : '♮';
        final angle = (i * 2 * math.pi) / keys.length - math.pi / 2;
        final px = center.dx + math.cos(angle) * (radius * 0.55);
        final py = center.dy + math.sin(angle) * (radius * 0.55);
        final tp = TextPainter(
          text: TextSpan(
            text: '$key$sym',
            style: TextStyle(
              fontFamily: 'Arial',
              fontFamilyFallback: const ['Roboto'],
              fontSize: lineSpacing * 0.8,
              color: color,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
      }
    }
    return radius * 2;
  }

  double _drawDamp(Canvas canvas, DirectionEvent dir, double xStart, double y) {
    if (dir.subType == 'damp') {
      final cx = xStart + lineSpacing * 0.5;
      final p = Path()
        ..moveTo(cx - 4, y + 4)
        ..lineTo(cx, y - 4)
        ..lineTo(cx + 4, y + 4);
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      return lineSpacing;
    } else if (dir.subType == 'damp-all') {
      return _drawTextWithEnclosure(
        canvas,
        '*',
        xStart + lineSpacing * 0.5,
        y,
        null,
        italic: false,
        fontSizeFactor: 2.0,
      );
    }
    return 0.0;
  }

  double _drawEyeglasses(Canvas canvas, double xStart, double y) {
    final cx = xStart + lineSpacing * 0.5;
    final c1 = Offset(cx - lineSpacing * 0.5, y);
    final c2 = Offset(cx + lineSpacing * 0.5, y);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c1, lineSpacing * 0.5, p);
    canvas.drawCircle(c2, lineSpacing * 0.5, p);
    canvas.drawLine(
      Offset(c1.dx + lineSpacing * 0.5, c1.dy),
      Offset(c2.dx - lineSpacing * 0.5, c2.dy),
      p,
    );
    return lineSpacing * 2.0;
  }

  double _measureDynamic(String? xmlName, String? otherText) {
    if (xmlName == 'other-dynamics' &&
        otherText != null &&
        otherText.isNotEmpty) {
      final musicalGlyphs = DynamicGlyphs.resolveCustom(otherText);
      if (musicalGlyphs != null && musicalGlyphs.isNotEmpty) {
        final style = MusicTextStyle.music(
          fontSize: lineSpacing * 3.8,
          color: color,
          height: 1.0,
        );
        return (TextPainter(
          text: TextSpan(text: musicalGlyphs, style: style),
          textDirection: TextDirection.ltr,
        )..layout())
            .width;
      }
      return _measureText(otherText, italic: true).width;
    }

    final name = xmlName;
    if (name == null) return 0.0;

    final glyphs = DynamicGlyphs.resolveXmlName(name);
    if (glyphs == null || glyphs.isEmpty) {
      return _measureText(name, italic: true).width;
    }

    final style = MusicTextStyle.music(
      fontSize: lineSpacing * 3.8,
      color: color,
      height: 1.0,
    );
    return (TextPainter(
      text: TextSpan(text: glyphs, style: style),
      textDirection: TextDirection.ltr,
    )..layout())
        .width;
  }

  double _measureMetronome(DirectionEvent dir) {
    if (dir.beatUnit == null) return 0.0;
    final noteStyle = MusicTextStyle.music(
      fontSize: lineSpacing * 2.4,
      color: color,
      height: 1.0,
    );
    final textStyle = TextStyle(
      fontFamily: 'Arial',
      fontFamilyFallback: const ['Roboto'],
      fontSize: lineSpacing * 2.0,
      color: color,
      height: 1.0,
    );

    double w = 0;
    if (dir.metronomeParentheses) w += lineSpacing * 2.4;

    final notePainter = TextPainter(
      text: TextSpan(
        text: Smufl.glyph(Smufl.metNoteGlyphName(dir.beatUnit!)),
        style: noteStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    w += notePainter.width;
    if (dir.beatUnitDots > 0) {
      w += lineSpacing * 0.3 + dir.beatUnitDots * lineSpacing * 0.6;
    }

    final eqPainter = TextPainter(
      text: TextSpan(text: ' = ', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    w += eqPainter.width;

    if (dir.perMinute != null) {
      final perMinutePainter = TextPainter(
        text: TextSpan(text: dir.perMinute!, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      w += perMinutePainter.width;
    } else if (dir.beatUnit2 != null) {
      final notePainter2 = TextPainter(
        text: TextSpan(
          text: Smufl.glyph(Smufl.metNoteGlyphName(dir.beatUnit2!)),
          style: noteStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      w += notePainter2.width;
      if (dir.beatUnit2Dots > 0) {
        w += lineSpacing * 0.3 + dir.beatUnit2Dots * lineSpacing * 0.6;
      }
    }

    return w;
  }

  DirectionPainter copyWith({double? lineSpacing, Color? color}) =>
      DirectionPainter(
        lineSpacing: lineSpacing ?? this.lineSpacing,
        color: color ?? this.color,
      );
}