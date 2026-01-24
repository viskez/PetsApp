import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../views/pet_details.dart';
import 'pet_utils.dart';

class PetCatalogItem {
  final String title;
  final List<String> images;
  final List<String> videos;
  final int price;
  final String location;
  final String description;

  final String sellerName;
  final String phone;
  final PetCategory category; // animals / birds / fish
  final DateTime? addedAt;
  final PetStatus status;

  const PetCatalogItem({
    required this.title,
    required this.images,
    this.videos = const [],
    required this.price,
    required this.location,
    required this.description,
    required this.sellerName,
    required this.phone,
    required this.category,
    this.addedAt,
    this.status = PetStatus.active,
  });

  String get displayTitle => normalizePetTitle(title);

  String get primaryImage =>
      images.isNotEmpty ? images.first : kPetPlaceholderImage;

  PetItem toItem() => PetItem(
        title: title,
        images: images,
        videos: videos,
        price: price,
        location: location,
        description: description,
        sellerName: sellerName,
        sellerPhone: phone,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'images': images,
        'videos': videos,
        'price': price,
        'location': location,
        'description': description,
        'sellerName': sellerName,
        'phone': phone,
        'category': category.name,
        'addedAt': addedAt?.toIso8601String(),
        'status': status.name,
      };

  factory PetCatalogItem.fromJson(Map<String, dynamic> json) => PetCatalogItem(
        title: json['title'] as String? ?? '',
        images: (json['images'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const <String>[],
        videos: (json['videos'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const <String>[],
        price: json['price'] as int? ?? 0,
        location: json['location'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sellerName: json['sellerName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        category: _categoryFromName(json['category'] as String?),
        addedAt: _parseDate(json['addedAt']),
        status: _statusFrom(json['status']),
      );

  PetCatalogItem copyWith({
    String? title,
    List<String>? images,
    List<String>? videos,
    int? price,
    String? location,
    String? description,
    String? sellerName,
    String? phone,
    PetCategory? category,
    DateTime? addedAt,
    PetStatus? status,
  }) {
    return PetCatalogItem(
      title: title ?? this.title,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      price: price ?? this.price,
      location: location ?? this.location,
      description: description ?? this.description,
      sellerName: sellerName ?? this.sellerName,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      addedAt: addedAt ?? this.addedAt,
      status: status ?? this.status,
    );
  }

  static PetCategory _categoryFromName(String? name) {
    return PetCategory.values
        .firstWhere((c) => c.name == name, orElse: () => PetCategory.animals);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static PetStatus _statusFrom(dynamic value) {
    if (value == null) return PetStatus.active;
    final raw = value.toString().trim().toLowerCase();
    switch (raw) {
      case 'inactive':
        return PetStatus.inactive;
      case 'sold':
        return PetStatus.sold;
      case 'deleted':
        return PetStatus.deleted;
      case 'pending_approval':
      case 'pending approval':
      case 'pendingapproval':
        return PetStatus.pendingApproval;
      case 'active':
      default:
        return PetStatus.active;
    }
  }
}

enum PetCategory { animals, birds, fish }

enum PetStatus { active, inactive, sold, pendingApproval, deleted }

extension PetStatusLabel on PetStatus {
  String get label {
    switch (this) {
      case PetStatus.active:
        return 'Active';
      case PetStatus.inactive:
        return 'Inactive';
      case PetStatus.sold:
        return 'Sold';
      case PetStatus.pendingApproval:
        return 'Pending';
      case PetStatus.deleted:
        return 'Deleted';
    }
  }
}

class PetCatalog {
  static const _prefsKey = 'pet_catalog_overrides_v1';
  static final Map<String, PetCatalogItem> _byTitle = {};
  static bool _sessionPruned = false;
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static void registerAll(Iterable<PetCatalogItem> items) {
    for (final p in items) {
      _byTitle.putIfAbsent(p.title, () => p);
    }
  }

  static Future<void> initWithLocalOverrides(
      Iterable<PetCatalogItem> base) async {
    clear();
    registerAll(base);
    await _applyOverrides();
    _dedupeNormalized();
    // Persist a cleaned snapshot so stale duplicates are not reloaded next run.
    await _saveOverrides();
    _bump();
  }

  /// Safe to call multiple times; runs only once per app session to
  /// normalize and persist the current catalog (helps clean stale duplicates
  /// after hot-reload without re-running `main`).
  static Future<void> pruneAndSaveOnce() async {
    if (_sessionPruned) return;
    _sessionPruned = true;
    final changed = _dedupeNormalized();
    await _saveOverrides();
    if (changed) _bump();
  }

  static void upsert(PetCatalogItem item, {String? previousTitle}) {
    if (previousTitle != null && previousTitle.isNotEmpty) {
      _removeByNormalized(previousTitle);
    }
    _removeConflictingTitles(item.title);
    _byTitle[item.title] = item;
    _dedupeNormalized();
    _bump();
  }

  static Future<void> upsertAndSave(PetCatalogItem item,
      {String? previousTitle}) async {
    upsert(item, previousTitle: previousTitle);
    await _saveOverrides();
  }

  static Future<void> removeAndSave(String title) async {
    _removeByNormalized(title);
    await _saveOverrides();
    _bump();
  }

  static PetCatalogItem? byTitle(String title) => _byTitle[title];

  static List<PetCatalogItem> selected(Iterable<String> titles) =>
      titles.map(byTitle).whereType<PetCatalogItem>().toList(growable: false);

  static List<PetCatalogItem> get all {
    return _byTitle.values.toList(growable: true);
  }

  static void clear() => _byTitle.clear();

  static Future<void> _applyOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final item = PetCatalogItem.fromJson(entry);
            upsert(item);
          } else if (entry is Map) {
            final item =
                PetCatalogItem.fromJson(entry.map((k, v) => MapEntry('$k', v)));
            upsert(item);
          }
        }
      }
      _dedupeNormalized();
    } catch (_) {
      // ignore corrupt cache
    }
  }

  static Future<void> _saveOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload =
          _byTitle.values.map((e) => e.toJson()).toList(growable: false);
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // ignore persistence errors
    }
  }

  static void _removeConflictingTitles(String title) {
    final key = _canonicalKey(title);
    _byTitle.removeWhere((k, _) => k != title && _canonicalKey(k) == key);
  }

  static void _removeByNormalized(String title) {
    if (title.isEmpty) return;
    final key = _canonicalKey(title);
    _byTitle
        .removeWhere((k, _) => _canonicalKey(k) == key || k == title.trim());
  }

  static bool _dedupeNormalized() {
    final seen = <String>{};
    final keep = <PetCatalogItem>[];
    for (final entry in _byTitle.entries.toList().reversed) {
      final norm = _canonicalKey(entry.key);
      if (seen.add(norm)) {
        keep.add(entry.value);
      }
    }
    if (keep.length == _byTitle.length) return false;
    _byTitle
      ..clear()
      ..addEntries(keep.reversed.map((item) => MapEntry(item.title, item)));
    return true;
  }

  static String _canonicalKey(String title) {
    final normalized = normalizePetTitle(title);
    final parts = normalized.split(kPetTitleSeparator);
    // Keep only the primary species/breed to avoid repeated segments.
    final primary = parts.take(2).map((p) => p.trim()).where((p) => p.isNotEmpty);
    final canon = primary.join(kPetTitleSeparator).trim();
    return canon.isEmpty ? normalized.trim() : canon;
  }

  static void _bump() {
    version.value++;
  }
}
