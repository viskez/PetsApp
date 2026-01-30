import 'package:flutter/material.dart';
import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import '../models/pet_utils.dart';
import '../widgets/pet_image.dart';
import 'pet_details.dart' show PetDetailsScreen, PetItem;

const Map<PetCategory, String> _kCategoryLabels = {
  PetCategory.animals: 'Animals',
  PetCategory.birds: 'Birds',
  PetCategory.fish: 'Fish',
};

String _labelForCategory(PetCategory category) => _kCategoryLabels[category]!;

PetCategory? _enumFromLabel(String label) {
  for (final entry in _kCategoryLabels.entries) {
    if (entry.value == label) return entry.key;
  }
  return null;
}

/* ========= Adapter: PetCatalogItem -> PetItem ========= */
extension PetCatalogToPetItem on PetCatalogItem {
  PetItem toItem() => PetItem(
        title: displayTitle,
        images: images,
        videos: videos,
        price: price,
        location: location,
        description: description,
        sellerName: sellerName,
        sellerPhone: phone,
        color: color,
        ageYears: ageYears,
        ageMonths: ageMonths,
        gender: gender,
        countType: countType,
        sizeValue: sizeValue,
        sizeUnit: sizeUnit,
        weightKg: weightKg,
        negotiable: negotiable,
        vaccinated: vaccinated,
        dewormed: dewormed,
        trained: trained,
        deliveryAvailable: deliveryAvailable,
        vaccineDetails: vaccineDetails,
        availableFrom: availableFrom,
        address: address,
        pincode: pincode,
        contactPreference: contactPreference,
        pairCount: pairCount,
        pairTotalPrice: pairTotalPrice,
        groupMaleCount: groupMaleCount,
        groupFemaleCount: groupFemaleCount,
        groupMalePrice: groupMalePrice,
        groupFemalePrice: groupFemalePrice,
        groupTotalPets: groupTotalPets,
        groupTotalPrice: groupTotalPrice,
      );
}

/* ===================== Screen ===================== */
class CheckPriceScreen extends StatefulWidget {
  const CheckPriceScreen({super.key});
  @override
  State<CheckPriceScreen> createState() => _CheckPriceScreenState();
}

class _CheckPriceScreenState extends State<CheckPriceScreen> {
  // Search + optional inputs
  final _searchCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _transportCtrl = TextEditingController();
  DateTime? _dob;
  bool _vaccinated = false;

  // Filters
  String _category = 'All';
  String _pet = 'Any';
  String _breed = 'Any';
  String _location = 'All locations';

  PriceResult? _result;

  // Derived maps
  late final List<String> _locations;
  late final Map<String, List<String>> _petMapByCategory;
  late final Map<String, List<String>> _breedMapByPet;

  @override
  void initState() {
    super.initState();

    // Locations
    final setLoc = <String>{'All locations'};
    for (final p in PET_CATALOG) {
      setLoc.add(p.location);
    }
    _locations = setLoc.toList();

    // Build pet/breed maps from catalog titles ("Dog / Labrador")
    final Map<String, Set<String>> petByCat = {
      'Animals': <String>{},
      'Birds': <String>{},
      'Fish': <String>{},
    };
    final Map<String, Set<String>> breedByPet = {};

    for (final it in PET_CATALOG) {
      final (pet, breed) = splitPetTitle(it.title);
      final catLabel = _labelForCategory(it.category);
      petByCat[catLabel]!.add(pet);
      if (breed.isNotEmpty) {
        breedByPet.putIfAbsent(pet, () => <String>{}).add(breed);
      }
    }

    _petMapByCategory = {
      'All': [
        'Any',
        ...{
          ...petByCat['Animals']!,
          ...petByCat['Birds']!,
          ...petByCat['Fish']!,
        }.toList()
          ..sort(),
      ],
      'Animals': ['Any', ...petByCat['Animals']!.toList()..sort()],
      'Birds': ['Any', ...petByCat['Birds']!.toList()..sort()],
      'Fish': ['Any', ...petByCat['Fish']!.toList()..sort()],
    };

    _breedMapByPet = {
      for (final e in breedByPet.entries)
        e.key: ['Any', ...e.value.toList()..sort()],
    };
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _colorCtrl.dispose();
    _transportCtrl.dispose();
    super.dispose();
  }

