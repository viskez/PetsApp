import 'package:flutter/material.dart';
import '../models/theme_store.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool notif = true;
  bool tips = false;
  late String _selectedThemeId;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = ThemeStore.currentOption.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: notif,
            onChanged: (v) => setState(() => notif = v),
            title: const Text('Notifications'),
            subtitle: const Text('Receive updates and chat alerts'),
          ),
          SwitchListTile(
            value: tips,
            onChanged: (v) => setState(() => tips = v),
            title: const Text('Show tips'),
            subtitle: const Text('Learning cards & quick guidance'),
          ),
          const SizedBox(height: 12),
          _themeSelector(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved')),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _themeSelector() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Color theme',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      value: _selectedThemeId,
      items: ThemeStore.options
          .map(
            (opt) => DropdownMenuItem<String>(
              value: opt.id,
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: opt.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(opt.label),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (value) async {
        if (value == null) return;
        setState(() => _selectedThemeId = value);
        await ThemeStore.setTheme(value);
      },
    );
  }
}
