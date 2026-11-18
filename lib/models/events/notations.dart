// lib/models/events/notations.dart
// ============================================================================
// MODÈLES DE NOTATIONS — v2c-116
// ============================================================================
// v2c-116 : Ajout de `attributes` dans `TechnicalNotation` pour capturer
//           DYNAMIQUEMENT tous les attributs XML spécifiques (direction,
//           closed, sounding, type, etc.) sans devoir les énumérer au
//           préalable dans le parser.
// ============================================================================

class FermataNotation {
  final String type;  // 'upright', 'inverted'
  final String shape; // 'normal', 'angled', 'square', 'double-dot', 'half-curve', 'double-square', 'double-angled'
  
  const FermataNotation({
    this.type = 'upright', 
    this.shape = 'normal',
  });
}

class ArpeggiateNotation {
  final String type; // 'arpeggiate' ou 'non-arpeggiate'
  final String? direction; // 'up', 'down' (pour arpeggiate)
  final String? placement; // 'top', 'bottom' (pour non-arpeggiate)

  /// v2c-32d : index du pitch dans l'accord auquel ce marqueur s'applique.
  final int pitchIndex;

  /// v2c-32e : attribut MusicXML `number`.
  /// Regroupe plusieurs marqueurs (éventuellement sur des voix/portées
  /// différentes) en UN SEUL arpège visuel. Défaut = 1.
  final int number;

  const ArpeggiateNotation({
    required this.type, 
    this.direction, 
    this.placement,
    this.pitchIndex = 0,
    this.number = 1,
  });
}

class AccidentalMark {
  final String type; // 'double-sharp', 'natural', 'flat', etc.
  final String placement; // 'above', 'below'
  const AccidentalMark({required this.type, this.placement = 'above'});
}

class OrnamentNotation {
  final String type; // 'trill-mark', 'turn', 'wavy-line', etc.
  final String placement; // 'above' ou 'below'
  final String? wavyLineType; // 'start', 'continue', 'stop'
  
  const OrnamentNotation({
    required this.type,
    this.placement = 'above',
    this.wavyLineType,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// v2c-100 : TECHNICAL (Doigtés, Archets, Harmoniques, etc.)
// v2c-116 : Ajout de `attributes` pour compatibilité 110% MusicXML.
// ═══════════════════════════════════════════════════════════════════════════
class TechnicalNotation {
  final String type; // 'up-bow', 'fingering', 'harmonic', etc.
  final String? text; // '1', 'a', 'T' pour les doigtés/plucks
  final String placement; // 'above', 'below'
  final bool substitution;
  final bool alternate;
  final String? harmonicType;
  
  /// v2c-116 : Capture DYNAMIQUE de tous les attributs XML.
  /// Exemples :
  /// - <arrow direction="up"/> → {'direction': 'up'}
  /// - <hole closed="yes"/>    → {'closed': 'yes'}
  /// - <handbell sounding="lift"/> → {'sounding': 'lift'}
  final Map<String, String> attributes;

  const TechnicalNotation({
    required this.type,
    this.text,
    this.placement = 'above',
    this.substitution = false,
    this.alternate = false,
    this.harmonicType,
    this.attributes = const {},
  });
}

class NoteNotations {
  final List<FermataNotation> fermatas;
  final List<ArpeggiateNotation> arpeggiates;
  final List<AccidentalMark> accidentalMarks;
  final List<OrnamentNotation> ornaments;
  final List<TechnicalNotation> technicals;

  const NoteNotations({
    this.fermatas = const [],
    this.arpeggiates = const [],
    this.accidentalMarks = const [],
    this.ornaments = const [],
    this.technicals = const [],
  });

  bool get isEmpty => fermatas.isEmpty && arpeggiates.isEmpty && accidentalMarks.isEmpty && ornaments.isEmpty && technicals.isEmpty;
  bool get isNotEmpty => !isEmpty;
}