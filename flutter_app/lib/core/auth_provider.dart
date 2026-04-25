import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'constants.dart';

// ─── Auth state ───────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.token,
    this.userId,
    this.role,
    this.isLoading = false,
    this.error,
  });

  final String? token;
  final int? userId;
  final String? role;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    String? token,
    int? userId,
    String? role,
    bool? isLoading,
    String? error,
    bool clearToken = false,
    bool clearError = false,
  }) =>
      AuthState(
        token: clearToken ? null : token ?? this.token,
        userId: clearToken ? null : userId ?? this.userId,
        role: clearToken ? null : role ?? this.role,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    // Wire up the 401 interceptor callback to force logout.
    onUnauthorized = _handleUnauthorized;
    _loadToken();
  }

  final ApiService _api;
  final FlutterSecureStorage _storage;

  Future<void> _loadToken() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    final userIdStr = await _storage.read(key: AppConstants.userIdKey);
    final role = await _storage.read(key: AppConstants.roleKey);
    if (token != null) {
      state = state.copyWith(
        token: token,
        userId: userIdStr != null ? int.tryParse(userIdStr) : null,
        role: role,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.login(email, password);

      final token = data['access_token'] as String;

      // The backend may return user_id directly in the login response or
      // nested inside a "user" object – handle both shapes gracefully.
      final dynamic rawUserId =
          data['user_id'] ?? (data['user'] as Map<String, dynamic>?)?['id'];
      final int? userId =
          rawUserId != null ? int.tryParse(rawUserId.toString()) : null;

      final String? role = data['role'] as String?;

      await _storage.write(key: AppConstants.tokenKey, value: token);
      if (userId != null) {
        await _storage.write(
            key: AppConstants.userIdKey, value: userId.toString());
      }
      if (role != null) {
        await _storage.write(key: AppConstants.roleKey, value: role);
      }

      state =
          state.copyWith(token: token, userId: userId, role: role, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.registerUser(userData);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }

  void _handleUnauthorized() {
    // Called by the Dio 401 interceptor. Clear state without touching storage
    // again (already cleared in the interceptor).
    if (state.isAuthenticated) {
      state = const AuthState();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        // FastAPI-style: {"detail": "..."} or {"detail": [{"msg": "..."}]}
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) return first['msg']?.toString() ?? detail.toString();
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your network and try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Unable to reach the server. Check your network connection.';
      }
      return e.message ?? 'An unexpected error occurred.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.read(apiServiceProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthNotifier(api, storage);
});
