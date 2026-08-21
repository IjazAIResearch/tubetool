import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/saved_note.dart';
import 'package:timeago/timeago.dart' as timeago;

class SavedNotesScreen extends StatelessWidget {
  const SavedNotesScreen({super.key});

  // Calculate total items including ads
  int _calculateTotalItems(List<SavedNote> notes) {
    if (notes.isEmpty) return 0;
    // Add one ad for every 4 notes
    final adCount = (notes.length / 4).floor();
    return notes.length + adCount;
  }

  // Calculate the actual note index accounting for ads
  int _calculateNoteIndex(int listIndex) {
    // Subtract the number of ads that appear before this index
    return listIndex - (listIndex / 5).floor();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'SAVED NOTES',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Titles'),
              Tab(text: 'Descriptions'),
              Tab(text: 'Comments'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box('saved_notes').listenable(),
                builder: (context, box, _) {
                  return TabBarView(
                    children: [
                      _buildNotesList(context, box, null),
                      _buildNotesList(context, box, 'title'),
                      _buildNotesList(context, box, 'description'),
                      _buildNotesList(context, box, 'comment'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddNoteDialog(context),
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, Box box, String? type) {
    final notes =
        box.values
            .whereType<SavedNote>()
            .where((note) => type == null || note.type == type)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved notes yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _calculateTotalItems(notes),
      itemBuilder: (context, index) {
        final noteIndex = _calculateNoteIndex(index);
        final note = notes[noteIndex];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showNoteDetails(context, note),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note.type.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeago.format(note.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          box.delete(note.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Note deleted',
                                style: GoogleFonts.poppins(),
                              ),
                              behavior: SnackBarBehavior.floating,
                              width: 200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    note.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddNoteDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedType = 'custom';

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Add New Note',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter note title',
                    labelStyle: GoogleFonts.poppins(),
                    hintStyle: GoogleFonts.poppins(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    labelText: 'Content',
                    hintText: 'Enter note content',
                    labelStyle: GoogleFonts.poppins(),
                    hintStyle: GoogleFonts.poppins(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'title', child: Text('Title')),
                    DropdownMenuItem(
                      value: 'description',
                      child: Text('Description'),
                    ),
                    DropdownMenuItem(value: 'comment', child: Text('Comment')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (value) {
                    selectedType = value!;
                  },
                  decoration: InputDecoration(
                    labelText: 'Note Type',
                    labelStyle: GoogleFonts.poppins(),
                  ),
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      contentController.text.isNotEmpty) {
                    final note = SavedNote.create(
                      titleController.text,
                      contentController.text,
                      selectedType,
                    );
                    Hive.box('saved_notes').put(note.id, note);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Save', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );
  }

  Future<void> _showNoteDetails(BuildContext context, SavedNote note) {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.type.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  note.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(note.content, style: GoogleFonts.poppins(height: 1.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Created ${timeago.format(note.createdAt)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );
  }
}
