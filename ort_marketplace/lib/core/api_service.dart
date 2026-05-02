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
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Explicitly follow redirects so that Railway's HTTPS redirect does
        // not break CORS preflight requests.
        followRedirects: true,
        maxRedirects: 3,
      ),
    );

    // Auth token injection
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
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

  Future<List<dynamic>> getReviews({int? tenantId, int? propertyId, int? agentId}) async {
    final res = await _dio.get('/reviews/', queryParameters: {
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
}
