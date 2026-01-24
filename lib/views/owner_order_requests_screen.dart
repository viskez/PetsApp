import 'package:flutter/material.dart';

import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import '../models/pet_utils.dart';
import '../widgets/pet_image.dart';
import 'pet_details.dart';

class OwnerOrderRequestsScreen extends StatefulWidget {
  const OwnerOrderRequestsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const OwnerOrderRequestsScreen());

  @override
  State<OwnerOrderRequestsScreen> createState() =>
      _OwnerOrderRequestsScreenState();
}

class _OwnerOrderRequestsScreenState extends State<OwnerOrderRequestsScreen> {
  late List<_RequestEntry> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _buildRequests();
  }

  List<_RequestEntry> _buildRequests() {
    final pets = PetCatalog.all.isNotEmpty ? PetCatalog.all : PET_CATALOG;
    final buyers = [
      'Arjun Mehta',
      'Priya Nair',
      'Rahul Sharma',
      'Sneha Rao',
      'Vikram Joshi',
    ];
    const statuses = ['Requested', 'Payment', 'Confirmed', 'Delivered', 'Requested'];

    final list = <_RequestEntry>[];
    for (var i = 0; i < pets.length && i < buyers.length; i++) {
      final pet = pets[i];
      list.add(_RequestEntry(
        pet: pet,
        buyer: buyers[i],
        status: statuses[i],
      ));
    }
    return list;
  }

  void _updateStatus(_RequestEntry entry, String newStatus) {
    if (newStatus == 'Payment') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Send payment link?'),
          content: const Text(
              'Send payment link to the buyer and confirm once paid.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Payment link sent to buyer')));
                  setState(() {
                    entry.status = 'Confirmed';
                  });
                },
                child: const Text('Send')),
          ],
        ),
      );
    } else {
      setState(() {
        entry.status = newStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'All',
      'Requested',
      'Payment',
      'Confirmed',
      'Delivered',
      'Cancelled',
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Requests'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: TabBarView(
          children: tabs.map((tab) {
            final filtered = tab == 'All'
                ? _requests
                : _requests.where((r) => r.status == tab).toList();

            if (filtered.isEmpty) {
              return const Center(
                  child: Text('No requests in this status yet.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = filtered[index];
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PetDetailsScreen(
                                  item: entry.pet.toItem(),
                                )),
                      );
                    },
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PetImage(
                        source: entry.pet.primaryImage,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      normalizePetTitle(entry.pet.title),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Buyer: ${entry.buyer}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('Amount: Rs ${entry.pet.price}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('Status: ${entry.status}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    trailing: _StatusChip(
                      value: entry.status,
                      onChanged: (newStatus) => _updateStatus(entry, newStatus),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RequestEntry {
  final PetCatalogItem pet;
  final String buyer;
  String status;
  _RequestEntry({required this.pet, required this.buyer, required this.status});
}

class _StatusChip extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusChip({required this.value, required this.onChanged});

  static const List<String> _options = [
    'Requested',
    'Payment',
    'Confirmed',
    'Delivered',
    'Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(value);
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: color),
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: _options
              .map((opt) => DropdownMenuItem(
                    value: opt,
                    child: Text(opt,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _colorFor(opt))),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Color _colorFor(String status) {
    switch (status) {
      case 'Confirmed':
        return Colors.blueGrey.shade600;
      case 'Delivered':
        return Colors.green.shade600;
      case 'Payment':
        return Colors.deepPurple.shade500;
      case 'Cancelled':
        return Colors.red.shade600;
      case 'Requested':
      default:
        return Colors.orange.shade600;
    }
  }
}
