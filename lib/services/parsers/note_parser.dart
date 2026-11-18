// lib/services/parsers/note_parser.dart
// ============================================================================
// PARSEUR DE NOTES (MUSICXML) — v2c-116-32f
// ============================================================================
// v2c-116 : Capture DYNAMIQUE des attributs XML pour les <technical>
// v2c-32c  : FIX W3C 32c. Itération sur TOUS les <notations> et TOUTES les
//            <articulations> enfants d'une note, pour ne rien rater.
// v2c-32f  : Fermatas avec `shape` distinct du `type` (upright/inverted).
// ============================================================================

import 'package:xml/xml.dart' as xml;

import '../../models/events/music_event.dart';
import '../../models/events/pitch.dart';
import '../../models/events/lyric.dart';
import '../../models/events/notations.dart';
import '../../models/enums/music_enums.dart';
import 'common.dart';

class NoteParser {
  static int _idCounter = 0;

  static MusicEvent? parse(
    xml.XmlElement noteNode,
    int defaultStaffNumber, {
    String? forcedId,
  }) {
    // ─── 1. VARIABLES DE BASE ───
    final isRest = noteNode.findElements('rest').isNotEmpty;
    final isGrace = noteNode.findElements('grace').isNotEmpty;
    final isCue = noteNode.findElements('cue').isNotEmpty;

    final String? printObjectAttr = noteNode.getAttribute('print-object');
    final bool printObject = printObjectAttr != 'no';

    final String? printLyricAttr = noteNode.getAttribute('print-lyric');
    final bool printLyric = printLyricAttr == 'no' ? false : (printLyricAttr == 'yes' ? true : printObject);

    final durationStr = noteNode.findElements('duration').firstOrNull?.innerText;
    final duration = isGrace ? 0 : (durationStr != null ? int.parse(durationStr) : 0);

    final typeNode = noteNode.findElements('type').firstOrNull;
    final type = typeNode?.innerText ?? 'quarter';
    final durationType = CommonParserHelpers.parseDurationType(type);

    final dotCount = noteNode.findAllElements('dot').length;
    final dotType = switch (dotCount) {
      1 => DotType.single, 2 => DotType.double, 3 => DotType.triple, _ => DotType.none,
    };

    // Tuplets
    int tupletNum = 1, tupletDen = 1;
    DurationType? tmNormalType;
    int tmNormalDots = 0;
    final tmNode = noteNode.findElements('time-modification').firstOrNull;
    if (tmNode != null) {
      final actualStr = tmNode.findElements('actual-notes').firstOrNull?.innerText;
      final normalStr = tmNode.findElements('normal-notes').firstOrNull?.innerText;
      if (actualStr != null) tupletNum = int.tryParse(actualStr) ?? 1;
      if (normalStr != null) tupletDen = int.tryParse(normalStr) ?? 1;
      final normalTypeStr = tmNode.findElements('normal-type').firstOrNull?.innerText;
      if (normalTypeStr != null && normalTypeStr.trim().isNotEmpty) {
        tmNormalType = CommonParserHelpers.parseDurationType(normalTypeStr.trim());
      }
      tmNormalDots = tmNode.findElements('normal-dot').length;
    }

    final voiceIndex = int.tryParse(noteNode.findElements('voice').firstOrNull?.innerText ?? '1') ?? 1;
    final staffNumber = int.tryParse(noteNode.findElements('staff').firstOrNull?.innerText ?? defaultStaffNumber.toString()) ?? defaultStaffNumber;
    final defaultX = double.tryParse(noteNode.getAttribute('default-x') ?? '');
    final defaultY = double.tryParse(noteNode.getAttribute('default-y') ?? '');
    final stem = noteNode.findElements('stem').firstOrNull?.innerText;
    final stemDirection = _parseStemDirection(stem);

    // ─── 2. VARIABLES DE NOTATIONS ───
    NoteheadShape noteheadShape = NoteheadShape.normal;
    bool? noteheadFilled;
    bool noteheadParentheses = false;
    DynamicType dynamicMark = DynamicType.none;

    final fermatas = <FermataNotation>[];
    final arpeggiates = <ArpeggiateNotation>[];
    final accidentalMarks = <AccidentalMark>[];
    final ornaments = <OrnamentNotation>[];
    final technicals = <TechnicalNotation>[];
    final articulations = <Articulation>[];

    final notationsNodes = noteNode.findElements('notations').toList();

    for (final notationsNode in notationsNodes) {
      // 1. Fermatas (v2c-32f : type + shape)
      for (final fermataNode in notationsNode.findElements('fermata')) {
        final text = fermataNode.innerText.trim();
        final typeAttr = fermataNode.getAttribute('type') ?? 'upright';
        final shape = text.isNotEmpty ? text : 'normal';
        fermatas.add(FermataNotation(type: typeAttr, shape: shape));
      }

      // 2. Arpeggiate / Non-Arpeggiate (v2c-32e : capture de `number`)
      for (final arpNode in notationsNode.findElements('arpeggiate')) {
        arpeggiates.add(ArpeggiateNotation(
          type: 'arpeggiate',
          direction: arpNode.getAttribute('direction'),
          number: int.tryParse(arpNode.getAttribute('number') ?? '1') ?? 1,
        ));
      }
      for (final nonArpNode in notationsNode.findElements('non-arpeggiate')) {
        arpeggiates.add(ArpeggiateNotation(
          type: 'non-arpeggiate',
          placement: nonArpNode.getAttribute('type'),
          number: int.tryParse(nonArpNode.getAttribute('number') ?? '1') ?? 1,
        ));
      }

      // 3. Accidental Marks
      for (final accNode in notationsNode.findElements('accidental-mark')) {
        accidentalMarks.add(AccidentalMark(type: accNode.innerText.trim(), placement: accNode.getAttribute('placement') ?? 'above'));
      }

      // 4. Ornaments
      final ornamentsNode = notationsNode.findElements('ornaments').firstOrNull;
      if (ornamentsNode != null) {
        for (final child in ornamentsNode.children) {
          if (child is xml.XmlElement) {
            final name = child.name.local;
            final placement = child.getAttribute('placement') ?? 'above';
            if (name == 'wavy-line') {
              ornaments.add(OrnamentNotation(type: 'wavy-line', placement: placement, wavyLineType: child.getAttribute('type') ?? 'start'));
            } else if (name == 'accidental-mark') {
              accidentalMarks.add(AccidentalMark(type: child.innerText.trim(), placement: placement));
            } else if (name != 'tremolo') {
              ornaments.add(OrnamentNotation(type: name, placement: placement));
            }
          }
        }
      }

      // 5. Technicals
      final techNode = notationsNode.findElements('technical').firstOrNull;
      if (techNode != null) {
        for (final child in techNode.children) {
          if (child is xml.XmlElement) {
            final name = child.name.local;
            final text = child.innerText.trim();
            final placement = child.getAttribute('placement') ?? 'above';

            if (name == 'harmonic') {
              final hasArtificial = child.findElements('artificial').isNotEmpty;
              final hasTouch = child.findElements('touching-pitch').isNotEmpty;
              final hasBase = child.findElements('base-pitch').isNotEmpty;
              final hasSound = child.findElements('sounding-pitch').isNotEmpty;

              String hType = 'natural';
              if (hasArtificial) hType = 'artificial';
              if (hasTouch) hType = 'touch';
              if (hasBase) hType = 'base';
              if (hasSound) hType = 'sound';

              technicals.add(TechnicalNotation(type: 'harmonic', placement: placement, harmonicType: hType));

              if (hasArtificial || hasTouch) noteheadShape = NoteheadShape.diamond;
              if (hasTouch) noteheadParentheses = true;
            } else {
              final substitution = child.getAttribute('substitution') == 'yes';
              final alternate = child.getAttribute('alternate') == 'yes';
              
              final attrs = <String, String>{};
              for (final attr in child.attributes) {
                attrs[attr.name.local] = attr.value;
              }

              technicals.add(TechnicalNotation(
                type: name, 
                text: text.isNotEmpty ? text : null, 
                placement: placement,
                substitution: substitution, 
                alternate: alternate,
                attributes: attrs,
              ));
            }
          }
        }
      }

      // 6. Articulations
      for (final articNode in notationsNode.findElements('articulations')) {
        for (final child in articNode.children) {
          if (child is xml.XmlElement) {
            final art = CommonParserHelpers.parseArticulation(child.name.local);
            if (art != ArticulationType.none) {
              final placement = child.getAttribute('placement');
              articulations.add(Articulation(type: art, placement: placement));
              if (child.name.local == 'detached-legato') {
                articulations.add(Articulation(type: ArticulationType.staccato, placement: placement));
              }
            }
          }
        }
      }
    }

    // ─── 3. BLOC NOTEHEAD ───
    final noteheadNode = noteNode.findElements('notehead').firstOrNull;
    if (noteheadNode != null) {
      final typeText = noteheadNode.innerText.trim().toLowerCase();
      switch (typeText) {
        case 'normal': noteheadShape = NoteheadShape.normal; break;
        case 'slash': noteheadShape = NoteheadShape.slash; break;
        case 'triangle': noteheadShape = NoteheadShape.triangle; break;
        case 'diamond': noteheadShape = NoteheadShape.diamond; break;
        case 'square': noteheadShape = NoteheadShape.square; break;
        case 'cross': noteheadShape = NoteheadShape.cross; break;
        case 'x': noteheadShape = NoteheadShape.x; break;
        case 'circle-x': noteheadShape = NoteheadShape.circleX; break;
        case 'inverted triangle': noteheadShape = NoteheadShape.invertedTriangle; break;
        case 'arrow down': noteheadShape = NoteheadShape.arrowDown; break;
        case 'arrow up': noteheadShape = NoteheadShape.arrowUp; break;
        case 'none': noteheadShape = NoteheadShape.none; break;
        default: break;
      }
      final filledAttr = noteheadNode.getAttribute('filled');
      if (filledAttr == 'no') {
        noteheadFilled = false;
      } else if (filledAttr == 'yes') {
        noteheadFilled = true;
      }
      if (noteheadNode.getAttribute('parentheses') == 'yes') noteheadParentheses = true;
    }

    // ─── 4. LE RESTE DU PARSING ───
    final slursStarted = <int>{};
    final slursStopped = <int>{};
    final tiesStarted = <int>{};
    final tiesStopped = <int>{};
    String? tieStartDirection, tieStopDirection;
    final tupletStarts = <int>{};
    final tupletStops = <int>{};
    final tupletMetadata = <int, TupletMetadata>{};
    final rawNotations = <String, String>{};

    void processTieNode(xml.XmlElement node) {
      final tieType = node.getAttribute('type') ?? '';
      final placement = node.getAttribute('placement');
      final orientation = node.getAttribute('orientation');
      String? dir = placement ?? (orientation == 'over' ? 'above' : (orientation == 'under' ? 'below' : null));

      if (tieType == 'start') {
        tiesStarted.add(1);
        if (dir != null) tieStartDirection = dir;
      }
      if (tieType == 'stop') {
        tiesStopped.add(1);
        if (dir != null) tieStopDirection = dir;
      }
    }

    for (final notationsNode in notationsNodes) {
      for (final slurNode in notationsNode.findElements('slur')) {
        final number = int.tryParse(slurNode.getAttribute('number') ?? '1') ?? 1;
        if (slurNode.getAttribute('type') == 'start') slursStarted.add(number);
        if (slurNode.getAttribute('type') == 'stop') slursStopped.add(number);
      }

      for (final tiedNode in notationsNode.findElements('tied')) {
        processTieNode(tiedNode);
      }

      for (final tupletNode in notationsNode.findElements('tuplet')) {
        final ttype = tupletNode.getAttribute('type') ?? '';
        final number = int.tryParse(tupletNode.getAttribute('number') ?? '1') ?? 1;
        if (ttype == 'start') {
          tupletStarts.add(number);
          final bracketAttr = tupletNode.getAttribute('bracket');
          final bool bracketExplicit = bracketAttr != null;
          final bool bracket = bracketExplicit ? (bracketAttr == 'yes') : true;
          final showNumAttr = tupletNode.getAttribute('show-number');
          final showTypeAttr = tupletNode.getAttribute('show-type');
          final lineShapeAttr = tupletNode.getAttribute('line-shape');
          final placementAttr = tupletNode.getAttribute('placement');

          final actual = _buildTupletDisplaySide(sideNode: tupletNode.findElements('tuplet-actual').firstOrNull, fallbackNumber: tupletNum, fallbackType: tmNormalType ?? durationType, fallbackDots: tmNormalDots > 0 ? tmNormalDots : dotCount);
          final normal = _buildTupletDisplaySide(sideNode: tupletNode.findElements('tuplet-normal').firstOrNull, fallbackNumber: tupletDen, fallbackType: tmNormalType ?? durationType, fallbackDots: tmNormalDots > 0 ? tmNormalDots : dotCount);

          tupletMetadata[number] = TupletMetadata(
            number: number, placement: placementAttr ?? '', bracket: bracket, bracketExplicit: bracketExplicit,
            showNumber: showNumAttr ?? 'actual', showType: showTypeAttr ?? '', lineShape: lineShapeAttr ?? 'straight',
            displayActual: actual, displayNormal: normal,
          );
        } else if (ttype == 'stop') {
          tupletStops.add(number);
        }
      }

      for (final child in notationsNode.children) {
        if (child is xml.XmlElement) rawNotations[child.name.local] = child.innerText;
      }

      final dynamicsNode = notationsNode.findElements('dynamics').firstOrNull;
      if (dynamicsNode != null) {
        rawNotations.remove('dynamics');
        final firstChild = dynamicsNode.children.whereType<xml.XmlElement>().firstOrNull;

        if (firstChild != null) {
          if (firstChild.name.local == 'other-dynamics') {
            final customText = firstChild.innerText.trim();
            if (customText.isNotEmpty) {
              rawNotations['other-dynamics'] = customText;
            }
          } else {
            dynamicMark = DynamicTypeParser.fromXmlName(firstChild.name.local);
          }
        }
      }
    }

    for (final tieNode in noteNode.findElements('tie')) {
      processTieNode(tieNode);
    }

    TremoloType tremoloType = TremoloType.none;
    int tremoloCount = 0;
    for (final notationsNode in notationsNodes) {
      final ornamentsNode = notationsNode.findElements('ornaments').firstOrNull;
      final tremoloNode = ornamentsNode?.findElements('tremolo').firstOrNull;
      if (tremoloNode != null) {
        final typeAttr = tremoloNode.getAttribute('type') ?? 'single';
        final count = int.tryParse(tremoloNode.innerText.trim()) ?? 0;
        switch (typeAttr) {
          case 'single': tremoloType = TremoloType.single; tremoloCount = count > 0 ? count : 1; break;
          case 'unmeasured': tremoloType = TremoloType.unmeasured; tremoloCount = 0; break;
          case 'start': tremoloType = TremoloType.start; tremoloCount = count > 0 ? count : 1; break;
          case 'stop': tremoloType = TremoloType.stop; tremoloCount = count > 0 ? count : 1; break;
        }
      }
    }

    final beams = <int, BeamType>{};
    for (final beamNode in noteNode.findElements('beam')) {
      final number = int.tryParse(beamNode.getAttribute('number') ?? '1') ?? 1;
      beams[number] = _parseBeamType(beamNode.innerText.trim());
    }

    final lyrics = <Lyric>[];
    for (final lyricNode in noteNode.findElements('lyric')) {
      final text = lyricNode.findElements('text').firstOrNull?.innerText ?? '';
      final syllabic = lyricNode.findElements('syllabic').firstOrNull?.innerText ?? 'single';
      final number = int.tryParse(lyricNode.getAttribute('number') ?? '1') ?? 1;
      final elision = lyricNode.findElements('elision').firstOrNull?.innerText;
      final extend = lyricNode.findElements('extend').isNotEmpty;
      final placement = lyricNode.getAttribute('placement');
      final justify = lyricNode.getAttribute('justify');

      lyrics.add(Lyric(
        text: text, syllabic: syllabic, number: number, elision: elision,
        extend: extend, placement: placement ?? 'below', justify: justify,
      ));
    }

    double alterRaw = 0.0;
    final pitchNodeForAlter = noteNode.findElements('pitch').firstOrNull;
    if (pitchNodeForAlter != null) {
      final alterStr = pitchNodeForAlter.findElements('alter').firstOrNull?.innerText;
      if (alterStr != null && alterStr.isNotEmpty) alterRaw = double.tryParse(alterStr) ?? 0.0;
    }

    Accidental accidental = Accidental.none;
    bool isCautionary = false;
    bool isEditorial = false;

    final accNode = noteNode.findElements('accidental').firstOrNull;
    if (accNode != null) {
      accidental = CommonParserHelpers.parseAccidental(accNode.innerText);
      final parensAttr = accNode.getAttribute('parentheses');
      final bracketAttr = accNode.getAttribute('bracket');
      final cautionaryAttr = accNode.getAttribute('cautionary') == 'yes';
      final editorialAttr = accNode.getAttribute('editorial') == 'yes';

      isCautionary = parensAttr != null ? parensAttr == 'yes' : cautionaryAttr;
      isEditorial = bracketAttr != null ? bracketAttr == 'yes' : (editorialAttr && cautionaryAttr && parensAttr == null ? false : editorialAttr);
    } else {
      accidental = CommonParserHelpers.accidentalFromAlter(alterRaw);
    }

    final noteNotations = NoteNotations(
      fermatas: fermatas, arpeggiates: arpeggiates, accidentalMarks: accidentalMarks,
      ornaments: ornaments, technicals: technicals,
    );

    if (isRest) {
      final restNode = noteNode.findElements('rest').first;
      final isMeasureRest = restNode.getAttribute('measure') == 'yes';
      final ds = restNode.findElements('display-step').firstOrNull?.innerText;
      final do_ = restNode.findElements('display-octave').firstOrNull?.innerText;

      return RestEvent(
        durationType: isMeasureRest ? DurationType.whole : durationType,
        duration: duration, dotType: dotType, tupletsNumerator: tupletNum, tupletsDenominator: tupletDen,
        voiceIndex: voiceIndex, staffNumber: staffNumber, defaultX: defaultX, defaultY: defaultY,
        displayStep: ds, displayOctave: do_ != null ? int.tryParse(do_) : null,
        isMeasureRest: isMeasureRest, noteheadParentheses: noteheadParentheses,
        notehead: (noteheadNode != null) ? noteheadShape : null, notations: noteNotations,
      );
    }

    final pitchNode = noteNode.findElements('pitch').firstOrNull;
    if (pitchNode == null) {
      final unpitchedNode = noteNode.findElements('unpitched').firstOrNull;
      if (unpitchedNode == null) return null;
    }

    final Pitch pitch;
    if (pitchNode != null) {
      final step = pitchNode.findElements('step').firstOrNull?.innerText ?? 'C';
      final octaveStr = pitchNode.findElements('octave').firstOrNull?.innerText;
      final octave = octaveStr != null ? int.parse(octaveStr) : 4;
      pitch = Pitch(
        letter: CommonParserHelpers.parseNoteLetter(step), octave: octave, alter: alterRaw,
        accidentalDisplay: accidental, isCautionary: isCautionary, isEditorial: isEditorial,
        tiesStarted: tiesStarted, tiesStopped: tiesStopped, tieStartDirection: tieStartDirection,
        tieStopDirection: tieStopDirection, notehead: noteheadShape, noteheadFilled: noteheadFilled,
        noteheadParentheses: noteheadParentheses, lyrics: lyrics,
      );
    } else {
      pitch = const Pitch(letter: NoteLetter.C, octave: 4);
    }

    bool graceSlash = false;
    if (isGrace) {
      final graceNode = noteNode.findElements('grace').first;
      graceSlash = graceNode.getAttribute('slash') == 'yes';
    }

    final isChordPart = noteNode.findElements('chord').isNotEmpty;
    final id = forcedId ?? 'n_new_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

    return NoteEvent(
      id: id, pitches: [pitch], durationType: durationType, duration: duration, dotType: dotType,
      tupletsNumerator: tupletNum, tupletsDenominator: tupletDen,
      voiceIndex: voiceIndex, staffNumber: staffNumber, defaultX: defaultX, defaultY: defaultY, stemDirection: stemDirection,
      articulations: articulations, dynamicMark: dynamicMark, stem: stem, lyrics: lyrics,
      isChordPart: isChordPart, isGrace: isGrace, graceSlash: graceSlash, isCue: isCue,
      slursStarted: slursStarted, slursStopped: slursStopped, beams: beams, tupletStarts: tupletStarts,
      tupletStops: tupletStops, tupletMetadata: tupletMetadata, rawNotations: rawNotations,
      tremoloType: tremoloType, tremoloCount: tremoloCount, notehead: noteheadShape,
      noteheadFilled: noteheadFilled, printObject: printObject, printLyric: printLyric,
      noteheadParentheses: noteheadParentheses, notations: noteNotations,
    );
  }

