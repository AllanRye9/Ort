/// Push notification service using Firebase Cloud Messaging (FCM).
///
/// ## Setup required
/// Before push notifications work you must add your Firebase config files:
///   - `android/app/google-services.json`  (Android)
///   - `ios/Runner/GoogleService-Info.plist`  (iOS)
///
/// Generate these in the Firebase console → Project settings → Your apps.
///
/// Usage:
///   Call [PushNotificationService.init] once during app startup (after
///   Firebase.initializeApp). The service will:
///     1. Request notification permissions (iOS / Android 13+).
///     2. Obtain the FCM token and register it with the Ort backend.
///     3. Listen for foreground messages and show a local snack-bar.
library;

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_provider.dart';

/// Background message handler – must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the OS notification tray.
  // Add any background processing logic here if needed.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;

  /// Callback invoked when a foreground notification arrives.
  /// The caller (e.g. main screen) can attach a SnackBar presenter here.
  static void Function(RemoteMessage)? onForegroundMessage;

  /// Initialise FCM, request permissions, and register the device token.
  ///
  /// [userId] is required to associate the token with the correct account.
  /// [apiService] is used to POST the token to the backend.
  static Future<void> init({
    required int userId,
    required ApiService apiService,
  }) async {
    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission (iOS + Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Push notification permission denied');
        return;
      }

      // Obtain and register the FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(userId: userId, token: token, apiService: apiService);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        await _registerToken(userId: userId, token: newToken, apiService: apiService);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[FCM] Foreground message: ${message.notification?.title}');
        onForegroundMessage?.call(message);
      });

      // Configure iOS foreground presentation
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('[FCM] Push notification service initialised');
    } catch (e) {
      // Firebase not configured (missing google-services.json / GoogleService-Info.plist)
      debugPrint('[FCM] Push notifications unavailable: $e');
    }
  }

  static Future<void> _registerToken({
    required int userId,
    required String token,
    required ApiService apiService,
  }) async {
    try {
      final platform = kIsWeb
          ? 'web'
          : Platform.isAndroid
              ? 'android'
              : Platform.isIOS
                  ? 'ios'
                  : 'unknown';
      await apiService.registerDeviceToken(
        userId: userId,
        token: token,
        platform: platform,
      );
      debugPrint('[FCM] Device token registered');
    } catch (e) {
      debugPrint('[FCM] Failed to register device token: $e');
    }
  }

  /// Unregister the device token (call on logout).
  static Future<void> unregister({
    required int userId,
    required ApiService apiService,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await apiService.unregisterDeviceToken(userId: userId, token: token);
        await _messaging.deleteToken();
      }
    } catch (e) {
      debugPrint('[FCM] Failed to unregister device token: $e');
    }
  }
}
