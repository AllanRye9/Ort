/// Shared Riverpod providers for listing data used on the home screen and
/// listing screens. Keeping them top-level (non-autoDispose) means any screen
/// can call `ref.invalidate(...)` to force a refresh after creating/editing a
/// listing, so uploaded images appear everywhere automatically.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'app_preferences.dart';
import 'friendly_error.dart';
import 'location_service.dart';
import '../models/models.dart';

// ─── Currency formatting ──────────────────────────────────────────────────────

const _kToUsdRates = {
  'UGX': 0.000272, // Ugandan Shilling  ≈ 0.000272 USD
  'SSP': 0.0013,   // South Sudanese Pound
  'AED': 0.2722940776, // UAE Dirham fixed peg (≈ 3.6725 AED : 1 USD)
  'USD': 1.0,
  'EUR': 1.08,
  'GBP': 1.25,
  'KES': 0.0077,   // Kenyan Shilling
  'TZS': 0.00039,  // Tanzanian Shilling
  'RWF': 0.00087,  // Rwandan Franc
  'BIF': 0.00035,  // Burundian Franc
  'ETB': 0.0088,   // Ethiopian Birr
  'GHS': 0.067,    // Ghanaian Cedi
  'NGN': 0.00062,  // Nigerian Naira
  'ZAR': 0.054,    // South African Rand
  'ZMW': 0.037,    // Zambian Kwacha
  'MWK': 0.00058,  // Malawian Kwacha
  'MZN': 0.016,    // Mozambican Metical
  'BWP': 0.073,    // Botswana Pula
  'NAD': 0.054,    // Namibian Dollar
  'EGP': 0.021,    // Egyptian Pound
  'MAD': 0.1,      // Moroccan Dirham
  'DZD': 0.0074,   // Algerian Dinar
  'TND': 0.32,     // Tunisian Dinar
  'CNY': 0.137,    // Chinese Yuan
  'INR': 0.012,    // Indian Rupee
  'JPY': 0.0064,   // Japanese Yen
  'CAD': 0.73,     // Canadian Dollar
  'AUD': 0.66,     // Australian Dollar
  'NZD': 0.61,     // New Zealand Dollar
  'CHF': 1.1,      // Swiss Franc
};

/// Converts [amount] between supported currencies using the shared USD rate
/// table. When [fromCurrency] is null, the app treats listing prices as UGX
/// source values; when [toCurrency] is null, USD is used as the safest display
/// fallback. Returns `null` when either currency is unknown, so callers can
/// fall back to USD and, if that also fails, keep showing the original stored
/// currency amount instead of inventing a target-currency value.
double? convertCurrency(
  double amount, {
  required String? fromCurrency,
  required String? toCurrency,
}) {
  final source = (fromCurrency ?? 'UGX').toUpperCase();
  final target = (toCurrency ?? 'USD').toUpperCase();
  if (source == target) return amount;

  final sourceToUsd = _kToUsdRates[source];
  final targetToUsd = _kToUsdRates[target];
  if (sourceToUsd == null || targetToUsd == null) return null;

  final amountInUsd = amount * sourceToUsd;
  return amountInUsd / targetToUsd;
}

/// Formats [amount] as a currency string based on [country] or explicit
/// [currency] code.
///
/// * Uganda (`UGX` or country == "Uganda") → `UGX 1,234,567` (no decimals)
/// * UAE (`AED` or country == "United Arab Emirates") → `AED 1,234` (no decimals)
/// * All other → `$1234.00` using [decimals] decimal places
String formatCurrency(
  double amount, {
  String? currency,
  int decimals = 0,
}) {
  final cur = currency?.toUpperCase();

  if (cur == 'UGX') {
    return 'UGX ${NumberFormat('#,###', 'en_US').format(amount.round())}';
  }
  if (cur == 'AED') {
    return 'AED ${NumberFormat('#,###', 'en_US').format(amount.round())}';
  }
  if (cur == 'USD' || cur == null) {
    return '\$${amount.toStringAsFixed(decimals)}';
  }
  return '$cur ${amount.toStringAsFixed(decimals)}';
}

