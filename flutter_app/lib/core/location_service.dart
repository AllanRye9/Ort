import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

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
        locationSettings: const LocationSettings(
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
    if (query.trim().isEmpty) return null;
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 1,
        },
        options: Options(headers: {'User-Agent': 'ort-marketplace/2.0'}),
      );
      final list = response.data as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (_) {
      return null;
    }
  }
}
