import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import 'script_writer_screen.dart';

// Helper to get Keep-style colors
Color getNoteColor(int index, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (index) {
    case 1: return isDark ? const Color(0xFF5C2B29) : const Color(0xFFF28B82); // Red
    case 2: return isDark ? const Color(0xFF614A19) : const Color(0xFFFBBC04); // Orange
    case 3: return isDark ? const Color(0xFF635D19) : const Color(0xFFFFF475); // Yellow
    case 4: return isDark ? const Color(0xFF345920) : const Color(0xFFCCFF90); // Green
    case 5: return isDark ? const Color(0xFF16504B) : const Color(0xFFA7FFEB); // Teal
    case 6: return isDark ? const Color(0xFF2D555E) : const Color(0xFFCBF0F8); // Blue
    case 7: return isDark ? const Color(0xFF42275E) : const Color(0xFFD7AEFB); // Purple
    default: return Theme.of(context).colorScheme.surface; // Default
  }
}

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _allNotes = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isGridView = true; // Toggle between Grid and List

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('notes') ?? [];
    setState(() {
      _allNotes = notesJson
          .map((n) => Note.fromJson(json.decode(n)))
          .toList();
      // Sort: Newest first
      _allNotes.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
    });
  }

  Future<void> _deleteNote(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allNotes.removeWhere((note) => note.id == noteId);
    });
    final notesJson = _allNotes.map((note) => json.encode(note.toJson())).toList();
    await prefs.setStringList('notes', notesJson);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note moved to trash'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _togglePin(Note note) async {
    note.isPinned = !note.isPinned;
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _allNotes.map((n) => json.encode(n.toJson())).toList();
    await prefs.setStringList('notes', notesJson);
    setState(() {}); // refresh UI
  }

  Future<void> _openNote(Note note) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScriptWriterScreen(note: note)),
    );
    _loadNotes(); // Refresh list when returning
  }

  List<Note> get _filteredNotes {
    if (_searchQuery.isEmpty) return _allNotes;
    final query = _searchQuery.toLowerCase();
    return _allNotes.where((note) {
      final titleMatch = note.title.toLowerCase().contains(query);
      final contentMatch = note.content.toLowerCase().contains(query);
      return titleMatch || contentMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: cs.primary)));
    }

    final displayedNotes = _filteredNotes;
    final pinnedNotes = displayedNotes.where((n) => n.isPinned).toList();
    final otherNotes = displayedNotes.where((n) => !n.isPinned).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar (Google Keep style)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search your scripts...',
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        IconButton(
                          icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view),
                          tooltip: _isGridView ? 'List view' : 'Grid view',
                          onPressed: () => setState(() => _isGridView = !_isGridView),
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _allNotes.isEmpty
                  ? _buildEmptyState(cs)
                  : CustomScrollView(
                      slivers: [
                        if (pinnedNotes.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                              child: Text('PINNED', style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant
                              )),
                            ),
                          ),
                          _buildNotesGrid(pinnedNotes),
                        ],
                        if (pinnedNotes.isNotEmpty && otherNotes.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                              child: Text('OTHERS', style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant
                              )),
                            ),
                          ),
                        _buildNotesGrid(otherNotes),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScriptWriterScreen()),
          );
          _loadNotes();
        },
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 80, color: cs.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'Notes you add appear here',
            style: TextStyle(fontSize: 16, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(List<Note> notes) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: _isGridView
          ? SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: notes.length,
              itemBuilder: (context, index) => _NoteCard(
                note: notes[index],
                onTap: () => _openNote(notes[index]),
                onDelete: () => _deleteNote(notes[index].id),
                onTogglePin: () => _togglePin(notes[index]),
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NoteCard(
                    note: notes[index],
                    onTap: () => _openNote(notes[index]),
                    onDelete: () => _deleteNote(notes[index].id),
                    onTogglePin: () => _togglePin(notes[index]),
                  ),
                ),
                childCount: notes.length,
              ),
            ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = getNoteColor(note.colorIndex, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine content preview
    String previewText = '';
    bool hasTags = false;
    try {
      final map = json.decode(note.content) as Map<String, dynamic>;
      final script = map['script']?.toString().trim() ?? '';
      final desc = map['description']?.toString().trim() ?? '';
      final tags = map['tags']?.toString().trim() ?? '';
      if (script.isNotEmpty) previewText = script;
      else if (desc.isNotEmpty) previewText = desc;
      hasTags = tags.isNotEmpty;
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: note.colorIndex == 0 
                ? Theme.of(context).colorScheme.outlineVariant 
                : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.title.isNotEmpty)
              Text(
                note.title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (note.title.isNotEmpty && previewText.isNotEmpty)
              const SizedBox(height: 8),
            if (previewText.isNotEmpty)
              Text(
                previewText,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            if (hasTags) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag, size: 12),
                    SizedBox(width: 4),
                    Text('Has Tags', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  note.date,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (note.isPinned)
                  Icon(Icons.push_pin, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
              onTap: () {
                Navigator.pop(ctx);
                onTogglePin();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
