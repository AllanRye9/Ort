/// App-wide user preferences that are not theme-specific:
///   - Distance unit (km / miles) with auto-detect
///   - Marketplace mode (local / international)
///   - App locale (language)
///
/// All are persisted via [SharedPreferences] so they survive restarts.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

// ─── Distance unit ────────────────────────────────────────────────────────────

enum DistanceUnit {
  km,
  miles;

  String get label {
    switch (this) {
      case DistanceUnit.km:
        return 'Kilometres (km)';
      case DistanceUnit.miles:
        return 'Miles (mi)';
    }
  }

  String get shortLabel {
    switch (this) {
      case DistanceUnit.km:
        return 'km';
      case DistanceUnit.miles:
        return 'mi';
    }
  }
}

const _kDistanceUnitKey = 'distance_unit';

class DistanceUnitNotifier extends StateNotifier<DistanceUnit> {
  DistanceUnitNotifier() : super(DistanceUnit.km) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kDistanceUnitKey);
    if (saved != null) {
      state = DistanceUnit.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => DistanceUnit.km,
      );
    }
  }

  Future<void> setUnit(DistanceUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDistanceUnitKey, unit.name);
  }

  /// Detects the appropriate distance unit from the current device GPS position
  /// using reverse-geocoding.  Countries that primarily use miles (US, UK,
  /// Myanmar, Liberia) get [DistanceUnit.miles]; everything else gets [DistanceUnit.km].
  ///
  /// Returns the auto-detected unit (or [DistanceUnit.km] on failure).
  Future<DistanceUnit> autoDetect() async {
    try {
      final position = await LocationService.instance.requestAndGetPosition();
      if (position == null) return DistanceUnit.km;
      final result = await LocationService.instance.reverseGeocodePosition(
        position.latitude,
        position.longitude,
      );
      if (result == null) return DistanceUnit.km;
      final detected = _unitForCountry(result.country);
      await setUnit(detected);
      return detected;
    } catch (_) {
      return DistanceUnit.km;
    }
  }

  static DistanceUnit _unitForCountry(String? country) {
    const milesCountries = {
      'united states',
      'united kingdom',
      'myanmar',
      'liberia',
    };
    final lower = country?.toLowerCase() ?? '';
    return milesCountries.contains(lower) ? DistanceUnit.miles : DistanceUnit.km;
  }
}

final distanceUnitProvider =
    StateNotifierProvider<DistanceUnitNotifier, DistanceUnit>(
  (_) => DistanceUnitNotifier(),
);

// ─── Marketplace mode ──────────────────────────────────────────────────────────

enum MarketplaceMode {
  local,
  international;

  String get label {
    switch (this) {
      case MarketplaceMode.local:
        return 'Local';
      case MarketplaceMode.international:
        return 'International (UG ↔ UAE)';
    }
  }

  String get description {
    switch (this) {
      case MarketplaceMode.local:
        return 'Browse listings in your local market. '
            'Prices shown in your local currency (UGX / AED / USD).';
      case MarketplaceMode.international:
        return 'Browse import & export listings between Uganda and the UAE. '
            'All prices shown in US Dollars (USD).';
    }
  }
}

const _kMarketplaceModeKey = 'marketplace_mode';
const _kModeEverSelectedKey = 'mode_ever_selected';

class MarketplaceModeNotifier extends StateNotifier<MarketplaceMode> {
  MarketplaceModeNotifier() : super(MarketplaceMode.local) {
    _loadFuture = _load();
  }

  /// Completes once the initial [_load] has finished reading from
  /// [SharedPreferences].  Await this before reading [everSelected] to
  /// avoid a race condition where the preferences have not been read yet.
  late final Future<void> _loadFuture;

  /// Returns a [Future] that completes once the initial persisted state has
  /// been loaded from [SharedPreferences].
  Future<void> waitForLoad() => _loadFuture;

  bool _everSelected = false;
  bool get everSelected => _everSelected;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kMarketplaceModeKey);
    if (saved != null) {
      state = MarketplaceMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => MarketplaceMode.local,
      );
    }
    _everSelected = prefs.getBool(_kModeEverSelectedKey) ?? false;
  }

  /// Sets the active marketplace mode.
  ///
  /// If [locationStatus] is [LocationAvailabilityStatus.denied] and the
  /// requested mode is [MarketplaceMode.local], the mode is silently forced
  /// to [MarketplaceMode.international] to respect the location-gating rule.
  Future<void> setMode(
    MarketplaceMode mode, {
    LocationAvailabilityStatus locationStatus =
        LocationAvailabilityStatus.unknown,
  }) async {
    final effectiveMode =
        (mode == MarketplaceMode.local &&
                locationStatus == LocationAvailabilityStatus.denied)
            ? MarketplaceMode.international
            : mode;
    state = effectiveMode;
    _everSelected = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMarketplaceModeKey, effectiveMode.name);
    await prefs.setBool(_kModeEverSelectedKey, true);
  }
}

final marketplaceModeProvider =
    StateNotifierProvider<MarketplaceModeNotifier, MarketplaceMode>(
  (_) => MarketplaceModeNotifier(),
);

/// Separate bool provider that resolves to `true` once the user has chosen
/// a mode.  Used to decide whether to show the on-boarding mode-selection
/// dialog.  Implemented as a [FutureProvider] so that it correctly awaits
/// the async initialisation of [MarketplaceModeNotifier] before resolving.
final modeEverSelectedProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.read(marketplaceModeProvider.notifier);
  await notifier.waitForLoad();
  return notifier.everSelected;
});

// ─── Distance formatting helper ───────────────────────────────────────────────

const _kmToMiles = 0.621371;

