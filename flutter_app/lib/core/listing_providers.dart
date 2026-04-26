/// Shared Riverpod providers for listing data used on the home screen and
/// listing screens. Keeping them top-level (non-autoDispose) means any screen
/// can call `ref.invalidate(...)` to force a refresh after creating/editing a
/// listing, so uploaded images appear everywhere automatically.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import '../models/models.dart';

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

/// Call this after creating any listing to ensure the home feed is refreshed.
void invalidateHomeProviders(Ref ref) {
  ref.invalidate(homePropertiesProvider);
  ref.invalidate(homeAgricultureProvider);
  ref.invalidate(homeMfgProvider);
}
