/*import 'package:flutter/material.dart';

/// ----- Data model -----
class CareTip {
  final String title;        // e.g. "Daily Grooming"
  final String species;      // e.g. "Cat"
  final String? breed;       // e.g. "Persian"
  final String category;     // e.g. "Care Tips"
  final String summary;      // short description
  const CareTip({
    required this.title,
    required this.species,
    required this.category,
    required this.summary,
    this.breed,
  });
}

/// ----- Demo data (extend freely) -----
const _tips = <CareTip>[
  // Cats
  CareTip(
    title: 'Daily Grooming',
    species: 'Cat',
    breed: 'Persian',
    category: 'Care Tips',
    summary: 'Brush coat daily to prevent mats; use wide-tooth comb then slicker brush.',
  ),
  CareTip(
    title: 'Eye Cleaning',
    species: 'Cat',
    breed: 'Persian',
    category: 'Pet Health',
    summary: 'Wipe tear stains with sterile gauze & saline; keep eyes dry to avoid irritation.',
  ),
  CareTip(
    title: 'Feeding Schedule',
    species: 'Cat',
    breed: 'Persian',
    category: 'Feed Guide',
    summary: 'High-protein wet+dry mix; 2–3 small meals/day; fresh water always.',
  ),
  CareTip(
    title: 'Hairball Remedy',
    species: 'Cat',
    category: 'Home Remedies',
    summary: 'Add fiber (pumpkin 1 tsp/day) and hairball gel; regular brushing helps.',
  ),
  CareTip(
    title: 'Core Vaccines',
    species: 'Cat',
    category: 'Vaccination',
    summary: 'FVRCP at 8/12/16 wks; rabies as per local law; annual boosters as advised.',
  ),
  CareTip(
    title: 'When to See the Vet',
    species: 'Cat',
    category: 'Pet Doctor',
    summary: 'Lethargy, refusal to eat >24h, breathing issues, pale gums: seek care.',
  ),
  CareTip(
    title: 'Monthly Budget',
    species: 'Cat',
    category: 'Expenses',
    summary: 'Food, litter, grooming, flea/tick, deworming; keep receipts in app.',
  ),
  CareTip(
    title: 'Litter Training',
    species: 'Cat',
    category: 'Training Tips',
    summary: 'Keep box clean, low-dust litter, place in quiet corner; reward usage.',
  ),
  CareTip(
    title: 'Bathing Basics',
    species: 'Cat',
    category: 'Grooming',
    summary: 'Bathe only if dirty; use cat-safe shampoo; dry thoroughly.',
  ),

  // Dogs
  CareTip(
    title: 'Puppy Vaccines',
    species: 'Dog',
    category: 'Vaccination',
    summary: 'DHPP at 6–8/10–12/14–16 wks; anti-rabies per schedule; vet confirms boosters.',
  ),
  CareTip(
    title: 'Basic Obedience',
    species: 'Dog',
    category: 'Training Tips',
    summary: 'Short sessions (5–10 mins), positive rewards, sit–stay–come daily.',
  ),
  CareTip(
    title: 'Home Bath Routine',
    species: 'Dog',
    category: 'Grooming',
    summary: 'Brush first; lukewarm water; dog shampoo; rinse well; dry ears.',
  ),
  CareTip(
    title: 'Skin Itch Soother',
    species: 'Dog',
    category: 'Home Remedies',
    summary: 'Oatmeal rinse and omega-3; vet visit if red/hot spots or wounds.',
  ),
  CareTip(
    title: 'Adult Feeding',
    species: 'Dog',
    category: 'Feed Guide',
    summary: 'Balanced kibble; adjust by activity; split into 2 meals; weigh monthly.',
  ),

  // Fish
  CareTip(
    title: 'Goldfish Tank Setup',
    species: 'Fish',
    breed: 'Goldfish',
    category: 'Care Tips',
    summary: 'At least 75L for first fish; strong filtration; weekly 25% water change.',
  ),
  CareTip(
    title: 'Water Quality Basics',
    species: 'Fish',
    breed: 'Goldfish',
    category: 'Pet Health',
    summary: 'Keep ammonia/nitrite at 0; nitrate <40ppm; test weekly.',
  ),
  CareTip(
    title: 'Feeding Goldfish',
    species: 'Fish',
    breed: 'Goldfish',
    category: 'Feed Guide',
    summary: 'Small portions 2x/day; soak pellets; one “fast” day/week.',
  ),
];

const _allCategories = <String>[
  'Pet Health',
  'Feed Guide',
  'Home Remedies',
  'Care Tips',
  'Vaccination',
  'Pet Doctor',
  'Expenses',
  'Training Tips',
  'Grooming',
];

const _speciesOptions = <String>['All', 'Dog', 'Cat', 'Fish'];

/// ----- Screen -----
class CareTipsScreen extends StatefulWidget {
  const CareTipsScreen({super.key});

  @override
  State<CareTipsScreen> createState() => _CareTipsScreenState();
}

class _CareTipsScreenState extends State<CareTipsScreen> {
  String _query = '';
  String _species = 'All';
  String _category = 'Care Tips'; // default land on “Care Tips”
  String _breed = 'All';

  List<String> get _breedOptions {
    final species = _species == 'All' ? _tips.map((t) => t.species) : [_species];
    final breeds = _tips
        .where((t) => species.contains(t.species) && t.breed != null && t.breed!.trim().isNotEmpty)
        .map((t) => t.breed!)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...breeds];
  }

  Iterable<CareTip> get _filtered {
    return _tips.where((t) {
      final matchesSpecies = _species == 'All' || t.species == _species;
      final matchesBreed = _breed == 'All' || t.breed == _breed;
      final matchesCategory = _category == 'All' || t.category == _category;
      final q = _query.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.summary.toLowerCase().contains(q) ||
          (t.breed ?? '').toLowerCase().contains(q);
      return matchesSpecies && matchesBreed && matchesCategory && matchesQuery;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C8A7E),
        foregroundColor: Colors.white,
        title: const Text('Care Tips'),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search (e.g. Persian, Goldfish, vaccination)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _species,
                  decoration: _ddStyle('Species'),
                  items: _speciesOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _species = v!;
                    _breed = 'All';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _breed,
                  decoration: _ddStyle('Breed'),
                  items: _breedOptions
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _breed = v!),
                ),
              ),
            ]),
          ),

          // Category chips (horizontal)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _allCategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = i == 0 ? 'All' : _allCategories[i - 1];
                final selected = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No tips match your filters.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TipCard(items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _ddStyle(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

/// ----- Card -----
class _TipCard extends StatelessWidget {
  const _TipCard(this.tip);
  final CareTip tip;

  Color _tagColor(String cat) {
    switch (cat) {
      case 'Pet Health':
        return const Color(0xFF0E8D7C);
      case 'Feed Guide':
        return const Color(0xFF6B5B95);
      case 'Home Remedies':
        return const Color(0xFFB56576);
      case 'Care Tips':
        return const Color(0xFF2E86AB);
      case 'Vaccination':
        return const Color(0xFFDAA520);
      case 'Pet Doctor':
        return const Color(0xFF6C757D);
      case 'Expenses':
        return const Color(0xFF2E7D32);
      case 'Training Tips':
        return const Color(0xFF7E57C2);
      case 'Grooming':
        return const Color(0xFF00897B);
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _tagColor(tip.category).withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tip.category,
        style: TextStyle(
          color: _tagColor(tip.category),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal.withOpacity(.12),
            child: const Icon(Icons.lightbulb_outline, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    tip.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                badge,
              ]),
              const SizedBox(height: 4),
              Text(
                '${tip.species}${tip.breed != null ? ' • ${tip.breed}' : ''}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(tip.summary),
            ]),
          ),
        ]),
      ),
    );
  }
}
*/
// lib/views/care_tips.dart
import 'package:flutter/material.dart';
import '../models/pet_data.dart'; // PetRepository comes from here

