import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:tubegrow/constants/app_config.dart';

class HashtagGeneratorScreen extends StatefulWidget {
  const HashtagGeneratorScreen({super.key});
  @override
  State<HashtagGeneratorScreen> createState() => _HashtagGeneratorScreenState();
}

class _HashtagGeneratorScreenState extends State<HashtagGeneratorScreen> {
  final _keywordController = TextEditingController();
  bool _isLoading = false;
  List<String> _hashtags = [];
  final Dio _dio = Dio();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _generateHashtags() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;
    setState(() { _isLoading = true; _hashtags = []; });

    try {
      final autocomplete = await _getAutocompleteSuggestions(keyword);
      final aiHashtags = await _getAIHashtags(keyword, autocomplete);

      final allHashtags = <String>{};
      for (final tag in aiHashtags) {
        final cleaned = tag.startsWith('#') ? tag : '#$tag';
        allHashtags.add(cleaned.replaceAll(' ', ''));
      }
      for (final s in autocomplete.take(10)) {
        final h = '#${s.replaceAll(' ', '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
        if (h.length > 2) allHashtags.add(h);
      }
      setState(() { _hashtags = allHashtags.toList(); _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<List<String>> _getAutocompleteSuggestions(String keyword) async {
    try {
      final response = await _dio.get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {'client': 'firefox', 'ds': 'yt', 'q': keyword},
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0'},
          responseType: ResponseType.json,
        ),
      );
      if (response.data is List && response.data.length > 1) {
        return (response.data[1] as List).cast<String>();
      }
      return [];
    } catch (e) { return []; }
  }

  Future<List<String>> _getAIHashtags(String keyword, List<String> suggestions) async {
    try {
      final sugStr = suggestions.take(5).join(', ');
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        }),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': 'You are a YouTube SEO expert. Generate relevant YouTube hashtags. Return ONLY a JSON array of hashtag strings (without #). No explanation.'},
            {'role': 'user', 'content': 'Generate 20 relevant YouTube hashtags for: "$keyword". Related: $sugStr. Return as JSON array like ["tag1","tag2"].'},
          ],
          'temperature': 0.7, 'max_tokens': 512,
        },
      );
      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].trim();
        try {
          final parsed = jsonDecode(content);
          if (parsed is List) return parsed.cast<String>();
        } catch (_) {
          return RegExp(r'#?(\w+)').allMatches(content).map((m) => m.group(1)!).toList();
        }
      }
      return [];
    } catch (e) { return []; }
  }

  void _copyAllHashtags() {
    if (_hashtags.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _hashtags.join(' ')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_hashtags.length} hashtags copied! 📋')),
    );
  }

  void _copyTop3() {
    if (_hashtags.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _hashtags.take(3).join(' ')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Top 3 hashtags copied 📋')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hashtag Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                hintText: 'Enter keyword (e.g. fitness, gaming)...',
                prefixIcon: Icon(Icons.tag, color: cs.primary),
                suffixIcon: IconButton(
                  icon: Icon(Icons.auto_awesome, color: cs.primary),
                  onPressed: _generateHashtags,
                ),
              ),
              onSubmitted: (_) => _generateHashtags(),
            ),
            const SizedBox(height: 12),
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('YouTube shows max 3 hashtags above title. Add more in description for SEO.', style: TextStyle(fontSize: 12))),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator())),
            if (_hashtags.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_hashtags.length} hashtags', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                  Row(children: [
                    TextButton.icon(onPressed: _copyTop3, icon: const Icon(Icons.looks_3, size: 18), label: const Text('Top 3')),
                    TextButton.icon(onPressed: _copyAllHashtags, icon: const Icon(Icons.copy, size: 18), label: const Text('Copy All')),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _hashtags.asMap().entries.map((entry) {
                  final isTop3 = entry.key < 3;
                  return GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: entry.value));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: ${entry.value}')));
                    },
                    child: Chip(
                      avatar: isTop3 ? Icon(Icons.star, size: 16, color: Colors.amber[700]) : null,
                      label: Text(entry.value, style: TextStyle(fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal)),
                      backgroundColor: isTop3 ? cs.primaryContainer : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
