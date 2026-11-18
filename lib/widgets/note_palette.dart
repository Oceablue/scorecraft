// lib/widgets/note_palette.dart
// ============================================================================
// PALETTE DE NOTES (FLOTTANTE) — v2c-93
// ============================================================================
// v2c-93 : passage à MusicTextStyle.music() pour cohérence avec le reste
//          du rendu (fallback Bravura disponible si Leland ne fournit pas
//          un glyphe). En pratique les ♩♪♫♬ et 𝄽 sont bien dans Leland,
//          mais on garde la cohérence.
// ============================================================================

import 'package:flutter/material.dart';

import '../utils/music_text_style.dart';

class NotePalette extends StatelessWidget {
  final VoidCallback onToggleVisibility;

  const NotePalette({
    super.key,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNoteButton(context, '\u2669', 'Ronde', Colors.black),
              _buildNoteButton(context, '\u266A', 'Blanche', Colors.black),
              _buildNoteButton(context, '\u266B', 'Noire', Colors.black),
              _buildNoteButton(context, '\u266C', 'Croche', Colors.black),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNoteButton(context, '\uD834\uDD3D', 'Silence',
                  Colors.grey.shade600),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                onPressed: onToggleVisibility,
                tooltip: 'Fermer la palette',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteButton(
    BuildContext context,
    String symbol,
    String label,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insérer : $label'),
              duration: const Duration(milliseconds: 500),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            symbol,
            style: MusicTextStyle.music(
              fontSize: 24,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}