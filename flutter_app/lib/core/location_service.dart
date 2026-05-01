// import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

/// Result returned by [LocationService.geocodeAddressDetailed].
class GeocodeResult {
  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    this.country,
    this.displayName,
  });

  final double latitude;
  final double longitude;

  /// ISO country name as returned by Nominatim, e.g. "Uganda", "Kenya".
  final String? country;

  /// Human-readable display name from Nominatim.
  final String? displayName;

  /// Returns `true` when this result is for a location in Uganda.
  bool get isUganda => country?.toLowerCase() == 'uganda';
}

/// Singleton service for device GPS and address geocoding.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Strips characters that may confuse Nominatim (e.g. special symbols) while
  /// preserving letters, digits, spaces, commas, hyphens, periods, and
  /// apostrophes (useful for place names such as "Côte d'Ivoire").
  static String sanitizeQuery(String query) {
    return query.replaceAll(RegExp(r"[^\w\s,.\-']"), ' ').trim();
  }

  /// Requests location permission (if needed) and returns the current device
  /// position. Caches the last known result.
  ///
  /// Returns `null` if permission is denied or if location services are off.
  Future<Position?> requestAndGetPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(accuracy: LocationAccuracy.medium)
            : const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 10),
              ),
      );
      _lastPosition = pos;
      return pos;
    } catch (_) {
      return null;
    }
  }

  /// Geocode a free-text address/city/query using Nominatim (OpenStreetMap).
  /// Returns `(lat, lon)` or `null` if nothing found.
  Future<(double, double)?> geocodeAddress(String query) async {
    final result = await geocodeAddressDetailed(query);
    if (result == null) return null;
    return (result.latitude, result.longitude);
  }

  /// Geocode a free-text address and return a full [GeocodeResult] (including
  /// country) or `null` when the place cannot be found.
  ///
  /// The query is sanitized before being sent to the API to increase match
  /// rates and reduce noise.
  Future<GeocodeResult?> geocodeAddressDetailed(String query) async {
    final sanitized = sanitizeQuery(query);
    if (sanitized.isEmpty) return null;
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': sanitized,
          'format': 'json',
          'limit': 1,
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'ort-marketplace/2.0'}),
      );
      final list = response.data as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;

      final address = first['address'] as Map<String, dynamic>?;
      final country = address?['country'] as String?;
      final displayName = first['display_name'] as String?;

      return GeocodeResult(
        latitude: lat,
        longitude: lon,
        country: country,
        displayName: displayName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocode a GPS coordinate to get country and display name.
  /// Uses Nominatim's /reverse endpoint for accurate results.
  Future<GeocodeResult?> reverseGeocodePosition(double lat, double lon) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'json',
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'ort-marketplace/2.0'}),
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) return null;
      final rLat = double.tryParse(data['lat']?.toString() ?? '');
      final rLon = double.tryParse(data['lon']?.toString() ?? '');
      if (rLat == null || rLon == null) return null;

      final address = data['address'] as Map<String, dynamic>?;
      final country = address?['country'] as String?;
      final displayName = data['display_name'] as String?;

      return GeocodeResult(
        latitude: rLat,
        longitude: rLon,
        country: country,
        displayName: displayName,
      );
    } catch (_) {
      return null;
    }
  }
}
