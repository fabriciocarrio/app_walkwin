import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import 'api_service.dart';
import 'notification_service.dart';

class WebSocketService {
  WebSocketService._();

  static final WebSocketService instance = WebSocketService._();

  static const String _appKey = 'kam8y8xinq3y49wxdleb';

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  bool _initialized = false;
  String? _userChannel;

  Future<void> initForAuthenticatedUser() async {
    if (_initialized) return;

    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('WebSocket skipped: no auth token');
        return;
      }

      final me = await ApiService.getCurrentUser();
      final userId = me['id']?.toString();
      if (userId == null || userId.isEmpty) {
        debugPrint('WebSocket skipped: unable to resolve user id');
        return;
      }

      _userChannel = 'user.$userId';

      await _pusher.init(
        apiKey: _appKey,
        cluster: 'mt1',
        onConnectionStateChange: (currentState, previousState) {
          debugPrint('WS state: $previousState -> $currentState');
        },
        onError: (message, code, error) {
          debugPrint('WS error: $message (code: $code)');
        },
        onSubscriptionSucceeded: (channelName, data) {
          debugPrint('WS subscribed: $channelName');
        },
        onSubscriptionError: (message, error) {
          debugPrint('WS subscription error: $message');
        },
        onEvent: _onEvent,
      );

      await _pusher.connect();

      await _pusher.subscribe(channelName: _userChannel!);
      await _pusher.subscribe(channelName: 'exploration');
      await _pusher.subscribe(channelName: 'missions');

      _initialized = true;
      debugPrint('WebSocket initialized for user $userId');
    } catch (e) {
      debugPrint('WebSocket init failed: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (_userChannel != null) {
        await _pusher.unsubscribe(channelName: _userChannel!);
      }
      await _pusher.unsubscribe(channelName: 'exploration');
      await _pusher.unsubscribe(channelName: 'missions');
      await _pusher.disconnect();
    } catch (_) {
      // Ignore disconnect failures.
    } finally {
      _initialized = false;
      _userChannel = null;
    }
  }

  // All events from all subscribed channels pass through this global handler.
  Future<void> _onEvent(PusherEvent event) async {
    final channelName = event.channelName;
    final eventName = event.eventName;

    if (channelName.isEmpty || eventName.isEmpty) return;

    final payload = _decodePayload(event.data);

    switch (eventName) {
      case 'achievement_unlocked':
        await NotificationService.showLocal(
          title: 'Logro desbloqueado',
          body: payload['achievement_name']?.toString() ?? 'Nuevo logro',
        );
        break;
      case 'rank_changed':
        final newRank = payload['new_rank']?.toString() ?? '?';
        await NotificationService.showLocal(
          title: 'Tu ranking cambio',
          body: 'Nuevo puesto: $newRank',
        );
        break;
      case 'collectible_spawned':
        await NotificationService.showLocal(
          title: 'Nuevo coleccionable',
          body:
              payload['collectible_name']?.toString() ??
              'Aparecio un nuevo item',
        );
        break;
      case 'new_mission_available':
        await NotificationService.showLocal(
          title: 'Nueva mision disponible',
          body:
              payload['mission_title']?.toString() ?? 'Revisa las misiones',
        );
        break;
      default:
        debugPrint('WS unhandled event: $channelName / $eventName');
    }
  }

  Map<String, dynamic> _decodePayload(dynamic rawData) {
    try {
      if (rawData is Map<String, dynamic>) return rawData;
      if (rawData is String && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {
      // Ignore malformed payloads.
    }

    return <String, dynamic>{};
  }
}