/// Returns the currency code for the given country name.
/// Defaults to 'USD' when the country is not specifically recognised.
String currencyCodeForCountry(String? country) {
  final normalized = normalizeCountryName(country)?.toLowerCase();
  const mapping = {
    'uganda': 'UGX',
    'south sudan': 'SSP',
    'kenya': 'KES',
    'tanzania': 'TZS',
    'rwanda': 'RWF',
    'burundi': 'BIF',
    'ethiopia': 'ETB',
    'nigeria': 'NGN',
    'ghana': 'GHS',
    'south africa': 'ZAR',
    'zambia': 'ZMW',
    'malawi': 'MWK',
    'mozambique': 'MZN',
    'botswana': 'BWP',
    'namibia': 'NAD',
    'egypt': 'EGP',
    'morocco': 'MAD',
    'algeria': 'DZD',
    'tunisia': 'TND',
    'united arab emirates': 'AED',
    'united states': 'USD',
    'united kingdom': 'GBP',
    'germany': 'EUR',
    'france': 'EUR',
    'italy': 'EUR',
    'spain': 'EUR',
    'india': 'INR',
    'china': 'CNY',
    'japan': 'JPY',
    'canada': 'CAD',
    'australia': 'AUD',
    'new zealand': 'NZD',
    'switzerland': 'CHF',
  };
  return mapping[normalized] ?? 'USD';
}

/// Returns the currency symbol / prefix for the given country.
String currencyPrefixForCountry(String? country) {
  if (matchesCountry(country, 'Uganda')) {
    return 'UGX ';
  }
  if (matchesCountry(country, 'United Arab Emirates')) {
    return 'AED ';
  }
  return '\$';
}

/// Like [formatCurrency] but respects the current [MarketplaceMode].
///
/// In [MarketplaceMode.international] all prices are converted to USD using
/// [convertToUsd] before display, regardless of the original currency.
/// In [MarketplaceMode.local] the existing country/currency logic applies.
String formatCurrencyForMode(
  double amount, {
  String? country,
  String? currency,
  String? viewerCountry,
  int decimals = 0,
  MarketplaceMode mode = MarketplaceMode.local,
}) {
  final sourceCurrency = currency?.isNotEmpty ?? false
      ? currency!.toUpperCase()
      : 'UGX';
  var targetCurrency = mode == MarketplaceMode.international
      ? 'USD'
      : currencyCodeForCountry(viewerCountry ?? country);

  var converted = convertCurrency(
    amount,
    fromCurrency: sourceCurrency,
    toCurrency: targetCurrency,
  );

  if (converted == null && targetCurrency != 'USD') {
    targetCurrency = 'USD';
    converted = convertCurrency(
      amount,
      fromCurrency: sourceCurrency,
      toCurrency: targetCurrency,
    );
  }

  // If we cannot convert to the viewer currency, try USD next. If both
  // conversions fail, show the stored amount with its original currency code
  // instead of fabricating a misleading display currency.
  return formatCurrency(
    converted ?? amount,
    currency: converted == null ? sourceCurrency : targetCurrency,
    decimals: decimals,
  );
}

/// The user's last known GPS position as `(lat, lon)`. Null until the user
/// grants location permission or manually sets a location.
final userLocationProvider = StateProvider<(double, double)?>((_) => null);

/// Radius (in km) for location-based listing filter. Default 50 km.
final radiusFilterProvider = StateProvider<double>((_) => 50.0);

final homePropertiesCacheFallbackProvider = StateProvider<bool>((_) => false);
final homeAgricultureCacheFallbackProvider = StateProvider<bool>((_) => false);
final homeMfgCacheFallbackProvider = StateProvider<bool>((_) => false);
final homeServicesCacheFallbackProvider = StateProvider<bool>((_) => false);

Future<List<dynamic>> _fetchWithOfflineCache(
  Ref ref, {
  required String cacheKey,
  required Future<List<dynamic>> Function() request,
  required StateProvider<bool> fallbackProvider,
}) async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final data = await request();
    await prefs.setString(cacheKey, jsonEncode(data));
    ref.read(fallbackProvider.notifier).state = false;
    return data;
  } catch (e, st) {
    debugPrint('Home feed fetch failed for $cacheKey: $e\n$st');
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      final decoded = jsonDecode(cached);
      if (decoded is List<dynamic>) {
        ref.read(fallbackProvider.notifier).state = true;
        return decoded;
      }
    }
    ref.read(fallbackProvider.notifier).state = false;
    throw Exception(friendlyErrorMessage());
  }
}

// ─── Haversine distance helper ────────────────────────────────────────────────

/// Returns the great-circle distance in kilometres between two coordinates.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // Earth's mean radius in kilometres
  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final dPhi = (lat2 - lat1) * pi / 180;
  final dLambda = (lon2 - lon1) * pi / 180;
  final a = sin(dPhi / 2) * sin(dPhi / 2) +
      cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Sorts [items] by distance from [userLoc] (closest first).
/// Items whose coordinates are null are placed at the end of the list.
List<T> sortedByDistance<T>(
  List<T> items,
  (double, double)? userLoc,
  double? Function(T) getLat,
  double? Function(T) getLon,
) {
  if (userLoc == null) return items;
  final (uLat, uLon) = userLoc;
  final copy = [...items];
  copy.sort((a, b) {
    final aLat = getLat(a), aLon = getLon(a);
    final bLat = getLat(b), bLon = getLon(b);
    if (aLat == null || aLon == null) return 1;
    if (bLat == null || bLon == null) return -1;
    return haversineKm(uLat, uLon, aLat, aLon)
        .compareTo(haversineKm(uLat, uLon, bLat, bLon));
  });
  return copy;
}

