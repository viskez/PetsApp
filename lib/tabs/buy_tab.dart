import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pet_catalog.dart';

import '../models/pet_data.dart';

import '../models/pet_utils.dart';

import '../models/wishlist.dart';
import '../models/call_stats_store.dart';
import '../models/session.dart';
import '../models/plan_store.dart';
import '../utils/plan_access.dart';
import '../utils/whatsapp_launcher.dart';

import '../views/chat_screen.dart';
import '../views/pet_details.dart';
import '../widgets/pet_image.dart';

enum BuyViewLayout { list, compact, gallery }

enum _FilterField { category, species, breed, location }

String _usageKeyFor(PetCatalogItem item, String action) {
  return buildUnlockKey(
    action: action,
    phone: item.phone,
    title: item.title,
  );
}

class BuyTab extends StatefulWidget {
  final String searchQuery;

  const BuyTab({super.key, this.searchQuery = ''});

  @override
  State<BuyTab> createState() => _BuyTabState();
}

class _BuyTabState extends State<BuyTab> {
  final wishlist = WishlistStore();
  List<PetCatalogItem> get _catalog =>
      PetCatalog.all.isNotEmpty ? PetCatalog.all : PET_CATALOG;

  BuyViewLayout _viewLayout = BuyViewLayout.gallery;

  String? _categoryFilter;

  String? _speciesFilter;

  String? _breedFilter;

  String? _locationFilter;

  String _inlineQuery = '';

  bool _isSearchExpanded = false;

  final TextEditingController _searchCtrl = TextEditingController();

  final FocusNode _searchFocus = FocusNode();

  late final List<String> _categoryOptions;

  late final List<String> _speciesOptions;

  late final List<String> _breedOptions;

  late final List<String> _locationOptions;

  late final Map<String, List<String>> _speciesByCategory;

  late final Map<String, List<String>> _breedBySpecies;

  late final Map<String, String> _categoryBySpecies;

  @override
  void initState() {
    super.initState();
    PetCatalog.pruneAndSaveOnce();

    _inlineQuery = widget.searchQuery;

    _searchCtrl.text = _inlineQuery;

    _buildFilterSources();
  }

