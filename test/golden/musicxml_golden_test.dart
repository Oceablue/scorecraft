// test/golden/musicxml_golden_test.dart
// ============================================================================
// GOLDEN TESTS MUSICXML — v2c-98b
// ============================================================================
// Pour chaque fichier .xml / .musicxml dans test/golden/fixtures/, on :
//   1. Parse le XML avec le vrai pipeline (MusicXmlParser).
//   2. Calcule le layout avec le vrai LayoutEngine.
//   3. Rend avec le vrai StaffRenderer dans un PictureRecorder.
//   4. Compare au PNG de référence dans test/golden/goldens/.
//
// Premier run : --update-goldens crée les goldens.
// Runs suivants : comparaison pixel-à-pixel avec tolérance 2 %.
// Échec : écrit test/golden/failures/NNx.png avec les pixels divergents
//         en rouge.
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scorecraft/models/layout/layout_models.dart';
import 'package:scorecraft/models/score/score_document.dart';
import 'package:scorecraft/renderer/staff_renderer.dart';
import 'package:scorecraft/services/layout/layout_engine.dart';
import 'package:scorecraft/services/parsers/music_xml_parser.dart';
import 'package:scorecraft/services/smufl/smufl.dart';
import 'package:scorecraft/services/smufl/smufl_metrics.dart';
import 'package:scorecraft/utils/constants.dart';

import 'golden_comparator.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // SETUP GLOBAL
  // ══════════════════════════════════════════════════════════════════════
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Charge les tables SMuFL (glyphes + bbox/anchors).
    await Smufl.load();
    await SmuflMetrics.load();

    // Installe le comparator pixel-à-pixel avec tolérance 2 %.
    goldenFileComparator = PixelGoldenComparator(
      Directory.current.uri,
      maxDiffPercent: 2.0,
    );
  });

  // ══════════════════════════════════════════════════════════════════════
  // DÉCOUVERTE DES FIXTURES
  // ══════════════════════════════════════════════════════════════════════
  final fixturesDir = Directory('test/golden/fixtures');
  if (!fixturesDir.existsSync()) {
    test('fixtures directory missing', () {
      fail('Crée test/golden/fixtures/ et dépose-y des fichiers .xml '
          'ou .musicxml.');
    });
    return;
  }

  // v2c-98b : accepte .xml ET .musicxml.
  final fixtures = fixturesDir
      .listSync()
      .whereType<File>()
      .where((f) {
        final p = f.path.toLowerCase();
        return p.endsWith('.xml') || p.endsWith('.musicxml');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (fixtures.isEmpty) {
    test('no fixtures found', () {
      fail('Aucun .xml / .musicxml dans test/golden/fixtures/. '
          'Dépose 23e, 24a…24h.');
    });
    return;
  }

  // ══════════════════════════════════════════════════════════════════════
  // 1 TEST PAR FIXTURE
  // ══════════════════════════════════════════════════════════════════════
  for (final fixture in fixtures) {
    // v2c-98b : supporte .xml ET .musicxml.
    // Ex: "31a-Directions.musicxml" → "31a-Directions"
    final String name = fixture.uri.pathSegments.last
        .replaceAll('.musicxml', '')
        .replaceAll('.xml', '');

    testWidgets('golden: $name', (tester) async {
      await tester.runAsync(() async {
        // 1. Parse
        final xmlString = await fixture.readAsString();
        final ScoreDocument doc = MusicXmlParser.parseString(xmlString);

        // 2. Layout
        final double usableWidth =
            doc.pageWidth - doc.marginLeft - doc.marginRight;
        final List<LayoutedSystem> systems = LayoutEngine.computeLayout(
          doc,
          usableWidth,
          startY: 100.0, // v2c-25b : marge top pour les paroles/directions above
        );

        // 3. Calcul de la hauteur du canvas
        final int width = doc.pageWidth.toInt();
        final int height = _computeHeight(systems, doc);

        // 4. Rendu
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(
          recorder,
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..color = Colors.white,
        );
        StaffRenderer.drawScore(canvas, doc, systems);
        final ui.Picture picture = recorder.endRecording();
        final ui.Image image = await picture.toImage(width, height);
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        // 5. Comparaison
        await expectLater(
          bytes!.buffer.asUint8List(),
          matchesGoldenFile('test/golden/goldens/$name.png'),
        );
      });
    });
  }
}

// ============================================================================
// CALCUL DE LA HAUTEUR DU CANVAS
// ============================================================================

int _computeHeight(List<LayoutedSystem> systems, ScoreDocument doc) {
  if (systems.isEmpty) return 400;

  final LayoutedSystem lastSystem = systems.last;

  // Overhang bottom : lyrics + directions du dernier système.
  double overhang = 0.0;
  for (final staff in lastSystem.staves) {
    final double h = LayoutEngine.computeBottomOverhang(
      measures: staff.measures,
      lineSpacing: ScoreCraftConstants.staffLineSpacing,
    );
    if (h > overhang) overhang = h;
  }

  final double height = lastSystem.yBottom + overhang + 60;
  return height.toInt().clamp(200, 2000);
}