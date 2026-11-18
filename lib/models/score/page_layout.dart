// lib/models/score/page_layout.dart
// ============================================================================
// MISE EN PAGE : DISPOSITION DES TEXTES ET ÉLÉMENTS GRAPHIQUES
// ============================================================================

// ============================================================================
// 1. ÉNUMÉRATIONS
// ============================================================================

/// Position du numéro de page sur la feuille
enum PageNumberPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  alternate, // recto-verso : droite sur pages impaires, gauche sur paires
}

/// Affichage des noms d'instruments
enum InstrumentNameDisplay {
  never,            // Jamais
  firstSystemOnly,  // Premier système uniquement
  everySystem,      // Chaque système
  everyPage,        // Chaque page (premier système de chaque page)
}

/// Style d'alignement du titre
enum TitleAlignment {
  left,
  center,
  right,
}

// ============================================================================
// 2. CLASSES DE CONFIGURATION
// ============================================================================

/// Regroupe les dimensions et marges d'une page
class PageDimensions {
  final double width;
  final double height;
  final double marginLeft;
  final double marginRight;
  final double marginTop;
  final double marginBottom;
  final double staffSpaceMm; // 1 interligne en millimètres

  const PageDimensions({
    this.width = 1200.33,
    this.height = 1696.72,
    this.marginLeft = 85.7143,
    this.marginRight = 85.7143,
    this.marginTop = 85.7143,
    this.marginBottom = 85.7143,
    this.staffSpaceMm = 1.75,
  });

  /// Largeur utile pour la musique (page - marges)
  double get usableWidth => width - marginLeft - marginRight;

  /// Hauteur utile pour la musique (page - marges)
  double get usableHeight => height - marginTop - marginBottom;

  PageDimensions copyWith({
    double? width,
    double? height,
    double? marginLeft,
    double? marginRight,
    double? marginTop,
    double? marginBottom,
    double? staffSpaceMm,
  }) {
    return PageDimensions(
      width: width ?? this.width,
      height: height ?? this.height,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      staffSpaceMm: staffSpaceMm ?? this.staffSpaceMm,
    );
  }
}

// ============================================================================
// 3. CONFIGURATION COMPLÈTE DE LA MISE EN PAGE
// ============================================================================

/// Configuration complète de la mise en page : positions des textes,
/// affichage des numéros de page, des noms d'instruments, etc.
class PageLayout {
  // ――― Dimensions et marges (déléguées à PageDimensions) ―――――――――――――――――――――――――

  final PageDimensions dimensions;

  // ――― TITRE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double titleOffsetY;      // Décallage depuis marginTop (en pixels)
  final double titleFontSize;
  final TitleAlignment titleAlignment;
  final bool titleBold;

  // ――― SOUS-TITRE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double subtitleOffsetY;   // Décallage depuis titleOffsetY (en pixels)
  final double subtitleFontSize;
  final bool subtitleBold;

  // ――― COMPOSITEUR ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double composerOffsetX;   // Décallage depuis la droite (en pixels)
  final double composerOffsetY;   // Décallage depuis marginTop (en pixels)
  final double composerFontSize;
  final bool composerItalic;

  // ――― PAROLIER ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double lyricistOffsetX;   // Décallage depuis marginLeft (en pixels)
  final double lyricistOffsetY;   // Décallage depuis composerOffsetY (en pixels)
  final double lyricistFontSize;
  final bool lyricistItalic;

  // ――― ARRANGEUR ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double arrangerOffsetX;   // Décallage depuis marginLeft (en pixels)
  final double arrangerOffsetY;   // Décallage depuis lyricistOffsetY (en pixels)
  final double arrangerFontSize;
  final bool arrangerItalic;

  // ――― COPYRIGHT ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double copyrightOffsetY;  // Décallage depuis marginBottom (vers le haut)
  final double copyrightFontSize;
  final bool copyrightCentered;

  // ――― COMMENTAIRE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final double commentOffsetX;    // Décallage depuis marginLeft
  final double commentOffsetY;    // Décallage depuis marginTop
  final double commentFontSize;
  final String? commentText;      // Texte libre (ex: "à Jeanne")

  // ――― NUMÉROS DE PAGE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final bool showPageNumbers;
  final PageNumberPosition pageNumberPosition;
  final double pageNumberOffsetY;  // Décallage depuis marginTop ou marginBottom
  final double pageNumberFontSize;

  // ――― NOMS D'INSTRUMENTS ―――――――――――――――――――――――――――――――――――――――――――――――――――――――

  final bool showInstrumentNames;
  final InstrumentNameDisplay instrumentNameDisplay;
  final double instrumentNameOffsetX; // Décallage avant la portée (en pixels)
  final double instrumentNameFontSize;
  final bool instrumentNameItalic;

  // ――― CRÉDITS (issus du parsing XML) ―――――――――――――――――――――――――――――――――――――――――

  /// Crédits (titre, sous-titre, compositeur, parolier, copyright...)
  /// Chaque entrée a pour clé le type (ex: "title") et pour valeur un Map
  /// contenant : text, x, y, justify, fontSize, valign.
  final Map<String, Map<String, dynamic>> credits;

  // ==========================================================================
  // CONSTRUCTEUR
  // ==========================================================================