  @override
  void didUpdateWidget(covariant BuyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() {
        _inlineQuery = widget.searchQuery;

        _searchCtrl.value = TextEditingValue(
          text: _inlineQuery,
          selection: TextSelection.collapsed(offset: _inlineQuery.length),
        );
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();

    _searchFocus.dispose();

    super.dispose();
  }

  void _buildFilterSources() {
    final categoryLabels =
        PetCategory.values.map(_categoryLabel).toSet().toList();

    categoryLabels.sort();

    _categoryOptions = categoryLabels;

    final speciesSet = <String>{};

    final breedSet = <String>{};

    final locationSet = <String>{};

    final categoryBySpecies = <String, String>{};

    final speciesByCategory = <String, Set<String>>{};

    final breedBySpecies = <String, Set<String>>{};

    for (final item in _catalog) {
      locationSet.add(item.location);

      final (species, breed) = splitPetTitle(item.title);

      final speciesName = species.isEmpty ? item.title.trim() : species;

      final breedName = breed.isEmpty ? 'Unknown' : breed;

      speciesSet.add(speciesName);

      breedSet.add(breedName);

      final category = _categoryLabel(item.category);

      categoryBySpecies.putIfAbsent(speciesName, () => category);

      speciesByCategory
          .putIfAbsent(category, () => <String>{})
          .add(speciesName);

      breedBySpecies.putIfAbsent(speciesName, () => <String>{}).add(breedName);
    }

    _speciesOptions = speciesSet.toList()..sort();

    _breedOptions = breedSet.toList()..sort();

    _locationOptions = locationSet.toList()..sort();

    _categoryBySpecies = categoryBySpecies;

    _speciesByCategory = {
      for (final entry in speciesByCategory.entries)
        entry.key: entry.value.toList()..sort(),
    };

    _breedBySpecies = {
      for (final entry in breedBySpecies.entries)
        entry.key: entry.value.toList()..sort(),
    };
  }

  List<PetCatalogItem> get _filteredItems {
    final searchSource =
        widget.searchQuery.isNotEmpty ? widget.searchQuery : _inlineQuery;

    final query = searchSource.trim().toLowerCase();

    return _catalog.where((item) {
      final (speciesRaw, breedRaw) = splitPetTitle(item.title);

      final species = speciesRaw.isEmpty ? item.title.trim() : speciesRaw;

      final breed = breedRaw.isEmpty ? 'Unknown' : breedRaw;

      final category = _categoryLabel(item.category);

      if (_categoryFilter != null && category != _categoryFilter) return false;

      if (_speciesFilter != null && species != _speciesFilter) return false;

      if (_breedFilter != null && breed != _breedFilter) return false;

      if (_locationFilter != null && item.location != _locationFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final haystack =
          '${item.title} ${item.description} ${item.location}'.toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  List<_FilterChipData> get _activeFilterChips => [
        if (_categoryFilter != null)
          _FilterChipData('Category', _categoryFilter!, _FilterField.category),
        if (_speciesFilter != null)
          _FilterChipData(
              'Sub category', _speciesFilter!, _FilterField.species),
        if (_breedFilter != null)
          _FilterChipData('Breed', _breedFilter!, _FilterField.breed),
        if (_locationFilter != null)
          _FilterChipData('Location', _locationFilter!, _FilterField.location),
      ];

  @override
  Widget build(BuildContext context) {
    final filters = _activeFilterChips;

    final items = _filteredItems;

    final showSearchBar = _isSearchExpanded || _inlineQuery.isNotEmpty;

    return ValueListenableBuilder<int>(
      valueListenable: PetCatalog.version,
      builder: (_, __, ___) {
        final refreshedItems = _filteredItems;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: showSearchBar
                    ? _buildExpandedToolbar()
                    : _buildCollapsedToolbar(),
              ),
            ),
            const SizedBox(height: 8),
            if (filters.isNotEmpty) const SizedBox(height: 4),
            if (filters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: filters
                      .map(
                        (chip) => InputChip(
                          label: Text('${chip.label}: ${chip.value}'),
                          onDeleted: () => _applyFilter(chip.field, null),
                        ),
                      )
                      .toList(),
                ),
              ),
            const Divider(height: 20),
            Expanded(
              child: refreshedItems.isEmpty
                  ? const Center(
                      child: Text('No pets matched these filters.'))
                  : _buildResults(refreshedItems),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCollapsedToolbar() {
    return Row(
      key: const ValueKey('collapsed-toolbar'),
      children: [
        const Text('Pets',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        _toolbarAction(Icons.search, _expandSearch),
        const SizedBox(width: 8),
        _ViewModeButton(
          current: _viewLayout,
          onLayoutChanged: (layout) => setState(() => _viewLayout = layout),
        ),
        const SizedBox(width: 8),
        _FilterMenuButton(onSelected: _openFilterSheet),
      ],
    );
  }

  Widget _buildExpandedToolbar() {
    return Row(
      key: const ValueKey('expanded-toolbar'),
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: _buildSearchField(),
          ),
        ),
        const SizedBox(width: 8),
        _ViewModeButton(
          current: _viewLayout,
          onLayoutChanged: (layout) => setState(() => _viewLayout = layout),
        ),
        const SizedBox(width: 8),
        _FilterMenuButton(onSelected: _openFilterSheet),
      ],
    );
  }

  Widget _buildSearchField() {
    final accent = Theme.of(context).colorScheme.primary;
    final accentSoft = accent.withOpacity(0.45);
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search pets or breeds',
        prefixIcon: Icon(Icons.search, color: accent),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: _clearOrCollapseSearch,
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: accent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: accentSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
      ),
    );
  }

  Widget _toolbarAction(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: _ToolbarIconChip(icon: icon),
      ),
    );
  }

