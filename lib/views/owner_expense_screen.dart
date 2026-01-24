import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pet_catalog.dart';
import '../models/pet_utils.dart';
import '../widgets/pet_image.dart';

class OwnerExpenseScreen extends StatelessWidget {
  final List<PetCatalogItem> pets;
  const OwnerExpenseScreen({super.key, required this.pets});

  static Route<void> route(List<PetCatalogItem> pets) =>
      MaterialPageRoute(builder: (_) => OwnerExpenseScreen(pets: pets));

  @override
  Widget build(BuildContext context) {
    final sold = pets.where((p) => p.status == PetStatus.sold).toList();
    final boughtCount = pets.length;
    final soldCount = sold.length;
    final totalIncome =
        sold.fold<int>(0, (sum, pet) => sum + (pet.price > 0 ? pet.price : 0));
    final potentialIncome = pets.fold<int>(
        0, (sum, pet) => sum + (pet.price > 0 ? pet.price : 0));

    Widget statCard(String label, String value, {Color? color}) {
      return Expanded(
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color ?? Colors.black87)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Trackers')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              statCard('Pets Bought', '$boughtCount'),
              const SizedBox(width: 10),
              statCard('Pets Sold', '$soldCount',
                  color: Colors.orange.shade800),
            ],
          ),
          Row(
            children: [
              statCard('Total Income', 'Rs $totalIncome',
                  color: Colors.teal.shade700),
              const SizedBox(width: 10),
              statCard('Potential Income', 'Rs $potentialIncome',
                  color: Colors.blueGrey.shade700),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Pet Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (pets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No pet data available.'),
              ),
            )
          else
            ...pets.map((pet) {
              final statusColor = () {
                switch (pet.status) {
                  case PetStatus.sold:
                    return Colors.green.shade700;
                  case PetStatus.inactive:
                    return Colors.grey.shade700;
                  case PetStatus.pendingApproval:
                    return Colors.orange.shade700;
                  case PetStatus.deleted:
                    return Colors.red.shade700;
                  case PetStatus.active:
                  default:
                    return Colors.teal.shade700;
                }
              }();
              final outcome = pet.status == PetStatus.sold ? 'Sold' : 'Bought';

              return Card(
                elevation: 0,
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    OwnerPetTransactionScreen.route(pet),
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PetImage(
                      source: pet.primaryImage,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(normalizePetTitle(pet.title)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outcome: $outcome',
                          style: TextStyle(color: statusColor)),
                      Text('Rs ${pet.price} • ${pet.location}'),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class OwnerPetTransactionScreen extends StatelessWidget {
  final PetCatalogItem pet;
  const OwnerPetTransactionScreen({super.key, required this.pet});

  static Route<void> route(PetCatalogItem pet) =>
      MaterialPageRoute(builder: (_) => OwnerPetTransactionScreen(pet: pet));

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy, h:mm a');
    final dateLabel = pet.addedAt != null
        ? formatter.format(pet.addedAt!)
        : 'Date not available';
    final outcome = pet.status == PetStatus.sold ? 'Sold' : 'Bought';
    final seller = pet.sellerName.isNotEmpty ? pet.sellerName : 'Unknown seller';
    final phone = pet.phone.isNotEmpty ? pet.phone : 'No contact';

    return Scaffold(
      appBar: AppBar(title: const Text('Pet Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: PetImage(
                      source: pet.primaryImage,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(normalizePetTitle(pet.title),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Outcome: $outcome',
                            style: TextStyle(
                                color: pet.status == PetStatus.sold
                                    ? Colors.green.shade700
                                    : Colors.teal.shade700)),
                        const SizedBox(height: 2),
                        Text('Rs ${pet.price}'),
                        const SizedBox(height: 4),
                        Text('Seller: $seller',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                        Text('Contact: $phone',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Details',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  _detailRow('Date & Time', dateLabel),
                  _detailRow('Amount', 'Rs ${pet.price}'),
                  _detailRow('Location', pet.location),
                  _detailRow('Status', pet.status.label),
                  _detailRow('Buyer/Seller', seller),
                  _detailRow('Contact', phone),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Listing Snapshot',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PetImage(
                          source: pet.primaryImage,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(normalizePetTitle(pet.title),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Rs ${pet.price}',
                                style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 16, color: Colors.black54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    pet.location.isNotEmpty
                                        ? pet.location
                                        : 'Location not shared',
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Seller: $seller',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black87)),
                            Text('Contact: $phone',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (pet.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      pet.description,
                      style: const TextStyle(
                          color: Colors.black87, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}