  /* -------------------- UI -------------------- */

  @override
  Widget build(BuildContext context) {
    final petsForCategory = _petMapByCategory[_category] ?? const ['Any'];
    if (!petsForCategory.contains(_pet)) _pet = 'Any';

    final breedsForPet = _breedMapByPet[_pet] ?? const ['Any'];
    if (!breedsForPet.contains(_breed)) _breed = 'Any';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check price',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          // Search
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search pet or breed (e.g. Minpin, Labrador, Parrot)',
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: _onSearchSubmitted,
          ),
          const SizedBox(height: 12),

          // Filters
          _sectionCard(
            title: 'Filters',
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: _dropdown<String>(
                    label: 'Category',
                    value: _category,
                    items: const ['All', 'Animals', 'Birds', 'Fish'],
                    onChanged: (v) => setState(() {
                      _category = v!;
                      _pet = 'Any';
                      _breed = 'Any';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown<String>(
                    label: 'Pet',
                    value: _pet,
                    items: petsForCategory,
                    onChanged: (v) => setState(() {
                      _pet = v!;
                      _breed = 'Any';
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _dropdown<String>(
                    label: 'Breed',
                    value: _breed,
                    items: breedsForPet,
                    onChanged: (v) => setState(() => _breed = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown<String>(
                    label: 'Location',
                    value: _location,
                    items: _locations,
                    onChanged: (v) => setState(() => _location = v!),
                  ),
                ),
              ]),
            ]),
          ),

          // Optional details
          _sectionCard(
            title: 'Details (optional)',
            subtitle: 'Used to fine-tune estimation',
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _colorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Color (optional)',
                      hintText: 'e.g. Black/White',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dobPicker(
                    label: 'DOB (optional)',
                    dob: _dob,
                    onPick: () async {
                      final now = DateTime.now();
                      final res = await showDatePicker(
                        context: context,
                        initialDate: now.subtract(const Duration(days: 365)),
                        firstDate: DateTime(2000),
                        lastDate: now,
                      );
                      if (res != null) setState(() => _dob = res);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _transportCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Transport charge (optional)',
                      hintText: '₹',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vaccinated'),
                    value: _vaccinated,
                    onChanged: (v) => setState(() => _vaccinated = v),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Text('Age: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_ageText),
              ]),
            ]),
          ),

          // Calculate button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate price'),
            ),
          ),
          const SizedBox(height: 12),