  void _expandSearch() {
    setState(() => _isSearchExpanded = true);

    _searchFocus.requestFocus();
  }

  void _collapseSearch() {
    setState(() => _isSearchExpanded = false);

    _searchFocus.unfocus();
  }

  void _clearOrCollapseSearch() {
    if (_searchCtrl.text.isNotEmpty) {
      _searchCtrl.clear();

      _onSearchChanged('');

      return;
    }

    _collapseSearch();
  }

  Widget _buildResults(List<PetCatalogItem> items) {
    switch (_viewLayout) {
      case BuyViewLayout.list:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) => _PetListTile(item: items[index]),
        );

      case BuyViewLayout.compact:
      case BuyViewLayout.gallery:
        final crossAxisCount = _viewLayout == BuyViewLayout.gallery ? 2 : 3;

        final childAspectRatio =
            _viewLayout == BuyViewLayout.gallery ? 0.82 : 0.9;

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 11,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => _PetCard(
            item: items[index],
            wishlist: wishlist,
            layout: _viewLayout,
          ),
        );
    }
  }

  Future<void> _openFilterSheet(_FilterField field) async {
    final options = _optionsForField(field);

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('No ${_fieldLabel(field).toLowerCase()} options yet.')),
      );

      return;
    }

    final current = _valueForField(field);

    const clearSignal = '__CLEAR__';

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        String? tempSelection = current;

        return StatefulBuilder(
          builder: (_, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select ${_fieldLabel(field)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: options
                          .map(
                            (option) => RadioListTile<String>(
                              title: Text(option),
                              value: option,
                              groupValue: tempSelection,
                              onChanged: (value) =>
                                  setSheetState(() => tempSelection = value),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, clearSignal),
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: tempSelection == null
                            ? null
                            : () => Navigator.pop(sheetContext, tempSelection),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;

    if (result == clearSignal) {
      _applyFilter(field, null);
    } else {
      _applyFilter(field, result);
    }
  }

  void _applyFilter(_FilterField field, String? value) {
    setState(() {
      switch (field) {
        case _FilterField.category:
          _categoryFilter = value;

          if (_categoryFilter == null) {
            _speciesFilter = null;

            _breedFilter = null;
          } else if (_speciesFilter != null &&
              _categoryBySpecies[_speciesFilter!] != _categoryFilter) {
            _speciesFilter = null;

            _breedFilter = null;
          }

          break;

        case _FilterField.species:
          _speciesFilter = value;

          if (_speciesFilter == null) {
            _breedFilter = null;
          } else if (_breedFilter != null &&
              !(_breedBySpecies[_speciesFilter!]?.contains(_breedFilter) ??
                  false)) {
            _breedFilter = null;
          }

          _categoryFilter =
              value == null ? _categoryFilter : _categoryBySpecies[value];

          break;

        case _FilterField.breed:
          _breedFilter = value;

          break;

        case _FilterField.location:
          _locationFilter = value;

          break;
      }
    });
  }

  List<String> _optionsForField(_FilterField field) {
    switch (field) {
      case _FilterField.category:
        return _categoryOptions;

      case _FilterField.species:
        if (_categoryFilter == null) return _speciesOptions;

        return _speciesByCategory[_categoryFilter!] ?? const [];

      case _FilterField.breed:
        if (_speciesFilter == null) return _breedOptions;

        return _breedBySpecies[_speciesFilter!] ?? const [];

      case _FilterField.location:
        return _locationOptions;
    }
  }

  String _fieldLabel(_FilterField field) => switch (field) {
        _FilterField.category => 'Category',
        _FilterField.species => 'Sub category / species',
        _FilterField.breed => 'Breed',
        _FilterField.location => 'Location',
      };

  String? _valueForField(_FilterField field) => switch (field) {
        _FilterField.category => _categoryFilter,
        _FilterField.species => _speciesFilter,
        _FilterField.breed => _breedFilter,
        _FilterField.location => _locationFilter,
      };

  String _categoryLabel(PetCategory category) => switch (category) {
        PetCategory.animals => 'Animals',
        PetCategory.birds => 'Birds',
        PetCategory.fish => 'Fish',
      };

  void _onSearchChanged(String value) {
    setState(() {
      _inlineQuery = value;
    });
  }
}

class _FilterChipData {
  final String label;

  final String value;

  final _FilterField field;

  const _FilterChipData(this.label, this.value, this.field);
}

class _ToolbarIconChip extends StatelessWidget {
  final IconData icon;

  const _ToolbarIconChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final BuyViewLayout current;

  final ValueChanged<BuyViewLayout> onLayoutChanged;

  const _ViewModeButton({
    required this.current,
    required this.onLayoutChanged,
  });

  static const _entries = [
    _ViewMenuEntry(_ViewMenuChoice.list, 'List', Icons.view_list),
    _ViewMenuEntry(_ViewMenuChoice.compact, 'Compact List', Icons.view_agenda),
    _ViewMenuEntry(_ViewMenuChoice.gallery, 'Gallery', Icons.grid_view),
  ];

  @override
  Widget build(BuildContext context) {
    final currentChoice = _choiceFromLayout(current);
    final accent = Theme.of(context).colorScheme.primary;

    return PopupMenuButton<_ViewMenuChoice>(
      tooltip: 'Change view',
      onSelected: (choice) {
        onLayoutChanged(_layoutFromChoice(choice));
      },
      itemBuilder: (_) => _entries
          .map(
            (entry) => PopupMenuItem<_ViewMenuChoice>(
              value: entry.choice,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: choiceCanCheck(entry.choice) &&
                            entry.choice == currentChoice
                        ? Icon(Icons.check, size: 18, color: accent)
                        : const SizedBox.shrink(),
                  ),
                  Icon(entry.icon, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(entry.label),
                ],
              ),
            ),
          )
          .toList(),
      child: const _ToolbarIconChip(icon: Icons.view_headline),
    );
  }

  static bool choiceCanCheck(_ViewMenuChoice choice) =>
      choice == _ViewMenuChoice.list ||
      choice == _ViewMenuChoice.compact ||
      choice == _ViewMenuChoice.gallery;

  static _ViewMenuChoice _choiceFromLayout(BuyViewLayout layout) =>
      switch (layout) {
        BuyViewLayout.list => _ViewMenuChoice.list,
        BuyViewLayout.compact => _ViewMenuChoice.compact,
        BuyViewLayout.gallery => _ViewMenuChoice.gallery,
      };

  static BuyViewLayout _layoutFromChoice(_ViewMenuChoice choice) =>
      switch (choice) {
        _ViewMenuChoice.list => BuyViewLayout.list,
        _ViewMenuChoice.compact => BuyViewLayout.compact,
        _ViewMenuChoice.gallery => BuyViewLayout.gallery,
      };
}

