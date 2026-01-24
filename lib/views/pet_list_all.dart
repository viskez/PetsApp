import 'package:flutter/material.dart';
import '../widgets/pet_image.dart';
import 'pet_details.dart';

class PetListAllScreen extends StatelessWidget {
  final String title;
  final List<PetItem> items;
  const PetListAllScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All $title')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
        itemCount: items.length,
        itemBuilder: (_, i) => _PetCard(items[i]),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final PetItem item; const _PetCard(this.item);
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: PetImage(
              source: item.primaryImage,
              fit: BoxFit.cover,
              width: double.infinity)),
      Padding(padding: const EdgeInsets.all(8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(children: [
          Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.location_on, size: 14, color: Colors.grey),
          const SizedBox(width: 2),
          Text(item.location, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PetDetailsScreen(item: item))),
          child: const Text('Details'),
        )),
      ])),
    ]),
  );
}