// ─── Raw fetch providers (network) ───────────────────────────────────────────

final homePropertiesProvider = FutureProvider<List<PropertyModel>>(
  (ref) async {
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
    final intlFilter = ref.watch(intlCountryFilterProvider);

    String? country;
    String? excludeCountry;
    if (mode == MarketplaceMode.local) {
      country = userCountry;
    } else {
      // International: exclude user's country; optionally filter to a target country
      if (intlFilter.isNotEmpty) {
        country = intlFilter;
      } else {
        excludeCountry = userCountry;
      }
    }

    final data = await _fetchWithOfflineCache(
      ref,
      cacheKey: 'cache_home_properties',
      fallbackProvider: homePropertiesCacheFallbackProvider,
      request: () => ref.read(apiServiceProvider).getPropertiesFiltered(
            limit: 20,
            country: country,
            excludeCountry: excludeCountry,
          ),
    );
    return data
        .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final homeAgricultureProvider = FutureProvider<List<AgricultureListingModel>>(
  (ref) async {
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
    final intlFilter = ref.watch(intlCountryFilterProvider);

    String? country;
    String? excludeCountry;
    if (mode == MarketplaceMode.local) {
      country = userCountry;
    } else {
      if (intlFilter.isNotEmpty) {
        country = intlFilter;
      } else {
        excludeCountry = userCountry;
      }
    }

    final data = await _fetchWithOfflineCache(
      ref,
      cacheKey: 'cache_home_agriculture',
      fallbackProvider: homeAgricultureCacheFallbackProvider,
      request: () => ref.read(apiServiceProvider).getAgricultureFiltered(
            limit: 8,
            country: country,
            excludeCountry: excludeCountry,
          ),
    );
    return data
        .map((e) =>
            AgricultureListingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final homeMfgProvider = FutureProvider<List<ManufacturingProductModel>>(
  (ref) async {
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
    final intlFilter = ref.watch(intlCountryFilterProvider);

    String? country;
    String? excludeCountry;
    if (mode == MarketplaceMode.local) {
      country = userCountry;
    } else {
      if (intlFilter.isNotEmpty) {
        country = intlFilter;
      } else {
        excludeCountry = userCountry;
      }
    }

    final data = await _fetchWithOfflineCache(
      ref,
      cacheKey: 'cache_home_mfg',
      fallbackProvider: homeMfgCacheFallbackProvider,
      request: () => ref.read(apiServiceProvider).getManufacturingFiltered(
            limit: 8,
            country: country,
            excludeCountry: excludeCountry,
          ),
    );
    return data
        .map((e) =>
            ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final homeServicesProvider = FutureProvider<List<ManufacturingServiceModel>>(
  (ref) async {
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
    final intlFilter = ref.watch(intlCountryFilterProvider);

    String? country;
    String? excludeCountry;
    if (mode == MarketplaceMode.local) {
      country = userCountry;
    } else {
      if (intlFilter.isNotEmpty) {
        country = intlFilter;
      } else {
        excludeCountry = userCountry;
      }
    }

    final data = await _fetchWithOfflineCache(
      ref,
      cacheKey: 'cache_home_services',
      fallbackProvider: homeServicesCacheFallbackProvider,
      request: () => ref.read(apiServiceProvider).getManufacturingServices(
            limit: 8,
            country: country,
            excludeCountry: excludeCountry,
          ),
    );
    return data
        .map((e) =>
            ManufacturingServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

// ─── Distance-sorted derived providers ───────────────────────────────────────
// These re-sort when userLocationProvider or radiusFilterProvider changes
// WITHOUT re-fetching from the API.

final sortedHomePropertiesProvider =
    Provider<AsyncValue<List<PropertyModel>>>((ref) {
  final data = ref.watch(homePropertiesProvider);
  final loc = ref.watch(userLocationProvider);
  final mode = ref.watch(marketplaceModeProvider);
  final recentlyViewed = ref.watch(recentlyViewedProvider);
  ref.watch(radiusFilterProvider); // trigger re-sort on radius change
  return data.whenData((items) {
    final byDist = mode == MarketplaceMode.local
        ? sortedByDistance(items, loc, (p) => p.latitude, (p) => p.longitude)
        : items;
    return applyPersonalization(byDist, recentlyViewed, 'property', (p) => p.id);
  });
});

final sortedHomeAgricultureProvider =
    Provider<AsyncValue<List<AgricultureListingModel>>>((ref) {
  final data = ref.watch(homeAgricultureProvider);
  final loc = ref.watch(userLocationProvider);
  final mode = ref.watch(marketplaceModeProvider);
  final recentlyViewed = ref.watch(recentlyViewedProvider);
  ref.watch(radiusFilterProvider);
  return data.whenData((items) {
    final byDist = mode == MarketplaceMode.local
        ? sortedByDistance(items, loc, (a) => a.latitude, (a) => a.longitude)
        : items;
    return applyPersonalization(byDist, recentlyViewed, 'agriculture', (a) => a.id);
  });
});

final sortedHomeMfgProvider =
    Provider<AsyncValue<List<ManufacturingProductModel>>>((ref) {
  final data = ref.watch(homeMfgProvider);
  final loc = ref.watch(userLocationProvider);
  final mode = ref.watch(marketplaceModeProvider);
  final recentlyViewed = ref.watch(recentlyViewedProvider);
  ref.watch(radiusFilterProvider);
  return data.whenData((items) {
    final byDist = mode == MarketplaceMode.local
        ? sortedByDistance(items, loc, (m) => m.latitude, (m) => m.longitude)
        : items;
    return applyPersonalization(byDist, recentlyViewed, 'manufacturing', (m) => m.id);
  });
});

final sortedHomeServicesProvider =
    Provider<AsyncValue<List<ManufacturingServiceModel>>>((ref) {
  final data = ref.watch(homeServicesProvider);
  final loc = ref.watch(userLocationProvider);
  final mode = ref.watch(marketplaceModeProvider);
  final recentlyViewed = ref.watch(recentlyViewedProvider);
  ref.watch(radiusFilterProvider);
  return data.whenData((items) {
    final byDist = mode == MarketplaceMode.local
        ? sortedByDistance(items, loc, (s) => s.latitude, (s) => s.longitude)
        : items;
    return applyPersonalization(byDist, recentlyViewed, 'manufacturing_service', (s) => s.id);
  });
});

/// Call this after creating any listing to ensure the home feed is refreshed.
void invalidateHomeProviders(WidgetRef ref) {
  ref.invalidate(homePropertiesProvider);
  ref.invalidate(homeAgricultureProvider);
  ref.invalidate(homeMfgProvider);
  ref.invalidate(homeServicesProvider);
}

// ─── Interaction tracking & personalization ───────────────────────────────────

const _kRecentlyViewedKey = 'recently_viewed_ids';
// Maximum number of listing IDs kept in the history.
const _kMaxRecentlyViewed = 100;

/// Tracks recently viewed listing IDs across all categories.  IDs are stored
/// as strings in SharedPreferences in the form `"<type>:<id>"`, e.g.
/// `"property:42"`, `"agriculture:7"`, `"manufacturing:15"`.
///
/// The list is ordered most-recently-viewed first; index 0 = the most recent.
class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_kRecentlyViewedKey) ?? [];
  }

  /// Records that the user has viewed a listing of [type] with the given [id].
  ///
  /// The entry is moved to the front (most recent) and the history is capped
  /// at [_kMaxRecentlyViewed] entries.
  Future<void> recordView(String type, int id) async {
    final key = '$type:$id';
    // Remove any existing occurrence so we don't get duplicates, then prepend.
    final updated = [key, ...state.where((k) => k != key)]
        .take(_kMaxRecentlyViewed)
        .toList();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentlyViewedKey, updated);
  }

  /// Returns `true` when the listing has been previously viewed.
  bool hasViewed(String type, int id) => state.contains('$type:$id');
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<String>>(
  (_) => RecentlyViewedNotifier(),
);

/// Re-orders [items] so that previously-viewed listings appear first, with
/// the most-recently-viewed item at the top.  Items not in the history keep
/// their original relative order after the viewed group.
///
/// Call this **after** distance-based sorting so the order within each group
/// still respects proximity.
List<T> applyPersonalization<T>(
  List<T> items,
  List<String> recentlyViewed,
  String type,
  int Function(T) getId,
) {
  // Build a lookup: key → recency rank (lower = more recent).
  final recencyRank = <String, int>{};
  for (var i = 0; i < recentlyViewed.length; i++) {
    recencyRank[recentlyViewed[i]] = i;
  }

  final viewed = <T>[];
  final rest = <T>[];
  for (final item in items) {
    final key = '$type:${getId(item)}';
    if (recencyRank.containsKey(key)) {
      viewed.add(item);
    } else {
      rest.add(item);
    }
  }

  // Sort viewed items by recency (index 0 = most recent → first).
  viewed.sort((a, b) {
    final rankA = recencyRank['$type:${getId(a)}'] ?? _kMaxRecentlyViewed;
    final rankB = recencyRank['$type:${getId(b)}'] ?? _kMaxRecentlyViewed;
    return rankA.compareTo(rankB);
  });

  return [...viewed, ...rest];
}
