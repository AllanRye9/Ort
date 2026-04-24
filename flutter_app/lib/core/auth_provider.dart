import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'constants.dart';

// Auth state
class AuthState {
  const AuthState({
    this.token,
    this.userId,
    this.isLoading = false,
    this.error,
  });

  final String? token;
  final int? userId;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    String? token,
    int? userId,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        token: token ?? this.token,
        userId: userId ?? this.userId,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _loadToken();
  }

  final ApiService _api;
  final FlutterSecureStorage _storage;

  Future<void> _loadToken() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    final userIdStr = await _storage.read(key: AppConstants.userIdKey);
    if (token != null) {
      state = state.copyWith(
        token: token,
        userId: userIdStr != null ? int.tryParse(userIdStr) : null,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.login(email, password);
      final token = data['access_token'] as String;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      state = state.copyWith(token: token, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.createUser(userData);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }

  String _extractError(Object e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return 'An unexpected error occurred';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.read(apiServiceProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthNotifier(api, storage);
});
