import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageStatsStore {
  static final MessageStatsStore _instance = MessageStatsStore._internal();
  factory MessageStatsStore() => _instance;
  MessageStatsStore._internal();

  /// Notifies listeners whenever message counts change.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  String _sentKey(String email) =>
      'messages_sent_${email.toLowerCase().replaceAll(' ', '_')}';

  String _receivedKey(String email) =>
      'messages_received_${email.toLowerCase().replaceAll(' ', '_')}';

  Future<int> loadSent(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_sentKey(email)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> loadReceived(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_receivedKey(email)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> incrementSent(String email) async {
    await _increment(_sentKey(email));
  }

  Future<void> incrementReceived(String email) async {
    await _increment(_receivedKey(email));
  }

  Future<void> _increment(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
      version.value = version.value + 1;
    } catch (_) {
      // ignore persistence errors
    }
  }
}
