// lib/services/parsers/direction_parser.dart
// ============================================================================
// PARSEUR DE DIRECTIONS (MUSICXML) — v2c-31a-29
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/events/direction.dart';
import '../../models/enums/music_enums.dart';
import 'common.dart';

class DirectionParser {
  static int _groupIdCounter = 0;

  static List<DirectionEvent> parseList(
    xml.XmlElement node, {
    int timePosition = 0,
    int eventIndexInVoice = -1,
  }) {
    final List<DirectionEvent> events = [];
    final placement = node.getAttribute('placement');
    final staffStr = node.findElements('staff').firstOrNull?.innerText;
    final staffNumber = int.tryParse(staffStr ?? '1') ?? 1;
    final offsetStr = node.findElements('offset').firstOrNull?.innerText;
    final double offset = double.tryParse(offsetStr ?? '') ?? 0.0;
    final int groupId = ++_groupIdCounter;

    for (final dirTypeNode in node.findElements('direction-type')) {
      
final wordsNodes = dirTypeNode.findElements('words').toList();
for (final w in wordsNodes) {
  final defaultX = double.tryParse(w.getAttribute('default-x') ?? '');
  final defaultY = double.tryParse(w.getAttribute('default-y') ?? '');
  final fontSizeAttr = w.getAttribute('font-size');
  final colorAttr = w.getAttribute('color');
  final colorValue = _hexToArgb(colorAttr);

  events.add(DirectionEvent(
    type: DirectionType.words,
    text: w.innerText.replaceAll(' ', '\u00A0'),
    enclosure: w.getAttribute('enclosure'),
    fontWeight: w.getAttribute('font-weight'),
    fontStyle: w.getAttribute('font-style'),
    placement: placement ?? 'above',
    staffNumber: staffNumber,
    timePosition: timePosition,
    eventIndexInVoice: eventIndexInVoice,
    offset: offset,
    groupId: groupId,
    // v2c-32b
    defaultX: defaultX,
    defaultY: defaultY,
    fontSize: fontSizeAttr,
    colorValue: colorValue,
  ));
}

      final rehearsalNodes = dirTypeNode.findElements('rehearsal').toList();
      for (final r in rehearsalNodes) {
        events.add(DirectionEvent(
          type: DirectionType.rehearsal,
          text: r.innerText.replaceAll(' ', '\u00A0'),
          enclosure: r.getAttribute('enclosure') ?? 'square',
          fontWeight: r.getAttribute('font-weight'),
          fontStyle: r.getAttribute('font-style'),
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final dynamicsNode = dirTypeNode.findElements('dynamics').firstOrNull;
      if (dynamicsNode != null) {
        var dynName = dynamicsNode.children.whereType<xml.XmlElement>().map((e) => e.name.local).firstOrNull;
        String? otherText;
        if (dynName == 'other-dynamics') otherText = dynamicsNode.findElements('other-dynamics').firstOrNull?.innerText;
        
        if (dynName != null) {
          events.add(DirectionEvent(
            type: DirectionType.dynamic,
            dynamicName: dynName,
            text: otherText,
            placement: placement ?? 'below',
            staffNumber: staffNumber,
            timePosition: timePosition,
            eventIndexInVoice: eventIndexInVoice,
            offset: offset,
            groupId: groupId,
          ));
        }
      }

      final metronomeNode = dirTypeNode.findElements('metronome').firstOrNull;
      if (metronomeNode != null) {
        DurationType? beatUnit1;
        int beatUnit1Dots = 0;
        DurationType? beatUnit2;
        int beatUnit2Dots = 0;
        String? perMinute;

        for (final child in metronomeNode.children) {
          if (child is! xml.XmlElement) continue;
          if (child.name.local == 'beat-unit') {
            final type = CommonParserHelpers.parseDurationType(child.innerText.trim());
            if (beatUnit1 == null) {
              beatUnit1 = type;
            } else {
              beatUnit2 = type;
            }
          } else if (child.name.local == 'beat-unit-dot') {
            if (beatUnit2 == null && perMinute == null) {
              beatUnit1Dots++;
            } else {
              beatUnit2Dots++;
            }
          } else if (child.name.local == 'per-minute') {
            perMinute = child.innerText;
          }
        }

        events.add(DirectionEvent(
          type: DirectionType.metronome,
          beatUnit: beatUnit1,
          beatUnitDots: beatUnit1Dots,
          beatUnit2: beatUnit2,
          beatUnit2Dots: beatUnit2Dots,
          perMinute: perMinute,
          metronomeParentheses: metronomeNode.getAttribute('parentheses') == 'yes',
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final wedgeNode = dirTypeNode.findElements('wedge').firstOrNull;
      if (wedgeNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.wedge,
          wedgeType: wedgeNode.getAttribute('type'),
          placement: placement ?? 'below',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final dashesNode = dirTypeNode.findElements('dashes').firstOrNull;
      if (dashesNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.dashes,
          subType: dashesNode.getAttribute('type'),
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final segnoNode = dirTypeNode.findElements('segno').firstOrNull;
      if (segnoNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.segno,
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final codaNodes = dirTypeNode.findElements('coda').toList();
      for (final _ in codaNodes) {
        events.add(DirectionEvent(
          type: DirectionType.coda,
          smuflGlyphName: 'coda',
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final symbolNode = dirTypeNode.findElements('symbol').firstOrNull;
      if (symbolNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.symbol,
          smuflGlyphName: symbolNode.innerText.trim(),
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final bracketNode = dirTypeNode.findElements('bracket').firstOrNull;
      if (bracketNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.bracket,
          subType: bracketNode.getAttribute('type'),
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final octaveShiftNode = dirTypeNode.findElements('octave-shift').firstOrNull;
      if (octaveShiftNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.octaveShift,
          subType: octaveShiftNode.getAttribute('type'),
          text: octaveShiftNode.getAttribute('size') ?? '8',
          placement: placement ?? 'below',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final pedalNode = dirTypeNode.findElements('pedal').firstOrNull;
      if (pedalNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.pedal,
          subType: pedalNode.getAttribute('type'),
          placement: placement ?? 'below',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final harpNode = dirTypeNode.findElements('harp-pedals').firstOrNull;
      if (harpNode != null) {
        final tunings = <String, int>{};
        for (final tuning in harpNode.findElements('pedal-tuning')) {
          final step = tuning.findElements('pedal-step').firstOrNull?.innerText;
          final alterStr = tuning.findElements('pedal-alter').firstOrNull?.innerText;
          if (step != null && alterStr != null) tunings[step] = int.tryParse(alterStr) ?? 0;
        }
        events.add(DirectionEvent(
          type: DirectionType.harpPedals,
          text: 'harp pedals',
          harpPedalTunings: tunings,
          placement: placement ?? 'below',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      if (dirTypeNode.findElements('damp').isNotEmpty) {
        events.add(DirectionEvent(
          type: DirectionType.damp,
          subType: 'damp',
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }
      if (dirTypeNode.findElements('damp-all').isNotEmpty) {
        events.add(DirectionEvent(
          type: DirectionType.damp,
          subType: 'damp-all',
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final stringMuteNode = dirTypeNode.findElements('string-mute').firstOrNull;
      if (stringMuteNode != null) {
        final type = stringMuteNode.getAttribute('type');
        events.add(DirectionEvent(
          type: DirectionType.stringMute,
          subType: type,
          text: type == 'on' ? 'mute on' : 'mute off',
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      if (dirTypeNode.findElements('eyeglasses').isNotEmpty) {
        events.add(DirectionEvent(
          type: DirectionType.eyeglasses,
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final percNode = dirTypeNode.findElements('percussion').firstOrNull;
      if (percNode != null) {
        final child = percNode.children.whereType<xml.XmlElement>().firstOrNull;
        events.add(DirectionEvent(
          type: DirectionType.percussion,
          subType: child?.name.local,
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final staffDivideNode = dirTypeNode.findElements('staff-divide').firstOrNull;
      if (staffDivideNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.staffDivide,
          subType: staffDivideNode.getAttribute('type'),
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final pvNode = dirTypeNode.findElements('principal-voice').firstOrNull;
      if (pvNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.principalVoice,
          subType: pvNode.getAttribute('type'),
          text: pvNode.getAttribute('symbol'),
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      if (dirTypeNode.findElements('accordion-registration').isNotEmpty) {
        events.add(DirectionEvent(
          type: DirectionType.accordion,
          text: 'accordion',
          placement: placement ?? 'above',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }

      final imageNode = dirTypeNode.findElements('image').firstOrNull;
      if (imageNode != null) {
        events.add(DirectionEvent(
          type: DirectionType.image,
          text: 'image',
          placement: placement ?? 'below',
          staffNumber: staffNumber,
          timePosition: timePosition,
          eventIndexInVoice: eventIndexInVoice,
          offset: offset,
          groupId: groupId,
        ));
      }
    }

    return events;
  }
  /// v2c-32b : convertit '#FF0000' → 0xFFFF0000. Retourne null si invalide.
static int? _hexToArgb(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceFirst('#', '').trim();
  if (h.isEmpty) return null;
  if (h.length == 6) h = 'FF$h';  // ajoute alpha opaque
  return int.tryParse(h, radix: 16);
}

}