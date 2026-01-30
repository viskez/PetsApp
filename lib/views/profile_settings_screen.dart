import 'package:flutter/material.dart';
import '../models/theme_store.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool notif = true;
  bool tips = false;
  late Color _pendingColor;

  @override
  void initState() {
    super.initState();
    _pendingColor = ThemeStore.currentOption.color;
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
          _themePicker(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await ThemeStore.setCustomColor(_pendingColor);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved')),
              );
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _themePicker() {
    final hex =
        '#${_pendingColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: const Text('Color theme',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle:
            Text(hex, style: const TextStyle(fontWeight: FontWeight.w500)),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _pendingColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        trailing: FilledButton.icon(
          onPressed: _openColorPicker,
          icon: const Icon(Icons.palette_outlined, size: 18),
          label: const Text('Pick'),
        ),
      ),
    );
  }

  Future<void> _openColorPicker() async {
    Color temp = _pendingColor;
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Choose a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _pendingColor,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
            paletteType: PaletteType.hsvWithHue,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, temp),
              child: const Text('Select')),
        ],
      ),
    );

    if (picked != null) {
      setState(() => _pendingColor = picked);
    }
  }
}
