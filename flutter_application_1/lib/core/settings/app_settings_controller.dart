import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english(Locale('en')),
  bahasaMelayu(Locale('ms'));

  const AppLanguage(this.locale);

  final Locale locale;

  static AppLanguage fromLocale(Locale? locale) {
    if (locale?.languageCode.toLowerCase() == 'ms') {
      return AppLanguage.bahasaMelayu;
    }
    return AppLanguage.english;
  }
}

class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.language,
    required this.notificationsEnabled,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool notificationsEnabled;

  Locale get locale => language.locale;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? notificationsEnabled,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class AppSettingsController extends ValueNotifier<AppSettingsState> {
  AppSettingsController._()
    : super(
        AppSettingsState(
          themeMode: ThemeMode.system,
          language: AppLanguage.fromLocale(PlatformDispatcher.instance.locale),
          notificationsEnabled: true,
        ),
      );

  static final AppSettingsController instance = AppSettingsController._();

  static const _themeModeKey = 'settings_theme_mode';
  static const _languageKey = 'settings_language';
  static const _notificationsEnabledKey = 'settings_notifications_enabled';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final storedThemeMode = prefs.getString(_themeModeKey);
    final themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == storedThemeMode,
      orElse: () => value.themeMode,
    );

    final storedLanguage = prefs.getString(_languageKey);
    final language = AppLanguage.values.firstWhere(
      (lang) => lang.name == storedLanguage,
      orElse: () => value.language,
    );

    final notificationsEnabled =
        prefs.getBool(_notificationsEnabledKey) ?? value.notificationsEnabled;

    value = value.copyWith(
      themeMode: themeMode,
      language: language,
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    value = value.copyWith(themeMode: themeMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode.name);
  }

  Future<void> updateLanguage(AppLanguage language) async {
    value = value.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.name);
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    value = value.copyWith(notificationsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
