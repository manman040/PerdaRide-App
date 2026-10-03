import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/settings/app_settings_controller.dart';
import '../core/theme/app_theme.dart';
import 'app_router.dart';

class PerdaRideApp extends StatelessWidget {
  const PerdaRideApp({super.key});

  static final AppSettingsController _settingsController =
      AppSettingsController.instance;

  static Future<void> loadSettings() => _settingsController.load();

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: _settingsController,
      child: AnimatedBuilder(
        animation: _settingsController,
        builder: (context, _) {
          final state = _settingsController.value;
          return MaterialApp(
            title: 'Urban Drive',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            locale: state.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ms')],
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
