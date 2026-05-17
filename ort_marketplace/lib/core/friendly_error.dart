import 'package:dio/dio.dart';

/// Extracts a user-friendly error message from various exception types.
/// Handles structured API error responses from the backend.
String friendlyErrorMessage([Object? error]) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      // Handle structured API error format: {detail, error_code, status_code, ...}
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      
      // Fallback to legacy formats
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    
    // Handle HTTP status-based messages
    switch (error.response?.statusCode) {
      case 400:
        return 'Invalid request. Please check your input and try again.';
      case 401:
        return 'Please sign in to continue.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'This item already exists or there is a conflict.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
      case 503:
        return 'Server error. Please try again later.';
      case null:
        return 'Network error. Please check your connection and try again.';
    }
  }
  
  if (error is Exception) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isNotEmpty) return text;
  }
  
  return 'Something went wrong. Please check your connection and try again.';
}

const String kOfflineDataNotice =
    'You are offline. Showing the latest cached data.';
