// lib/models/events/lyric.dart
// ============================================================================
// PAROLES (LYRICS) — v2c-97
// ============================================================================
// Une parole est attachée à une note. Elle peut avoir :
//   - Un texte ("Bon", "jour", "-lé-", etc.)
//   - Un type syllabique ("single", "begin", "middle", "end")
//   - Un numéro de vers (1 = 1er couplet, 2 = 2e...)
//   - Une élision (caractère entre deux syllabes sur la même note)
//   - Une extension (mélisme : la syllabe s'étend sur plusieurs notes)
//   - Un placement (above / below)
//   - v2c-97 : Un alignement horizontal (justify : left / center / right)
//
// MusicXML :
//   <lyric number="1" placement="below" justify="left">
//     <syllabic>begin</syllabic>
//     <text>Bon</text>
//     <elision>‿</elision>
//     <text>jour</text>
//     <extend/>
//   </lyric>
// ============================================================================

/// Représente une syllabe de parole attachée à une note.
class Lyric {
  /// Texte de la syllabe (ex: "Bon", "jour").
  /// ⚠️ MusicXML permet plusieurs text> séparés par elision>.
  ///    Dans ce cas, `text` contient le PREMIER texte.
  ///    Les suivants sont dans `elisionTexts` (v2c-2, voir plus bas).
  final String text;

  /// Type syllabique :
  ///   - "single" : syllabe unique sur la note.
  ///   - "begin"  : début d'un mot (la suite est sur la note suivante).
  ///   - "middle" : milieu d'un mot.
  ///   - "end"    : fin d'un mot.
  final String syllabic;

  /// Numéro de vers (1 = 1er couplet, 2 = 2e, etc.).
  final int number;

  // ─── v2c-2 : CHAMPS SUPPLÉMENTAIRES ───────────────────────────────────────

  /// Élision : caractère inséré entre deux syllabes sur la même note.
  /// Ex : espace, tiret "-", demi-cercle "‿".
  /// Null si pas d'élision.
  final String? elision;

  /// v2c-2 : textes supplémentaires après l'élision.
  /// Ex : text>Bon /text>elision>‿/elision>text>jour/text>
  ///    → text = "Bon", elision = "‿", elisionTexts = ["jour"].
  final List<String> elisionTexts;

  /// v2c-2 : mélisme. La syllabe s'étend sur plusieurs notes.
  /// true si extend/> est présent dans le XML.
  final bool extend;

  /// v2c-2 : placement vertical. "above" ou "below".
  /// Par défaut, les paroles sont en dessous de la portée.
  final String placement;

  /// v2c-2 : format (verse, chorus, etc.). Optionnel, vient de lyric>.
  final String? format;

  /// v2c-2 : identifiant stable (pour undo/redo si besoin).
  /// Optionnel, peut rester null.
  final String? id;

  // ─── v2c-97 : ALIGNEMENT HORIZONTAL ──────────────────────────────────────

  /// Alignement horizontal spécifié dans le XML ("left", "center", "right").
  /// Null = "center" par défaut (spec MusicXML).
  /// ⚠️ Le moteur de rendu force "left" si `extend` est vrai et que
  /// `justify` est null (pour que le trait de mélisme soit propre).
  final String? justify;

  const Lyric({
    required this.text,
    this.syllabic = 'single',
    this.number = 1,
    this.elision,
    this.elisionTexts = const [],
    this.extend = false,
    this.placement = 'below',
    this.format,
    this.id,
    this.justify, // <--- v2c-97
  });

  // ─── GETTERS UTILITAIRES ─────────────────────────────────────────────────

  /// Vrai si la syllabe est un début de mot (à coller avec la suivante).
  bool get isBegin => syllabic == 'begin';

  /// Vrai si la syllabe est une fin de mot (à coller avec la précédente).
  bool get isEnd => syllabic == 'end';

  /// Vrai si la syllabe est unique (mot complet).
  bool get isSingle => syllabic == 'single';

  /// Vrai si c'est un mélisme (la syllabe s'étend sur plusieurs notes).
  bool get isMelisma => extend;

  /// Vrai si la parole est placée au-dessus de la portée.
  bool get isAbove => placement == 'above';

  /// Texte complet (avec élisions reconstituées).
  /// Ex : "Bonjour" si text="Bon", elision="", elisionTexts=["jour"].
  String get fullText {
    if (elisionTexts.isEmpty) return text;
    final buffer = StringBuffer(text);
    for (int i = 0; i < elisionTexts.length; i++) {
      if (elision != null) buffer.write(elision);
      buffer.write(elisionTexts[i]);
    }
    return buffer.toString();
  }

  // ─── COPY WITH ───────────────────────────────────────────────────────────

  Lyric copyWith({
    String? text,
    String? syllabic,
    int? number,
    String? elision,
    List<String>? elisionTexts,
    bool? extend,
    String? placement,
    String? format,
    String? id,
    String? justify, // <--- v2c-97
  }) {
    return Lyric(
      text: text ?? this.text,
      syllabic: syllabic ?? this.syllabic,
      number: number ?? this.number,
      elision: elision ?? this.elision,
      elisionTexts: elisionTexts ?? this.elisionTexts,
      extend: extend ?? this.extend,
      placement: placement ?? this.placement,
      format: format ?? this.format,
      id: id ?? this.id,
      justify: justify ?? this.justify, // <--- v2c-97
    );
  }

  @override
  String toString() {
    return 'Lyric("$text" [$syllabic, n°$number]'
        '${extend ? ", extend" : ""}'
        '${elisionTexts.isNotEmpty ? ", elision" : ""}'
        '${justify != null ? ", justify=$justify" : ""})';
  }
}