import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

const _kThemeKey = 'ort_theme_choice';

class ThemeNotifier extends Notifier<AppThemeChoice> {
  @override
  AppThemeChoice build() {
    // Default is White; load from prefs asynchronously after init.
    _loadSaved();
    return AppThemeChoice.white;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeKey);
    if (saved != null) {
      final choice = AppThemeChoice.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeChoice.white,
      );
      state = choice;
    }
  }

  Future<void> setTheme(AppThemeChoice choice) async {
    state = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, choice.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeChoice>(
  ThemeNotifier.new,
);
