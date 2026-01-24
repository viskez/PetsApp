import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/plan_store.dart';
import '../models/session.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  PlanStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await PlanStore().loadForUser(Session.currentUser.email);
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _buyPlan(PlanOption plan) async {
    final uri = Uri.parse(
        'upi://pay?pa=selvan.ux@okicici&pn=PetsApp&tn=${Uri.encodeComponent(plan.name)}&am=${plan.amount}&cu=INR');
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Complete payment in your UPI app to activate.')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI app found on this device.')),
      );
    }
  }

  String _expiryLabel(PlanStatus? status) {
    final expiry = status?.expiresAt;
    if (expiry == null) {
      if (status?.planName != null) return 'No expiry';
      return 'No active plan';
    }
    return 'Valid until ${DateFormat('dd MMM yyyy').format(expiry)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('My Plan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current plan',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          status?.planName ?? 'No plan selected',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _expiryLabel(status),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _pill(
                              label: 'Points',
                              value: '${status?.points ?? 0}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Plans',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final plan in PlanStore.plans) ...[
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      title: Text(plan.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${plan.points} points • ${plan.durationDays} days',
                      ),
                      trailing: FilledButton(
                        onPressed: () => _buyPlan(plan),
                        child: Text(plan.priceLabel),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                const Text('Point usage',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _usageRow(
                    'Call', PlanStore.costFor(PlanAction.call)),
                _usageRow(
                    'Chat', PlanStore.costFor(PlanAction.chat)),
                _usageRow('WhatsApp',
                    PlanStore.costFor(PlanAction.whatsapp)),
                _usageRow(
                    'Add pet (after 5)', PlanStore.costFor(PlanAction.addPet)),
              ],
            ),
    );
  }

  Widget _pill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12, color: Colors.black54)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _usageRow(String label, int cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$cost pts',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
