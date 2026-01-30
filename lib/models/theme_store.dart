import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeOption {
  final String id;
  final String label;
  final Color color;
  const ThemeOption(
      {required this.id, required this.label, required this.color});
}

class ThemeStore {
  static const _prefsKey = 'app_theme_seed';
  static const _prefsHexKey = 'app_theme_seed_hex';
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
    if (saved == 'custom') {
      final hex = prefs.getString(_prefsHexKey);
      final color = _parseHex(hex) ?? options.first.color;
      current.value = ThemeOption(id: 'custom', label: 'Custom', color: color);
      return;
    }
    final opt =
        options.firstWhere((o) => o.id == saved, orElse: () => options.first);
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
    await prefs.setString(_prefsHexKey, _hexFromColor(opt.color));
  }

  static Future<void> setCustomColor(Color color) async {
    final custom = ThemeOption(id: 'custom', label: 'Custom', color: color);
    current.value = custom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, 'custom');
    await prefs.setString(_prefsHexKey, _hexFromColor(color));
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return null;
  }

  static String _hexFromColor(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
