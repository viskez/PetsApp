import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';

class UserProfileStore {
  static final UserProfileStore _instance = UserProfileStore._internal();
  factory UserProfileStore() => _instance;
  UserProfileStore._internal();

  String _key(String email) =>
      'profile_${email.toLowerCase().replaceAll(' ', '_')}';
  String _nameKey(String name) =>
      'verified_name_${name.toLowerCase().replaceAll(' ', '_')}';

  Future<UserProfile> load(UserProfile fallback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(fallback.email));
      UserProfile profile = fallback;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          profile = UserProfile.fromJson(
              decoded.map((k, v) => MapEntry('$k', v)));
        }
      }

      final nameVerified = prefs.getBool(_nameKey(profile.name)) ??
          prefs.getBool(_nameKey(fallback.name)) ??
          false;
      if (nameVerified && !profile.isVerified) {
        profile = profile.copyWith(isVerified: true);
      }
      return profile;
    } catch (_) {
      // ignore corrupt cache
    }
    return fallback;
  }

  Future<void> save(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(profile.email), jsonEncode(profile.toJson()));
      await prefs.setBool(_nameKey(profile.name), profile.isVerified);
    } catch (_) {
      // ignore persistence errors
    }
  }

  Future<bool> isNameVerified(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_nameKey(name)) ?? false;
    } catch (_) {
      return false;
    }
  }
}
