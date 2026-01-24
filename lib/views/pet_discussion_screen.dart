import 'package:flutter/material.dart';

class PetDiscussionScreen extends StatelessWidget {
  const PetDiscussionScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Discussion posting coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Discussion')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Community topics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask questions and share tips with local pet owners.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const _TopicCard(
              title: 'Nutrition and diet',
              subtitle: 'Healthy food plans for pets',
            ),
            const SizedBox(height: 10),
            const _TopicCard(
              title: 'Training and behavior',
              subtitle: 'Obedience, socialization, and routines',
            ),
            const SizedBox(height: 10),
            const _TopicCard(
              title: 'Vet care and vaccines',
              subtitle: 'Schedules and emergency help',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _showComingSoon(context),
              child: const Text('Start a discussion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _TopicCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.forum_outlined, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
