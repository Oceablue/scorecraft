// lib/views/dashboard/dashboard_view.dart
// ============================================================================
// MENU DE DÉMARRAGE / DASHBOARD PRINCIPAL
// ============================================================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../editor/editor_view.dart';
import '../../models/score/score_document.dart';
import '../../services/parsers/music_xml_parser.dart';

// ============================================================================
// 1. MODÈLE POUR UN FICHIER RÉCENT
// ============================================================================

class RecentFile {
  final String title;
  final String format;
  final String date;
  final bool isPinned;

  const RecentFile({
    required this.title,
    required this.format,
    required this.date,
    this.isPinned = false,
  });

  RecentFile copyWith({bool? isPinned}) {
    return RecentFile(
      title: title,
      format: format,
      date: date,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

// ============================================================================
// 2. VUE PRINCIPALE
// ============================================================================

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final TextEditingController _searchController = TextEditingController();

  final List<RecentFile> _recentFiles = [
    const RecentFile(
      title: 'Sonate_No1',
      format: '.enc',
      date: "Aujourd'hui 14:30",
      isPinned: true,
    ),
    const RecentFile(
      title: 'Quatuor_A_Cordes',
      format: '.xml',
      date: 'Hier 18:15',
      isPinned: false,
    ),
    const RecentFile(
      title: 'Partition_Symphonique',
      format: '.proj',
      date: '08/08/2026',
      isPinned: false,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ACTIONS DE L'APPLICATION
  // ---------------------------------------------------------------------------

  void _continueLastProject() {
    final lastScore = ScoreDocument.withTestNotes();
    _navigateToEditor(lastScore);
  }

  void _openCreationWizard() {
    final newScore = ScoreDocument.withTestNotes();
    _navigateToEditor(newScore);
  }

  // --- OUVERTURE DE FICHIER (XML / MXL) ---
  Future<void> _openSystemFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'musicxml', 'mxl'],
      );
      if (result == null) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null) {
        _showErrorSnackBar('Impossible de récupérer le chemin du fichier.');
        return;
      }

      // Utilisation de MusicXmlParser.parseFile (gère .xml et .mxl)
      final scoreDocument = await MusicXmlParser.parseFile(path);
      _navigateToEditor(scoreDocument);
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ouverture : $e');
    }
  }

  Future<void> _importEncFile() async {
    _showInfoSnackBar('Fonction d\'import .enc désactivée temporairement');
  }

  // ========================================================================
  // NAVIGATION
  // ========================================================================

  void _navigateToEditor(ScoreDocument document) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorView(scoreDocument: document),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue.shade700,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // INTERFACE GRAPHIQUE (INCHANGÉE)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeaderBar(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildActionColumn()),
                    const SizedBox(width: 32),
                    Expanded(flex: 6, child: _buildRecentFilesColumn()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. EN-TÊTE SUPÉRIEUR
  // ===========================================================================

  Widget _buildTopHeaderBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'ScoreCraft',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Text(
                  'v1.0.0 / Build 2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.language_rounded),
                tooltip: 'Sélecteur de langue',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Paramètres globaux',
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. COLONNE GAUCHE : ACTIONS PRINCIPALES
  // ===========================================================================

  Widget _buildActionColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Démarrer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildActionTile(
          icon: Icons.replay_rounded,
          color: Colors.indigo,
          title: 'Continuer',
          subtitle: 'Dernier projet : Sonate_No1.enc',
          onTap: _continueLastProject,
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.add_circle_outline_rounded,
          color: Colors.teal,
          title: 'Nouveau Projet',
          subtitle: 'Lancer le wizard de création initiale',
          onTap: _openCreationWizard,
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.folder_open_rounded,
          color: Colors.orange,
          title: 'Ouvrir',
          subtitle: 'Explorer les fichiers (.proj, .xml, .mid)',
          onTap: _openSystemFile,
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.music_note_rounded,
          color: Colors.purple,
          title: 'Importer .ENC',
          subtitle: 'Convertir un fichier Encore (.enc)',
          onTap: _importEncFile,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. COLONNE DROITE : FICHIERS RÉCENTS
  // ===========================================================================

  Widget _buildRecentFilesColumn() {
    final filteredFiles = _recentFiles.where((file) {
      if (_searchController.text.isEmpty) return true;
      return file.title.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fichiers récents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un fichier...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredFiles.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun fichier trouvé',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredFiles.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = filteredFiles[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              file.format,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            file.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            file.date,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  file.isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  size: 18,
                                  color: file.isPinned ? Colors.amber : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    final idx = _recentFiles.indexOf(file);
                                    if (idx != -1) {
                                      _recentFiles[idx] = file.copyWith(
                                        isPinned: !file.isPinned,
                                      );
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _recentFiles.removeWhere(
                                      (f) => f.title == file.title && f.date == file.date,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            // TODO: Charger le fichier
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}