          if (_result != null) ...[
            _resultCard(_result!),
            const SizedBox(height: 12),
            if (_result!.matches.isNotEmpty)
              _comparableScroller(_result!.matches),
          ],
        ],
      ),
    );
  }

  /* -------------------- Actions & helpers -------------------- */

  void _onSearchSubmitted(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return;

    for (final it in PET_CATALOG) {
      final (pet, breed) = splitPetTitle(it.title);
      if (pet.toLowerCase().contains(query) ||
          breed.toLowerCase().contains(query) ||
          it.title.toLowerCase().contains(query)) {
        setState(() {
          _category = _labelForCategory(it.category);
          _pet = pet;
          _breed = (breed.isNotEmpty &&
                  (_breedMapByPet[_pet]?.contains(breed) ?? false))
              ? breed
              : 'Any';
          _location = 'All locations';
        });
        break;
      }
    }
  }

  void _calculate() {
    final res = computeRange(
      catalog: PET_CATALOG,
      category: _category,
      pet: _pet,
      breed: _breed,
      location: _location,
    );
    setState(() => _result = res);
  }

  String get _ageText {
    if (_dob == null) return '-';
    final now = DateTime.now();
    int years = now.year - _dob!.year;
    int months = now.month - _dob!.month;
    if (now.day < _dob!.day) months -= 1;
    while (months < 0) {
      years -= 1;
      months += 12;
    }
    return years > 0 ? '$years y $months m' : '$months m';
  }

  /* -------------------- small builders -------------------- */

  Widget _sectionCard(
      {required String title, String? subtitle, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem<T>(value: e, child: Text('$e')))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _dobPicker(
      {required String label,
      required DateTime? dob,
      required VoidCallback onPick}) {
    String text;
    if (dob == null) {
      text = 'Select date';
    } else {
      final y = dob.year.toString().padLeft(4, '0');
      final m = dob.month.toString().padLeft(2, '0');
      final d = dob.day.toString().padLeft(2, '0');
      text = '$d-$m-$y';
    }
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        child: Row(children: [
          const Icon(Icons.event, size: 18),
          const SizedBox(width: 8),
          Text(text)
        ]),
      ),
    );
  }

  Widget _resultCard(PriceResult r) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Estimated Range',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _metric('Low', r.low == null ? '-' : '₹${r.low}')),
            Expanded(
                child: _metric('High', r.high == null ? '-' : '₹${r.high}')),
            Expanded(
                child: _metric('Average', r.avg == null ? '-' : '₹${r.avg}')),
          ]),
        ]),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.teal, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  /* ------------ Horizontal comparable scroller ------------ */

  Widget _comparableScroller(List<PetCatalogItem> items) {
    final sorted = [...items]
      ..sort((a, b) => _postedAtFor(b).compareTo(_postedAtFor(a)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Comparable listings',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _ComparableCard(
              item: sorted[i],
              postedAt: _postedAtFor(sorted[i]),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PetDetailsScreen(item: sorted[i].toItem())),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Pseudo "posted at" using a hash from title (newer-looking dates first).
  DateTime _postedAtFor(PetCatalogItem it) {
    final h = it.title.hashCode.abs();
    final daysAgo = (h % 20); // within last ~3 weeks
    return DateTime.now().subtract(Duration(days: daysAgo));
  }
}

/* ================== Card for comparable item ================== */

class _ComparableCard extends StatelessWidget {
  final PetCatalogItem item;
  final DateTime postedAt;
  final VoidCallback onTap;
  const _ComparableCard(
      {required this.item, required this.postedAt, required this.onTap});

  String get _postedText {
    final days = DateTime.now().difference(postedAt).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 12,
                child: PetImage(source: item.primaryImage, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('₹${item.price}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, height: 1.0)),
                        const Spacer(),
                        const Icon(Icons.schedule,
                            size: 12.5, color: Colors.grey),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            _postedText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey, height: 1.0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================== Range computation ================== */

class PriceResult {
  final int? low, high, avg;
  final List<PetCatalogItem> matches;
  const PriceResult(
      {required this.low,
      required this.high,
      required this.avg,
      required this.matches});
}

PriceResult computeRange({
  required List<PetCatalogItem> catalog,
  required String category, // 'All', 'Animals', 'Birds', 'Fish'
  required String pet, // 'Any' or actual pet
  required String breed, // 'Any' or actual breed
  required String location, // 'All locations' or a city
}) {
  List<PetCatalogItem> list = List.of(catalog);

  final PetCategory? filterCategory = _enumFromLabel(category);

  if (filterCategory != null) {
    list = list.where((e) => e.category == filterCategory).toList();
  }
  if (pet != 'Any') {
    list = list.where((e) => splitPetTitle(e.title).$1 == pet).toList();
  }
  if (breed != 'Any') {
    list = list.where((e) => splitPetTitle(e.title).$2 == breed).toList();
  }
  if (location != 'All locations') {
    list = list.where((e) => e.location == location).toList();
  }

  if (list.isEmpty) {
    return const PriceResult(low: null, high: null, avg: null, matches: []);
  }

  list.sort((a, b) => a.price.compareTo(b.price));
  final low = list.first.price;
  final high = list.last.price;
  final avg =
      (list.map((e) => e.price).reduce((a, b) => a + b) / list.length).round();

  return PriceResult(low: low, high: high, avg: avg, matches: list);
}
