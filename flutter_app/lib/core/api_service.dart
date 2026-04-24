import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
            // Clear stored credentials and signal the auth layer
            await _storage.deleteAll();
            onUnauthorized?.call();
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

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    return res.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> createProperty(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/properties/', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ─── Agriculture ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getAgricultureListings({
    int skip = 0,
    int limit = 20,
    String? category,
    String? status,
    int? tenantId,
  }) async {
    final res = await _dio.get('/agriculture/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (category != null) 'category': category,
      if (status != null) 'status': status,
      if (tenantId != null) 'tenant_id': tenantId,
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

  // ─── Manufacturing ────────────────────────────────────────────────────────

  Future<List<dynamic>> getManufacturingProducts({
    int skip = 0,
    int limit = 20,
    String? category,
    String? status,
    int? tenantId,
  }) async {
    final res = await _dio.get('/manufacturing/', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (category != null) 'category': category,
      if (status != null) 'status': status,
      if (tenantId != null) 'tenant_id': tenantId,
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

  Future<List<dynamic>> getReviews({int? tenantId, int? propertyId}) async {
    final res = await _dio.get('/reviews/', queryParameters: {
      if (tenantId != null) 'tenant_id': tenantId,
      if (propertyId != null) 'property_id': propertyId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createReview(Map<String, dynamic> data) async {
    final res = await _dio.post('/reviews/', data: data);
    return res.data as Map<String, dynamic>;
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

  // ─── Tenants ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getTenants({int skip = 0, int limit = 20}) async {
    final res = await _dio.get('/tenants/', queryParameters: {
      'skip': skip,
      'limit': limit,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> data) async {
    final res = await _dio.post('/tenants/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSubscriptionPlans() async {
    final res = await _dio.get('/subscription-plans/');
    return res.data as List<dynamic>;
  }
}
