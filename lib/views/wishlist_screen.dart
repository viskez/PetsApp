import 'package:flutter/material.dart';

import '../models/pet_catalog.dart';
import '../models/wishlist.dart';
import '../widgets/pet_image.dart';
import 'pet_details.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = WishlistStore();
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Wishlist', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: wishlist.ids,
        builder: (context, ids, _) {
          final items = PetCatalog.selected(ids).toList();
          if (items.isEmpty) {
            return const Center(
              child: Text('No items wishlisted yet.'),
            );
          }

          final byCategory = <PetCategory, List<PetCatalogItem>>{};
          for (final item in items) {
            byCategory.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: byCategory.entries
                .map((entry) => _WishlistCategorySection(
                      category: entry.key,
                      items: entry.value,
                      wishlist: wishlist,
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _WishlistCategorySection extends StatelessWidget {
  final PetCategory category;
  final List<PetCatalogItem> items;
  final WishlistStore wishlist;

  const _WishlistCategorySection(
      {required this.category, required this.items, required this.wishlist});

  String get _title => switch (category) {
        PetCategory.animals => 'Animals',
        PetCategory.birds => 'Birds',
        PetCategory.fish => 'Fish',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        ...items.map((pet) => _WishlistCard(pet: pet, wishlist: wishlist)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final PetCatalogItem pet;
  final WishlistStore wishlist;

  const _WishlistCard({required this.pet, required this.wishlist});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PetDetailsScreen(item: pet.toItem())),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PetImage(
                  source: pet.primaryImage,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('₹${pet.price}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pet.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => wishlist.toggle(pet.title),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
