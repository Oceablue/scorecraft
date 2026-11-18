// test/golden/golden_comparator.dart
// ============================================================================
// COMPARATEUR GOLDEN AVEC TOLÉRANCE PIXEL — v2c-98
// ============================================================================
// Remplace le GoldenFileComparator par défaut (qui est byte-exact, trop
// strict pour du rendu antialiasing-dependent).
//
// POLITIQUE :
//   - Compare pixel-à-pixel (RGBA brut).
//   - Un pixel est "différent" si |ΔR| + |ΔG| + |ΔB| > 30 (tolère les
//     variations d'anti-aliasing marginales).
//   - Le test échoue si > [maxDiffPercent] % de pixels diffèrent.
//   - En cas d'échec, écrit un PNG de diff dans `failures/` (rouge = pixel
//     qui diverge, blanc = pixel identique).
//   - Si le golden n'existe pas encore, il est créé silencieusement
//     (premier run).
// ============================================================================

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PixelGoldenComparator extends GoldenFileComparator {
  /// Répertoire racine utilisé pour résoudre les chemins relatifs.
  /// En pratique : `Directory.current.uri` (la racine du projet).
  final Uri baseDir;

  /// Seuil au-delà duquel le test échoue, en % de pixels différents.
  /// 2.0 = tolérance raisonnable pour l'anti-aliasing.
  final double maxDiffPercent;

  PixelGoldenComparator(this.baseDir, {this.maxDiffPercent = 2.0});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenFile = File((await getGoldenFile(golden)).path);

    // Première exécution : on crée le golden.
    if (!await goldenFile.exists()) {
      await goldenFile.parent.create(recursive: true);
      await goldenFile.writeAsBytes(imageBytes);
      debugPrint('[golden] CRÉÉ : ${golden.path}');
      return true;
    }

    final goldenBytes = await goldenFile.readAsBytes();
    final diff = await _computeDiff(imageBytes, goldenBytes, golden);

    if (diff == null) {
      debugPrint('[golden] ÉCHEC (${golden.path}) — dimensions différentes');
      return false;
    }

    if (diff.diffPercent <= maxDiffPercent) {
      debugPrint('[golden] OK    (${golden.path}) — '
          'diff=${diff.diffPercent.toStringAsFixed(3)}% '
          '(< ${maxDiffPercent.toStringAsFixed(1)}%)');
      return true;
    }

    debugPrint('[golden] ÉCHEC (${golden.path}) — '
        'diff=${diff.diffPercent.toStringAsFixed(2)}% '
        '> ${maxDiffPercent.toStringAsFixed(1)}%');
    debugPrint('         diff image : ${diff.diffPath}');
    return false;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final goldenFile = File((await getGoldenFile(golden)).path);
    await goldenFile.parent.create(recursive: true);
    await goldenFile.writeAsBytes(imageBytes);
    debugPrint('[golden] MIS À JOUR : ${golden.path}');
  }

  @override
  Future<File> getGoldenFile(Uri golden) async {
    return File.fromUri(baseDir.resolveUri(golden));
  }

  // ==========================================================================
  // COMPARAISON PIXEL
  // ==========================================================================

  Future<_DiffResult?> _computeDiff(
    Uint8List actualBytes,
    Uint8List goldenBytes,
    Uri golden,
  ) async {
    final actual = await _decode(actualBytes);
    final goldenImg = await _decode(goldenBytes);

    if (actual.width != goldenImg.width ||
        actual.height != goldenImg.height) {
      debugPrint('[golden] ${actual.width}×${actual.height} '
          'vs ${goldenImg.width}×${goldenImg.height}');
      return null;
    }

    final actualData = await actual.toByteData(format: ui.ImageByteFormat.rawRgba);
    final goldenData = await goldenImg.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (actualData == null || goldenData == null) return null;

    final a = actualData.buffer.asUint8List();
    final b = goldenData.buffer.asUint8List();

    final w = actual.width;
    final h = actual.height;
    final totalPixels = w * h;

    // Canvas pour le diff.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = Colors.white,
    );

    final redPaint = Paint()..color = const Color(0xFFFF0000);

    int diffCount = 0;
    for (int i = 0; i < totalPixels; i++) {
      final off = i * 4;
      final dr = (a[off]     - b[off]).abs();
      final dg = (a[off + 1] - b[off + 1]).abs();
      final db = (a[off + 2] - b[off + 2]).abs();
      if (dr + dg + db > 30) {
        diffCount++;
        final x = (i % w).toDouble();
        final y = (i ~/ w).toDouble();
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), redPaint);
      }
    }

    final diffPercent = diffCount * 100.0 / totalPixels;

    // Écriture du diff (seulement si on a des différences).
    final diffFileName = golden.path.split('/').last;
    final diffPath = baseDir
        .resolve('test/golden/failures/$diffFileName')
        .toFilePath();
    if (diffCount > 0) {
      final picture = recorder.endRecording();
      final diffImage = await picture.toImage(w, h);
      final diffPng =
          await diffImage.toByteData(format: ui.ImageByteFormat.png);
      if (diffPng != null) {
        final diffFile = File(diffPath);
        await diffFile.parent.create(recursive: true);
        await diffFile.writeAsBytes(diffPng.buffer.asUint8List());
      }
    }

    return _DiffResult(diffPercent: diffPercent, diffPath: diffPath);
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _DiffResult {
  final double diffPercent;
  final String diffPath;

  _DiffResult({required this.diffPercent, required this.diffPath});
}