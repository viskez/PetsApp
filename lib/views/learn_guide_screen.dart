import 'package:flutter/material.dart';

class LearnGuideScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> steps;
  final List<String> tips;

  const LearnGuideScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const Text('Steps',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...steps.map(
            (step) => Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.teal),
                title: Text(step),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Tips',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Card(
              color: const Color(0xFFF2F7F6),
              child: ListTile(
                leading: const Icon(Icons.lightbulb, color: Colors.orange),
                title: Text(tip),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
