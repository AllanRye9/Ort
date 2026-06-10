import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'constants.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((_) {
  // On web, flutter_secure_storage uses IndexedDB.  Providing explicit
  // WebOptions avoids naming collisions when multiple apps share the same
  // browser origin.
  if (kIsWeb) {
    return const FlutterSecureStorage(
      webOptions: WebOptions(dbName: 'ort_marketplace', publicKey: 'ort_key'),
    );
  }
  return const FlutterSecureStorage();
});

/// Called by the 401 interceptor to clear auth state without a hard import
/// cycle. Set once from auth_provider.dart after it initialises.
void Function()? onUnauthorized;

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.read(secureStorageProvider);
  return ApiService(storage);
});

class ApiService {
  ApiService(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.connectTimeout,
        headers: {
          'Accept': 'application/json',
          // Content-Type is set per-request where needed.
          // Setting it globally breaks multipart/form-data uploads because
          // the boundary parameter would be overwritten.
        },
        // followRedirects is unsupported on Flutter Web (XHR) – omit it to
        // avoid a runtime assertion on web builds.
        ...(kIsWeb ? {} : {'followRedirects': true, 'maxRedirects': 3}),
        // Tell Dio (and the underlying XHR on web) NOT to send cookies /
        // credentials.  withCredentials=false is required when the server
        // returns Access-Control-Allow-Origin: <specific-origin> without
        // Access-Control-Allow-Credentials: true.
        extra: {'withCredentials': false},
      ),
    );

    // Auth token + Content-Type injection
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inject Bearer token when available
          final token = await _storage.read(key: AppConstants.tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Set Content-Type to JSON for all requests that carry a body,
          // UNLESS the caller already set a content type (e.g. multipart).
          if (!options.headers.containsKey('Content-Type') &&
              options.data != null &&
              options.data is! FormData) {
            options.headers['Content-Type'] = 'application/json';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Only trigger logout when the failing request was authenticated
            // with a Bearer token. Unauthenticated endpoints returning 401
            // (e.g., wrong credentials on login) must not clear a valid session.
            final hadToken =
                error.requestOptions.headers['Authorization'] != null;
            if (hadToken) {
              await _storage.deleteAll();
              onUnauthorized?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Human-readable logging (debug builds only)
    assert(() {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          error: true,
          compact: true,
        ),
      );
      return true;
    }());

    // Retry once on connection error – handles Railway cold-start where the
    // first request races with the dyno waking up.
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    // The backend /auth/login accepts JSON: { "email": "...", "password": "..." }
    // We set Content-Type explicitly here to be safe on all platforms.
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(
        headers: {'Content-Type': 'application/json'},
        // Return the raw response so we can handle non-2xx ourselves.
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      final detail = (res.data is Map ? res.data['detail'] : null) ?? 'Invalid email or password';
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        message: detail.toString(),
      );
    }
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final res = await _dio.post('/users/', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// Unified registration endpoint – use this instead of [createUser] for all
  /// new account creation (agent, company, organisation).
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> data) async {
    final res = await _dio.post('/auth/register', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final res = await _dio.patch('/users/me', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteMe() async {
    await _dio.delete('/users/me');
  }

  /// Find an existing conversation between [initiatorId] and [recipientId]
  /// for the given [propertyId] (if provided), or create one.
  /// Returns the conversation ID.
  Future<int> findOrCreateConversation({
    required int initiatorId,
    required int recipientId,
    String? subject,
    int? propertyId,
  }) async {
    // Check existing conversations for this initiator
    final existing = await getConversations(initiatorId);
    for (final raw in existing) {
      final c = raw as Map<String, dynamic>;
      final cInitiator = c['initiator_id'] as int?;
      final cRecipient = c['recipient_id'] as int?;
      final cProperty = c['property_id'] as int?;
      if (cInitiator == initiatorId && cRecipient == recipientId) {
        if (propertyId == null || cProperty == propertyId) {
          return c['id'] as int;
        }
      }
    }
    // Not found – create a new one
    final created = await createConversation({
      'initiator_id': initiatorId,
      'recipient_id': recipientId,
      if (subject != null) 'subject': subject,
      if (propertyId != null) 'property_id': propertyId,
    });
    return created['id'] as int;
  }

  // ─── Properties ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getProperties({int skip = 0, int limit = 20}) async {
    final res = await _dio.get('/properties/', queryParameters: {
      'skip': skip,
      'limit': limit,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getProperty(int id) async {
    final res = await _dio.get('/properties/$id');
    return res.data as Map<String, dynamic>;
  }

  /// Returns a list of image URLs for a property by fetching its images.
  Future<List<String>> getPropertyImageUrls(int propertyId) async {
    try {
      final res = await _dio.get(
        '/property-images/',
        queryParameters: {'property_id': propertyId},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((e) => (e as Map<String, dynamic>)['image_url'] as String)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> createProperty(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/properties/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProperty(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/properties/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteProperty(int id) async {
    await _dio.delete('/properties/$id');
  }

  Future<Map<String, dynamic>> patchPropertyStatus(
      int id, String status) async {
    final res = await _dio.patch('/properties/$id/status',
        data: {'status': status});
    return res.data as Map<String, dynamic>;
  }

  Future<int> getPropertyBidCount(int id) async {
    final res = await _dio.get('/properties/$id/bid-count');
    final data = res.data as Map<String, dynamic>;
    return (data['bid_count'] as num).toInt();
  }

  Future<List<dynamic>> getMyProperties({int? agentId}) async {
    final res = await _dio.get('/properties/', queryParameters: {
      'limit': 200,
      if (agentId != null) 'agent_id': agentId,
    });
    return res.data as List<dynamic>;
  }

  // ─── Agriculture ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getAgricultureListings({
    int skip = 0,
    int limit = 20,
    String? category,
    String? status,
    int? tenantId,
    int? ownerUserId,
  }) async {
    final res = await _dio.get('/agriculture/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (category != null) 'category': category,
      if (status != null) 'status': status,
      if (tenantId != null) 'tenant_id': tenantId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAgricultureListing(int id) async {
    final res = await _dio.get('/agriculture/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAgricultureListing(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/agriculture/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAgricultureListing(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/agriculture/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteAgricultureListing(int id) async {
    await _dio.delete('/agriculture/$id');
  }

  Future<Map<String, dynamic>> patchAgriStatus(
      int id, String status) async {
    final res = await _dio.patch('/agriculture/$id/status',
        data: {'status': status});
    return res.data as Map<String, dynamic>;
  }

  // ─── Manufacturing ────────────────────────────────────────────────────────

  Future<List<dynamic>> getManufacturingProducts({
    int skip = 0,
    int limit = 20,
    String? category,
    String? status,
    int? tenantId,
    int? ownerUserId,
  }) async {
    final res = await _dio.get('/manufacturing/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (category != null) 'category': category,
      if (status != null) 'status': status,
      if (tenantId != null) 'tenant_id': tenantId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getManufacturingProduct(int id) async {
    final res = await _dio.get('/manufacturing/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createManufacturingProduct(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/manufacturing/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateManufacturingProduct(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/manufacturing/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteManufacturingProduct(int id) async {
    await _dio.delete('/manufacturing/$id');
  }

  Future<Map<String, dynamic>> patchMfgStatus(int id, String status) async {
    final res = await _dio.patch('/manufacturing/$id/status',
        data: {'status': status});
    return res.data as Map<String, dynamic>;
  }

  // ─── Services ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getServiceListings({
    int skip = 0,
    int limit = 50,
    String? keyword,
    String? category,
    String? serviceMode,
    String? status,
    String? country,
    String? city,
    double? minPrice,
    double? maxPrice,
    bool? isFlashDeal,
    bool? isTodayDeal,
    double? lat,
    double? lon,
    double? radiusKm,
    int? postedByUserId,
  }) async {
    final res = await _dio.get('/services/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (category != null && category.isNotEmpty) 'category': category,
      if (serviceMode != null) 'service_mode': serviceMode,
      if (status != null && status.isNotEmpty) 'status': status,
      if (country != null && country.isNotEmpty) 'country': country,
      if (city != null && city.isNotEmpty) 'city': city,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (isFlashDeal != null) 'is_flash_deal': isFlashDeal,
      if (isTodayDeal != null) 'is_today_deal': isTodayDeal,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (radiusKm != null) 'radius_km': radiusKm,
      if (postedByUserId != null) 'posted_by_user_id': postedByUserId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getServiceListing(int id) async {
    final res = await _dio.get('/services/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createServiceListing(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/services/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateServiceListing(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/services/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteServiceListing(int id) async {
    await _dio.delete('/services/$id');
  }

  // ─── Manufacturing Services ──────────────────────────────────────────────

  Future<List<dynamic>> getManufacturingServices({
    int skip = 0,
    int limit = 100,
    String? serviceType,
    String? status,
    int? tenantId,
    int? ownerUserId,
    String? keyword,
    double? minPrice,
    double? maxPrice,
    double? lat,
    double? lon,
    double? radiusKm,
    String? country,
    String? excludeCountry,
  }) async {
    final res = await _dio.get('/manufacturing/services/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (serviceType != null) 'service_type': serviceType,
      if (status != null) 'status': status,
      if (tenantId != null) 'tenant_id': tenantId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (keyword != null) 'keyword': keyword,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (radiusKm != null) 'radius_km': radiusKm,
      if (country != null) 'country': country,
      if (excludeCountry != null) 'exclude_country': excludeCountry,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getManufacturingService(int id) async {
    final res = await _dio.get('/manufacturing/services/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createManufacturingService(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/manufacturing/services/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteManufacturingService(int id) async {
    await _dio.delete('/manufacturing/services/$id');
  }

  Future<Map<String, dynamic>> patchMfgServiceStatus(
      int id, String status) async {
    final res = await _dio.patch('/manufacturing/services/$id/status',
        data: {'status': status});
    return res.data as Map<String, dynamic>;
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getOrders({
    int skip = 0,
    int limit = 20,
    int? buyerUserId,
    int? sellerTenantId,
    String? orderStatus,
  }) async {
    final res = await _dio.get('/orders/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (buyerUserId != null) 'buyer_user_id': buyerUserId,
      if (sellerTenantId != null) 'seller_tenant_id': sellerTenantId,
      if (orderStatus != null) 'order_status': orderStatus,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getOrder(int id) async {
    final res = await _dio.get('/orders/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    final res = await _dio.post('/orders/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOrder(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/orders/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── Conversations ────────────────────────────────────────────────────────

  Future<List<dynamic>> getConversations(int userId) async {
    final res = await _dio.get('/messages/conversations/',
        queryParameters: {'user_id': userId});
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createConversation(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/messages/conversations/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateConversationLocation({
    required int conversationId,
    required int actorId,
    String? location,
  }) async {
    final res = await _dio.patch(
      '/messages/conversations/$conversationId/location',
      data: {
        'actor_id': actorId,
        'location': location,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteConversation({
    required int conversationId,
    required int actorId,
  }) async {
    await _dio.delete(
      '/messages/conversations/$conversationId',
      data: {'actor_id': actorId},
    );
  }

  Future<List<dynamic>> getMessages(int conversationId) async {
    final res = await _dio
        .get('/messages/', queryParameters: {'conversation_id': conversationId});
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> data) async {
    final res = await _dio.post('/messages/', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── RFQ ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getRFQs({int? buyerId, int? sellerTenantId}) async {
    final res = await _dio.get('/rfq/', queryParameters: {
      if (buyerId != null) 'buyer_id': buyerId,
      if (sellerTenantId != null) 'seller_tenant_id': sellerTenantId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createRFQ(Map<String, dynamic> data) async {
    final res = await _dio.post('/rfq/', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── Reviews ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getReviews({
    int? reviewerId,
    int? tenantId,
    int? propertyId,
    int? agentId,
  }) async {
    final res = await _dio.get('/reviews/', queryParameters: {
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (propertyId != null) 'property_id': propertyId,
      if (agentId != null) 'agent_id': agentId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createReview(Map<String, dynamic> data) async {
    final res = await _dio.post('/reviews/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAgentReviews(int agentId) async {
    return getReviews(agentId: agentId);
  }

  Future<Map<String, dynamic>> createAgentReview({
    required int agentId,
    required int rating,
    String? title,
    String? body,
    int? reviewerId,
  }) async {
    return createReview({
      'reviewed_agent_id': agentId,
      'rating': rating,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (title != null && title.isNotEmpty) 'title': title,
      if (body != null && body.isNotEmpty) 'body': body,
    });
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Future<List<dynamic>> getNotifications(int userId,
      {bool unreadOnly = false}) async {
    final res = await _dio.get('/notifications/', queryParameters: {
      'user_id': userId,
      'unread_only': unreadOnly,
    });
    return res.data as List<dynamic>;
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _dio.put('/notifications/$notificationId', data: {'is_read': true});
  }

  Future<void> markAllNotificationsRead(int userId) async {
    await _dio.put('/notifications/read-all/', queryParameters: {'user_id': userId});
  }

  // ─── Tenants ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getTenants({int skip = 0, int limit = 20}) async {
    final res = await _dio.get('/tenants/', queryParameters: {
      'skip': skip,
      'limit': limit,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>?> getTenantByOwner(int ownerUserId) async {
    final res = await _dio.get('/tenants/', queryParameters: {
      'owner_user_id': ownerUserId,
      'limit': 1,
    });
    final list = res.data as List<dynamic>;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTenant(int tenantId) async {
    final res = await _dio.get('/tenants/$tenantId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> data) async {
    final res = await _dio.post('/tenants/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSubscriptionPlans() async {
    final res = await _dio.get('/subscription-plans/');
    return res.data as List<dynamic>;
  }

  // ─── User update ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateUser(
      int userId, Map<String, dynamic> data) async {
    final res = await _dio.put('/users/$userId', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── Image upload ─────────────────────────────────────────────────────────

  /// Upload multiple image files and return their public URLs.
  Future<List<String>> uploadMultipleImages(
      List<({List<int> bytes, String filename, String mimeType})> files) async {
    final formData = FormData.fromMap({
      'files': files
          .map(
            (f) => MultipartFile.fromBytes(
              f.bytes,
              filename: f.filename,
              contentType: MediaType.parse(f.mimeType),
            ),
          )
          .toList(),
    });
    final res = await _dio.post(
      '/upload/images',
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    final data = res.data as Map<String, dynamic>;
    return (data['urls'] as List<dynamic>).cast<String>();
  }

  /// Upload an image file and return its public URL.
  /// [bytes] – raw image bytes
  /// [filename] – original filename (e.g. "photo.jpg")
  /// [mimeType] – MIME type (e.g. "image/jpeg")
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    });
    final res = await _dio.post(
      '/upload/image',
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    final data = res.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  // ─── Saved items ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getSavedItems(int userId, {String? itemType}) async {
    final res = await _dio.get('/saved-items/', queryParameters: {
      'user_id': userId,
      if (itemType != null) 'item_type': itemType,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> saveItem({
    required int userId,
    required String itemType,
    required int itemId,
  }) async {
    final res = await _dio.post('/saved-items/', data: {
      'user_id': userId,
      'item_type': itemType,
      'item_id': itemId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> unsaveItem({
    required int userId,
    required String itemType,
    required int itemId,
  }) async {
    await _dio.delete('/saved-items/', queryParameters: {
      'user_id': userId,
      'item_type': itemType,
      'item_id': itemId,
    });
  }

  Future<bool> checkSaved({
    required int userId,
    required String itemType,
    required int itemId,
  }) async {
    final res = await _dio.get('/saved-items/check', queryParameters: {
      'user_id': userId,
      'item_type': itemType,
      'item_id': itemId,
    });
    return res.data as bool;
  }

  // ─── Image delete ─────────────────────────────────────────────────────────

  Future<void> deleteImage(String url) async {
    await _dio.delete('/upload/image', queryParameters: {'url': url});
  }

  // ─── Filtered listings ────────────────────────────────────────────────────

  Future<List<dynamic>> getPropertiesFiltered({
    int skip = 0,
    int limit = 50,
    String? keyword,
    double? minPrice,
    double? maxPrice,
    String? city,
    String? propertyType,
    String? status,
    int? agentId,
    String? country,
    String? excludeCountry,
    double? lat,
    double? lon,
    double? radiusKm,
  }) async {
    final res = await _dio.get('/properties/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (city != null && city.isNotEmpty) 'city': city,
      if (propertyType != null && propertyType.isNotEmpty) 'property_type': propertyType,
      if (status != null && status.isNotEmpty) 'status': status,
      if (agentId != null) 'agent_id': agentId,
      if (country != null && country.isNotEmpty) 'country': country,
      if (excludeCountry != null && excludeCountry.isNotEmpty) 'exclude_country': excludeCountry,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (radiusKm != null) 'radius_km': radiusKm,
    });
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getAgricultureFiltered({
    int skip = 0,
    int limit = 50,
    String? keyword,
    double? minPrice,
    double? maxPrice,
    String? category,
    String? location,
    String? status,
    String? country,
    String? excludeCountry,
    double? lat,
    double? lon,
    double? radiusKm,
  }) async {
    final res = await _dio.get('/agriculture/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (category != null && category.isNotEmpty) 'category': category,
      if (location != null && location.isNotEmpty) 'location': location,
      if (status != null && status.isNotEmpty) 'status': status,
      if (country != null && country.isNotEmpty) 'country': country,
      if (excludeCountry != null && excludeCountry.isNotEmpty) 'exclude_country': excludeCountry,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (radiusKm != null) 'radius_km': radiusKm,
    });
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getManufacturingFiltered({
    int skip = 0,
    int limit = 50,
    String? keyword,
    double? minPrice,
    double? maxPrice,
    String? category,
    String? location,
    String? status,
    String? country,
    String? excludeCountry,
    double? lat,
    double? lon,
    double? radiusKm,
  }) async {
    final res = await _dio.get('/manufacturing/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (category != null && category.isNotEmpty) 'category': category,
      if (location != null && location.isNotEmpty) 'location': location,
      if (status != null && status.isNotEmpty) 'status': status,
      if (country != null && country.isNotEmpty) 'country': country,
      if (excludeCountry != null && excludeCountry.isNotEmpty) 'exclude_country': excludeCountry,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (radiusKm != null) 'radius_km': radiusKm,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateReview(
      int reviewId, Map<String, dynamic> data) async {
    final res = await _dio.put('/reviews/$reviewId', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── Agent stats & clients ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAgentStats(int agentId) async {
    final res = await _dio.get('/agent/stats', queryParameters: {'agent_id': agentId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAgentClients(int agentId) async {
    final res = await _dio.get('/agent/clients', queryParameters: {'agent_id': agentId});
    return res.data as Map<String, dynamic>;
  }

  // ─── Messages: delete ─────────────────────────────────────────────────────

  Future<void> deleteMessage(int messageId, int senderId) async {
    await _dio.delete('/messages/$messageId', data: {'sender_id': senderId});
  }

  Future<int> bulkDeleteMessages({
    required int senderId,
    required List<int> messageIds,
  }) async {
    final res = await _dio.post(
      '/messages/bulk-delete',
      data: {
        'sender_id': senderId,
        'message_ids': messageIds,
      },
    );
    return (res.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> clearMessageBody(int messageId, int senderId) async {
    final res = await _dio.patch(
      '/messages/$messageId/body',
      data: {'sender_id': senderId},
    );
    return res.data as Map<String, dynamic>;
  }

  // ─── User lookup by UID ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserByUid(String uid) async {
    final res = await _dio.get('/users/by-uid/$uid');
    return res.data as Map<String, dynamic>;
  }

  // ─── Wallet ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyWallet({String currency = 'UGX'}) async {
    final res = await _dio.get(
      '/wallet/me',
      queryParameters: {'currency': currency},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> topupWallet({
    required int amount,
    required String paymentMethod,
    String currency = 'UGX',
    String? reference,
  }) async {
    final res = await _dio.post(
      '/wallet/topup',
      queryParameters: {'currency': currency},
      data: {
        'amount': amount,
        'payment_method': paymentMethod,
        if (reference != null) 'reference': reference,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getWalletTransactions({int skip = 0, int limit = 50}) async {
    final res = await _dio.get('/wallet/transactions', queryParameters: {
      'skip': skip,
      'limit': limit,
    });
    return res.data as List<dynamic>;
  }

  // ─── Ad Promotions ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createPromotion({
    required String listingType,
    required int listingId,
    required int durationDays,
  }) async {
    final res = await _dio.post('/promotions/', data: {
      'listing_type': listingType,
      'listing_id': listingId,
      'duration_days': durationDays,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyPromotions() async {
    final res = await _dio.get('/promotions/');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getActivePromotions({
    String? listingType,
    int? listingId,
  }) async {
    final res = await _dio.get('/promotions/active', queryParameters: {
      if (listingType != null) 'listing_type': listingType,
      if (listingId != null) 'listing_id': listingId,
    });
    return res.data as List<dynamic>;
  }

  // ─── File upload (attachments) ────────────────────────────────────────────

  /// Upload any file (image, PDF, doc, etc.) for use as a message attachment.
  /// Returns a record with 'url' and 'filename'.
  Future<Map<String, dynamic>> uploadFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    });
    final res = await _dio.post(
      '/upload/file',
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    return res.data as Map<String, dynamic>;
  }

  // ─── Property by tracking code ────────────────────────────────────────────

  Future<Map<String, dynamic>> getPropertyByCode(String code) async {
    final res = await _dio.get('/properties/by-code/$code');
    return res.data as Map<String, dynamic>;
  }

  // ─── User profile ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUser(int userId) async {
    final res = await _dio.get('/users/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lookupConversationRecipient(String query) async {
    final res = await _dio.get(
      '/users/lookup',
      queryParameters: {'q': query, 'role_scope': 'business'},
    );
    return res.data as Map<String, dynamic>;
  }

  // ─── Product Tracking ─────────────────────────────────────────────────────

  Future<List<dynamic>> getTrackingEvents({
    int? orderId,
    String? listingType,
    int? listingId,
  }) async {
    final res = await _dio.get('/tracking/', queryParameters: {
      if (orderId != null) 'order_id': orderId,
      if (listingType != null) 'listing_type': listingType,
      if (listingId != null) 'listing_id': listingId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTrackingEvent(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/tracking/', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── AI ───────────────────────────────────────────────────────────────────

  /// Ask the backend AI to generate a listing description.
  Future<String> generateAiDescription({
    required String listingType,
    required String title,
    String? category,
    String? location,
    String? extraContext,
  }) async {
    final res = await _dio.post('/ai/generate-description', data: {
      'listing_type': listingType,
      'title': title,
      if (category != null) 'category': category,
      if (location != null) 'location': location,
      if (extraContext != null) 'extra_context': extraContext,
    });
    return (res.data as Map<String, dynamic>)['description'] as String;
  }

  /// Send a chat message to the ORT AI support assistant.
  Future<String> aiChat(List<Map<String, String>> messages) async {
    final res = await _dio.post('/ai/chat', data: {
      'messages': messages,
    });
    return (res.data as Map<String, dynamic>)['reply'] as String;
  }

  // ─── Push notification device tokens ──────────────────────────────────────

  Future<void> registerDeviceToken({
    required int userId,
    required String token,
    String? platform,
  }) async {
    await _dio.post('/notifications/device-token', data: {
      'token': token,
      if (platform != null) 'platform': platform,
    });
  }

  Future<void> unregisterDeviceToken({
    required int userId,
    required String token,
  }) async {
    await _dio.delete('/notifications/device-token', queryParameters: {
      'token': token,
    });
  }
}

// ─── Retry interceptor ────────────────────────────────────────────────────────
/// Retries a request once after a short delay when a connection-level error
/// occurs.  This handles Railway cold-starts where the server may not be
/// immediately ready on the first attempt.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const int _maxRetries = 1;
  static const Duration _retryDelay = Duration(seconds: 3);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['_retryCount'] as int? ?? 0;

    final shouldRetry =
        retryCount < _maxRetries &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout);

    if (!shouldRetry) {
      return handler.next(err);
    }

    await Future<void>.delayed(_retryDelay);

    final opts = err.requestOptions;
    opts.extra['_retryCount'] = retryCount + 1;

    try {
      final response = await _dio.request<dynamic>(
        opts.path,
        data: opts.data,
        queryParameters: opts.queryParameters,
        options: Options(
          method: opts.method,
          headers: opts.headers,
          responseType: opts.responseType,
          contentType: opts.contentType,
          validateStatus: opts.validateStatus,
          extra: opts.extra,
        ),
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
