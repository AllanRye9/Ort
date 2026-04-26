import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';

/// WebSocket service for real-time chat and notifications.
class WebSocketService {
  WebSocketService(this._baseWsUrl);

  final String _baseWsUrl;
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;

  Stream<Map<String, dynamic>>? get stream => _controller?.stream;

  void connectToRoom(String roomId) {
    _disconnect();
    _controller = StreamController<Map<String, dynamic>>.broadcast();
    try {
      final uri = Uri.parse('$_baseWsUrl/ws/chat/$roomId');
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _controller?.add(msg);
          } catch (e) {
            debugPrint('WS message decode error: $e');
          }
        },
        onDone: () => _controller?.close(),
        onError: (e) => debugPrint('WS error: $e'),
      );
    } catch (e) {
      debugPrint('WS connect error: $e');
    }
  }

  void connectToNotifications(int userId) {
    _disconnect();
    _controller = StreamController<Map<String, dynamic>>.broadcast();
    try {
      final uri = Uri.parse('$_baseWsUrl/ws/notifications/$userId');
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _controller?.add(msg);
          } catch (e) {
            debugPrint('WS message decode error: $e');
          }
        },
        onDone: () => _controller?.close(),
        onError: (e) => debugPrint('WS error: $e'),
      );
    } catch (e) {
      debugPrint('WS connect error: $e');
    }
  }

  void send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }

  void dispose() => _disconnect();
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  // Convert HTTP(S) base URL to WS(S)
  final wsBase = AppConstants.baseUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://')
      .replaceFirst('/api/v1', '');
  final service = WebSocketService(wsBase);
  ref.onDispose(service.dispose);
  return service;
});
