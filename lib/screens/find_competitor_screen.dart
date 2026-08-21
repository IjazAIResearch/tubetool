import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';

class FindCompetitorScreen extends StatelessWidget {
  final List<Video> competitors;

  const FindCompetitorScreen({super.key, required this.competitors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Competitor')),
      body: competitors.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No competitor videos found.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: competitors.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VideoCard(video: competitors[index]),
                );
              },
            ),
    );
  }
}
