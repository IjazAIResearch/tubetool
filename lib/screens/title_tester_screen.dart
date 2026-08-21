import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:tubegrow/constants/app_config.dart';

class TitleTesterScreen extends StatefulWidget {
  const TitleTesterScreen({super.key});
  @override
  State<TitleTesterScreen> createState() => _TitleTesterScreenState();
}

class _TitleTesterScreenState extends State<TitleTesterScreen> {
  final _titleAController = TextEditingController();
  final _titleBController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _titleAController.dispose();
    _titleBController.dispose();
    super.dispose();
  }

  Future<void> _compareTitles() async {
    final titleA = _titleAController.text.trim();
    final titleB = _titleBController.text.trim();
    if (titleA.isEmpty || titleB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both titles')),
      );
      return;
    }

    setState(() { _isLoading = true; _result = null; });

    try {
      final dio = Dio();
      final response = await dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        }),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a YouTube SEO expert. Compare two video titles and return a JSON object with this exact structure: {"winner":"A or B","scoreA":number 1-10,"scoreB":number 1-10,"clickabilityA":number 1-10,"clickabilityB":number 1-10,"seoA":number 1-10,"seoB":number 1-10,"emotionA":number 1-10,"emotionB":number 1-10,"clarityA":number 1-10,"clarityB":number 1-10,"reasonA":"why A is good/bad","reasonB":"why B is good/bad","suggestion":"improved version of the better title"}. Return ONLY the JSON object, no other text.',
            },
            {
              'role': 'user',
              'content': 'Compare these YouTube video titles:\nTitle A: "$titleA"\nTitle B: "$titleB"',
            },
          ],
          'temperature': 0.5,
          'max_tokens': 1024,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].trim();
        // Extract JSON from response
        String jsonStr = content;
        if (content.contains('{')) {
          jsonStr = content.substring(content.indexOf('{'), content.lastIndexOf('}') + 1);
        }
        setState(() {
          _result = jsonDecode(jsonStr);
          _isLoading = false;
        });
      } else {
        throw Exception('API error');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Title A/B Tester')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                  // Title A
                  Text('Title A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleAController,
                    decoration: InputDecoration(
                      hintText: 'Enter first title option...',
                      prefixIcon: Icon(Icons.looks_one, color: Colors.blue[700]),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // VS badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title B
                  Text('Title B', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700])),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleBController,
                    decoration: InputDecoration(
                      hintText: 'Enter second title option...',
                      prefixIcon: Icon(Icons.looks_two, color: Colors.orange[700]),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Compare button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _compareTitles,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Compare Titles'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Center(child: Column(children: [
                      SizedBox(height: 20),
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('AI analyzing titles...'),
                    ])),

                  if (_result != null) ..._buildResults(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildResults() {
    final r = _result!;
    final winner = r['winner'] ?? 'A';
    final isAWinner = winner.toString().toUpperCase() == 'A';

    return [
      // Winner banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAWinner
                ? [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0.05)]
                : [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAWinner ? Colors.blue : Colors.orange, width: 2),
        ),
        child: Row(children: [
          Icon(Icons.emoji_events, color: Colors.amber[700], size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🏆 Title ${winner.toString().toUpperCase()} Wins!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(isAWinner ? _titleAController.text : _titleBController.text,
                style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
      const SizedBox(height: 16),

      // Score comparison bars
      _buildComparisonRow('Overall', r['scoreA'] ?? 5, r['scoreB'] ?? 5),
      _buildComparisonRow('Clickability', r['clickabilityA'] ?? 5, r['clickabilityB'] ?? 5),
      _buildComparisonRow('SEO Value', r['seoA'] ?? 5, r['seoB'] ?? 5),
      _buildComparisonRow('Emotion', r['emotionA'] ?? 5, r['emotionB'] ?? 5),
      _buildComparisonRow('Clarity', r['clarityA'] ?? 5, r['clarityB'] ?? 5),
      const SizedBox(height: 16),

      // Feedback cards
      if (r['reasonA'] != null) _buildFeedbackCard('Title A', r['reasonA'], Colors.blue),
      if (r['reasonB'] != null) _buildFeedbackCard('Title B', r['reasonB'], Colors.orange),

      // Suggestion
      if (r['suggestion'] != null)
        Card(
          color: Colors.green.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('AI Suggested Title', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
              const SizedBox(height: 8),
              Text(r['suggestion'], style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
    ];
  }

  Widget _buildComparisonRow(String label, dynamic scoreA, dynamic scoreB) {
    final a = (scoreA is int ? scoreA : int.tryParse(scoreA.toString()) ?? 5).toDouble();
    final b = (scoreB is int ? scoreB : int.tryParse(scoreB.toString()) ?? 5).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Text('${a.round()}', style: TextStyle(fontWeight: FontWeight.bold, color: a >= b ? Colors.blue : Colors.grey)),
        const SizedBox(width: 8),
        Expanded(child: Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(widthFactor: a / 10, child: Container(height: 8, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.7), borderRadius: BorderRadius.circular(4)))),
        ])),
        const SizedBox(width: 4),
        Expanded(child: Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(widthFactor: b / 10, child: Container(height: 8, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.7), borderRadius: BorderRadius.circular(4)))),
        ])),
        const SizedBox(width: 8),
        Text('${b.round()}', style: TextStyle(fontWeight: FontWeight.bold, color: b >= a ? Colors.orange : Colors.grey)),
      ]),
    );
  }

  Widget _buildFeedbackCard(String title, String reason, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(reason, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }
}
