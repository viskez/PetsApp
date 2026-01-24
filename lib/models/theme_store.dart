import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeOption {
  final String id;
  final String label;
  final Color color;
  const ThemeOption({required this.id, required this.label, required this.color});
}

class ThemeStore {
  static const _prefsKey = 'app_theme_seed';
  static const List<ThemeOption> options = [
    ThemeOption(id: 'teal', label: 'Teal', color: Colors.teal),
    ThemeOption(id: 'blue', label: 'Blue', color: Colors.blue),
    ThemeOption(id: 'indigo', label: 'Indigo', color: Colors.indigo),
    ThemeOption(id: 'orange', label: 'Orange', color: Colors.deepOrange),
    ThemeOption(id: 'green', label: 'Green', color: Colors.green),
  ];

  static final ValueNotifier<ThemeOption> current =
      ValueNotifier<ThemeOption>(options.first);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final opt = options.firstWhere(
      (o) => o.id == saved,
      orElse: () => options.first,
    );
    current.value = opt;
  }

  static ThemeOption get currentOption => current.value;

  static Future<void> setTheme(String id) async {
    final opt = options.firstWhere(
      (o) => o.id == id,
      orElse: () => options.first,
    );
    current.value = opt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, opt.id);
  }
}