enum _ViewMenuChoice { list, compact, gallery }

class _ViewMenuEntry {
  final _ViewMenuChoice choice;

  final String label;

  final IconData icon;

  const _ViewMenuEntry(this.choice, this.label, this.icon);
}

class _FilterMenuButton extends StatelessWidget {
  final ValueChanged<_FilterField> onSelected;

  const _FilterMenuButton({required this.onSelected});

  static const _entries = [
    _FilterMenuEntry(_FilterField.category, 'Category'),
    _FilterMenuEntry(_FilterField.species, 'Sub category / species'),
    _FilterMenuEntry(_FilterField.breed, 'Breed'),
    _FilterMenuEntry(_FilterField.location, 'Location'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_FilterField>(
      tooltip: 'Filters',
      onSelected: onSelected,
      itemBuilder: (_) => _entries
          .map((entry) => PopupMenuItem<_FilterField>(
              value: entry.field, child: Text(entry.label)))
          .toList(),
      child: const _ToolbarIconChip(icon: Icons.filter_list),
    );
  }
}

class _FilterMenuEntry {
  final _FilterField field;

  final String label;

  const _FilterMenuEntry(this.field, this.label);
}

class _MediaCountDots extends StatelessWidget {
  final int total;
  final int activeIndex;
  final double size;

