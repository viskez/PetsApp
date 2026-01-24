/*import 'package:flutter/foundation.dart';

class WishlistStore {
  static final WishlistStore _instance = WishlistStore._internal();
  factory WishlistStore() => _instance;
  WishlistStore._internal();

  // store product ids (we'll use title as id for demo)
  final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>({});

  bool contains(String id) => ids.value.contains(id);

  void toggle(String id) {
    final s = Set<String>.from(ids.value);
    if (s.contains(id)) { s.remove(id); } else { s.add(id); }
    ids.value = s;
  }
}
*/
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

class WishlistStore {
  // Singleton
  static final WishlistStore _instance = WishlistStore._internal();
  factory WishlistStore() => _instance;
  WishlistStore._internal();

  // Selected item IDs (we store titles; you could switch to unique IDs if you have them)
  final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>(<String>{});
  String _prefsKey = _keyForEmail(Session.currentUser.email);

  static String _keyForEmail(String email) =>
      'wishlist_${email.toLowerCase().replaceAll(' ', '_')}';

  bool contains(String title) => ids.value.contains(title);

  void toggle(String title) {
    final next = Set<String>.from(ids.value);
    if (next.contains(title)) {
      next.remove(title);
    } else {
      next.add(title);
    }
    ids.value = next;
    _persist();
  }

  void clear() {
    ids.value = <String>{};
    _persist();
  }

  Future<void> loadForUser(String email) async {
    _prefsKey = _keyForEmail(email);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      ids.value = list == null ? <String>{} : list.toSet();
    } catch (_) {
      ids.value = <String>{};
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, ids.value.toList(growable: false));
    } catch (_) {
      // ignore persistence errors
    }
  }
}
