import 'package:dio/dio.dart';

String friendlyErrorMessage([Object? error]) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
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
