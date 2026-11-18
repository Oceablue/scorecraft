// lib/views/editor/editor_view.dart
// ============================================================================
// ÉDITEUR PRINCIPAL : AFFICHE LA PARTITION ET LES OUTILS
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../models/score/score_document.dart';
import '../../models/score/page_layout.dart';
import '../../models/layout/layout_models.dart';
import '../../services/layout/layout_engine.dart';
import '../../renderer/staff_renderer.dart';
import '../../renderer/painters/structure_painter.dart';
import '../../utils/constants.dart';
import '../../utils/music_text_style.dart';

import '../../widgets/top_menu_bar.dart';
import '../../widgets/main_toolbar.dart';
import '../../widgets/note_palette.dart';

import 'editor_controller.dart';

// ============================================================================
// PART 1 : WIDGET PRINCIPAL
// ============================================================================

class EditorView extends StatefulWidget {
  final ScoreDocument scoreDocument;
  const EditorView({super.key, required this.scoreDocument});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  late EditorController _controller;
  late List<LayoutedSystem> _systems;
  ScoreDocument? _currentDocument;
  final GlobalKey _canvasKey = GlobalKey();
  double _canvasHeight = 0;
  double _headerHeight = 220.0;

  bool _showPaletteNotes = true;

  // ==========================================================================
  // RECALCUL DU LAYOUT
  // ==========================================================================

  void _recomputeLayout() {
    if (_currentDocument != null) {
      final pageLayout = _currentDocument!.pageLayout;

      _headerHeight = StructurePainter.computeHeaderHeight(pageLayout);

      final usableWidth =
          pageLayout.pageWidth - pageLayout.marginLeft - pageLayout.marginRight;

      _systems = LayoutEngine.computeLayout(
        _currentDocument!,
        usableWidth,
        startY: 20,
      );

      _canvasHeight = _computeTotalCanvasHeight(_systems, pageLayout);
    } else {
      _systems = [];
      _canvasHeight = 0;
      _headerHeight = 220.0;
    }
  }

    double _computeTotalCanvasHeight(
    List<LayoutedSystem> systems,
    PageLayout pageLayout,
  ) {
    if (systems.isEmpty) return 400;

    final lastSystem = systems.last;

    double overhang = 0;
    for (final staff in lastSystem.staves) {
      final h = LayoutEngine.computeBottomOverhang(
        measures: staff.measures,
        lineSpacing: ScoreCraftConstants.staffLineSpacing,
      );
      if (h > overhang) overhang = h;
    }

    final total = lastSystem.yBottom + overhang + 60;
    return math.max(total, 400);
  }

  // ==========================================================================
  // CYCLE DE VIE
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _controller = EditorController();
    _currentDocument = widget.scoreDocument;
    _recomputeLayout();

    _controller.setOnLayoutRequested(() {
      final updatedDoc = _controller.document;
      if (updatedDoc != null) {
        _currentDocument = updatedDoc;
      }
      _recomputeLayout();
      _controller.restoreSelectionAfterLayout(_systems);
      setState(() {});
    });

    _controller.setDocument(widget.scoreDocument);
  }

  @override
  void didUpdateWidget(EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scoreDocument != widget.scoreDocument) {
      _currentDocument = widget.scoreDocument;
      _controller.setDocument(widget.scoreDocument);
      _recomputeLayout();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_systems.isEmpty && _currentDocument != null) {
      _recomputeLayout();
    }

    final docToRender = _currentDocument ?? widget.scoreDocument;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          const TopMenuBar(),
          const MainToolbar(),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        primary: true,
                        scrollDirection: Axis.vertical,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ---- HEADER (titre, compositeur, etc.) ----
                            SizedBox(
                              width: docToRender.pageLayout.pageWidth,
                              height: _headerHeight,
                              child: CustomPaint(
                                painter: _HeaderPainter(
                                  pageLayout: docToRender.pageLayout,
                                ),
                                size: Size(
                                  docToRender.pageLayout.pageWidth,
                                  _headerHeight,
                                ),
                              ),
                            ),

                            // ---- PARTITION ----
                            GestureDetector(
                              onPanDown: (details) {
                                final RenderBox? box = _canvasKey.currentContext
                                    ?.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final Offset localOffset =
                                    box.globalToLocal(details.globalPosition);

                                final LayoutedNote? hitNote =
                                    StaffRenderer.hitTest(localOffset);
                                if (hitNote != null) {
                                  _controller.selectNote(hitNote);
                                  _controller.startDrag(localOffset);
                                } else {
                                  _controller.clearSelection();
                                }
                                setState(() {});
                              },
                              onPanUpdate: (details) {
                                final RenderBox? box = _canvasKey.currentContext
                                    ?.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final Offset localOffset =
                                    box.globalToLocal(details.globalPosition);
                                _controller.updateDrag(localOffset);
                                setState(() {});
                              },
                              onPanEnd: (details) {
                                _controller.endDrag();
                              },
                              child: ClipRect( // <── v2c-32b : Empêche le débordement hors de la feuille
                                child: CustomPaint(
                                  key: _canvasKey,
                                  painter: _ScorePainter(
                                    document: docToRender,
                                    systems: _systems,
                                    selectedNote: _controller.selectedNote,
                                    dragOffsetY: _controller.dragOffsetY ?? 0.0,
                                  ),
                                  size: Size(
                                    docToRender.pageLayout.pageWidth, // <── Taille normale de la page
                                    math.max(400, _canvasHeight),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showPaletteNotes)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: NotePalette(
                      onToggleVisibility: () {
                        setState(() => _showPaletteNotes = !_showPaletteNotes);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PART 2 : CUSTOM PAINTER - SCORE
// ============================================================================

class _ScorePainter extends CustomPainter {
  final ScoreDocument document;
  final List<LayoutedSystem> systems;
  final LayoutedNote? selectedNote;
  final double dragOffsetY;

  const _ScorePainter({
    required this.document,
    required this.systems,
    this.selectedNote,
    required this.dragOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    StaffRenderer.drawScore(
      canvas,
      document,
      systems,
      selectedNote: selectedNote,
      dragOffsetY: dragOffsetY,
    );
  }

  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.systems != systems ||
        oldDelegate.selectedNote != selectedNote ||
        oldDelegate.dragOffsetY != dragOffsetY;
  }
}

// ============================================================================
// PART 3 : CUSTOM PAINTER - HEADER
// ============================================================================

class _HeaderPainter extends CustomPainter {
  final PageLayout pageLayout;

  const _HeaderPainter({required this.pageLayout});

  @override
  void paint(Canvas canvas, Size size) {
    // Fond blanc (séparation visuelle)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

final structurePainter = StructurePainter(
  scale: ScoreCraftConstants.scale,
  staffLineSpacing: ScoreCraftConstants.staffLineSpacing,
  clefStyle: MusicTextStyle.music(
    fontSize: 30,
    color: Colors.black,
  ),
  timeSigStyle: MusicTextStyle.music(
    fontSize: 20,
    color: Colors.black,
  ),
  linePaint: Paint()..color = Colors.black,
);

    structurePainter.drawCredits(canvas, pageLayout);
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter oldDelegate) {
    return oldDelegate.pageLayout != pageLayout;
  }
}