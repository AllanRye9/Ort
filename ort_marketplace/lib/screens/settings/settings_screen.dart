import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _msgNotifications = true;
  bool _orderNotifications = true;
  bool _reviewNotifications = true;
  bool _savedItemNotifications = true;
  bool _privateProfile = false;
  bool _showEmail = true;
  bool _loading = false;

  // Change password controllers
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _msgNotifications = prefs.getBool('notif_messages') ?? true;
      _orderNotifications = prefs.getBool('notif_orders') ?? true;
      _reviewNotifications = prefs.getBool('notif_reviews') ?? true;
      _savedItemNotifications = prefs.getBool('notif_saved') ?? true;
      _privateProfile = prefs.getBool('privacy_private') ?? false;
      _showEmail = prefs.getBool('privacy_show_email') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text.trim();
    final newPw = _newPwCtrl.text.trim();
    final confirm = _confirmPwCtrl.text.trim();
    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all password fields.');
      return;
    }
    if (newPw != confirm) {
      _showSnack('New passwords do not match.');
      return;
    }
    if (newPw.length < 8) {
      _showSnack('New password must be at least 8 characters.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(apiServiceProvider).updateMe({
        'current_password': current,
        'password': newPw,
      });
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      if (mounted) _showSnack('Password updated!', success: true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.primary : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);
    final marketplaceMode = ref.watch(marketplaceModeProvider);
    final locationStatus = ref.watch(locationAvailabilityProvider);
    final locationDenied = locationStatus == LocationAvailabilityStatus.denied;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Theme ───────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(theme.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context),
          ),
          Consumer(
            builder: (ctx, r, _) {
              final locale = r.watch(localeProvider);
              final l10n = AppLocalizations.of(ctx);
              final langName = locale == null
                  ? (l10n?.systemDefault ?? 'System default')
                  : (kSupportedLocaleNames[locale.languageCode] ?? locale.languageCode);
              return ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n?.language ?? 'Language'),
                subtitle: Text(langName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context),
              );
            },
          ),

          // ── Marketplace Mode ─────────────────────────────────────────────
          _SectionHeader('Marketplace'),
          ListTile(
            leading: Icon(
              marketplaceMode == MarketplaceMode.international
                  ? Icons.public
                  : Icons.place_rounded,
              color: marketplaceMode == MarketplaceMode.international
                  ? const Color(0xFF0288D1)
                  : AppTheme.primary,
            ),
            title: const Text('Marketplace Mode'),
            subtitle: Text(marketplaceMode.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showModePicker(context, locationDenied: locationDenied),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Text(
              locationDenied
                  ? 'Local mode is disabled because location access was denied. '
                    'Grant location access to switch to Local mode.'
                  : marketplaceMode.description,
              style: TextStyle(
                fontSize: 12,
                color: locationDenied
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.75)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),

          // ── Distance & Units ─────────────────────────────────────────────
          _SectionHeader('Distance & Units'),
          ListTile(
            leading: const Icon(Icons.straighten_outlined),
            title: const Text('Distance Unit'),
            subtitle: Text(distanceUnit.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDistanceUnitPicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.my_location_outlined),
            title: const Text('Auto-detect unit from location'),
            subtitle: const Text('Detects km or miles based on your country'),
            trailing: const Icon(Icons.gps_fixed, size: 18),
            onTap: () => _autoDetectDistanceUnit(context),
          ),

          // ── Notifications ───────────────────────────────────────────────
          _SectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.chat_bubble_outline),
            title: const Text('New Messages'),
            value: _msgNotifications,
            onChanged: (v) {
              setState(() => _msgNotifications = v);
              _savePref('notif_messages', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Order Updates'),
            value: _orderNotifications,
            onChanged: (v) {
              setState(() => _orderNotifications = v);
              _savePref('notif_orders', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.star_border),
            title: const Text('Reviews'),
            value: _reviewNotifications,
            onChanged: (v) {
              setState(() => _reviewNotifications = v);
              _savePref('notif_reviews', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bookmark_border),
            title: const Text('Saved Item Updates'),
            value: _savedItemNotifications,
            onChanged: (v) {
              setState(() => _savedItemNotifications = v);
              _savePref('notif_saved', v);
            },
          ),

          // ── Privacy ─────────────────────────────────────────────────────
          _SectionHeader('Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Private Profile'),
            subtitle: const Text('Hide your profile from search'),
            value: _privateProfile,
            onChanged: (v) {
              setState(() => _privateProfile = v);
              _savePref('privacy_private', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.email_outlined),
            title: const Text('Show Email'),
            subtitle: const Text('Display email on your public profile'),
            value: _showEmail,
            onChanged: (v) {
              setState(() => _showEmail = v);
              _savePref('privacy_show_email', v);
            },
          ),

          // ── Account Management ───────────────────────────────────────────
          _SectionHeader('Account'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _changePassword,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ],
            ),
          ),

          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final current = ref.read(themeProvider);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Choose Theme',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...AppThemeChoice.values.map(
                (choice) => RadioListTile<AppThemeChoice>(
                  value: choice,
                  groupValue: current,
                  title: Text(choice.label),
                  onChanged: (v) {
                    if (v != null) ref.read(themeProvider.notifier).setTheme(v);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final current = ref.read(localeProvider);
    final l10n = AppLocalizations.of(context);
    // Entries: null → system default, then each supported locale.
    final options = <Locale?>[null, ...kSupportedLocaleNames.keys.map(Locale.new)];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n?.chooseLanguage ?? 'Choose Language',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...options.map(
                (locale) => RadioListTile<Locale?>(
                  value: locale,
                  groupValue: current,
                  title: Text(
                    locale == null
                        ? (l10n?.systemDefault ?? 'System default')
                        : (kSupportedLocaleNames[locale.languageCode] ?? locale.languageCode),
                  ),
                  onChanged: (v) {
                    ref.read(localeProvider.notifier).setLocale(v);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModePicker(BuildContext context, {bool locationDenied = false}) {
    final current = ref.read(marketplaceModeProvider);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Choose Marketplace Mode',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  locationDenied
                      ? 'Local mode requires location access. '
                        'Grant location permission to enable it.'
                      : 'International mode shows all prices in USD and is designed for Uganda ↔ UAE import & export.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              ...MarketplaceMode.values.map(
                (mode) {
                  final isLocalDisabled =
                      locationDenied && mode == MarketplaceMode.local;
                  return RadioListTile<MarketplaceMode>(
                    value: mode,
                    groupValue: current,
                    title: Text(mode.label),
                    subtitle: Text(
                      isLocalDisabled
                          ? 'Requires location access'
                          : mode.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isLocalDisabled ? Colors.red[400] : null,
                      ),
                    ),
                    onChanged: isLocalDisabled
                        ? null
                        : (v) {
                            if (v != null) {
                              ref
                                  .read(marketplaceModeProvider.notifier)
                                  .setMode(v);
                            }
                            Navigator.of(ctx).pop();
                          },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistanceUnitPicker(BuildContext context) {
    final current = ref.read(distanceUnitProvider);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Choose Distance Unit',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...DistanceUnit.values.map(
                (unit) => RadioListTile<DistanceUnit>(
                  value: unit,
                  groupValue: current,
                  title: Text(unit.label),
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(distanceUnitProvider.notifier).setUnit(v);
                    }
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _autoDetectDistanceUnit(BuildContext context) async {
    _showSnack('Detecting your location…');
    final detected = await ref.read(distanceUnitProvider.notifier).autoDetect();
    if (mounted) {
      _showSnack(
        'Distance unit set to ${detected.label}',
        success: true,
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
