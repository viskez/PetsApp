import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallStatsStore {
  static final CallStatsStore _instance = CallStatsStore._internal();
  factory CallStatsStore() => _instance;
  CallStatsStore._internal();

  /// Notifies listeners whenever call counts change so UI can refresh live.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  String _keyFor(String email) =>
      'calls_made_${email.toLowerCase().replaceAll(' ', '_')}';

  Future<int> loadCallsMade(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyFor(email)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> incrementCallsMade(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyFor(email);
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
      version.value = version.value + 1;
    } catch (_) {
      // ignore persistence errors
    }
  }
}
