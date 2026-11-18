// lib/widgets/top_menu_bar.dart
// ============================================================================
// BARRE DE MENUS SUPÉRIEURE – VERSION HYBRIDE (HOVER + CLIC)
// ============================================================================
// Comportement :
//   - Survol : ouverture après 300ms, surbrillance active.
//   - Sortie : fermeture après 200ms si non épinglé ET souris hors du menu.
//   - Clic : épingle/désépingle le menu (persistant).
//   - Clic extérieur : ferme les menus épinglés.
//   - Navigation horizontale fluide entre titres.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';


class TopMenuBar extends StatefulWidget {
  const TopMenuBar({super.key});

  @override
  State<TopMenuBar> createState() => _TopMenuBarState();
}

class _TopMenuBarState extends State<TopMenuBar> {
  String? _hoveredTitle;
  String? _pinnedTitle;
  String? _openTitle;

  Timer? _hoverTimer;
  Timer? _closeTimer;

  bool _isMouseOverMenu = false;

  OverlayEntry? _overlayEntry;

  final Map<String, GlobalKey> _titleKeys = {};
  final Map<String, Offset> _titlePositions = {};
  final Map<String, double> _titleWidths = {};

  final Map<String, List<PopupMenuItem<String>>> _menuItems = {
    'Fichier': [
      const PopupMenuItem(value: 'Nouveau', child: Text('Nouveau')),
      const PopupMenuItem(value: 'Ouvrir', child: Text('Ouvrir')),
      const PopupMenuItem(value: 'Enregistrer', child: Text('Enregistrer')),
      const PopupMenuItem(value: 'Enregistrer sous', child: Text('Enregistrer sous')),
      const PopupMenuItem(value: 'Importer', child: Text('Importer')),
      const PopupMenuItem(value: 'Exporter', child: Text('Exporter')),
      const PopupMenuItem(value: 'Imprimer', child: Text('Imprimer')),
      const PopupMenuItem(value: 'Accueil', child: Text('Accueil')),
      const PopupMenuItem(value: 'Quitter', child: Text('Quitter')),
    ],
    'Édition': [
      const PopupMenuItem(value: 'Annuler', child: Text('Annuler')),
      const PopupMenuItem(value: 'Rétablir', child: Text('Rétablir')),
      const PopupMenuItem(value: 'Couper', child: Text('Couper')),
      const PopupMenuItem(value: 'Copier', child: Text('Copier')),
      const PopupMenuItem(value: 'Coller', child: Text('Coller')),
      const PopupMenuItem(value: 'Supprimer', child: Text('Supprimer')),
      const PopupMenuItem(value: 'Sélectionner', child: Text('Sélectionner')),
      const PopupMenuItem(value: 'Micro-déplacement', child: Text('Micro-déplacement')),
    ],
    'Affichage': [
      const PopupMenuItem(value: 'Zoom', child: Text('Zoom')),
      const PopupMenuItem(value: 'Mode de vue', child: Text('Mode de vue')),
      const PopupMenuItem(value: 'Repères', child: Text('Repères')),
      const PopupMenuItem(value: 'Mode Focus (F11)', child: Text('Mode Focus (F11)')),
    ],
    'Insertion': [
      const PopupMenuItem(value: 'Page', child: Text('Page')),
      const PopupMenuItem(value: 'Système', child: Text('Système')),
      const PopupMenuItem(value: 'Portée', child: Text('Portée')),
      const PopupMenuItem(value: 'Clef', child: Text('Clef')),
      const PopupMenuItem(value: 'Armure', child: Text('Armure')),
      const PopupMenuItem(value: 'Chiffrage de mesure', child: Text('Chiffrage de mesure')),
    ],
    'Notes': [
      const PopupMenuItem(value: 'Déplacement de hauteur', child: Text('Déplacement de hauteur')),
      const PopupMenuItem(value: 'Attributs de note', child: Text('Attributs de note')),
      const PopupMenuItem(value: 'Transposer...', child: Text('Transposer...')),
      const PopupMenuItem(value: 'Durées & Figures', child: Text('Durées & Figures')),
      const PopupMenuItem(value: 'Hampes', child: Text('Hampes')),
      const PopupMenuItem(value: 'Liaisons', child: Text('Liaisons')),
      const PopupMenuItem(value: 'Altérations', child: Text('Altérations')),
      const PopupMenuItem(value: 'Alignement & Espacement', child: Text('Alignement & Espacement')),
    ],
    'Fenêtre': [
      const PopupMenuItem(value: 'Palettes', child: Text('Palettes')),
      const PopupMenuItem(value: 'Tout afficher', child: Text('Tout afficher')),
      const PopupMenuItem(value: 'Tout masquer', child: Text('Tout masquer')),
      const PopupMenuItem(value: 'Réinitialiser', child: Text('Réinitialiser')),
      const PopupMenuItem(value: 'Paramètres', child: Text('Paramètres')),
    ],
    'Aide': [
      const PopupMenuItem(value: 'Manuel', child: Text('Manuel')),
      const PopupMenuItem(value: 'Raccourcis', child: Text('Raccourcis')),
      const PopupMenuItem(value: 'À propos', child: Text('À propos')),
    ],
  };

  List<String> get _menuTitles => _menuItems.keys.toList();

