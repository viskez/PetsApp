import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import '../models/pet_utils.dart';
import '../models/session.dart';
import '../models/plan_store.dart';
import '../utils/plan_access.dart';
import '../views/location_picker_screen.dart';
import '../views/pet_details.dart';
import '../widgets/responsive_tiles.dart';
import '../widgets/pet_image.dart';

class SellTab extends StatefulWidget {
  final PetCatalogItem? initial;
  final ValueChanged<PetCatalogItem>? onSaved;
  final bool closeOnSave;
  final bool startInForm;
  const SellTab({
    super.key,
    this.initial,
    this.onSaved,
    this.closeOnSave = false,
    this.startInForm = false,
  });

  @override
  State<SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<SellTab> {
  static const int _maxListings = 5;
  final _formKey = GlobalKey<FormState>();
  String get _snapshotPrefsKey =>
      'sell_tab_form_snapshot_${Session.currentUser.email.toLowerCase().replaceAll(' ', '_')}';
  String get _customOptionsPrefsKey =>
      'sell_tab_custom_options_${Session.currentUser.email.toLowerCase().replaceAll(' ', '_')}';

  static const int _maxPhotos = 6;
  static const int _maxVideos = 2;

  // Picked media
  final List<XFile> _images = [];
  final List<XFile> _videos = [];
  final List<String> _existingImages = [];
  final List<String> _existingVideos = [];
  final _picker = ImagePicker();
  final PageController _mediaPageController = PageController();
  int _mediaPageIndex = 0;
  _FormSnapshot? _lastSavedSnapshot;
  final ScrollController _scrollController = ScrollController();

  // Form fields
  final _priceCtrl = TextEditingController();
  final _ageYearsCtrl = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _pairCountCtrl = TextEditingController();
  final _groupMaleCountCtrl = TextEditingController();
  final _groupFemaleCountCtrl = TextEditingController();
  final _groupMalePriceCtrl = TextEditingController();
  final _groupFemalePriceCtrl = TextEditingController();

  // Dropdowns & toggles
  final List<String> _categoryOptions = const [
    'All',
    'Animals',
    'Birds',
    'Fish',
    'Reptiles'
  ];
  final List<String> _countOptions = const ['Single', 'Pair', 'Group'];
  final List<String> _sizeUnits = const ['cm', 'inch', 'feet', 'meter'];
  late final Map<String, List<String>> _petOptionsByCategory;
  late final Map<String, List<String>> _breedOptionsByPet;
  late final List<String> _allPets;
  late final List<String> _allBreeds;
  late final Map<String, List<String>> _categoryBreedIndex;
  late final List<_CatalogEntry> _catalogEntries;
  final Map<String, Set<String>> _customSubCategoriesByCategory = {};
  final Map<String, Map<String, Set<String>>> _customBreedsByCategory = {};
  bool _customOptionsLoaded = false;
  String _category = 'All';
  String _subCategory = '';
  String _breed = '';
  String _gender = 'Male';
  String _countType = 'Single';
  String _sizeUnit = 'cm';
  final List<String> _locationOptions = [
    'BENGALURU URBAN',
    'MYSURU',
    'HUBLI',
    'DELHI',
    'MUMBAI',
    'OTHER',
  ];
  String _location = 'BENGALURU URBAN';
  bool _negotiable = true;
  bool _vaccinated = false;
  final TextEditingController _vaccineDetailsCtrl = TextEditingController();
  bool _dewormed = false;
  bool _trained = false;
  bool _deliveryAvailable = true;
  String _contactPref = 'WhatsApp';
  LocationSelectionResult? _locationFromMap;
  PetStatus? _petStatusFilter;
  bool get _isReadOnlyFilter =>
      _petStatusFilter == PetStatus.sold || _petStatusFilter == PetStatus.deleted;

  DateTime? _availableFrom;
  static const Set<String> _noVaccineCategories = {'Birds', 'Fish', 'Reptiles'};

  bool get _isPair => _countType == 'Pair';
  bool get _isGroup => _countType == 'Group';
  bool get _isSingle => _countType == 'Single';
  bool get _showGenderCountFields => _isGroup;
  int get _photoCount => _existingImages.length + _images.length;
  int get _videoCount => _existingVideos.length + _videos.length;
  int get _mediaCount => _photoCount + _videoCount;
  bool get _hasAnyMedia => _mediaCount > 0;
  bool get _canAddPhoto => _photoCount < _maxPhotos;
  bool get _canAddVideo => _videoCount < _maxVideos;
  bool get _isAdmin => Session.currentUser.role.toLowerCase() == 'admin';
  List<_PickedMedia> get _mediaItems => [
        ..._existingImages
            .map((path) => _PickedMedia(existingPath: path, isVideo: false)),
        ..._existingVideos
            .map((path) => _PickedMedia(existingPath: path, isVideo: true)),
        ..._images.map((file) => _PickedMedia(file: file, isVideo: false)),
        ..._videos.map((file) => _PickedMedia(file: file, isVideo: true)),
      ];
  List<PetCatalogItem> get _sellerPets {
    final current = Session.currentUser;
    final phoneDigits = current.phone.replaceAll(RegExp(r'[^0-9]'), '');
    return PetCatalog.all.where((p) {
      final nameMatch =
          p.sellerName.toLowerCase() == current.name.toLowerCase();
      final sellerDigits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatch = phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
      return nameMatch || phoneMatch;
    }).toList();
  }

  List<PetCatalogItem> get _filteredSellerPets {
    final filter = _petStatusFilter;
    if (filter == null) return _sellerPets;
    return _sellerPets.where((p) => p.status == filter).toList();
  }

  Future<void> _deletePet(PetCatalogItem pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete listing'),
        content: Text('Delete "${normalizePetTitle(pet.title)}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final updated = pet.copyWith(status: PetStatus.deleted);
    await PetCatalog.upsertAndSave(updated, previousTitle: pet.title);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listing moved to Deleted tab.')),
    );
  }

  String get _ageDisplay {
    final years = int.tryParse(_ageYearsCtrl.text.trim());
    final months = int.tryParse(_ageMonthsCtrl.text.trim());
    final yText = years == null || years <= 0 ? '0y' : '${years}y';
    final mText = months == null || months <= 0 ? '0m' : '${months}m';
    return '$yText $mText';
  }

  int get _pairCount =>
      _isPair ? int.tryParse(_pairCountCtrl.text.trim()) ?? 0 : 0;
  int get _pairTotalPrice =>
      _pairCount * (int.tryParse(_priceCtrl.text.trim()) ?? 0);

  int get _groupMaleCount =>
      _isGroup ? int.tryParse(_groupMaleCountCtrl.text.trim()) ?? 0 : 0;
  int get _groupFemaleCount =>
      _isGroup ? int.tryParse(_groupFemaleCountCtrl.text.trim()) ?? 0 : 0;
  int get _groupTotalPets => _groupMaleCount + _groupFemaleCount;
  int get _groupMalePrice => int.tryParse(_groupMalePriceCtrl.text.trim()) ?? 0;
  int get _groupFemalePrice =>
      int.tryParse(_groupFemalePriceCtrl.text.trim()) ?? 0;
  int get _groupTotalPrice =>
      _groupMaleCount * _groupMalePrice + _groupFemaleCount * _groupFemalePrice;
  bool get _showVaccinationFields => !_noVaccineCategories.contains(_category);
  String _priceLabel(PetCatalogItem pet) {
    if (pet.price <= 0) return 'Price not set';
    return NumberFormat.compactCurrency(symbol: 'Rs ', decimalDigits: 0)
        .format(pet.price);
  }
  String _locationLabel(PetCatalogItem pet) {
    final loc = pet.location.trim();
    return loc.isEmpty ? 'Location not set' : loc;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 30, now.month, now.day);
    DateTime initial =
        _dateOfBirth ?? DateTime(now.year - 1, now.month, now.day);
    if (initial.isBefore(firstDate)) initial = firstDate;
    final res = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (res != null) {
      _setAgeFromDob(res);
    }
  }

  void _setAgeFromDob(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    if (now.day < dob.day) {
      months -= 1;
    }
    while (months < 0) {
      years -= 1;
      months += 12;
    }
    years = years.clamp(0, 80);
    months = months.clamp(0, 11);
    _ageYearsCtrl.text = years.toString();
    _ageMonthsCtrl.text = months.toString();
    setState(() {
      _dateOfBirth = dob;
    });
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<LocationSelectionResult?>(
      LocationPickerScreen.route(initialResult: _locationFromMap),
    );
    if (result == null) return;

    final formattedPin = result.postalCode?.trim();
    if (formattedPin != null && formattedPin.isNotEmpty) {
      _pincodeCtrl.text = formattedPin;
    }
    _addressCtrl.text = result.formattedAddress;

    setState(() {
      _locationFromMap = result;
      final city = (result.city ?? '').trim().toUpperCase();
      if (city.isNotEmpty) {
        _addLocationOption(city);
        _location = city;
      }
    });
  }

  void _addLocationOption(String value) {
    final city = value.trim();
    if (city.isEmpty) return;
    if (!_locationOptions.contains(city)) {
      _locationOptions.insert(0, city);
    }
  }