/// ---------- Data model ----------
class CareTip {
  final String title;
  final String species;   // e.g., Dog / Cat / Goldfish / Iguana
  final String? breed;    // e.g., Labrador / Persian / Ringneck (optional)
  final String category;  // Pet Health / Feed Guide / Home Remedies / ...
  final String summary;

  const CareTip({
    required this.title,
    required this.species,
    required this.category,
    required this.summary,
    this.breed,
  });
}

/// ---------- Categories shown in the Category dropdown ----------
const _allCategories = <String>[
  'Pet Health',
  'Feed Guide',
  'Home Remedies',
  'Care Tips',
  'Vaccination',
  'Pet Doctor',
  'Expenses',
  'Training Tips',
  'Grooming',
];

/// ---------- Tips dataset (Animals + Birds + Fish + Reptiles) ----------
const _tips = <CareTip>[
  // ===== ANIMALS =====
  // Dog (Labrador)
  CareTip(
    title: 'Balanced Adult Diet',
    species: 'Dog',
    breed: 'Labrador',
    category: 'Feed Guide',
    summary: 'High-quality kibble; 2 meals/day; monitor weight monthly.',
  ),
  CareTip(
    title: 'Hip & Joint Watch',
    species: 'Dog',
    breed: 'Labrador',
    category: 'Pet Health',
    summary: 'Large breeds prone to hip dysplasia; keep lean; omega-3 helpful.',
  ),
  CareTip(
    title: 'Basic Obedience',
    species: 'Dog',
    category: 'Training Tips',
    summary: 'Short positive sessions; sit–stay–come daily; reward calm behavior.',
  ),
  CareTip(
    title: 'Bath & Ear Care',
    species: 'Dog',
    category: 'Grooming',
    summary: 'Bathe monthly; dry ears after bath; trim nails every 3–4 weeks.',
  ),

  // Cat (Persian)
  CareTip(
    title: 'Daily Grooming',
    species: 'Cat',
    breed: 'Persian',
    category: 'Care Tips',
    summary: 'Brush coat daily; wide-tooth comb then slicker brush; detangle mats.',
  ),
  CareTip(
    title: 'Eye Cleaning',
    species: 'Cat',
    breed: 'Persian',
    category: 'Pet Health',
    summary: 'Wipe tear stains with sterile gauze; keep area dry; vet if red/irritated.',
  ),
  CareTip(
    title: 'Feeding Schedule',
    species: 'Cat',
    breed: 'Persian',
    category: 'Feed Guide',
    summary: 'High-protein wet+dry; 2–3 small meals/day; fresh water always.',
  ),
  CareTip(
    title: 'Hairball Remedy',
    species: 'Cat',
    category: 'Home Remedies',
    summary: 'Fiber (1 tsp pumpkin/day) + hairball gel; regular brushing.',
  ),

  // Rabbit (Dutch)
  CareTip(
    title: 'Daily Hay First',
    species: 'Rabbit',
    breed: 'Dutch',
    category: 'Feed Guide',
    summary: '80% timothy hay; small pellets; leafy greens; avoid iceberg & seeds.',
  ),
  CareTip(
    title: 'Litter Training',
    species: 'Rabbit',
    breed: 'Dutch',
    category: 'Training Tips',
    summary: 'Place litter box where they pee; use paper pellets; reward use.',
  ),
  CareTip(
    title: 'Heat Stress Signs',
    species: 'Rabbit',
    breed: 'Dutch',
    category: 'Pet Health',
    summary: 'Panting, drooling—move to cool area; offer water; consult vet.',
  ),

  // Horse (Marwari)
  CareTip(
    title: 'Hoof Care Routine',
    species: 'Horse',
    breed: 'Marwari',
    category: 'Care Tips',
    summary: 'Daily picking; farrier every 6–8 weeks; dry standing area.',
  ),
  CareTip(
    title: 'Deworm & Vaccines',
    species: 'Horse',
    breed: 'Marwari',
    category: 'Vaccination',
    summary: 'Deworm per fecal count; core vaccines as per vet & region.',
  ),
  CareTip(
    title: 'Monthly Budgeting',
    species: 'Horse',
    breed: 'Marwari',
    category: 'Expenses',
    summary: 'Feed, farrier, vet, transport—log in app; track seasonal spikes.',
  ),

  // Goat (Boer)
  CareTip(
    title: 'Forage + Minerals',
    species: 'Goat',
    breed: 'Boer',
    category: 'Feed Guide',
    summary: 'Quality forage; free-choice mineral; avoid sudden diet changes.',
  ),
  CareTip(
    title: 'Bloat First Aid',
    species: 'Goat',
    breed: 'Boer',
    category: 'Home Remedies',
    summary: 'Gentle walking; simethicone if advised; urgent vet if severe.',
  ),
  CareTip(
    title: 'Parasite Check',
    species: 'Goat',
    breed: 'Boer',
    category: 'Pet Health',
    summary: 'FAMACHA scoring; rotational grazing; fecal tests with vet.',
  ),

  // ===== BIRDS =====
  // Parrot (Ringneck)
  CareTip(
    title: 'Speech Training',
    species: 'Parrot',
    breed: 'Ringneck',
    category: 'Training Tips',
    summary: 'Short sessions; repeat words clearly; reward immediately.',
  ),
  CareTip(
    title: 'Pellets + Veg',
    species: 'Parrot',
    breed: 'Ringneck',
    category: 'Feed Guide',
    summary: '60–70% pellets; add veggies & limited seeds; avoid avocado/choc.',
  ),
  CareTip(
    title: 'Enrichment',
    species: 'Parrot',
    breed: 'Ringneck',
    category: 'Care Tips',
    summary: 'Rotate toys; foraging puzzles; daily out-of-cage time.',
  ),

  // Pigeon (Homing)
  CareTip(
    title: 'Loft Hygiene',
    species: 'Pigeon',
    breed: 'Homing',
    category: 'Care Tips',
    summary: 'Daily scrape perches; dry bedding; good airflow reduces illness.',
  ),
  CareTip(
    title: 'Respiratory Watch',
    species: 'Pigeon',
    breed: 'Homing',
    category: 'Pet Health',
    summary: 'Sneezing, open-mouth breathing—check drafts & consult vet.',
  ),

  // Lovebird (no breed)
  CareTip(
    title: 'Bonding & Nesting',
    species: 'Lovebird',
    category: 'Care Tips',
    summary: 'Pair bonding strong; provide chewable nesting material.',
  ),
  CareTip(
    title: 'Balanced Diet',
    species: 'Lovebird',
    category: 'Feed Guide',
    summary: 'Pellets + leafy greens; limited millet; fresh water daily.',
  ),

  // Cockatiel (no breed)
  CareTip(
    title: 'Whistle Training',
    species: 'Cockatiel',
    category: 'Training Tips',
    summary: 'Imitate simple tunes; reward chirps; avoid loud punishments.',
  ),
  CareTip(
    title: 'Night Frights',
    species: 'Cockatiel',
    category: 'Pet Health',
    summary: 'Use night light; cover partially; reduce sudden noises.',
  ),

  // Canary (no breed)
  CareTip(
    title: 'Song Conditioning',
    species: 'Canary',
    category: 'Care Tips',
    summary: 'Quiet room; consistent daylight; reduce stressors.',
  ),
  CareTip(
    title: 'Seed Mix Upgrade',
    species: 'Canary',
    category: 'Feed Guide',
    summary: 'Seeds + greens + egg food during molt; calcium source.',
  ),

  // ===== FISH =====
  // Goldfish
  CareTip(
    title: 'Goldfish Tank Setup',
    species: 'Fish',
    breed: 'Goldfish',
    category: 'Care Tips',
    summary: '≥75L for first fish; strong filtration; 25% weekly water change.',
  ),
  CareTip(
    title: 'Water Quality Basics',
    species: 'Fish',
    breed: 'Goldfish',
    category: 'Pet Health',
    summary: 'Ammonia/nitrite 0; nitrate <40ppm; test weekly.',
  ),
  CareTip(
    title: 'Feeding Goldfish',
    species: 'Fish',
    breed: 'Goldfish',
    category: 'Feed Guide',
    summary: 'Small portions 2×/day; soak pellets; one fast day/week.',
  ),

  // Betta
  CareTip(
    title: 'Betta Habitat',
    species: 'Fish',
    breed: 'Betta',
    category: 'Care Tips',
    summary: 'Min 10L; gentle filter; heater 26–28°C; many plants.',
  ),
  CareTip(
    title: 'Fin Rot Signs',
    species: 'Fish',
    breed: 'Betta',
    category: 'Pet Health',
    summary: 'Ragged fins; improve water; consider antibacterial per vet.',
  ),
  CareTip(
    title: 'Feeding Betta',
    species: 'Fish',
    breed: 'Betta',
    category: 'Feed Guide',
    summary: 'Protein-rich pellets; tiny meals 1–2×/day; avoid overfeeding.',
  ),

  // Guppy
  CareTip(
    title: 'Easy Breeders',
    species: 'Fish',
    breed: 'Guppy',
    category: 'Care Tips',
    summary: 'Provide floating plants; separate fry; gentle filtration.',
  ),
  CareTip(
    title: 'Flake + Baby Brine',
    species: 'Fish',
    breed: 'Guppy',
    category: 'Feed Guide',
    summary: 'Quality flake; supplement with baby brine for growth.',
  ),

  // Tetra
  CareTip(
    title: 'Schooling Needs',
    species: 'Fish',
    breed: 'Tetra',
    category: 'Care Tips',
    summary: 'Keep groups ≥6; soft acidic water; dark substrate reduces stress.',
  ),
  CareTip(
    title: 'Spot Ich Early',
    species: 'Fish',
    breed: 'Tetra',
    category: 'Pet Health',
    summary: 'White spots; raise temp gradually; treat in hospital tank.',
  ),

  // Angelfish
  CareTip(
    title: 'Community Compatibility',
    species: 'Fish',
    breed: 'Angelfish',
    category: 'Care Tips',
    summary: 'Semi-aggressive; avoid tiny tankmates; vertical plants help.',
  ),
  CareTip(
    title: 'Mixed Diet',
    species: 'Fish',
    breed: 'Angelfish',
    category: 'Feed Guide',
    summary: 'Pellets + frozen bloodworms; small frequent feedings.',
  ),

  // ===== REPTILES =====
  // Iguana
  CareTip(
    title: 'UVB & Basking',
    species: 'Iguana',
    category: 'Care Tips',
    summary: '12hrs UVB daily; basking 35–38°C; large vertical enclosure.',
  ),
  CareTip(
    title: 'Greens-Only Diet',
    species: 'Iguana',
    category: 'Feed Guide',
    summary: 'Collard, mustard, dandelion greens; avoid animal protein & fruit excess.',
  ),
  CareTip(
    title: 'Metabolic Bone Prevention',
    species: 'Iguana',
    category: 'Pet Health',
    summary: 'Strong UVB + calcium supplement; watch tremors & soft jaw.',
  ),
];

