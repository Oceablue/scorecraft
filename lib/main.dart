// lib/main.dart
// ============================================================================
// POINT D'ENTRÉE DE L'APPLICATION SCORECRAFT — v2c-116
// ============================================================================
// v2c-116 : Ajout de `_checkTechnicalGlyphs()` exhaustif pour vérifier que TOUS
//           les glyphes SMuFL des techniques existent dans Leland.
// ============================================================================

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'services/smufl/smufl.dart';
import 'services/smufl/smufl_metrics.dart';
import 'views/dashboard/dashboard_view.dart';

const bool _debugSmuflMetrics = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Smufl.load();
  await SmuflMetrics.load();

  if (kDebugMode && _debugSmuflMetrics) {
    _runSmuflDiagnostics();
  }

  if (kDebugMode) {
    _checkOrnamentGlyphs();
    _checkDynamicGlyphs();
    _checkTechnicalGlyphs();
  }

  runApp(const ScoreCraftApp());
}

// ============================================================================
// v2c-99 : VÉRIFICATION DES GLYPHES D'ORNEMENTS
// ============================================================================
void _checkOrnamentGlyphs() {
  final glyphs = [
    'ornamentTurn', 'ornamentTurnInverted', 'ornamentTurnSlash',
    'ornamentMordent', 'ornamentMordentInverted', 'ornamentTrill',
    'ornamentSchleifer', 'ornamentHaydn', 'ornamentShake',
  ];

  print('════════════════════════════════════════════════════════════════');
  print('[v2c-99 DIAG] Vérification des glyphes d\'ornements dans SmuFL :');
  for (final name in glyphs) {
    print('  $name: ${Smufl.has(name)}');
  }
  print('════════════════════════════════════════════════════════════════');
}

// ============================================================================
// v2c-113 : VÉRIFICATION DES GLYPHES DE DYNAMIQUES
// ============================================================================
void _checkDynamicGlyphs() {
  final glyphs = <String>[
    'dynamicPiano', 'dynamicPP', 'dynamicPPP', 'dynamicPPPP', 'dynamicPPPPP', 'dynamicPPPPPP',
    'dynamicForte', 'dynamicFF', 'dynamicFFF', 'dynamicFFFF', 'dynamicFFFFF', 'dynamicFFFFFF',
    'dynamicMP', 'dynamicMF', 'dynamicFortePiano', 'dynamicPF', 'dynamicForzando',
    'dynamicSforzato', 'dynamicSforzandoPiano', 'dynamicSforzandoPianissimo', 
    'dynamicSforzatoPiano', 'dynamicSforzatoFF', 'dynamicRinforzando1', 
    'dynamicRinforzando2', 'dynamicNiente', 'dynamicMezzo', 'dynamicRinforzando', 
    'dynamicSforzando', 'dynamicZ',
  ];

  final missing = glyphs.where((g) => !Smufl.has(g)).toList();
  print('════════════════════════════════════════════════════════════════');
  if (missing.isEmpty) {
    print('[v2c-113 DIAG] Dynamiques : ${glyphs.length} glyphes OK.');
  } else {
    print('[v2c-113 DIAG] Dynamiques : ${missing.length} MANQUANT(S) → $missing');
  }
  print('════════════════════════════════════════════════════════════════');
}

// ============================================================================
// v2c-116 : VÉRIFICATION DES GLYPHES DE TECHNIQUES
// ============================================================================
void _checkTechnicalGlyphs() {
  final glyphs = <String>[
    // Clavier
    'keyboardPedalHeel1', 'keyboardPedalToe1',
    // Cordes / Archets
    'fingering0', 'stringsUpBow', 'stringsDownBow', 'stringsHarmonic',
    'stringsThumbPosition', 'pluckedSnapPizzicatoAbove', 'pluckedSnapPizzicatoBelow',
    'pluckedFingernailFlick',
    // Vents / Cuivres
    'doubleTongueAbove', 'doubleTongueBelow', 'tripleTongueAbove', 'tripleTongueBelow',
    'brassMuteClosed', 'brassMuteOpen', 'brassMuteHalf', 'brassHarmonMuteClosed',
    'brassBend', 'brassFlip', 'brassSmear', 'windOpenHole', 'windClosedHole',
    // Guitares / Percussions
    'guitarGolpe', 'guitarString0', 'guitarString1', 'guitarString2', 
    'guitarString3', 'guitarString4', 'guitarString5', 'guitarString6', 
    'guitarString7', 'guitarString8', 'guitarString9',
    // Cloches / Divers
    'handbell', 'arrowBlackUp', 'arrowBlackDown',
  ];

  final missing = glyphs.where((g) => !Smufl.has(g)).toList();
  print('════════════════════════════════════════════════════════════════');
  if (missing.isEmpty) {
    print('[v2c-116 DIAG] Techniques : ${glyphs.length} glyphes OK.');
  } else {
    print('[v2c-116 DIAG] Techniques : ${missing.length} MANQUANT(S) → $missing');
  }
  print('════════════════════════════════════════════════════════════════');
}

// ============================================================================
// DIAGNOSTIC DEBUG — v2c-96
// ============================================================================
void _runSmuflDiagnostics() {
  print('════════════════════════════════════════════════════════════════');
  print('[v2c-96 DIAG] valeurs brutes SMuFL — déjà en staff spaces (sp)');
  print('════════════════════════════════════════════════════════════════');

  void report(String name, {double? currentSp}) {
    final bbox = SmuflMetrics.bbox(name);
    if (bbox.isEmpty) { print('[v2c-96] $name : bbox ABSENT'); return; }
    final center = bbox.center;
    print('[v2c-96] $name');
    print('  bbox sp    : NE=${bbox.ne} SW=${bbox.sw}');
    print('  center sp  : $center');
    print('  halfW sp   : ${(bbox.ne.dx - center.dx).toStringAsFixed(3)}');
    print('  stemUpSE   : ${SmuflMetrics.anchor(name, "stemUpSE")}');
    print('  stemDownNW : ${SmuflMetrics.anchor(name, "stemDownNW")}');
  
  }

  report('noteheadBlack', currentSp: 0.65);
  report('noteheadHalf', currentSp: 0.65);
  report('noteheadWhole', currentSp: 0.75);
  
  print('════════════════════════════════════════════════════════════════');
}

class ScoreCraftApp extends StatelessWidget {
  const ScoreCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScoreCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DashboardView(),
    );
  }
}