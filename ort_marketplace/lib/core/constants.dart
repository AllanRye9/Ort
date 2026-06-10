class AppConstants {
  AppConstants._();

  // ── API base URL ───────────────────────────────────────────────────────────
  // Override at build time with:
  //   flutter build apk --dart-define=API_BASE_URL=https://piitrade.com/api/v1
  //   flutter build web --dart-define=API_BASE_URL=https://piitrade.com/api/v1
  //
  // The default points to the live production server so debug builds work
  // without any extra configuration.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://piitrade.com/api/v1',
  );

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String roleKey = 'user_role';
  static const String tenantIdKey = 'tenant_id';

  // Pagination
  static const int defaultPageSize = 20;

  // Timeouts – generous for Railway cold-start (free tier can take ~10 s)
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Image upload
  static const int maxImageSizeMb = 10;
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
}