/// ---------- Screen ----------
class CareTipsScreen extends StatefulWidget {
  const CareTipsScreen({super.key});

  @override
  State<CareTipsScreen> createState() => _CareTipsScreenState();
}

class _CareTipsScreenState extends State<CareTipsScreen> {
  String _query = '';
  String _category = 'All';
  String _species  = 'Any';
  String _breed    = 'Any';

  // Build species list: union of PetRepository + species present in tips
  List<String> get _speciesOptions {
    final set = <String>{...PetRepository.species};
    for (final t in _tips) {
      set.add(t.species);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Any', ...list];
  }

  // Build breeds: prefer PetRepository, then enrich with breeds from tips
  List<String> get _breedOptions {
    if (_species == 'Any') return const ['Any'];
    final set = <String>{};
    // repo breeds
    final repo = PetRepository.breedsBySpecies[_species] ?? const <String>[];
    set.addAll(repo);
    // breeds present in tips
    for (final t in _tips) {
      if (t.species == _species && (t.breed ?? '').isNotEmpty) set.add(t.breed!);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Any', ...list];
  }

  Iterable<CareTip> get _filtered {
    return _tips.where((t) {
      final byCat = _category == 'All' || t.category == _category;
      final byPet = _species == 'Any' || t.species == _species;
      final byBrd = _breed == 'Any' || (t.breed != null && t.breed == _breed);

      final q = _query.toLowerCase().trim();
      final byQ = q.isEmpty
          || t.title.toLowerCase().contains(q)
          || t.summary.toLowerCase().contains(q)
          || (t.breed ?? '').toLowerCase().contains(q)
          || t.species.toLowerCase().contains(q);

      return byCat && byPet && byBrd && byQ;
    });
  }

  void _clearFilters() {
    setState(() {
      _category = 'All';
      _species  = 'Any';
      _breed    = 'Any';
      _query    = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C8A7E),
        foregroundColor: Colors.white,
        title: const Text('Care Tips'),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(children: [
        // ---- Search ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search (e.g. Persian, Goldfish, Iguana, vaccination)...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        // ---- Filters (2x2 like your screenshot) ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(children: [
            Expanded(
              child: _UnderlinedDD(
                label: 'Category',
                value: _category,
                items: ['All', ..._allCategories],
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _UnderlinedDD(
                label: 'Pet',
                value: _species,
                items: _speciesOptions,
                onChanged: (v) => setState(() {
                  _species = v!;
                  _breed = 'Any';
                }),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            Expanded(
              child: _UnderlinedDD(
                label: 'Breed',
                value: _breed,
                items: _breedOptions,
                onChanged: (v) => setState(() => _breed = v!),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // no Location column
          ]),
        ),

        // ---- Results ----
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No tips match your filters.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TipCard(items[i]),
                ),
        ),
      ]),
    );
  }
}

/// ---------- Underline dropdown (matches your UI) ----------
class _UnderlinedDD extends StatelessWidget {
  const _UnderlinedDD({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        labelText: null, // keep material label small like your screenshot
        border: UnderlineInputBorder(),
        enabledBorder: UnderlineInputBorder(),
        focusedBorder: UnderlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 6),
      ).copyWith(labelText: label),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
    );
  }
}

/// ---------- Tip card ----------
class _TipCard extends StatelessWidget {
  const _TipCard(this.tip);
  final CareTip tip;

  Color _tagColor(String cat) {
    switch (cat) {
      case 'Pet Health':
        return const Color(0xFF0E8D7C);
      case 'Feed Guide':
        return const Color(0xFF6B5B95);
      case 'Home Remedies':
        return const Color(0xFFB56576);
      case 'Care Tips':
        return const Color(0xFF2E86AB);
      case 'Vaccination':
        return const Color(0xFFDAA520);
      case 'Pet Doctor':
        return const Color(0xFF6C757D);
      case 'Expenses':
        return const Color(0xFF2E7D32);
      case 'Training Tips':
        return const Color(0xFF7E57C2);
      case 'Grooming':
        return const Color(0xFF00897B);
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _tagColor(tip.category).withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tip.category,
        style: TextStyle(
          color: _tagColor(tip.category),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal.withOpacity(.12),
            child: const Icon(Icons.lightbulb_outline, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    tip.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                badge,
              ]),
              const SizedBox(height: 4),
              Text(
                '${tip.species}${tip.breed != null ? ' • ${tip.breed}' : ''}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(tip.summary),
            ]),
          ),
        ]),
      ),
    );
  }
}