  @override
  void initState() {
    super.initState();
    for (final title in _menuTitles) {
      _titleKeys[title] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _closeTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  // ========================================================================
  // OUVERTURE / FERMETURE
  // ========================================================================

  void _showMenu(String title, Offset globalPosition) {
    _removeOverlay();

    final titleRenderBox =
        _titleKeys[title]!.currentContext!.findRenderObject() as RenderBox?;
    final titleWidth = titleRenderBox?.size.width ?? 100.0;
    _titleWidths[title] = titleWidth;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Barrière transparente LIMITÉE à la zone sous la barre de menus
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleOutsideTap,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Zone tampon transparente (hauteur 32 px, largeur du titre)
          Positioned(
            left: globalPosition.dx,
            top: globalPosition.dy,
            width: titleWidth,
            height: 32,
            child: MouseRegion(
              opaque: false,
              onEnter: (_) => _onMenuEnter(),
              onExit: (_) => _onMenuExit(),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Le menu déroulant (32 px plus bas)
          Positioned(
            left: globalPosition.dx,
            top: globalPosition.dy + 32,
            child: MouseRegion(
              onEnter: (_) => _onMenuEnter(),
              onExit: (_) => _onMenuExit(),
              child: _buildMenuPanelContent(title),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
    setState(() => _openTitle = title);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_openTitle != null) {
      setState(() => _openTitle = null);
    }
  }

  void _closeMenu() {
    if (_pinnedTitle == null && _openTitle != null) {
      _removeOverlay();
    }
  }

  void _handleOutsideTap() {
    _pinnedTitle = null;
    _closeMenu();
  }

  // ========================================================================
  // ÉVÉNEMENTS SOURIS
  // ========================================================================

  void _onTitleEnter(String title) {
    _hoveredTitle = title;
    _closeTimer?.cancel();

    if (_pinnedTitle == null) {
      _removeOverlay();
    }

    if (_pinnedTitle != null) return;

    _titlePositions[title] = _getTitlePosition(title);
    final renderBox =
        _titleKeys[title]!.currentContext!.findRenderObject() as RenderBox?;
    _titleWidths[title] = renderBox?.size.width ?? 100.0;

    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 300), () {
      if (_hoveredTitle == title && _pinnedTitle == null) {
        _showMenu(title, _titlePositions[title]!);
      }
    });
  }

  void _onTitleExit(String title) {
    _hoveredTitle = null;
    _hoverTimer?.cancel();

    if (_pinnedTitle == null) {
      _scheduleClose();
    }
  }

  void _onMenuEnter() {
    _isMouseOverMenu = true;
    _closeTimer?.cancel();
  }

  void _onMenuExit() {
    _isMouseOverMenu = false;
    if (_pinnedTitle == null) {
      _scheduleClose();
    }
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 200), () {
      if (_pinnedTitle == null && !_isMouseOverMenu) {
        _closeMenu();
      }
    });
  }

  void _togglePin(String title) {
    _hoverTimer?.cancel();
    _closeTimer?.cancel();

    if (_pinnedTitle == title) {
      _pinnedTitle = null;
      _removeOverlay();
    } else {
      _pinnedTitle = title;
      final position = _titlePositions[title] ?? _getTitlePosition(title);
      _showMenu(title, position);
    }
    setState(() {});
  }

  Offset _getTitlePosition(String title) {
    final renderBox =
        _titleKeys[title]!.currentContext!.findRenderObject() as RenderBox;
    return renderBox.localToGlobal(Offset.zero);
  }

void _onMenuItemSelected(String title, String value) {
  _pinnedTitle = null;
  _removeOverlay();

  // Cas spécial : retour à l'accueil
  if (value == 'Accueil') {
    // On vide la pile de navigation pour revenir au dashboard
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    return;
  }

  // Pour les autres items : affichage d'un SnackBar (à remplacer plus tard par de vraies actions)
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$title → $value'),
      duration: const Duration(seconds: 1),
    ),
  );
}

  // ========================================================================
  // INTERFACE
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildDirectButton(context),
          const SizedBox(width: 16),
          ..._menuTitles.map((title) => _buildMenu(context, title)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            color: Colors.indigo.shade700,
            tooltip: 'Lecture / Pause (Espace)',
            onPressed: () => _showSnackBar(context, 'Playback'),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectButton(BuildContext context) {
    return InkWell(
      onTap: () => _showSnackBar(context, 'Ouvrir le wizard de la partition'),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 18, color: Colors.indigo.shade700),
            const SizedBox(width: 6),
            Text(
              'Ma partition',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.indigo.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, String title) {
    final bool isActive = _openTitle == title;
    final bool isPinned = _pinnedTitle == title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MouseRegion(
        onEnter: (_) => _onTitleEnter(title),
        onExit: (_) => _onTitleExit(title),
        child: GestureDetector(
          key: _titleKeys[title],
          behavior: HitTestBehavior.opaque,
          onTap: () => _togglePin(title),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.indigo.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? Colors.indigo.shade700 : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 20,
                  child: Icon(
                    isPinned ? Icons.push_pin : Icons.arrow_drop_down,
                    size: 16,
                    color: isPinned
                        ? Colors.amber.shade700
                        : (isActive ? Colors.indigo.shade700 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuPanelContent(String title) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _menuItems[title]!.map((item) {
            return InkWell(
              onTap: () => _onMenuItemSelected(title, item.value!),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: item.child ?? const SizedBox.shrink()),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}