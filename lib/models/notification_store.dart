import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredNotification {
  final String title;
  final String message;
  final String timeLabel;
  final String image;

  const StoredNotification(
      {required this.title,
      required this.message,
      required this.timeLabel,
      required this.image});

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'time': timeLabel,
        'image': image,
      };

  factory StoredNotification.fromJson(Map<String, dynamic> json) =>
      StoredNotification(
        title: json['title'] as String? ?? 'Notification',
        message: json['message'] as String? ?? '',
        timeLabel: json['time'] as String? ?? '',
        image: json['image'] as String? ?? '',
      );
}

class NotificationStore {
  static final NotificationStore _instance = NotificationStore._internal();
  factory NotificationStore() => _instance;
  NotificationStore._internal();

  String _keyFor(String email) =>
      'notifications_${email.toLowerCase().replaceAll(' ', '_')}';

  Future<List<StoredNotification>> loadForUser(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(email));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => StoredNotification.fromJson(
                e.map((k, v) => MapEntry('$k', v))))
            .toList();
      }
    } catch (_) {
      // ignore malformed cache
    }
    return const [];
  }

  Future<void> saveForUser(String email, List<StoredNotification> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_keyFor(email), raw);
    } catch (_) {
      // ignore persistence errors
    }
  }
}
