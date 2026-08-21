import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:tubegrow/constants/app_config.dart';

class BestTimeScreen extends StatefulWidget {
  const BestTimeScreen({super.key});
  @override
  State<BestTimeScreen> createState() => _BestTimeScreenState();
}

class _BestTimeScreenState extends State<BestTimeScreen> {
  String? _selectedNiche;
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  final List<Map<String, dynamic>> _niches = [
    {'name': 'Gaming', 'icon': Icons.sports_esports},
    {'name': 'Tech / Reviews', 'icon': Icons.devices},
    {'name': 'Education', 'icon': Icons.school},
    {'name': 'Entertainment', 'icon': Icons.movie},
    {'name': 'Music', 'icon': Icons.music_note},
    {'name': 'Fitness / Health', 'icon': Icons.fitness_center},
    {'name': 'Cooking / Food', 'icon': Icons.restaurant},
    {'name': 'Travel / Vlog', 'icon': Icons.flight},
    {'name': 'Beauty / Fashion', 'icon': Icons.face},
    {'name': 'Finance / Business', 'icon': Icons.attach_money},
    {'name': 'News / Politics', 'icon': Icons.newspaper},
    {'name': 'DIY / Crafts', 'icon': Icons.build},
    {'name': 'Sports', 'icon': Icons.sports_soccer},
    {'name': 'Kids / Family', 'icon': Icons.child_care},
    {'name': 'Science', 'icon': Icons.science},
    {'name': 'Motivation', 'icon': Icons.emoji_events},
  ];

  Future<void> _analyze() async {
    if (_selectedNiche == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a niche first')),
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
              'content': 'You are a YouTube analytics expert. Given a niche, provide the best upload times. Return ONLY a JSON object: {"bestDays":["day1","day2","day3"],"bestHours":["HH:MM AM/PM","HH:MM AM/PM"],"timezone":"UTC","weeklySchedule":{"Monday":"good/great/average/poor","Tuesday":"good/great/average/poor","Wednesday":"good/great/average/poor","Thursday":"good/great/average/poor","Friday":"good/great/average/poor","Saturday":"good/great/average/poor","Sunday":"good/great/average/poor"},"peakHours":[{"hour":"HH:MM","score":1-10}],"tips":["tip1","tip2","tip3"],"reason":"brief explanation"}. No extra text.',
            },
            {
              'role': 'user',
              'content': 'What are the best times to upload YouTube videos in the "$_selectedNiche" niche?',
            },
          ],
          'temperature': 0.5, 'max_tokens': 1024,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].trim();
        String jsonStr = content;
        if (content.contains('{')) {
          jsonStr = content.substring(content.indexOf('{'), content.lastIndexOf('}') + 1);
        }
        setState(() { _result = jsonDecode(jsonStr); _isLoading = false; });
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

  Color _getDayColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'great': return Colors.green;
      case 'good': return Colors.lightGreen;
      case 'average': return Colors.orange;
      case 'poor': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Best Upload Time')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select Your Niche',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _niches.map((niche) {
                      final selected = _selectedNiche == niche['name'];
                      return ChoiceChip(
                        avatar: Icon(niche['icon'] as IconData, size: 18,
                            color: selected ? Colors.white : cs.primary),
                        label: Text(niche['name'] as String),
                        selected: selected,
                        onSelected: (v) => setState(() => _selectedNiche = niche['name'] as String),
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(color: selected ? Colors.white : null),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Find Best Times button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _analyze,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Find Best Times'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Center(child: Column(children: [
                      SizedBox(height: 20), CircularProgressIndicator(),
                      SizedBox(height: 12), Text('AI analyzing best times...'),
                    ])),

                  if (_result != null) ..._buildResults(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildResults() {
    final r = _result!;
    final cs = Theme.of(context).colorScheme;

    return [
      // Best days & hours
      Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calendar_today, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Best Days', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            if (r['bestDays'] is List) Wrap(spacing: 8, children: (r['bestDays'] as List).map((d) => Chip(
              label: Text(d.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green.withOpacity(0.15),
              avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            )).toList()),
            const Divider(height: 24),
            Row(children: [
              Icon(Icons.access_time, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Best Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            if (r['bestHours'] is List) Wrap(spacing: 8, children: (r['bestHours'] as List).map((h) => Chip(
              label: Text(h.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: cs.primaryContainer,
              avatar: Icon(Icons.schedule, color: cs.primary, size: 18),
            )).toList()),
            if (r['timezone'] != null) ...[
              const SizedBox(height: 8),
              Text('Timezone: ${r['timezone']}', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
            ],
          ],
        )),
      ),
      const SizedBox(height: 12),

      // Weekly heatmap
      if (r['weeklySchedule'] is Map)
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Heatmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(r['weeklySchedule'] as Map).entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 90, child: Text(e.key.toString(), style: const TextStyle(fontSize: 13))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value == 'great' ? 1.0 : e.value == 'good' ? 0.75 : e.value == 'average' ? 0.5 : 0.25,
                    minHeight: 20,
                    backgroundColor: Colors.grey.withOpacity(0.15),
                    color: _getDayColor(e.value.toString()),
                  ),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 60, child: Text(
                  e.value.toString().toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getDayColor(e.value.toString())),
                )),
              ]),
            )),
          ],
        ))),
      const SizedBox(height: 12),

      // Tips
      if (r['tips'] is List)
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('Pro Tips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ...(r['tips'] as List).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💡 ', style: TextStyle(fontSize: 14)),
                Expanded(child: Text(t.toString(), style: const TextStyle(fontSize: 13, height: 1.4))),
              ]),
            )),
          ],
        ))),
      const SizedBox(height: 12),

      // Reason
      if (r['reason'] != null)
        Card(color: cs.primaryContainer.withOpacity(0.3), child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(r['reason'].toString(), style: const TextStyle(fontSize: 13, height: 1.4)),
        )),
    ];
  }
}
