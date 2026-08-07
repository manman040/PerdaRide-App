import 'package:flutter/material.dart';

import '../../../core/settings/app_copy.dart';
import '../../../core/settings/app_settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppSettingsScope.of(context);
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final state = controller.value;

    return Scaffold(
      appBar: AppBar(title: Text(copy.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsCard(
            title: copy.appearanceSection,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: state.isDarkMode,
                  onChanged: (enabled) {
                    controller.updateThemeMode(
                      enabled ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                  activeThumbColor: theme.colorScheme.primary,
                  title: Text(copy.darkModeTitle),
                  subtitle: Text(copy.darkModeDescription),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(copy.systemDefault),
                      icon: const Icon(Icons.phone_android_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(copy.lightMode),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(copy.darkMode),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (selection) {
                    controller.updateThemeMode(selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: copy.languageSection,
            subtitle: copy.languageDescription,
            child: SegmentedButton<AppLanguage>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AppLanguage.english,
                  label: Text(copy.english),
                ),
                ButtonSegment(
                  value: AppLanguage.bahasaMelayu,
                  label: Text(copy.bahasaMelayu),
                ),
              ],
              selected: {state.language},
              onSelectionChanged: (selection) {
                controller.updateLanguage(selection.first);
              },
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: copy.notificationsSection,
            child: SwitchListTile.adaptive(
              value: state.notificationsEnabled,
              onChanged: (enabled) {
                controller.updateNotificationsEnabled(enabled);
              },
              activeThumbColor: theme.colorScheme.primary,
              title: Text(copy.pushNotificationsToggleTitle),
              subtitle: Text(copy.pushNotificationsToggleDescription),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                copy.settingsFooter,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