  const PageLayout({
    required this.dimensions,
    this.titleOffsetY = 10.0,
    this.titleFontSize = 22.0,
    this.titleAlignment = TitleAlignment.center,
    this.titleBold = true,
    this.subtitleOffsetY = 28.0,
    this.subtitleFontSize = 14.0,
    this.subtitleBold = false,
    this.composerOffsetX = 0.0,
    this.composerOffsetY = 60.0,
    this.composerFontSize = 13.0,
    this.composerItalic = true,
    this.lyricistOffsetX = 0.0,
    this.lyricistOffsetY = 20.0,
    this.lyricistFontSize = 12.0,
    this.lyricistItalic = true,
    this.arrangerOffsetX = 0.0,
    this.arrangerOffsetY = 18.0,
    this.arrangerFontSize = 12.0,
    this.arrangerItalic = true,
    this.copyrightOffsetY = 20.0,
    this.copyrightFontSize = 9.0,
    this.copyrightCentered = true,
    this.commentOffsetX = 0.0,
    this.commentOffsetY = 0.0,
    this.commentFontSize = 12.0,
    this.commentText,
    this.showPageNumbers = true,
    this.pageNumberPosition = PageNumberPosition.bottomCenter,
    this.pageNumberOffsetY = 15.0,
    this.pageNumberFontSize = 10.0,
    this.showInstrumentNames = true,
    this.instrumentNameDisplay = InstrumentNameDisplay.firstSystemOnly,
    this.instrumentNameOffsetX = 10.0,
    this.instrumentNameFontSize = 11.0,
    this.instrumentNameItalic = true,
    this.credits = const {},
  });

  // ==========================================================================
  // RACCOURCIS VERS PageDimensions (pour compatibilité)
  // ==========================================================================

  double get pageWidth => dimensions.width;
  double get pageHeight => dimensions.height;
  double get marginLeft => dimensions.marginLeft;
  double get marginRight => dimensions.marginRight;
  double get marginTop => dimensions.marginTop;
  double get marginBottom => dimensions.marginBottom;
  double get staffSpaceMm => dimensions.staffSpaceMm;

  // ==========================================================================
  // COPY WITH (IMMUTABILITÉ)
  // ==========================================================================

  PageLayout copyWith({
    PageDimensions? dimensions,
    double? titleOffsetY,
    double? titleFontSize,
    TitleAlignment? titleAlignment,
    bool? titleBold,
    double? subtitleOffsetY,
    double? subtitleFontSize,
    bool? subtitleBold,
    double? composerOffsetX,
    double? composerOffsetY,
    double? composerFontSize,
    bool? composerItalic,
    double? lyricistOffsetX,
    double? lyricistOffsetY,
    double? lyricistFontSize,
    bool? lyricistItalic,
    double? arrangerOffsetX,
    double? arrangerOffsetY,
    double? arrangerFontSize,
    bool? arrangerItalic,
    double? copyrightOffsetY,
    double? copyrightFontSize,
    bool? copyrightCentered,
    double? commentOffsetX,
    double? commentOffsetY,
    double? commentFontSize,
    String? commentText,
    bool? showPageNumbers,
    PageNumberPosition? pageNumberPosition,
    double? pageNumberOffsetY,
    double? pageNumberFontSize,
    bool? showInstrumentNames,
    InstrumentNameDisplay? instrumentNameDisplay,
    double? instrumentNameOffsetX,
    double? instrumentNameFontSize,
    bool? instrumentNameItalic,
    Map<String, Map<String, dynamic>>? credits,
  }) {
    return PageLayout(
      dimensions: dimensions ?? this.dimensions,
      titleOffsetY: titleOffsetY ?? this.titleOffsetY,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titleAlignment: titleAlignment ?? this.titleAlignment,
      titleBold: titleBold ?? this.titleBold,
      subtitleOffsetY: subtitleOffsetY ?? this.subtitleOffsetY,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleBold: subtitleBold ?? this.subtitleBold,
      composerOffsetX: composerOffsetX ?? this.composerOffsetX,
      composerOffsetY: composerOffsetY ?? this.composerOffsetY,
      composerFontSize: composerFontSize ?? this.composerFontSize,
      composerItalic: composerItalic ?? this.composerItalic,
      lyricistOffsetX: lyricistOffsetX ?? this.lyricistOffsetX,
      lyricistOffsetY: lyricistOffsetY ?? this.lyricistOffsetY,
      lyricistFontSize: lyricistFontSize ?? this.lyricistFontSize,
      lyricistItalic: lyricistItalic ?? this.lyricistItalic,
      arrangerOffsetX: arrangerOffsetX ?? this.arrangerOffsetX,
      arrangerOffsetY: arrangerOffsetY ?? this.arrangerOffsetY,
      arrangerFontSize: arrangerFontSize ?? this.arrangerFontSize,
      arrangerItalic: arrangerItalic ?? this.arrangerItalic,
      copyrightOffsetY: copyrightOffsetY ?? this.copyrightOffsetY,
      copyrightFontSize: copyrightFontSize ?? this.copyrightFontSize,
      copyrightCentered: copyrightCentered ?? this.copyrightCentered,
      commentOffsetX: commentOffsetX ?? this.commentOffsetX,
      commentOffsetY: commentOffsetY ?? this.commentOffsetY,
      commentFontSize: commentFontSize ?? this.commentFontSize,
      commentText: commentText ?? this.commentText,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      pageNumberPosition: pageNumberPosition ?? this.pageNumberPosition,
      pageNumberOffsetY: pageNumberOffsetY ?? this.pageNumberOffsetY,
      pageNumberFontSize: pageNumberFontSize ?? this.pageNumberFontSize,
      showInstrumentNames: showInstrumentNames ?? this.showInstrumentNames,
      instrumentNameDisplay: instrumentNameDisplay ?? this.instrumentNameDisplay,
      instrumentNameOffsetX: instrumentNameOffsetX ?? this.instrumentNameOffsetX,
      instrumentNameFontSize: instrumentNameFontSize ?? this.instrumentNameFontSize,
      instrumentNameItalic: instrumentNameItalic ?? this.instrumentNameItalic,
      credits: credits ?? this.credits,
    );
  }
}