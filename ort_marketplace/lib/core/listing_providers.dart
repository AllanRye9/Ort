/// Shared Riverpod providers for listing data used on the home screen and
/// listing screens. Keeping them top-level (non-autoDispose) means any screen
/// can call `ref.invalidate(...)` to force a refresh after creating/editing a
/// listing, so uploaded images appear everywhere automatically.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'app_preferences.dart';
import '../models/models.dart';

// ─── Currency formatting ──────────────────────────────────────────────────────

/// Formats [amount] as a currency string based on [country] or explicit
/// [currency] code.
///
/// * Uganda (`UGX` or country == "Uganda") → `UGX 1,234,567` (no decimals)
/// * UAE (`AED` or country == "United Arab Emirates") → `AED 1,234` (no decimals)
/// * All other → `$1234.00` using [decimals] decimal places
String formatCurrency(
  double amount, {
  String? country,
  String? currency,
  int decimals = 0,
}) {
  final c = country?.toLowerCase();
  final cur = currency?.toUpperCase();

  if (cur == 'UGX' || c == 'uganda') {
    return 'UGX ${NumberFormat('#,###', 'en_US').format(amount.round())}';
  }
  if (cur == 'AED' || c == 'united arab emirates') {
    return 'AED ${NumberFormat('#,###', 'en_US').format(amount.round())}';
  }
  return '\$${amount.toStringAsFixed(decimals)}';
}

/// Returns the currency code for the given country name.
/// Defaults to 'USD' when the country is not specifically recognised.
String currencyCodeForCountry(String? country) {
  switch (country?.toLowerCase()) {
    case 'uganda':
      return 'UGX';
    case 'united arab emirates':
      return 'AED';
    default:
      return 'USD';
  }
}

/// Returns the currency symbol / prefix for the given country.
String currencyPrefixForCountry(String? country) {
  switch (country?.toLowerCase()) {
    case 'uganda':
      return 'UGX ';
    case 'united arab emirates':
      return 'AED ';
    default:
      return '\$';
  }
}

/// Like [formatCurrency] but respects the current [MarketplaceMode].
///
/// In [MarketplaceMode.international] the currency is always USD regardless
/// of country/currency arguments.  In [MarketplaceMode.local] the existing
/// country/currency logic applies.
String formatCurrencyForMode(
  double amount, {
  String? country,
  String? currency,
  int decimals = 0,
  MarketplaceMode mode = MarketplaceMode.local,
}) {
  if (mode == MarketplaceMode.international) {
    return '\$${amount.toStringAsFixed(decimals == 0 ? 2 : decimals)}';
  }
  return formatCurrency(amount, country: country, currency: currency, decimals: decimals);
}

/// The user's last known GPS position as `(lat, lon)`. Null until the user
/// grants location permission or manually sets a location.
final userLocationProvider = StateProvider<(double, double)?>((_) => null);

/// Radius (in km) for location-based listing filter. Default 50 km.
final radiusFilterProvider = StateProvider<double>((_) => 50.0);

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
    final data = await ref.read(apiServiceProvider).getProperties(limit: 20);
    return data
        .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final homeAgricultureProvider = FutureProvider<List<AgricultureListingModel>>(
  (ref) async {
    final data =
        await ref.read(apiServiceProvider).getAgricultureListings(limit: 8);
    return data
        .map((e) =>
            AgricultureListingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final homeMfgProvider = FutureProvider<List<ManufacturingProductModel>>(
  (ref) async {
    final data =
        await ref.read(apiServiceProvider).getManufacturingProducts(limit: 8);
    return data
        .map((e) =>
            ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final homeServicesProvider = FutureProvider<List<ManufacturingServiceModel>>(
  (ref) async {
    final data =
        await ref.read(apiServiceProvider).getManufacturingServices(limit: 8);
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
  ref.watch(radiusFilterProvider); // trigger re-sort on radius change
  return data.whenData(
      (items) => sortedByDistance(items, loc, (p) => p.latitude, (p) => p.longitude));
});

final sortedHomeAgricultureProvider =
    Provider<AsyncValue<List<AgricultureListingModel>>>((ref) {
  final data = ref.watch(homeAgricultureProvider);
  final loc = ref.watch(userLocationProvider);
  ref.watch(radiusFilterProvider);
  return data.whenData(
      (items) => sortedByDistance(items, loc, (a) => a.latitude, (a) => a.longitude));
});

final sortedHomeMfgProvider =
    Provider<AsyncValue<List<ManufacturingProductModel>>>((ref) {
  final data = ref.watch(homeMfgProvider);
  final loc = ref.watch(userLocationProvider);
  ref.watch(radiusFilterProvider);
  return data.whenData(
      (items) => sortedByDistance(items, loc, (m) => m.latitude, (m) => m.longitude));
});

final sortedHomeServicesProvider =
    Provider<AsyncValue<List<ManufacturingServiceModel>>>((ref) {
  final data = ref.watch(homeServicesProvider);
  final loc = ref.watch(userLocationProvider);
  ref.watch(radiusFilterProvider);
  return data.whenData(
      (items) => sortedByDistance(items, loc, (s) => s.latitude, (s) => s.longitude));
});

/// Call this after creating any listing to ensure the home feed is refreshed.
void invalidateHomeProviders(WidgetRef ref) {
  ref.invalidate(homePropertiesProvider);
  ref.invalidate(homeAgricultureProvider);
  ref.invalidate(homeMfgProvider);
  ref.invalidate(homeServicesProvider);
}
