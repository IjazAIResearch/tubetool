import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/note.dart';
import 'notes_list_screen.dart' show getNoteColor;

class ScriptWriterScreen extends StatefulWidget {
  final Note? note;
  const ScriptWriterScreen({super.key, this.note});

  @override
  State<ScriptWriterScreen> createState() => _ScriptWriterScreenState();
}

class _ScriptWriterScreenState extends State<ScriptWriterScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _scriptController = TextEditingController();
  final _scrollController = ScrollController();

  late String _noteId;
  late String _currentDate;
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initNote();
  }

  void _initNote() {
    if (widget.note != null) {
      final content = widget.note!.content;
      final contentMap = json.decode(content) as Map<String, dynamic>;

      _titleController.text = widget.note!.title;
      _descriptionController.text = contentMap['description'] ?? '';
      _tagsController.text = contentMap['tags'] ?? '';
      _scriptController.text = contentMap['script'] ?? '';
      _currentDate = widget.note!.date;
      _noteId = widget.note!.id;
      _colorIndex = widget.note!.colorIndex;
      _isPinned = widget.note!.isPinned;
    } else {
      _titleController.text = '';
      _descriptionController.text = '';
      _tagsController.text = '';
      _scriptController.text = '';
      _currentDate = DateTime.now().toString().split(' ')[0];
      _noteId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    _titleController.addListener(_saveNote);
    _descriptionController.addListener(_saveNote);
    _tagsController.addListener(_saveNote);
    _scriptController.addListener(_saveNote);

    setState(() => _isLoading = false);
  }

  Future<void> _saveNote() async {
    if (_isLoading) return;

    final content = json.encode({
      'description': _descriptionController.text,
      'tags': _tagsController.text,
      'script': _scriptController.text,
    });

    final prefs = await SharedPreferences.getInstance();
    final currentNote = Note(
      id: _noteId,
      title: _titleController.text,
      content: content,
      date: _currentDate,
      colorIndex: _colorIndex,
      isPinned: _isPinned,
    );

    final notesJson = prefs.getStringList('notes') ?? [];
    List<Note> notes = notesJson.map((str) => Note.fromJson(json.decode(str))).toList();

    final index = notes.indexWhere((n) => n.id == _noteId);
    if (index >= 0) {
      notes[index] = currentNote;
    } else {
      notes.add(currentNote);
    }

    await prefs.setStringList('notes', notes.map((n) => json.encode(n.toJson())).toList());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _scriptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Features ─────────────────────────────────────────────────────────────

  void _formatTags() {
    if (_tagsController.text.isEmpty) return;
    
    // Remove # symbols and split by current delimiters
    final rawInput = _tagsController.text;
    final cleanInput = rawInput.replaceAll('#', ' ').replaceAll(',', ' ').replaceAll('\n', ' ');
    
    // Split by whitespace, filter empties, and join with commas
    final words = cleanInput.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final formatted = words.join(', ');
    
    _tagsController.text = formatted;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tags formatted for YouTube! 🎉')),
    );
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text(_titleController.text.isNotEmpty ? _titleController.text : 'Untitled Script', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('Date: $_currentDate', style: const pw.TextStyle(color: PdfColors.grey)),
              pw.SizedBox(height: 20),
              if (_descriptionController.text.isNotEmpty) ...[
                pw.Text('Description:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(_descriptionController.text),
                pw.SizedBox(height: 16),
              ],
              if (_tagsController.text.isNotEmpty) ...[
                pw.Text('Tags:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(_tagsController.text),
                pw.SizedBox(height: 16),
              ],
              pw.Text('Script:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              pw.SizedBox(height: 8),
              pw.Text(_scriptController.text.isNotEmpty ? _scriptController.text : '(Empty Script)', style: const pw.TextStyle(lineSpacing: 2)),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/TubeTool_Script_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    if (mounted) {
      Share.shareXFiles([XFile(file.path)], text: 'Here is my YouTube script!');
    }
  }

  Future<void> _exportText() async {
    final text = 'Title: ${_titleController.text}\n\n'
                 'Description:\n${_descriptionController.text}\n\n'
                 'Tags:\n${_tagsController.text}\n\n'
                 'Script:\n${_scriptController.text}';
    Share.share(text);
  }

  void _copySection(String text, String name) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name copied!')));
  }

  // ── UI Builders ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader({required String title, required String content, required VoidCallback onCopy}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          if (content.isNotEmpty)
            Row(
              children: [
                IconButton(icon: const Icon(Icons.share, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4), onPressed: () => Share.share(content)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.copy, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4), onPressed: onCopy),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCounterStream(TextEditingController controller, {bool countWords = false}) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final text = controller.text;
        final count = countWords 
            ? text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length
            : text.length;
        final label = countWords ? (count == 1 ? 'word' : 'words') : (count == 1 ? 'char' : 'chars');
        return Text(
          '$count $label',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        );
      },
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Note Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: List.generate(8, (i) {
                  final color = getNoteColor(i, context);
                  final isSelected = _colorIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _colorIndex = i);
                      _saveNote();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : (i == 0 ? Colors.grey.withValues(alpha: 0.5) : Colors.transparent),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.black54) : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;
    final bgColor = getNoteColor(_colorIndex, context);
    // Darken input backgrounds slightly if the screen has a color
    final inputColor = _colorIndex == 0 ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.4));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: _isPinned ? 'Unpin' : 'Pin',
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              _saveNote();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'pdf') _exportPdf();
              if (val == 'txt') _exportText();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              const PopupMenuItem(value: 'txt', child: Text('Export as Text')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Video Title',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  maxLines: null,
                ),
                Text(
                  _currentDate,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 24),

                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(title: 'DESCRIPTION', content: _descriptionController.text, onCopy: () => _copySection(_descriptionController.text, 'Description')),
                      TextField(
                        controller: _descriptionController,
                        maxLines: null,
                        minLines: 3,
                        decoration: const InputDecoration(hintText: 'Write your description...', border: InputBorder.none),
                      ),
                      Align(alignment: Alignment.centerRight, child: _buildCounterStream(_descriptionController)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tags
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TAGS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.auto_fix_high, size: 14),
                                label: const Text('Format', style: TextStyle(fontSize: 12)),
                                onPressed: _formatTags,
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                              ),
                              if (_tagsController.text.isNotEmpty)
                                IconButton(icon: const Icon(Icons.copy, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4), onPressed: () => _copySection(_tagsController.text, 'Tags')),
                            ],
                          ),
                        ],
                      ),
                      TextField(
                        controller: _tagsController,
                        maxLines: null,
                        minLines: 2,
                        decoration: const InputDecoration(hintText: 'gaming, tutorial, ps5...', border: InputBorder.none),
                      ),
                      Align(alignment: Alignment.centerRight, child: _buildCounterStream(_tagsController)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Script
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(title: 'SCRIPT', content: _scriptController.text, onCopy: () => _copySection(_scriptController.text, 'Script')),
                      TextField(
                        controller: _scriptController,
                        maxLines: null,
                        minLines: 15, // Tall area for writing script
                        decoration: const InputDecoration(hintText: 'Start writing your script hook...', border: InputBorder.none),
                        style: const TextStyle(height: 1.5, fontSize: 15),
                      ),
                      Align(alignment: Alignment.centerRight, child: _buildCounterStream(_scriptController, countWords: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // padding for bottom bar
              ],
            ),
          ),
        ],
      ),
      
      // Bottom Bar (Keep style)
      bottomNavigationBar: BottomAppBar(
        color: bgColor,
        elevation: 8,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Change color',
              onPressed: _showColorPicker,
            ),
            const Spacer(),
            Text('Edited $_currentDate', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