  @override
  void initState() {
    super.initState();
    _showForm = widget.initial != null || widget.startInForm;
    _ageYearsCtrl.addListener(_onAgeChanged);
    _ageMonthsCtrl.addListener(_onAgeChanged);
    _priceCtrl.addListener(_autoSaveDraft);
    _descCtrl.addListener(_autoSaveDraft);
    _addressCtrl.addListener(_autoSaveDraft);
    _pincodeCtrl.addListener(_autoSaveDraft);
    _colorCtrl.addListener(_autoSaveDraft);
    _sizeCtrl.addListener(_autoSaveDraft);
    _weightCtrl.addListener(_autoSaveDraft);
    _subCategoryCtrl.addListener(_autoSaveDraft);
    _breedCtrl.addListener(_autoSaveDraft);
    _pairCountCtrl.addListener(_autoSaveDraft);
    _groupMaleCountCtrl.addListener(_autoSaveDraft);
    _groupFemaleCountCtrl.addListener(_autoSaveDraft);
    _groupMalePriceCtrl.addListener(_autoSaveDraft);
    _groupFemalePriceCtrl.addListener(_autoSaveDraft);
    _vaccineDetailsCtrl.addListener(_autoSaveDraft);
    _buildPetOptions();
    _prefillIfEditing();
    _loadCustomOptions();
    if (widget.initial == null) {
      _resetToBlank();
      _loadSavedSnapshot();
    } else {
      _lastSavedSnapshot = _captureSnapshot();
    }
    _ensureValidSelections(allowUnknownCustoms: true);
  }

  void _prefillIfEditing() {
    final pet = widget.initial;
    if (pet == null) return;
    _showForm = true;
    _priceCtrl.text = pet.price.toString();
    _descCtrl.text = pet.description;
    _location = pet.location;
    _addLocationOption(_location);
    _addressCtrl.text = pet.location;
    final (petName, breed) = _parseTitle(pet.title);
    _category = _labelForCategory(pet.category);
    _subCategory = petName;
    _breed = breed;
    _subCategoryCtrl.text = _subCategory;
    _breedCtrl.text = _breed;
    _contactPref = 'Phone';
    _existingImages
      ..clear()
      ..addAll(pet.images);
    _existingVideos
      ..clear()
      ..addAll(pet.videos);
  }

  void _resetToBlank() {
    _priceCtrl.clear();
    _descCtrl.clear();
    _addressCtrl.clear();
    _pincodeCtrl.clear();
    _colorCtrl.clear();
    _sizeCtrl.clear();
    _weightCtrl.clear();
    _subCategoryCtrl.clear();
    _breedCtrl.clear();
    _ageYearsCtrl.clear();
    _ageMonthsCtrl.clear();
    _location = _locationOptions.first;
    _category = 'All';
    _subCategory = 'All';
    _breed = 'All';
    _subCategoryCtrl.text = 'All';
    _breedCtrl.text = 'All';
    _images.clear();
    _videos.clear();
    _existingImages.clear();
    _existingVideos.clear();
    _mediaPageIndex = 0;
    _ensureValidSelections(allowUnknownCustoms: !_customOptionsLoaded);
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _startAddPet() async {
    final created = await Navigator.push<PetCatalogItem>(
      context,
      MaterialPageRoute(
        builder: (_) => SellTab(
          startInForm: true,
          closeOnSave: true,
          onSaved: (pet) {
            widget.onSaved?.call(pet);
          },
        ),
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _showForm = false;
      });
    }
  }

  Future<void> _startEditPet(PetCatalogItem pet) async {
    final updated = await Navigator.push<PetCatalogItem>(
      context,
      MaterialPageRoute(
        builder: (_) => SellTab(
          initial: pet,
          closeOnSave: true,
          onSaved: (updatedPet) {
            widget.onSaved?.call(updatedPet);
          },
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _updatePetStatus(
      PetCatalogItem pet, PetStatus status) async {
    final updated = pet.copyWith(status: status);
    await PetCatalog.upsertAndSave(updated, previousTitle: pet.title);
    if (!mounted) return;
    setState(() {});
  }

  void _autoSaveDraft() {
    if (!mounted) return;
    final snapshot = _captureSnapshot();
    _lastSavedSnapshot = snapshot;
    _saveSnapshotToPrefs(snapshot);
  }

  void _onAgeChanged() {
    setState(() {
      _dateOfBirth = null;
    });
    _autoSaveDraft();
  }

  DateTime? _dateOfBirth;

  void _buildPetOptions() {
    final Map<String, Set<String>> petMap = {
      for (final cat in _categoryOptions.where((c) => c != 'All'))
        cat: <String>{},
    };
    final Map<String, Set<String>> breedMap = {};
    final Map<String, Set<String>> breedByCategory = {
      for (final cat in _categoryOptions.where((c) => c != 'All'))
        cat: <String>{},
    };
    final allPets = <String>{};
    final entries = <_CatalogEntry>[];

    for (final item in PET_CATALOG) {
      final categoryLabel = _labelForCategory(item.category);
      final (pet, breed) = _parseTitle(item.title);
      petMap[categoryLabel]?.add(pet);
      allPets.add(pet);
      breedMap.putIfAbsent(pet, () => <String>{}).add(breed);
      breedByCategory[categoryLabel]?.add(breed);
      entries.add(_CatalogEntry(
          item: item, category: categoryLabel, pet: pet, breed: breed));
    }

    _petOptionsByCategory = {
      for (final entry in petMap.entries)
        entry.key: entry.value.toList()..sort()
    };
    _allPets = allPets.toList()..sort();
    _breedOptionsByPet = {
      for (final entry in breedMap.entries)
        entry.key: entry.value.toList()..sort()
    };
    _categoryBreedIndex = {
      for (final entry in breedByCategory.entries)
        entry.key: entry.value.toList()..sort()
    };
    _allBreeds = _categoryBreedIndex.values
        .expand((list) => list)
        .toSet()
        .toList()
      ..sort();

    _catalogEntries = entries;

    _category = 'All';
    _subCategory = 'All';
    _breed = 'All';
    _subCategoryCtrl.text = _subCategory;
    _breedCtrl.text = _breed;
  }

  String _labelForCategory(PetCategory category) {
    if (category == PetCategory.animals) return 'Animals';
    if (category == PetCategory.birds) return 'Birds';
    if (category == PetCategory.fish) return 'Fish';
    return 'Reptiles';
  }

  PetCategory _categoryFromLabel(String label) {
    switch (label) {
      case 'Birds':
        return PetCategory.birds;
      case 'Fish':
        return PetCategory.fish;
      default:
        return PetCategory.animals;
    }
  }

  
  (String, String) _parseTitle(String title) {
    final normalized = normalizePetTitle(title);
    final (pet, breed) = splitPetTitle(normalized);
    if (pet.isEmpty) return (normalized, '');
    if (breed.isEmpty || breed == pet) return (pet, '');
    return (pet, breed);
  }


  bool _containsIgnoreCase(Iterable<String> values, String value) {
    final target = value.trim().toLowerCase();
    if (target.isEmpty) return false;
    for (final item in values) {
      if (item.trim().toLowerCase() == target) return true;
    }
    return false;
  }

  Future<void> _loadCustomOptions() async {
    final subCats = <String, Set<String>>{};
    final breedMap = <String, Map<String, Set<String>>>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customOptionsPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final subs = decoded['subCategories'];
          if (subs is Map) {
            subs.forEach((key, value) {
              if (value is List) {
                final set =
                    subCats.putIfAbsent(key.toString(), () => <String>{});
                set.addAll(value
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty));
              }
            });
          }
          final breeds = decoded['breeds'];
          if (breeds is Map) {
            breeds.forEach((catKey, subValue) {
              if (subValue is Map) {
                final subMap = breedMap.putIfAbsent(
                    catKey.toString(), () => <String, Set<String>>{});
                subValue.forEach((subKey, breedList) {
                  if (breedList is List) {
                    final set = subMap.putIfAbsent(
                        subKey.toString(), () => <String>{});
                    set.addAll(breedList
                        .map((e) => e.toString().trim())
                        .where((e) => e.isNotEmpty));
                  }
                });
              }
            });
          }
        }
      }
    } catch (_) {
      // Persistence errors are non-blocking for the form
    }
    if (!mounted) return;
    setState(() {
      _customSubCategoriesByCategory
        ..clear()
        ..addAll(subCats);
      _customBreedsByCategory
        ..clear()
        ..addAll(breedMap);
      _customOptionsLoaded = true;
    });
    _ensureValidSelections(allowUnknownCustoms: !_customOptionsLoaded);
  }