  static TupletDisplaySide _buildTupletDisplaySide({
    required xml.XmlElement? sideNode,
    required int? fallbackNumber,
    required DurationType? fallbackType,
    required int fallbackDots,
  }) {
    if (sideNode == null) {
      return TupletDisplaySide(
        number: fallbackNumber,
        type: fallbackType,
        dots: fallbackDots,
      );
    }

    final numberStr = sideNode.findElements('tuplet-number').firstOrNull?.innerText;
    final int? number = (numberStr != null && numberStr.trim().isNotEmpty)
        ? (int.tryParse(numberStr.trim()) ?? fallbackNumber)
        : fallbackNumber;

    final typeStr = sideNode.findElements('tuplet-type').firstOrNull?.innerText;
    final DurationType? type = (typeStr != null && typeStr.trim().isNotEmpty)
        ? CommonParserHelpers.parseDurationType(typeStr.trim())
        : fallbackType;

    final int explicitDots = sideNode.findElements('tuplet-dot').length;
    final int dots = explicitDots > 0 ? explicitDots : fallbackDots;

    return TupletDisplaySide(
      number: number,
      type: type,
      dots: dots,
    );
  }

  static StemDirection _parseStemDirection(String? stem) {
    switch (stem) {
      case 'up': return StemDirection.up;
      case 'down': return StemDirection.down;
      case 'none': return StemDirection.none;
      default: return StemDirection.auto;
    }
  }

  static BeamType _parseBeamType(String value) {
    switch (value) {
      case 'begin': return BeamType.start;
      case 'continue': return BeamType.continue_;
      case 'end': return BeamType.end;
      case 'forward hook': return BeamType.forwardHook;
      case 'backward hook': return BeamType.backwardHook;
      default: return BeamType.none;
    }
  }
}