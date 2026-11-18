// lib/views/editor/widgets/main_toolbar.dart
// ============================================================================
// BARRE D'OUTILS PRINCIPALE
// ============================================================================

import 'package:flutter/material.dart';

class MainToolbar extends StatefulWidget {
  const MainToolbar({super.key});

  @override
  State<MainToolbar> createState() => _MainToolbarState();
}

class _MainToolbarState extends State<MainToolbar> {
  String _selectedTool = 'select';
  String _selectedDuration = 'quarter';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // ---- Outils ----
          _buildToolButton(context, Icons.arrow_forward, 'select', 'Sélection'),
          _buildToolButton(context, Icons.edit, 'pencil', 'Crayon'),
          _buildToolButton(context, Icons.delete_outline, 'eraser', 'Gomme'),
          _buildToolButton(context, Icons.zoom_in, 'zoom', 'Loupe'),
          const VerticalDivider(width: 16),

          // ---- Durées ----
          _buildDurationButton(context, 'Ronde', 'whole'),
          _buildDurationButton(context, 'Blanche', 'half'),
          _buildDurationButton(context, 'Noire', 'quarter'),
          _buildDurationButton(context, 'Croche', 'eighth'),
          _buildDurationButton(context, 'D-Croche', '16th'),

          const Spacer(),

          // ---- Focus Mode (F11) ----
          IconButton(
            icon: const Icon(Icons.fullscreen),
            color: Colors.grey.shade600,
            tooltip: 'Mode Focus (F11)',
            onPressed: () {
              // À connecter plus tard (cache les barres)
              _showSnackBar(context, 'Mode Focus activé (F11)');
            },
          ),

          // ---- Palette (toggle) ----
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            color: Colors.grey.shade600,
            tooltip: 'Afficher/Masquer les palettes',
            onPressed: () {
              // À connecter plus tard
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Widgets internes
  // --------------------------------------------------------------------------

  Widget _buildToolButton(
    BuildContext context,
    IconData icon,
    String tool,
    String label,
  ) {
    final bool isSelected = _selectedTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedTool = tool);
          _showSnackBar(context, 'Outil : $label');
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationButton(
    BuildContext context,
    String label,
    String duration,
  ) {
    final bool isSelected = _selectedDuration == duration;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedDuration = duration);
          _showSnackBar(context, 'Durée : $label');
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}