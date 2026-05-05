import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise Firebase (requires google-services.json / GoogleService-Info.plist).
  // Silently skipped when Firebase is not configured so that the app works in
  // development environments without the config files.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase config files not present – push notifications will be disabled.
  }
  runApp(const ProviderScope(child: OrtMarketplaceApp()));
}

class OrtMarketplaceApp extends ConsumerWidget {
  const OrtMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeChoice = ref.watch(themeProvider);

    final themeData = switch (themeChoice) {
      AppThemeChoice.white => AppTheme.lightTheme,
      AppThemeChoice.dark => AppTheme.darkTheme,
      AppThemeChoice.ocean => AppTheme.oceanTheme,
    };

    return MaterialApp.router(
      title: 'Ort Marketplace',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      routerConfig: router,
    );
  }
}
