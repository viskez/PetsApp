import 'pet_catalog.dart';
import 'pet_utils.dart';

const List<PetCatalogItem> PET_CATALOG = [
  PetCatalogItem(
    title: 'Dog / Labrador',
    images: ['assets/images/dog.jpg'],
    price: 12000,
    location: 'BENGALURU URBAN',
    description: 'Friendly Labrador, vaccinated.',
    sellerName: 'Mo ji',
    phone: '+919000000001',
    category: PetCategory.animals,
  ),
  PetCatalogItem(
    title: 'Cat / Persian',
    images: ['assets/images/cat.jpg'],
    price: 9000,
    location: 'BENGALURU URBAN',
    description: 'Calm Persian cat, litter trained.',
    sellerName: 'Mo ji',
    phone: '+919000000001',
    category: PetCategory.animals,
  ),
  PetCatalogItem(
    title: 'Rabbit / Dutch',
    images: ['assets/images/rabbit.jpg'],
    price: 2500,
    location: 'BENGALURU URBAN',
    description: 'Cute Dutch rabbit, healthy.',
    sellerName: 'Ravi',
    phone: '+919000000002',
    category: PetCategory.animals,
  ),
  PetCatalogItem(
    title: 'Horse / Marwari',
    images: ['assets/images/horse.jpg'],
    price: 80000,
    location: 'MYSURU',
    description: 'Strong Marwari horse.',
    sellerName: 'Kiran',
    phone: '+919000000003',
    category: PetCategory.animals,
  ),
  PetCatalogItem(
    title: 'Goat / Boer',
    images: ['assets/images/goat.jpg'],
    price: 7000,
    location: 'HUBLI',
    description: 'Healthy Boer goat.',
    sellerName: 'Akhil',
    phone: '+919000000004',
    category: PetCategory.animals,
  ),
  PetCatalogItem(
    title: 'Parrot / Ringneck',
    images: ['assets/images/parrot.jpg'],
    price: 3000,
    location: 'BENGALURU URBAN',
    description: 'Talking Ringneck parrot.',
    sellerName: 'Sana',
    phone: '+919000000005',
    category: PetCategory.birds,
  ),
  PetCatalogItem(
    title: 'Pigeon / Homing',
    images: ['assets/images/pigeon.jpg'],
    price: 900,
    location: 'MYSURU',
    description: 'Homing pigeon pair.',
    sellerName: 'Mo ji',
    phone: '+919000000001',
    category: PetCategory.birds,
  ),
  PetCatalogItem(
    title: 'Lovebird',
    images: ['assets/images/lovebird.jpg'],
    price: 2000,
    location: 'HUBLI',
    description: 'Colorful lovebirds.',
    sellerName: 'Ravi',
    phone: '+919000000002',
    category: PetCategory.birds,
  ),
  PetCatalogItem(
    title: 'Cockatiel',
    images: ['assets/images/cockatiel.jpg'],
    price: 5000,
    location: 'BENGALURU URBAN',
    description: 'Hand-tamed cockatiel.',
    sellerName: 'Kiran',
    phone: '+919000000003',
    category: PetCategory.birds,
  ),
  PetCatalogItem(
    title: 'Canary',
    images: ['assets/images/canary.jpg'],
    price: 2500,
    location: 'MYSURU',
    description: 'Singing canary bird.',
    sellerName: 'Akhil',
    phone: '+919000000004',
    category: PetCategory.birds,
  ),
  PetCatalogItem(
    title: 'Goldfish',
    images: ['assets/images/goldfish.jpg'],
    price: 200,
    location: 'BENGALURU URBAN',
    description: 'Bright goldfish.',
    sellerName: 'Sana',
    phone: '+919000000005',
    category: PetCategory.fish,
  ),
  PetCatalogItem(
    title: 'Betta',
    images: ['assets/images/betta.jpg'],
    price: 350,
    location: 'MYSURU',
    description: 'Flaring betta male.',
    sellerName: 'Mo ji',
    phone: '+919000000001',
    category: PetCategory.fish,
  ),
  PetCatalogItem(
    title: 'Guppy',
    images: ['assets/images/guppy.jpg'],
    price: 120,
    location: 'HUBLI',
    description: 'Mixed guppies.',
    sellerName: 'Ravi',
    phone: '+919000000002',
    category: PetCategory.fish,
  ),
  PetCatalogItem(
    title: 'Tetra',
    images: ['assets/images/tetra.jpg'],
    price: 150,
    location: 'MYSURU',
    description: 'Schooling tetras.',
    sellerName: 'Kiran',
    phone: '+919000000003',
    category: PetCategory.fish,
  ),
  PetCatalogItem(
    title: 'Angelfish',
    images: ['assets/images/angelfish.jpg'],
    price: 500,
    location: 'BENGALURU URBAN',
    description: 'Graceful angelfish.',
    sellerName: 'Akhil',
    phone: '+919000000004',
    category: PetCategory.fish,
  ),
];

List<PetCatalogItem> get PETS_ANIMALS =>
    PET_CATALOG.where((p) => p.category == PetCategory.animals).toList();
List<PetCatalogItem> get PETS_BIRDS =>
    PET_CATALOG.where((p) => p.category == PetCategory.birds).toList();
List<PetCatalogItem> get PETS_FISH =>
    PET_CATALOG.where((p) => p.category == PetCategory.fish).toList();

class PetRepository {
  static List<String> get species {
    final set = <String>{};
    for (final p in PET_CATALOG) {
      final (sp, _) = splitPetTitle(p.title);
      if (sp.isNotEmpty) set.add(sp);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Map<String, List<String>> get breedsBySpecies {
    final map = <String, Set<String>>{};
    for (final p in PET_CATALOG) {
      final (sp, br) = splitPetTitle(p.title);
      if (sp.isEmpty || br.isEmpty) continue;
      map.putIfAbsent(sp, () => <String>{}).add(br);
    }
    return {
      for (final e in map.entries)
        e.key: (e.value.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
    };
  }

}

