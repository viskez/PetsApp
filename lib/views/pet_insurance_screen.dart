import 'package:flutter/material.dart';

class PetInsuranceScreen extends StatelessWidget {
  const PetInsuranceScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quotes coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Insurance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Affordable coverage for your pets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Protect against accidents, illness, and emergency care.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const _PlanCard(
              title: 'Basic Care',
              subtitle: 'Accident cover and annual checkup',
              priceNote: 'Best for indoor pets',
            ),
            const SizedBox(height: 10),
            const _PlanCard(
              title: 'Complete Care',
              subtitle: 'Accident, illness, and surgery cover',
              priceNote: 'Popular choice for families',
            ),
            const SizedBox(height: 10),
            const _PlanCard(
              title: 'Premium Care',
              subtitle: 'Complete cover with wellness add-ons',
              priceNote: 'For frequent vet visits',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _showComingSoon(context),
              child: const Text('Get a quote'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String priceNote;
  const _PlanCard(
      {required this.title, required this.subtitle, required this.priceNote});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  const SizedBox(height: 4),
                  Text(priceNote,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
