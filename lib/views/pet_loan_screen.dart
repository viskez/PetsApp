import 'package:flutter/material.dart';

class PetLoanScreen extends StatelessWidget {
  const PetLoanScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loan applications coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Loan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan at Home for Pet Care',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Cover vet bills, food, and accessories with flexible plans.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const _InfoCard(
              title: 'Why choose Pet Loan',
              items: [
                'Quick approval with minimal paperwork',
                'Flexible tenure and easy monthly payments',
                'Use for adoption, vet care, or supplies',
              ],
            ),
            const SizedBox(height: 12),
            const _InfoCard(
              title: 'How it works',
              items: [
                'Choose the loan amount and tenure',
                'Verify your profile and phone number',
                'Get approval and start using funds',
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _showComingSoon(context),
              child: const Text('Apply for a loan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
