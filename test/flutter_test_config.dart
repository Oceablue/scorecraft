// test/flutter_test_config.dart
// ============================================================================
// CONFIGURATION GLOBALE DES TESTS — v2c-98
// ============================================================================
// Flutter utilise la police "Ahem" (carrés pleins) par défaut dans les
// tests. Sans charger explicitement Leland / LelandText, tous les goldens
// rendent des blocs noirs et ne servent à rien.
//
// De plus, LelandText ne contient pas forcément tous les caractères latins.
// On charge Arial pour servir de fallback aux paroles (texte).
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1. Polices musicales
  await _loadFont('Leland', 'assets/fonts/Leland.otf');
  await _loadFont('LelandText', 'assets/fonts/LelandText.otf');
  
  // 2. Police de secours pour le texte (paroles)
  // On charge Arial depuis le système. (Si tu es sur Mac, le chemin sera
  // '/System/Library/Fonts/Supplemental/Arial.ttf')
  await _loadFont('Arial', 'C:/Windows/Fonts/arial.ttf');

  await testMain();
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    // ignore: avoid_print
    print('[flutter_test_config] font introuvable : $path');
    return;
  }
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
  // ignore: avoid_print
  print('[flutter_test_config] font chargée : $family');
}