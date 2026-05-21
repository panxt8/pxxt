import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('外观'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _themeModeLabel(theme.themeMode),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showThemeModeSheet(context, theme.themeMode),
          ),
        ],
      ),
    );
  }

  Future<void> _showThemeModeSheet(
    BuildContext context,
    ThemeMode currentMode,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('外观')),
              RadioGroup<ThemeMode>(
                groupValue: currentMode,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('跟随系统'),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('浅色'),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('深色'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;
    _setThemeMode(context, selected);
  }

  void _setThemeMode(BuildContext context, ThemeMode? value) {
    if (value == null) return;
    context.read<AppThemeController>().setThemeMode(value);
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '跟随系统',
    };
  }
}
