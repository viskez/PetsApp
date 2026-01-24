import 'package:flutter/material.dart';

import 'owner_order_requests_screen.dart';

class OwnerOrdersScreen extends StatelessWidget {
  const OwnerOrdersScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const OwnerOrdersScreen());

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'Order Requests from buyers',
        'Track incoming requests from interested buyers and review their details.'
      ),
      (
        'Invoice / Bill Generation',
        'Generate and share invoices/bills with buyers for each order.'
      ),
      (
        'Daily / Monthly Sales Report',
        'View summarized sales totals to understand daily and monthly performance.'
      ),
      (
        'Cancel & Refund Rules',
        'Define cancellation windows, refund eligibility, and penalties.'
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (title, description) = items[index];

          void openDetails() {
            if (title == 'Order Requests from buyers') {
              Navigator.push(
                context,
                OwnerOrderRequestsScreen.route(),
              );
              return;
            }
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(description,
                          style:
                              const TextStyle(fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
              ),
            );
          }

          return Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: ListTile(
              onTap: openDetails,
              leading: Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.primary),
        ),
      );
    },
  ),
);
  }
}
