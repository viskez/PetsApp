import 'package:flutter/material.dart';

class PlayGameScreen extends StatelessWidget {
  const PlayGameScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mini games coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play Game')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pet games and challenges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Play short games and earn coins for pet care perks.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            _GameCard(
              title: 'Pet Quiz',
              subtitle: 'Test your pet knowledge',
              onPlay: () => _showComingSoon(context),
            ),
            const SizedBox(height: 10),
            _GameCard(
              title: 'Breed Match',
              subtitle: 'Match breeds with photos',
              onPlay: () => _showComingSoon(context),
            ),
            const SizedBox(height: 10),
            _GameCard(
              title: 'Care Challenge',
              subtitle: 'Pick the right care tips',
              onPlay: () => _showComingSoon(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  const _GameCard(
      {required this.title, required this.subtitle, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.sports_esports, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onPlay, child: const Text('Play')),
      ),
    );
  }
}