/// Formats a distance for display.
///
/// * [km] – the raw distance in kilometres.
/// * [unit] – the unit to display.
///
/// Returns an empty string when [km] is null.
String formatDistance(double? km, DistanceUnit unit) {
  if (km == null) return '';
  if (unit == DistanceUnit.miles) {
    final miles = km * _kmToMiles;
    if (miles < 0.1) {
      return '${(miles * 5280).toStringAsFixed(0)} ft';
    }
    return '${miles.toStringAsFixed(2)} mi';
  } else {
    if (km < 1.0) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(2)} km';
  }
}

// ─── Location availability ────────────────────────────────────────────────────

/// Tracks whether the user has granted, denied, or not yet responded to the
/// location permission request.  Used to gate Local mode.
enum LocationAvailabilityStatus {
  /// Initial state – permission has not been checked yet.
  unknown,

  /// Location permission was granted and a GPS position was obtained.
  granted,

  /// Location permission was permanently denied or GPS is disabled.
  denied,
}

final locationAvailabilityProvider =
    StateProvider<LocationAvailabilityStatus>((_) => LocationAvailabilityStatus.unknown);

// ─── User country ─────────────────────────────────────────────────────────────

/// The user's current country, auto-detected by GPS or manually set.
/// Defaults to "Uganda" since that is the primary market.
const _kUserCountryKey = 'user_country';

class UserCountryNotifier extends StateNotifier<String> {
  UserCountryNotifier() : super('Uganda') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kUserCountryKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> setCountry(String country) async {
    state = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserCountryKey, country);
  }

  /// Auto-detect the user's country from GPS.
  Future<void> autoDetect() async {
    try {
      final position = await LocationService.instance.requestAndGetPosition();
      if (position == null) return;
      final result = await LocationService.instance.reverseGeocodePosition(
        position.latitude,
        position.longitude,
      );
      if (result?.country != null && result!.country!.isNotEmpty) {
        await setCountry(result.country!);
      }
    } catch (_) {}
  }
}

final userCountryProvider =
    StateNotifierProvider<UserCountryNotifier, String>(
  (_) => UserCountryNotifier(),
);

// ─── Display currency ─────────────────────────────────────────────────────────

const _kDisplayCurrencyKey = 'display_currency';

String currencyCodeForCountry(String? country) {
  switch (country?.trim().toLowerCase()) {
    case 'uganda':
      return 'UGX';
    case 'kenya':
      return 'KES';
    case 'tanzania':
      return 'TZS';
    case 'rwanda':
      return 'RWF';
    case 'united arab emirates':
    case 'uae':
      return 'AED';
    case 'united kingdom':
    case 'uk':
      return 'GBP';
    default:
      return 'USD';
  }
}

class DisplayCurrencyNotifier extends StateNotifier<String> {
  DisplayCurrencyNotifier(this._ref) : super('USD') {
    _initialize();
  }

  final Ref _ref;
  Future<void>? _refreshInFlight;

  Future<void> _initialize() async {
    await _load();
    await refreshFromLocation();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kDisplayCurrencyKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved.toUpperCase();
    }
  }

  Future<void> refreshFromLocation() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final refresh = _refreshFromLocationInternal();
    _refreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _refreshFromLocationInternal() async {
    try {
      final position = await LocationService.instance.requestAndGetPosition();
      if (position == null) {
        await _setCurrency('USD');
        return;
      }
      final result = await LocationService.instance.reverseGeocodePosition(
        position.latitude,
        position.longitude,
      );
      final country = result?.country?.trim();
      if (country == null || country.isEmpty) {
        await _setCurrency('USD');
        return;
      }

      await _ref.read(userCountryProvider.notifier).setCountry(country);
      await _setCurrency(currencyCodeForCountry(country));
    } catch (_) {
      await _setCurrency('USD');
    }
  }

  Future<void> _setCurrency(String currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDisplayCurrencyKey, currency);
  }
}

final displayCurrencyProvider =
    StateNotifierProvider<DisplayCurrencyNotifier, String>(
  (ref) => DisplayCurrencyNotifier(ref),
);

// ─── International country filter ─────────────────────────────────────────────

/// When in international mode, the user can optionally filter to a specific
/// foreign country. Empty string means "show all international listings".
/// Default target market is Uganda (so UAE/other users see Uganda goods).
const _kIntlCountryFilterKey = 'intl_country_filter';

class IntlCountryFilterNotifier extends StateNotifier<String> {
  IntlCountryFilterNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kIntlCountryFilterKey) ?? '';
  }

  Future<void> setFilter(String country) async {
    state = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIntlCountryFilterKey, country);
  }

  void clear() => setFilter('');
}

final intlCountryFilterProvider =
    StateNotifierProvider<IntlCountryFilterNotifier, String>(
  (_) => IntlCountryFilterNotifier(),
);

/// A curated list of countries available as filter options.
const kInternationalCountries = [
  'Uganda',
  'Kenya',
  'Tanzania',
  'Rwanda',
  'Ethiopia',
  'United Arab Emirates',
  'United States',
  'United Kingdom',
  'China',
  'India',
  'Germany',
  'France',
  'South Africa',
  'Nigeria',
  'Egypt',
];

// ─── App locale (language) ────────────────────────────────────────────────────

const _kLocaleKey = 'app_locale';

/// Supported locales with their display names.
const kSupportedLocaleNames = {
  'en': 'English',
  'ar': 'العربية',
  'sw': 'Kiswahili',
};

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null && kSupportedLocaleNames.containsKey(saved)) {
      state = Locale(saved);
    }
  }

  /// Explicitly set the locale.  Pass [null] to follow the system locale.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, locale.languageCode);
    }
  }
}

/// Holds the user-selected [Locale], or [null] to follow the system locale.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (_) => LocaleNotifier(),
);