  Future<void> _saveCustomOptions() async {
    final payload = {
      'subCategories': _customSubCategoriesByCategory.map(
        (key, value) {
          final list = value.toList()..sort();
          return MapEntry(key, list);
        },
      ),
      'breeds': _customBreedsByCategory.map(
        (cat, subs) => MapEntry(
          cat,
          subs.map((sub, breeds) {
            final list = breeds.toList()..sort();
            return MapEntry(sub, list);
          }),
        ),
      ),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customOptionsPrefsKey, jsonEncode(payload));
    } catch (_) {
      // Ignore save failures; options remain in memory
    }
  }

  void _addCustomSubCategory(String category, String value) {
    final name = value.trim();
    if (name.isEmpty) return;
    final set =
        _customSubCategoriesByCategory.putIfAbsent(category, () => <String>{});
    if (_containsIgnoreCase(set, name)) return;
    set.add(name);
  }

  void _addCustomBreed(String category, String subCategory, String breed) {
    final sub = subCategory.trim();
    final name = breed.trim();
    if (sub.isEmpty || name.isEmpty) return;
    final subMap = _customBreedsByCategory.putIfAbsent(
        category, () => <String, Set<String>>{});
    final breedSet = subMap.putIfAbsent(sub, () => <String>{});
    if (_containsIgnoreCase(breedSet, name)) return;
    breedSet.add(name);
  }

  List<String> _customSubCategoriesFor(String category) {
    final values = <String>{};
    if (category == 'All') {
      for (final entry in _customSubCategoriesByCategory.values) {
        values.addAll(entry);
      }
    } else {
      values.addAll(_customSubCategoriesByCategory[category] ?? const <String>{});
      values.addAll(_customSubCategoriesByCategory['All'] ?? const <String>{});
    }
    final list = values.toList()..sort();
    return list;
  }

  List<String> _customBreedsForCategory(String category) {
    if (category == 'All') {
      return _allCustomBreeds();
    }
    final values = <String>{};
    final map = _customBreedsByCategory[category];
    if (map != null) {
      values.addAll(map.values.expand((s) => s));
    }
    final global = _customBreedsByCategory['All'];
    if (global != null) {
      values.addAll(global.values.expand((s) => s));
    }
    final list = values.toList()..sort();
    return list;
  }

  List<String> _customBreedsFor(String category, String subCategory) {
    if (subCategory == 'All') {
      return _customBreedsForCategory(category);
    }
    final values = <String>{};
    if (category == 'All') {
      for (final entry in _customBreedsByCategory.entries) {
        final breeds = entry.value[subCategory];
        if (breeds != null) values.addAll(breeds);
      }
    } else {
      final map = _customBreedsByCategory[category];
      if (map != null) {
        values.addAll(map[subCategory] ?? const <String>{});
      }
      final global = _customBreedsByCategory['All'];
      if (global != null) {
        values.addAll(global[subCategory] ?? const <String>{});
      }
    }
    final list = values.toList()..sort();
    return list;
  }

  List<String> _allCustomBreeds() {
    return _customBreedsByCategory.values
        .expand((map) => map.values)
        .expand((set) => set)
        .toSet()
        .toList()
      ..sort();
  }

  bool _isCustomSubCategory(String category, String value) {
    if (value == 'All' || value == 'Other') return false;
    final candidates = category == 'All'
        ? _customSubCategoriesFor('All')
        : _customSubCategoriesFor(category);
    return _containsIgnoreCase(candidates, value);
  }

  bool _isCustomBreed(String category, String subCategory, String value) {
    if (value == 'All' || value == 'Other') return false;
    if (_containsIgnoreCase(_customBreedsFor(category, subCategory), value)) {
      return true;
    }
    if (category == 'All') {
      return _containsIgnoreCase(_allCustomBreeds(), value);
    }
    return false;
  }

  bool _hasSubCategory(String category, String value) {
    final options = _subCategoriesFor(category)
        .where((item) => item != 'All' && item != 'Other');
    return _containsIgnoreCase(options, value);
  }



  List<String> _subCategoriesFor(String category) {
    final base = category == 'All'
        ? (_allPets.isEmpty ? <String>[] : _allPets)
        : (_petOptionsByCategory[category] ?? const <String>[]);
    final custom = _customSubCategoriesFor(category);
    final merged = <String>{
      ...base.where((v) => v.toLowerCase() != 'other'),
      ...custom.where((v) => v.toLowerCase() != 'other'),
    }.toList()
      ..sort();
    final options = ['All', ...merged];
    if (!options.contains('Other')) {
      options.add('Other');
    }
    return options;
  }

  List<String> _breedsForSelection(String category, String subCategory) {
    final values = <String>{};
    if (subCategory != 'All') {
      values.addAll(_breedOptionsByPet[subCategory] ?? const <String>[]);
      values.addAll(_customBreedsFor(category, subCategory));
    } else if (category == 'All') {
      values.addAll(_allBreeds);
      values.addAll(_allCustomBreeds());
    } else {
      values.addAll(_categoryBreedIndex[category] ?? const <String>[]);
      values.addAll(_customBreedsForCategory(category));
    }

    final merged = values
        .where((v) => v.toLowerCase() != 'other')
        .toSet()
        .toList()
      ..sort();
    final options = ['All', ...merged];
    if (!options.contains('Other')) {
      options.add('Other');
    }
    return options;
  }

  void _onCategoryChanged(String? value) {
    if (value == null) return;
    final subCats = _subCategoriesFor(value);
    final newSub =
        subCats.contains(_subCategory) ? _subCategory : subCats.first;
    final breeds = _breedsForSelection(value, newSub);
    final newBreed = breeds.contains(_breed) ? _breed : breeds.first;
    setState(() {
      _category = value;
      _subCategory = newSub;
      _breed = newBreed;
      _subCategoryCtrl.text = newSub;
      _breedCtrl.text = newBreed;
    });
  }

  void _onSubCategorySelected(String? value) async {
    if (value == null) return;
    if (value == 'Other') {
      final prevSub = _subCategory;
      final prevBreed = _breed;
      final result = await _showCustomOptionDialog(
        title: 'Add Sub Category',
        requireSubCategory: true,
        requireBreed: false,
      );
      if (!mounted) return;
      if (result == null || !result.hasSubCategory) {
        setState(() {
          _subCategory = prevSub;
          _breed = prevBreed;
          _subCategoryCtrl.text = prevSub;
          _breedCtrl.text = prevBreed;
        });
        return;
      }
      final newSub = result.subCategory!.trim();
      final newBreedInput = result.breed?.trim() ?? '';
      if (!_hasSubCategory(_category, newSub)) {
        _addCustomSubCategory(_category, newSub);
      }
      if (newBreedInput.isNotEmpty) {
        _addCustomBreed(_category, newSub, newBreedInput);
      }
      final breeds = _breedsForSelection(_category, newSub);
      final normalizedBreed = newBreedInput.isNotEmpty
          ? newBreedInput
          : (breeds.contains(prevBreed) ? prevBreed : breeds.first);
      setState(() {
        _subCategory = newSub;
        _breed = normalizedBreed;
        _subCategoryCtrl.text = newSub;
        _breedCtrl.text = normalizedBreed;
      });
      await _saveCustomOptions();
      return;
    }
    final breeds = _breedsForSelection(_category, value);
    final newBreed = breeds.contains(_breed) ? _breed : breeds.first;
    setState(() {
      _subCategory = value;
      _breed = newBreed;
      _subCategoryCtrl.text = value;
      _breedCtrl.text = newBreed;
    });
  }

  void _onBreedSelected(String? value) async {
    if (value == null) return;
    if (value == 'Other') {
      final prevBreed = _breed;
      final prevSub = _subCategory;
      final hasSubSelection =
          prevSub.isNotEmpty && prevSub != 'All' && prevSub != 'Other';
      final result = await _showCustomOptionDialog(
        title: 'Add Breed',
        requireSubCategory: !hasSubSelection,
        requireBreed: true,
        initialSubCategory: hasSubSelection ? prevSub : '',
      );
      if (!mounted) return;
      if (result == null || !result.hasBreed) {
        setState(() {
          _breed = prevBreed;
          _breedCtrl.text = prevBreed;
        });
        return;
      }
      final submittedSub = result.subCategory?.trim() ?? '';
      final targetSub =
          submittedSub.isNotEmpty ? submittedSub : (hasSubSelection ? prevSub : '');
      if (targetSub.isEmpty) {
        setState(() {
          _breed = prevBreed;
          _breedCtrl.text = prevBreed;
        });
        return;
      }
      final newBreed = result.breed!.trim();
      if (!_hasSubCategory(_category, targetSub)) {
        _addCustomSubCategory(_category, targetSub);
      }
      _addCustomBreed(_category, targetSub, newBreed);
      setState(() {
        _subCategory = targetSub;
        _breed = newBreed;
        _subCategoryCtrl.text = targetSub;
        _breedCtrl.text = newBreed;
      });
      await _saveCustomOptions();
      return;
    }
    setState(() {
      _breed = value;
      _breedCtrl.text = value;
    });
  }

  Future<_CustomOptionResult?> _showCustomOptionDialog({
    required bool requireSubCategory,
    required bool requireBreed,
    String? initialSubCategory,
    String? initialBreed,
    String? title,
  }) async {
    final formKey = GlobalKey<FormState>();
    final subCtrl = TextEditingController(text: initialSubCategory ?? '');
    final breedCtrl = TextEditingController(text: initialBreed ?? '');
    try {
      return await showDialog<_CustomOptionResult>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title ?? 'Add option'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: subCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Sub category name'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (requireSubCategory && text.isEmpty) {
                      return 'Please add a sub category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: breedCtrl,
                  decoration: const InputDecoration(labelText: 'Breed name'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (requireBreed && text.isEmpty) {
                      return 'Please add a breed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Custom entries are saved for you and shown in red.',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _CustomOptionResult(
                    subCategory: subCtrl.text.trim(),
                    breed: breedCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      subCtrl.dispose();
      breedCtrl.dispose();
    }
  }

  void _applyCatalogSelection(_CatalogEntry entry) {
    final subOptions = _subCategoriesFor(entry.category);
    final normalizedPet = subOptions.contains(entry.pet)
        ? entry.pet
        : (subOptions.isNotEmpty ? subOptions.first : 'All');
    final breedOptions = _breedsForSelection(entry.category, normalizedPet);
    final normalizedBreed = breedOptions.contains(entry.breed)
        ? entry.breed
        : (breedOptions.isNotEmpty ? breedOptions.first : 'All');

    setState(() {
      _category = entry.category;
      _subCategory = normalizedPet;
      _breed = normalizedBreed;
      _subCategoryCtrl.text = normalizedPet;
      _breedCtrl.text = normalizedBreed;
    });
  }

  Future<void> _openCatalogSearch() async {
    final controller = TextEditingController();
    final categoryFilter = _category;
    List<_CatalogEntry> results = categoryFilter == 'All'
        ? _catalogEntries
        : _catalogEntries.where((e) => e.category == categoryFilter).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          void filter(String query) {
            final q = query.trim().toLowerCase();
            setModalState(() {
              Iterable<_CatalogEntry> source = categoryFilter == 'All'
                  ? _catalogEntries
                  : _catalogEntries.where((e) => e.category == categoryFilter);
              results = q.isEmpty
                  ? source.toList()
                  : source
                      .where((entry) =>
                          entry.item.title.toLowerCase().contains(q) ||
                          entry.pet.toLowerCase().contains(q) ||
                          entry.breed.toLowerCase().contains(q) ||
                          entry.item.description.toLowerCase().contains(q))
                      .toList();
            });
          }

          void selectEntry(_CatalogEntry entry) {
            Navigator.pop(context);
            _applyCatalogSelection(entry);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Search catalog',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: filter,
                  onSubmitted: (_) {
                    if (results.isNotEmpty) {
                      selectEntry(results.first);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: results.isEmpty
                      ? const Center(child: Text('No matches found'))
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final entry = results[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade50,
                                child: Text(
                                  entry.pet.isNotEmpty
                                      ? entry.pet.substring(0, 1).toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(entry.pet),
                              subtitle:
                                  Text('${entry.breed} • ${entry.category}'),
                              trailing: const Icon(Icons.check),
                              onTap: () => selectEntry(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // Helpers
  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (!_canAddPhoto) {
      _showMediaLimitMessage('photos', _maxPhotos);
      return;
    }

    final choice = await _chooseSource();
    if (choice == null) return;

    if (choice == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) {
        final slots = _maxPhotos - _photoCount;
        final allowed = picked.take(slots).toList();
        if (allowed.isNotEmpty) {
          setState(() {
            _images.addAll(allowed);
            _mediaPageIndex = _mediaCount - 1;
          });
          _animatePagerTo(_mediaPageIndex);
        }
        if (allowed.length < picked.length) {
          _showMediaLimitMessage('photos', _maxPhotos);
        }
        return;
      }
    }

    final single = await _picker.pickImage(source: choice, imageQuality: 85);
    if (single != null) {
      setState(() {
        _images.add(single);
        _mediaPageIndex = _mediaCount - 1;
      });
      _animatePagerTo(_mediaPageIndex);
    }
  }

  Future<void> _pickVideo() async {
    if (!_canAddVideo) {
      _showMediaLimitMessage('videos', _maxVideos);
      return;
    }

    final choice = await _chooseSource();
    if (choice == null) return;

    final single = await _picker.pickVideo(
      source: choice,
      maxDuration: const Duration(seconds: 60),
    );

    if (single != null) {
      setState(() {
        _videos.add(single);
        _mediaPageIndex = _mediaCount - 1;
      });
      _animatePagerTo(_mediaPageIndex);
    }
  }

  void _removeMediaAt(int index) {
    if (index < 0 || index >= _mediaCount) return;
    setState(() {
      final existingPhotoCount = _existingImages.length;
      final existingVideoCount = _existingVideos.length;
      final newPhotoCount = _images.length;

      if (index < existingPhotoCount) {
        _existingImages.removeAt(index);
      } else if (index < existingPhotoCount + existingVideoCount) {
        final videoIdx = index - existingPhotoCount;
        if (videoIdx >= 0 && videoIdx < _existingVideos.length) {
          _existingVideos.removeAt(videoIdx);
        }
      } else if (index <
          existingPhotoCount + existingVideoCount + newPhotoCount) {
        final photoIdx = index - existingPhotoCount - existingVideoCount;
        if (photoIdx >= 0 && photoIdx < _images.length) {
          _images.removeAt(photoIdx);
        }
      } else {
        final videoIdx =
            index - existingPhotoCount - existingVideoCount - newPhotoCount;
        if (videoIdx >= 0 && videoIdx < _videos.length) {
          _videos.removeAt(videoIdx);
        }
      }
      final total = _mediaCount;
      if (total == 0) {
        _mediaPageIndex = 0;
      } else if (_mediaPageIndex >= total) {
        _mediaPageIndex = total - 1;
      }
    });
    _animatePagerTo(_mediaPageIndex);
  }

  void _animatePagerTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final total = _mediaCount;
      if (total == 0 || !_mediaPageController.hasClients) return;
      final target = index.clamp(0, total - 1).toInt();
      _mediaPageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  _FormSnapshot _captureSnapshot() {
    return _FormSnapshot(
      category: _category,
      subCategory: _subCategory,
      breed: _breed,
      gender: _gender,
      countType: _countType,
      sizeUnit: _sizeUnit,
      location: _location,
      negotiable: _negotiable,
      vaccinated: _vaccinated,
      dewormed: _dewormed,
      trained: _trained,
      deliveryAvailable: _deliveryAvailable,
      contactPref: _contactPref,
      availableFrom: _availableFrom,
      dateOfBirth: _dateOfBirth,
      termsAccepted: _termsAccepted,
      locationFromMap: _cloneLocation(_locationFromMap),
      locationOptions: List<String>.from(_locationOptions),
      mediaPageIndex: _mediaPageIndex,
      existingImages: List<String>.from(_existingImages),
      existingVideos: List<String>.from(_existingVideos),
      localImages: _images.map((file) => file.path).toList(),
      localVideos: _videos.map((file) => file.path).toList(),
      textFields: {
        'price': _priceCtrl.text,
        'ageYears': _ageYearsCtrl.text,
        'ageMonths': _ageMonthsCtrl.text,
        'desc': _descCtrl.text,
        'address': _addressCtrl.text,
        'pincode': _pincodeCtrl.text,
        'color': _colorCtrl.text,
        'size': _sizeCtrl.text,
        'weight': _weightCtrl.text,
        'subCategory': _subCategoryCtrl.text,
        'breed': _breedCtrl.text,
        'pairCount': _pairCountCtrl.text,
        'groupMaleCount': _groupMaleCountCtrl.text,
        'groupFemaleCount': _groupFemaleCountCtrl.text,
        'groupMalePrice': _groupMalePriceCtrl.text,
        'groupFemalePrice': _groupFemalePriceCtrl.text,
        'vaccineDetails': _vaccineDetailsCtrl.text,
      },
    );
  }

  Future<void> _saveSnapshotToPrefs(_FormSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _snapshotPrefsKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Ignore persistence errors; UI will still reflect in-memory snapshot
    }
  }

  Future<void> _loadSavedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_snapshotPrefsKey);
      if (data == null || data.isEmpty) {
        _lastSavedSnapshot = _captureSnapshot();
        return;
      }
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        final snapshot = _FormSnapshot.fromJson(decoded);
        _lastSavedSnapshot = snapshot;
        _restoreSnapshot(snapshot);
      } else {
        _lastSavedSnapshot = _captureSnapshot();
      }
    } catch (_) {
      _lastSavedSnapshot = _captureSnapshot();
    }
  }

  void _restoreSnapshot(_FormSnapshot snapshot) {
    setState(() {
      _category = snapshot.category;
      _subCategory = snapshot.subCategory;
      _breed = snapshot.breed;
      _gender = snapshot.gender;
      _countType = snapshot.countType;
      _sizeUnit = snapshot.sizeUnit;
      _location = snapshot.location;
      _negotiable = snapshot.negotiable;
      _vaccinated = snapshot.vaccinated;
      _dewormed = snapshot.dewormed;
      _trained = snapshot.trained;
      _deliveryAvailable = snapshot.deliveryAvailable;
      _contactPref = snapshot.contactPref;
      _availableFrom = snapshot.availableFrom;
      _dateOfBirth = snapshot.dateOfBirth;
      _termsAccepted = snapshot.termsAccepted;
      _locationFromMap = _cloneLocation(snapshot.locationFromMap);
      _locationOptions
        ..clear()
        ..addAll(snapshot.locationOptions);
      _addLocationOption(_location);
      _existingImages
        ..clear()
        ..addAll(snapshot.existingImages);
      _existingVideos
        ..clear()
        ..addAll(snapshot.existingVideos);
      _images
        ..clear()
        ..addAll(snapshot.localImages.map((path) => XFile(path)));
      _videos
        ..clear()
        ..addAll(snapshot.localVideos.map((path) => XFile(path)));
      _mediaPageIndex = snapshot.mediaPageIndex.clamp(
          0, _mediaCount == 0 ? 0 : _mediaCount - 1);
    });

    _ensureValidSelections(allowUnknownCustoms: !_customOptionsLoaded);

    _priceCtrl.text = snapshot.textFields['price'] ?? '';
    _ageYearsCtrl.text = snapshot.textFields['ageYears'] ?? '';
    _ageMonthsCtrl.text = snapshot.textFields['ageMonths'] ?? '';
    _descCtrl.text = snapshot.textFields['desc'] ?? '';
    _addressCtrl.text = snapshot.textFields['address'] ?? '';
    _pincodeCtrl.text = snapshot.textFields['pincode'] ?? '';
    _colorCtrl.text = snapshot.textFields['color'] ?? '';
    _sizeCtrl.text = snapshot.textFields['size'] ?? '';
    _weightCtrl.text = snapshot.textFields['weight'] ?? '';
    _subCategoryCtrl.text = snapshot.textFields['subCategory'] ?? '';
    _breedCtrl.text = snapshot.textFields['breed'] ?? '';
    _pairCountCtrl.text = snapshot.textFields['pairCount'] ?? '';
    _groupMaleCountCtrl.text = snapshot.textFields['groupMaleCount'] ?? '';
    _groupFemaleCountCtrl.text =
        snapshot.textFields['groupFemaleCount'] ?? '';
    _groupMalePriceCtrl.text = snapshot.textFields['groupMalePrice'] ?? '';
    _groupFemalePriceCtrl.text =
        snapshot.textFields['groupFemalePrice'] ?? '';
    _vaccineDetailsCtrl.text = snapshot.textFields['vaccineDetails'] ?? '';

    _animatePagerTo(_mediaPageIndex);
  }

  LocationSelectionResult? _cloneLocation(LocationSelectionResult? value) {
    if (value == null) return null;
    return LocationSelectionResult(
      latitude: value.latitude,
      longitude: value.longitude,
      formattedAddress: value.formattedAddress,
      city: value.city,
      postalCode: value.postalCode,
    );
  }

  void _ensureValidSelections({bool allowUnknownCustoms = false}) {
    final subOptions = _subCategoriesFor(_category);
    final missingSub = !subOptions.contains(_subCategory);
    if (missingSub && subOptions.isNotEmpty) {
      final waitForCustoms =
          allowUnknownCustoms && !_customOptionsLoaded && _subCategory.isNotEmpty;
      if (!waitForCustoms) {
        _subCategory = subOptions.first;
        _subCategoryCtrl.text = _subCategory;
      }
    }
    final breedOptions = _breedsForSelection(_category, _subCategory);
    final missingBreed = !breedOptions.contains(_breed);
    if (missingBreed && breedOptions.isNotEmpty) {
      final waitForCustoms =
          allowUnknownCustoms && !_customOptionsLoaded && _breed.isNotEmpty;
      if (!waitForCustoms) {
        _breed = breedOptions.first;
        _breedCtrl.text = _breed;
      }
    }
    _autoSaveDraft();
  }

  void _showMediaLimitMessage(String label, int max) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can add up to $max $label.')),
    );
  }

  int _ownedPetCount() {
    final current = Session.currentUser;
    final phoneDigits = current.phone.replaceAll(RegExp(r'[^0-9]'), '');
    return PetCatalog.all.where((p) {
      final nameMatch = p.sellerName.toLowerCase() == current.name.toLowerCase();
      final sellerDigits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatch = phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
      return nameMatch || phoneMatch;
    }).length;
  }

  Future<bool> _ensureListingLimit() async {
    if (_isAdmin || widget.initial != null) return true;
    if (_ownedPetCount() < _maxListings) return true;
    return await requirePlanPoints(context, PlanAction.addPet);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _availableFrom ?? now,
    );
    if (res != null) setState(() => _availableFrom = res);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_hasAnyMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one photo or video.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms & Conditions.')),
      );
      return;
    }
    if (!await _ensureListingLimit()) return;

    final isEditing = widget.initial != null;
    if (isEditing) {
      final confirmUpdate = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update listing?'),
          content: const Text(
              'This will update the existing post for this pet.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update')),
          ],
        ),
      );
      if (confirmUpdate != true) return;
    } else {
      final postToBuy = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Post to Buy?'),
          content: const Text(
              'Do you want to publish this listing to the Buy screen?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Post')),
          ],
        ),
      );
      if (postToBuy != true) {
        return;
      }
    }

    // Build request payload (demo)
    final payload = {
      'category': _category,
      'subCategory': _subCategory.trim(),
      'breed': _breed.trim(),
      'gender': _isSingle ? _gender : null,
      'countType': _countType,
      'pairCount': _isPair ? _pairCount : null,
      'groupMaleCount': _isGroup ? _groupMaleCount : null,
      'groupFemaleCount': _isGroup ? _groupFemaleCount : null,
      'groupTotalPets': _isGroup ? _groupTotalPets : null,
      'color': _colorCtrl.text.trim(),
      'sizeValue': _sizeCtrl.text.trim(),
      'sizeUnit': _sizeUnit,
      'weightKg': _isSingle ? _weightCtrl.text.trim() : null,
      'ageYears': int.tryParse(_ageYearsCtrl.text.trim()) ?? 0,
      'ageMonths': int.tryParse(_ageMonthsCtrl.text.trim()) ?? 0,
      'dob': _dateOfBirth?.toIso8601String(),
      'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
      'pairTotalPrice': _isPair ? _pairTotalPrice : null,
      'groupMalePricePerPet': _isGroup ? _groupMalePrice : null,
      'groupFemalePricePerPet': _isGroup ? _groupFemalePrice : null,
      'groupTotalPrice': _isGroup ? _groupTotalPrice : null,
      'negotiable': _negotiable,
      'vaccinated': _vaccinated,
      'dewormed': _dewormed,
      'trained': _trained,
      'location': _location,
      'address': _addressCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'locationLatitude': _locationFromMap?.latitude,
      'locationLongitude': _locationFromMap?.longitude,
      'locationAddressFromMap': _locationFromMap?.formattedAddress,
      'mapCity': _locationFromMap?.city,
      'mapPostalCode': _locationFromMap?.postalCode,
      'availableFrom': _availableFrom?.toIso8601String(),
      'deliveryAvailable': _deliveryAvailable,
      'contactPreference': _contactPref,
      'description': _descCtrl.text.trim(),
      'imagesCount': _photoCount,
      'videosCount': _videoCount,
    };

    final titlePart = _subCategory.isNotEmpty && _subCategory != 'All'
        ? _subCategory
        : _category;
    final breedPart = _breed.isNotEmpty && _breed != 'All' ? _breed : '';
    final displayTitle =
        breedPart.isNotEmpty ? '$titlePart - $breedPart' : titlePart;
    // New images take precedence so the latest photo becomes the thumbnail
    final mergedImages = [
      ..._images.map((file) => file.path),
      ..._existingImages,
    ];
    final mergedVideos = [
      ..._videos.map((file) => file.path),
      ..._existingVideos,
    ];
    if (mergedImages.isEmpty) mergedImages.add(kPetPlaceholderImage);
    final updatedPet = PetCatalogItem(
      title: displayTitle,
      images: mergedImages,
      videos: mergedVideos,
      price: int.tryParse(_priceCtrl.text.trim()) ?? 0,
      location: _location,
      description: _descCtrl.text.trim().isEmpty
          ? 'Managed from admin panel.'
          : _descCtrl.text.trim(),
      sellerName: Session.currentUser.name,
      phone: Session.currentUser.phone,
      category: _categoryFromLabel(_category),
      addedAt: widget.initial?.addedAt ?? DateTime.now(),
      status: widget.initial?.status ?? PetStatus.active,
    );

    final snapshot = _captureSnapshot();
    _lastSavedSnapshot = snapshot;
    _saveSnapshotToPrefs(snapshot);
    await PetCatalog.upsertAndSave(updatedPet,
        previousTitle: widget.initial?.title);

    if (widget.onSaved != null) {
      widget.onSaved!(updatedPet);
      if (widget.closeOnSave && mounted) {
        Navigator.pop(context, updatedPet);
        return;
      }
    }

    final listingName = _subCategory.isNotEmpty ? _subCategory : _category;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Changes saved for $listingName')),
    );
  }

  void _resetToSaved() {
    final snapshot = _lastSavedSnapshot;
    if (snapshot == null) return;
    _restoreSnapshot(snapshot);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reverted to last saved changes.')),
    );
  }

  Widget _statusTabs() {
    final filters = <PetStatus?>[
      null,
      PetStatus.active,
      PetStatus.inactive,
      PetStatus.sold,
      PetStatus.pendingApproval,
      PetStatus.deleted,
    ];
    final initialIndex =
        _petStatusFilter == null ? 0 : filters.indexOf(_petStatusFilter!);
    return DefaultTabController(
      length: filters.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Theme.of(context).colorScheme.primary,
            onTap: (index) {
              setState(() {
                _petStatusFilter = filters[index];
              });
            },
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Active'),
              Tab(text: 'Inactive'),
              Tab(text: 'Sold'),
              Tab(text: 'Pending'),
              Tab(text: 'Deleted'),
            ],
          ),
        ],
      ),
    );
  }


  bool _termsAccepted = false;
  bool _showForm = false;

  @override
  void dispose() {
    _ageYearsCtrl.removeListener(_onAgeChanged);
    _ageMonthsCtrl.removeListener(_onAgeChanged);
    _priceCtrl.dispose();
    _ageYearsCtrl.dispose();
    _ageMonthsCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _colorCtrl.dispose();
    _sizeCtrl.dispose();
    _weightCtrl.dispose();
    _subCategoryCtrl.dispose();
    _breedCtrl.dispose();
    _pairCountCtrl.dispose();
    _vaccineDetailsCtrl.dispose();
    _groupMaleCountCtrl.dispose();
    _groupFemaleCountCtrl.dispose();
    _groupMalePriceCtrl.dispose();
    _groupFemalePriceCtrl.dispose();
    _mediaPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(color: Colors.grey.shade600);
    SliverAppBar _floatingHeader(
        {required bool showBack,
        required bool showAdd,
        required bool innerBoxIsScrolled}) {
      const double collapsedHeight = 72;
      final double expandedHeight = collapsedHeight;
      final theme = Theme.of(context);

      Widget plainIconButton({
        required IconData icon,
        required VoidCallback onTap,
        String? tooltip,
      }) {
        return IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.black87, size: 22),
          onPressed: onTap,
        );
      }

      final bool isEdit = widget.initial != null;
      final bool showFormTitle = _showForm || isEdit;
      final Widget titleRow = showFormTitle
          ? Text(
              isEdit ? 'Pet Update' : 'Add Pet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            )
          : const SizedBox.shrink();

      return SliverAppBar(
        pinned: true,
        floating: true,
        snap: true,
        stretch: true,
        forceElevated: innerBoxIsScrolled,
        automaticallyImplyLeading: false,
        expandedHeight: showFormTitle ? expandedHeight : 0,
        collapsedHeight: showFormTitle ? collapsedHeight : 0,
        toolbarHeight: showFormTitle ? collapsedHeight : 0,
        backgroundColor: Colors.white,
        shadowColor: Colors.black26,
        leadingWidth: showBack ? 56 : 0,
        leading: showBack
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Center(
                  child: plainIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                        return;
                      }
                      setState(() => _showForm = false);
                    },
                    tooltip: 'Back',
                  ),
                ),
              )
            : null,
        actions: [
          if (showAdd)
            IconButton(
              icon: Icon(Icons.add,
                  color: Theme.of(context).colorScheme.primary, size: 24),
              tooltip: 'Add pet',
              onPressed: _startAddPet,
            ),
        ],
        centerTitle: false,
        titleSpacing: 0,
        title: titleRow,
        iconTheme: const IconThemeData(color: Colors.black87),
        flexibleSpace: null,
      );
    }

    if (!_showForm) {
      return Scaffold(
        floatingActionButton: _isReadOnlyFilter
            ? null
            : FloatingActionButton.extended(
                heroTag: 'add_pet_fab',
                onPressed: _startAddPet,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Pet',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                extendedPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
        body: NestedScrollView(
          controller: _scrollController,
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) => const [
            SliverToBoxAdapter(child: SizedBox.shrink()),
          ],
          body: ListView(
            padding:
                const EdgeInsets.only(top: 0, bottom: 16, left: 16, right: 16),
            children: [
              _statusTabs(),
              const SizedBox(height: 10),
              _MyPetsTile(
                pets: _filteredSellerPets,
                onAddTap: null,
                onEditTap: _isReadOnlyFilter ? null : _startEditPet,
                onDeleteTap: _deletePet,
                onStatusChanged: _updatePetStatus,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _floatingHeader(
            showBack: true,
            showAdd: false,
            innerBoxIsScrolled: innerBoxIsScrolled,
          ),
        ],
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
            _SectionCard(
              title: 'Photos & videos',
              child: _buildMediaSection(subtitleStyle),
            ),

            // Basic info
            _SectionCard(
              title: 'Basic Info',
              trailing: IconButton(
                tooltip: 'Search catalog',
                icon: const Icon(Icons.search),
                onPressed: _openCatalogSearch,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DropdownTile<String>(
                          label: 'Category',
                          value: _category,
                          items: _categoryOptions,
                          onChanged: _onCategoryChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                       child: _DropdownTile<String>(
                         label: 'Sub category',
                         value: _subCategory,
                         items: _subCategoriesFor(_category),
                          onChanged: _onSubCategorySelected,
                          isHighlighted: (val) =>
                              _isCustomSubCategory(_category, val),
                          itemBuilder: (val) => val == 'Other'
                              ? Row(
                                  children: const [
                                    Icon(Icons.add_circle_outline, size: 18),
                                    SizedBox(width: 6),
                                    Text('Other'),
                                  ],
                                )
                              : Text(val),
                       ),
                     ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                       child: _DropdownTile<String>(
                         label: 'Breed',
                         value: _breed,
                         items: _breedsForSelection(_category, _subCategory),
                          onChanged: _onBreedSelected,
                          isHighlighted: (val) =>
                              _isCustomBreed(_category, _subCategory, val),
                          itemBuilder: (val) => val == 'Other'
                              ? Row(
                                  children: const [
                                    Icon(Icons.add_circle_outline, size: 18),
                                    SizedBox(width: 6),
                                    Text('Other'),
                                  ],
                                )
                              : Text(val),
                       ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _colorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Color (optional)',
                            hintText: 'e.g. Brown / White',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Age',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _ageYearsCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            labelText: 'Years',
                            hintText: '03',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _ageMonthsCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: 'Months',
                            hintText: '05',
                            counterText: '',
                          ),
                          validator: (value) {
                            final text = value?.trim();
                            if (text == null || text.isEmpty) return null;
                            final parsed = int.tryParse(text);
                            if (parsed == null || parsed < 0) {
                              return 'Invalid';
                            }
                            if (parsed > 11) {
                              return 'Months can\'t exceed 11';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: _dateOfBirth == null
                            ? 'Select date of birth'
                            : 'DOB: ${DateFormat('dd MMM yyyy').format(_dateOfBirth!)}',
                        onPressed: _pickDob,
                        icon: const Icon(Icons.cake_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DropdownTile<String>(
                    label: 'Count',
                    value: _countType,
                    items: _countOptions,
                    onChanged: (value) {
                      final selected = value ?? 'Single';
                      setState(() {
                        _countType = selected;
                        if (selected != 'Pair') {
                          _pairCountCtrl.clear();
                        }
                      });
                    },
                  ),
                  if (_isPair) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pairCountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of pairs',
                        hintText: 'For ex: 2',
                      ),
                      validator: (value) {
                        if (!_isPair) return null;
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter valid count';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pair totaprice: ₹$_pairTotalPrice',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (_showGenderCountFields) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _groupMaleCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Male count',
                            ),
                            validator: (value) {
                              if (!_showGenderCountFields) return null;
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 0) {
                                return 'Enter valid count';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _groupFemaleCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Female count',
                            ),
                            validator: (value) {
                              if (!_showGenderCountFields) return null;
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 0) {
                                return 'Enter valid count';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total pets: $_groupTotalPets',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  if (_isSingle) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DropdownTile<String>(
                            label: 'Gender',
                            value: _gender,
                            items: const ['Male', 'Female', 'Unknown'],
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ResponsiveTileRow(
                    children: [
                      TextFormField(
                        controller: _sizeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Size (Approx.)', //≈
                          hintText: 'For example 5.5',
                        ),
                      ),
                      _DropdownTile<String>(
                        label: 'Unit',
                        value: _sizeUnit,
                        items: _sizeUnits,
                        onChanged: (value) =>
                            setState(() => _sizeUnit = value ?? 'cm'),
                      ),
                    ],
                  ),
                ],
              ),
            ), // Pricing
            _SectionCard(
              title: 'Pricing',
              child: Column(
                children: [
                  ResponsiveTileRow(
                    children: [
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Base price (₹)',
                          hintText: 'For ex: 12000',
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Negotiable'),
                        value: _negotiable,
                        onChanged: (v) => setState(() => _negotiable = v),
                      ),
                    ],
                  ),
                  if (_isPair) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pair total price: ₹$_pairTotalPrice',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (_isGroup) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _groupMalePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Male price / pet (?)',
                            ),
                            validator: (value) {
                              if (!_isGroup) return null;
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Enter valid price';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _groupFemalePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Female price / pet (?)',
                            ),
                            validator: (value) {
                              if (!_isGroup) return null;
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Enter valid price';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total pets: $_groupTotalPets'),
                          Text(
                            'Group total price: ?$_groupTotalPrice',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ), // Health & features
            _SectionCard(
              title: 'Health & Features',
              child: Column(
                children: [
                  if (_showVaccinationFields)
                    Column(
                      children: [
                        _BoolRow(
                          left: SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Vaccinated'),
                            value: _vaccinated,
                            onChanged: (v) => setState(() => _vaccinated = v),
                          ),
                          right: SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Dewormed'),
                            value: _dewormed,
                            onChanged: (v) => setState(() => _dewormed = v),
                          ),
                        ),
                        if (_vaccinated) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _vaccineDetailsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vaccine details',
                              hintText: 'Type, date, batch, vet, etc.',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
                  _BoolRow(
                    left: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Trained'),
                      value: _trained,
                      onChanged: (v) => setState(() => _trained = v),
                    ),
                    right: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Delivery available'),
                      value: _deliveryAvailable,
                      onChanged: (v) => setState(() => _deliveryAvailable = v),
                    ),
                  ),
                ],
              ),
            ),

            // Location
            _SectionCard(
              title: 'Location',
              subtitle: 'Pick on the map to auto-fill details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _DropdownTile<String>(
                          label: 'City / District',
                          value: _location,
                          items: _locationOptions,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _location = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Pick location on map',
                            onPressed: _openLocationPicker,
                            icon: const Icon(Icons.map_outlined),
                          ),
                          const Text(
                            'Map',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_locationFromMap != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                        border:
                            Border.all(color: Theme.of(context).colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected on map',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_locationFromMap!.formattedAddress),
                          if ((_locationFromMap!.postalCode ?? '').isNotEmpty)
                            Text('PIN: ${_locationFromMap!.postalCode}'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address / Landmark',
                      hintText: 'House / Street / Landmark',
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pincodeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Pincode',
                      hintText: '6-digit postal code',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),

            // Availability & Contact pref
            _SectionCard(
              title: 'Availability & Contact',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available from'),
                    subtitle: Text(
                      _availableFrom == null
                          ? 'Choose a date'
                          : DateFormat('EEE, dd MMM yyyy')
                              .format(_availableFrom!),
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: const Text('Pick'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('WhatsApp'),
                        _chip('Call'),
                        _chip('Chat'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Description
            _SectionCard(
              title: 'Description',
              child: TextFormField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText:
                      'Describe the pet (temperament, diet, special care, etc.)',
                ),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Add at least 10 characters'
                    : null,
              ),
            ),

            const SizedBox(height: 8),
            CheckboxListTile(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I accept the Terms & Conditions.'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    ),

    // Submit bar
    bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                !_hasAnyMedia
                    ? 'Add photos to continue'
                    : '$_photoCount photo(s), $_videoCount video(s)',
                style: TextStyle(
                    color: !_hasAnyMedia ? Colors.red : Colors.grey.shade700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _lastSavedSnapshot == null ? null : _resetToSaved,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(widget.initial != null ? 'Update' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(TextStyle subtitleStyle) {
    final media = _mediaItems;
    final hasMedia = media.isNotEmpty;
    final safeIndex =
        hasMedia ? _mediaPageIndex.clamp(0, media.length - 1).toInt() : 0;

    Widget preview;
    if (!hasMedia) {
      preview = _EmptyMediaPlaceholder(onTap: _pickImage);
    } else {
      preview = Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _mediaPageController,
            itemCount: media.length,
            onPageChanged: (index) => setState(() => _mediaPageIndex = index),
            itemBuilder: (_, index) {
              final entry = media[index];
              return _buildMediaPreview(entry);
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            child: _MediaCircleButton(
              icon: Icons.delete_outline,
              onTap: () => _removeMediaAt(_mediaPageIndex),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _MediaLabelChip(
              label: media[safeIndex].isVideo ? 'Video' : 'Photo',
            ),
          ),
          if (media.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: _MediaDots(count: media.length, index: safeIndex),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey.shade200,
              child: preview,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MediaActionButton(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Add photo (${_photoCount}/$_maxPhotos)',
              onPressed: _canAddPhoto ? _pickImage : null,
            ),
            _MediaActionButton(
              icon: Icons.videocam_outlined,
              label: 'Add video (${_videoCount}/$_maxVideos)',
              onPressed: _canAddVideo ? _pickVideo : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaPreview(_PickedMedia entry) {
    if (entry.isVideo) {
      if (entry.file != null) {
        return SizedBox.expand(
          child: _SellVideoPreview(file: File(entry.file!.path)),
        );
      }
      return const _VideoPlaceholder();
    }

    final path = entry.file?.path ?? entry.existingPath ?? '';
    if (path.isEmpty) return const _MissingMediaBox();
    return SizedBox.expand(child: PetImage(source: path, fit: BoxFit.cover));
  }

  // Choice chips for contact preference
  Widget _chip(String label) {
    final sel = _contactPref == label;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => setState(() => _contactPref = label),
      selectedColor: Colors.teal,
      labelStyle: TextStyle(color: sel ? Colors.white : Colors.teal),
      backgroundColor: Colors.teal.shade50,
      side: BorderSide(color: sel ? Colors.teal : Colors.teal.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}

/*──────────────────── helper widgets ────────────────────*/

class _CustomOptionResult {
  final String? subCategory;
  final String? breed;

  const _CustomOptionResult({this.subCategory, this.breed});

  bool get hasSubCategory =>
      subCategory != null && subCategory!.trim().isNotEmpty;
  bool get hasBreed => breed != null && breed!.trim().isNotEmpty;
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(color: Colors.grey.shade600);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: caption),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _SuggestInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSuggestionSelected;

  const _SuggestInputField({
    required this.label,
    required this.controller,
    required this.suggestions,
    required this.onChanged,
    this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = _filterSuggestions(controller.text, suggestions);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: menuItems.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Choose $label',
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (value) {
                  controller.text = value;
                  controller.selection =
                      TextSelection.collapsed(offset: value.length);
                  onSuggestionSelected?.call(value);
                  onChanged(value);
                },
                itemBuilder: (_) => menuItems
                    .map((s) => PopupMenuItem<String>(
                          value: s,
                          child: Text(s),
                        ))
                    .toList(),
              ),
      ),
      onChanged: onChanged,
    );
  }

  List<String> _filterSuggestions(String query, List<String> source) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return source;
    final starts = <String>[];
    final contains = <String>[];
    for (final item in source) {
      final lower = item.toLowerCase();
      if (lower.startsWith(trimmed)) {
        starts.add(item);
      } else if (lower.contains(trimmed)) {
        contains.add(item);
      }
    }
    return [
      ...starts,
      ...contains,
    ];
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final bool Function(T value)? isHighlighted;
  final Widget Function(T value)? itemBuilder;
  final TextStyle? highlightStyle;
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isHighlighted,
    this.itemBuilder,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(T item) {
      final highlight = isHighlighted != null && isHighlighted!(item);
      final style = highlight
          ? highlightStyle ??
              const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)
          : null;
      final custom = itemBuilder?.call(item);
      if (custom != null) {
        if (style == null) return custom;
        return DefaultTextStyle.merge(style: style, child: custom);
      }
      return Text('$item', style: style);
    }

    final T? normalizedValue =
        items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<T>(
      value: normalizedValue,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: buildItem(e),
              ))
          .toList(),
      selectedItemBuilder: (isHighlighted == null && itemBuilder == null)
          ? null
          : (context) => items
              .map((e) => Align(
                    alignment: Alignment.centerLeft,
                    child: buildItem(e),
                  ))
              .toList(),
      onChanged: onChanged,
    );
  }
}

class _BoolRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _BoolRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return ResponsiveTileRow(
      breakpoint: 560,
      children: [left, right],
    );
  }
}

class _FormSnapshot {
  final String category;
  final String subCategory;
  final String breed;
  final String gender;
  final String countType;
  final String sizeUnit;
  final String location;
  final bool negotiable;
  final bool vaccinated;
  final bool dewormed;
  final bool trained;
  final bool deliveryAvailable;
  final String contactPref;
  final DateTime? availableFrom;
  final DateTime? dateOfBirth;
  final bool termsAccepted;
  final LocationSelectionResult? locationFromMap;
  final List<String> locationOptions;
  final int mediaPageIndex;
  final List<String> existingImages;
  final List<String> existingVideos;
  final List<String> localImages;
  final List<String> localVideos;
  final Map<String, String> textFields;

  const _FormSnapshot({
    required this.category,
    required this.subCategory,
    required this.breed,
    required this.gender,
    required this.countType,
    required this.sizeUnit,
    required this.location,
    required this.negotiable,
    required this.vaccinated,
    required this.dewormed,
    required this.trained,
    required this.deliveryAvailable,
    required this.contactPref,
    required this.availableFrom,
    required this.dateOfBirth,
    required this.termsAccepted,
    required this.locationFromMap,
    required this.locationOptions,
    required this.mediaPageIndex,
    required this.existingImages,
    required this.existingVideos,
    required this.localImages,
    required this.localVideos,
    required this.textFields,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'subCategory': subCategory,
        'breed': breed,
        'gender': gender,
        'countType': countType,
        'sizeUnit': sizeUnit,
        'location': location,
        'negotiable': negotiable,
        'vaccinated': vaccinated,
        'dewormed': dewormed,
        'trained': trained,
        'deliveryAvailable': deliveryAvailable,
        'contactPref': contactPref,
        'availableFrom': availableFrom?.toIso8601String(),
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'termsAccepted': termsAccepted,
        'locationFromMap': locationFromMap == null
            ? null
            : {
                'latitude': locationFromMap!.latitude,
                'longitude': locationFromMap!.longitude,
                'formattedAddress': locationFromMap!.formattedAddress,
                'city': locationFromMap!.city,
                'postalCode': locationFromMap!.postalCode,
              },
        'locationOptions': locationOptions,
        'mediaPageIndex': mediaPageIndex,
        'existingImages': existingImages,
        'existingVideos': existingVideos,
        'localImages': localImages,
        'localVideos': localVideos,
        'textFields': textFields,
      };

  factory _FormSnapshot.fromJson(Map<String, dynamic> json) {
    LocationSelectionResult? loc;
    final locMap = json['locationFromMap'];
    if (locMap is Map<String, dynamic>) {
      final lat = locMap['latitude'];
      final lng = locMap['longitude'];
      final addr = locMap['formattedAddress'];
      if (lat is num && lng is num && addr is String) {
        loc = LocationSelectionResult(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
          formattedAddress: addr,
          city: locMap['city'] as String?,
          postalCode: locMap['postalCode'] as String?,
        );
      }
    }

    List<String> _list(dynamic value) => value is List
        ? value.map((e) => e.toString()).toList(growable: false)
        : <String>[];

    Map<String, String> _map(dynamic value) {
      if (value is Map) {
        return value.map((key, val) =>
            MapEntry(key.toString(), val?.toString() ?? ''));
      }
      return {};
    }

    DateTime? _parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return _FormSnapshot(
      category: json['category'] as String? ?? 'Animals',
      subCategory: json['subCategory'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Male',
      countType: json['countType'] as String? ?? 'Single',
      sizeUnit: json['sizeUnit'] as String? ?? 'cm',
      location: json['location'] as String? ?? 'BENGALURU URBAN',
      negotiable: json['negotiable'] as bool? ?? true,
      vaccinated: json['vaccinated'] as bool? ?? false,
      dewormed: json['dewormed'] as bool? ?? false,
      trained: json['trained'] as bool? ?? false,
      deliveryAvailable: json['deliveryAvailable'] as bool? ?? true,
      contactPref: json['contactPref'] as String? ?? 'WhatsApp',
      availableFrom: _parseDate(json['availableFrom']),
      dateOfBirth: _parseDate(json['dateOfBirth']),
      termsAccepted: json['termsAccepted'] as bool? ?? false,
      locationFromMap: loc,
      locationOptions: _list(json['locationOptions']),
      mediaPageIndex: json['mediaPageIndex'] as int? ?? 0,
      existingImages: _list(json['existingImages']),
      existingVideos: _list(json['existingVideos']),
      localImages: _list(json['localImages']),
      localVideos: _list(json['localVideos']),
      textFields: _map(json['textFields']),
    );
  }
}

class _CatalogEntry {
  final PetCatalogItem item;
  final String category;
  final String pet;
  final String breed;

  const _CatalogEntry({
    required this.item,
    required this.category,
    required this.pet,
    required this.breed,
  });
}

class _PickedMedia {
  final XFile? file;
  final String? existingPath;
  final bool isVideo;
  const _PickedMedia({this.file, this.existingPath, required this.isVideo});
}

class _EmptyMediaPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyMediaPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Colors.grey.shade600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: mutedColor),
              const SizedBox(height: 10),
              Text('Tap to add a photo', style: TextStyle(color: mutedColor)),
              const SizedBox(height: 4),
              Text(
                'Use the buttons below to add photos or videos',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _MediaActionButton(
      {required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _MediaDots extends StatelessWidget {
  final int count;
  final int index;
  const _MediaDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(i == index ? 0.95 : 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _MediaCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MediaCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _MediaLabelChip extends StatelessWidget {
  final String label;
  const _MediaLabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(Icons.videocam, size: 42, color: Colors.white70),
      ),
    );
  }
}

class _MissingMediaBox extends StatelessWidget {
  const _MissingMediaBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child:
            Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
      ),
    );
  }
}

class _SellVideoPreview extends StatefulWidget {
  final File file;
  const _SellVideoPreview({required this.file});

  @override
  State<_SellVideoPreview> createState() => _SellVideoPreviewState();
}

class _SellVideoPreviewState extends State<_SellVideoPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _SellVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller?.dispose();
      _initController();
    }
  }

  void _initController() {
    final controller = VideoPlayerController.file(widget.file)
      ..setLooping(true)
      ..setVolume(0);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.play();
    });
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        const Align(
          alignment: Alignment.center,
          child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70),
        ),
      ],
    );
  }
}

/* ====== Seller overview tiles ====== */
class _MyPetsTile extends StatelessWidget {
  final List<PetCatalogItem> pets;
  final VoidCallback? onAddTap;
  final ValueChanged<PetCatalogItem>? onEditTap;
  final ValueChanged<PetCatalogItem>? onDeleteTap;
  final Future<void> Function(PetCatalogItem pet, PetStatus status)?
      onStatusChanged;

  const _MyPetsTile(
      {required this.pets,
      this.onAddTap,
      this.onEditTap,
      this.onDeleteTap,
      this.onStatusChanged});

  void _openPet(BuildContext context, PetCatalogItem pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetDetailsScreen(item: pet.toItem()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    text: 'My Pets ',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(
                        text: pets.isEmpty ? '0' : '${pets.length}',
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (onAddTap != null)
                  TextButton.icon(
                    onPressed: onAddTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                    ),
                    icon: Icon(Icons.add_circle_outline,
                        color: Theme.of(context).colorScheme.primary, size: 22),
                    label: Text('Add Pet',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (pets.isEmpty)
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You haven\'t listed any pets yet.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  for (int i = 0; i < pets.length && i < 5; i++) ...[
                  _SellerPetRow(
                    pet: pets[i],
                    onTap: () => _openPet(context, pets[i]),
                    onEdit: onEditTap == null
                        ? null
                        : () => onEditTap!(pets[i]),
                    onDelete:
                        onDeleteTap == null ? null : () => onDeleteTap!(pets[i]),
                    onStatusChanged: onStatusChanged == null
                        ? null
                        : (status) => onStatusChanged!(pets[i], status),
                  ),
                    if (i < pets.length - 1 && i < 4)
                      const Divider(height: 12, thickness: 0.6),
                  ]
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SellerPetRow extends StatelessWidget {
  final PetCatalogItem pet;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<PetStatus>? onStatusChanged;

  const _SellerPetRow(
      {required this.pet,
      this.onTap,
      this.onEdit,
      this.onDelete,
      this.onStatusChanged});

  Color _statusColor(PetStatus status) {
    switch (status) {
      case PetStatus.active:
        return Colors.teal;
      case PetStatus.inactive:
        return Colors.grey.shade700;
      case PetStatus.sold:
        return Colors.blueGrey;
      case PetStatus.pendingApproval:
        return Colors.orange.shade700;
      case PetStatus.deleted:
        return Colors.red.shade400;
    }
  }

  Widget _statusDropdown(BuildContext context) {
    final color = _statusColor(pet.status);
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
          color: color.withOpacity(0.08),
        ),
        child: DropdownButton<PetStatus>(
          value: pet.status,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
          onChanged: onStatusChanged == null
              ? null
              : (status) {
                  if (status != null) onStatusChanged!(status);
                },
          items: PetStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(
                    status.label,
                    style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.findAncestorStateOfType<_SellTabState>();
    final price =
        state == null ? '' : state._priceLabel(pet); // ignore: library_private_types_in_public_api
    final location =
        state == null ? '' : state._locationLabel(pet); // ignore: library_private_types_in_public_api
    final addedAt = pet.addedAt ?? DateTime.now();
    final addedLabel = DateFormat('dd MMM yyyy, h:mm a').format(addedAt);
    final canDelete = onDelete != null && pet.status != PetStatus.deleted;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: PetImage(
                source: pet.images.isNotEmpty
                    ? pet.images.first
                    : kPetPlaceholderImage,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.title.trim().isEmpty
                        ? 'Untitled listing'
                        : pet.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Added $addedLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusDropdown(context),
                if (onEdit != null || canDelete) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit listing',
                          onPressed: onEdit,
                          splashRadius: 20,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                      if (canDelete)
                        IconButton(
                          icon:
                              const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete listing',
                          onPressed: onDelete,
                          splashRadius: 20,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