  const _MediaCountDots(
      {required this.total, required this.activeIndex, this.size = 28});

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final dots = List.generate(total, (i) => i);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dots
          .map(
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: size / 2.6,
                height: size / 2.6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ == activeIndex
                        ? accent
                        : const Color(0xFFBDBDBD)),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PetCard extends StatefulWidget {
  final PetCatalogItem item;
  final WishlistStore wishlist;
  final BuyViewLayout layout;

  const _PetCard(
      {required this.item, required this.wishlist, required this.layout});

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard> {
  late final PageController _pageController;
  int _pageIndex = 0;

  bool get _hasPhone => widget.item.phone.trim().isNotEmpty;

  List<_CardMedia> get _media {
    final images = widget.item.images;
    final videos = widget.item.videos;
    final list = <_CardMedia>[
      ...images.map((e) => _CardMedia(path: e, isVideo: false)),
      ...videos.map((e) => _CardMedia(path: e, isVideo: true)),
    ];
    return list.isEmpty
        ? [const _CardMedia(path: kPetPlaceholderImage, isVideo: false)]
        : list;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.layout == BuyViewLayout.compact
        ? _buildCompact(context)
        : _buildGallery(context);
  }

  Widget _buildCompact(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetails(context),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _mediaStack(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Text(
                widget.item.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetails(context),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _mediaStack(),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _MediaCountDots(
                        total: _media.length,
                        activeIndex: _pageIndex,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: widget.wishlist.ids,
                      builder: (_, ids, __) {
                        final saved = ids.contains(widget.item.title);
                        return IconButton(
                          onPressed: () => widget.wishlist.toggle(widget.item.title),
                          tooltip: saved
                              ? 'Remove from wishlist'
                              : 'Add to wishlist',
                          icon: Icon(
                            saved ? Icons.favorite : Icons.favorite_border,
                            color: saved ? Colors.red : Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₹${widget.item.price}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.location_on,
                          size: 15, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          widget.item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.item.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(
                            tooltip: 'Chat',
                            color: Theme.of(context).colorScheme.primary,
                            onTap: () => _openChat(context),
                            child: const Icon(Icons.chat_bubble_outline,
                                size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          _actionButton(
                            tooltip: 'Call',
                            color: Colors.blue,
                            onTap:
                                _hasPhone ? () => _callSeller(context) : null,
                            child: Icon(
                              Icons.call,
                              size: 16,
                              color: _hasPhone ? Colors.white : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _actionButton(
                            tooltip: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: _hasPhone
                                ? () => _openWhatsApp(context)
                                : null,
                            child: Image.asset(
                              'assets/icons/whatsapp.png',
                              width: 16,
                              height: 16,
                              color: _hasPhone ? Colors.white : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PetDetailsScreen(item: widget.item.toItem()),
      ),
    );
  }

  Widget _actionButton({
    required String tooltip,
    required Color color,
    required Widget child,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final background = enabled ? color : Colors.grey.shade300;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final allowed = await requirePlanPointsForTarget(
      context,
      PlanAction.chat,
      _usageKeyFor(widget.item, 'chat'),
    );
    if (!allowed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sellerName: widget.item.sellerName,
          sellerPhone: widget.item.phone,
        ),
      ),
    );
  }

  Future<void> _callSeller(BuildContext context) async {
    if (!_hasPhone) return;
    final allowed = await requirePlanPointsForTarget(
      context,
      PlanAction.call,
      _usageKeyFor(widget.item, 'call'),
    );
    if (!allowed) return;
    final uri = Uri(scheme: 'tel', path: widget.item.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await CallStatsStore().incrementCallsMade(Session.currentUser.email);
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    if (!_hasPhone) return;
    final allowed = await requirePlanPointsForTarget(
      context,
      PlanAction.whatsapp,
      _usageKeyFor(widget.item, 'whatsapp'),
    );
    if (!allowed) return;
    final msg =
        'Hi ${widget.item.sellerName}, I\'m interested in ${widget.item.displayTitle}.';
    await launchWhatsAppChat(context, widget.item.phone, msg);
  }

  Widget _mediaStack() {
    final media = _media;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: media.length,
          onPageChanged: (i) => setState(() => _pageIndex = i),
          itemBuilder: (_, i) {
            final m = media[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                PetImage(source: m.path, fit: BoxFit.cover),
                if (m.isVideo)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: Icon(Icons.videocam, color: Colors.white70),
                  ),
              ],
            );
          },
        ),
        if (media.length > 1)
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: _NavArrow(
              icon: Icons.chevron_left,
              onTap: () => _jumpRelative(-1, media.length),
            ),
          ),
        if (media.length > 1)
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: _NavArrow(
              icon: Icons.chevron_right,
              onTap: () => _jumpRelative(1, media.length),
            ),
          ),
      ],
    );
  }

  void _jumpRelative(int delta, int len) {
    final target = (_pageIndex + delta).clamp(0, len - 1);
    if (target == _pageIndex) return;
    _pageController.animateToPage(target,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }
}

class _CardMedia {
  final String path;
  final bool isVideo;

  const _CardMedia({required this.path, required this.isVideo});
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _PetListTile extends StatelessWidget {
  final PetCatalogItem item;

  const _PetListTile({required this.item});

  bool get _hasPhone => item.phone.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PetImage(
                  source: item.primaryImage,
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
                    Text(
                      item.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '\u20B9${item.price}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.person,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionButton(
                          tooltip: 'Chat',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => _openChat(context),
                          child: const Icon(Icons.chat_bubble_outline,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        _actionButton(
                          tooltip: 'Call',
                          color: Colors.blue,
                          onTap: _hasPhone ? () => _callSeller(context) : null,
                          child: Icon(
                            Icons.call,
                            size: 16,
                            color: _hasPhone ? Colors.white : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _actionButton(
                          tooltip: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: _hasPhone ? () => _openWhatsApp(context) : null,
                          child: Image.asset(
                            'assets/icons/whatsapp.png',
                            width: 16,
                            height: 16,
                            color: _hasPhone ? Colors.white : Colors.grey,
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

  Widget _actionButton({
    required String tooltip,
    required Color color,
    required Widget child,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final background = enabled ? color : Colors.grey.shade300;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: child,
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetDetailsScreen(item: item.toItem())),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final allowed = await requirePlanPointsForTarget(
      context,
      PlanAction.chat,
      _usageKeyFor(item, 'chat'),
    );
    if (!allowed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sellerName: item.sellerName,
          sellerPhone: item.phone,
        ),
      ),
    );
  }

  Future<void> _callSeller(BuildContext context) async {
    if (!_hasPhone) return;
    final allowed = await requirePlanPointsForTarget(
      context,
      PlanAction.call,
      _usageKeyFor(item, 'call'),
    );
    if (!allowed) return;
    final uri = Uri(scheme: 'tel', path: item.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await CallStatsStore().incrementCallsMade(Session.currentUser.email);
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    if (!_hasPhone) return;
    final allowed = await requirePlanPointsForTarget(
      context,
      PlanAction.whatsapp,
      _usageKeyFor(item, 'whatsapp'),
    );
    if (!allowed) return;
    final msg =
        'Hi ${item.sellerName}, I\'m interested in ${item.displayTitle}.';
    await launchWhatsAppChat(context, item.phone, msg);
  }
}
