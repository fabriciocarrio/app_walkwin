import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';
import '../config/app_config.dart';
import 'notification_service.dart';
import 'notification_store.dart';

class WebSocketService {
  WebSocketService._();

  static final WebSocketService instance = WebSocketService._();

  static String get _appKey => AppConfig.wsAppKey;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSubscription;

  bool _initialized = false;
  bool _connecting = false;
  String? _userChannel;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  Future<void> initForAuthenticatedUser() async {
    if (_initialized || _connecting) return;
    if (!AppConfig.wsEnable) {
      debugPrint('WebSocket disabled for environment ${AppConfig.environment}');
      return;
    }
    if (_appKey.isEmpty) {
      debugPrint('WebSocket skipped: WS_APP_KEY is empty');
      return;
    }

    _connecting = true;

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

      final uri = _buildSocketUri();
      debugPrint('WS connecting to: $uri');

      _socket = WebSocketChannel.connect(uri);
      _socketSubscription = _socket!.stream.listen(
        _onRawMessage,
        onError: (error) {
          debugPrint('WS stream error: $error');
          _initialized = false;
        },
        onDone: () {
          debugPrint('WS stream closed');
          _initialized = false;
        },
      );

      // Mark as initialized after opening the stream. Channel subscriptions
      // happen when the server confirms `pusher:connection_established`.
      _initialized = true;
      debugPrint('WebSocket stream initialized for user $userId');
    } catch (e) {
      debugPrint('WebSocket init failed: $e');
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    try {
      _socketSubscription?.cancel();
      _socketSubscription = null;
      await _socket?.sink.close();
      _socket = null;
    } catch (_) {
      // Ignore disconnect failures.
    } finally {
      _initialized = false;
      _connecting = false;
      _userChannel = null;
    }
  }

  Uri _buildSocketUri() {
    final apiUri = Uri.parse(AppConfig.apiBaseUrl);
    final host = AppConfig.wsHost.isNotEmpty ? AppConfig.wsHost : apiUri.host;

    final configuredScheme = AppConfig.wsScheme.toLowerCase();
    final wsScheme = configuredScheme == 'http'
        ? 'ws'
        : configuredScheme == 'https'
            ? 'wss'
            : configuredScheme;

    final port = AppConfig.wsPort > 0
        ? AppConfig.wsPort
        : (wsScheme == 'wss' ? 443 : 80);

    return Uri(
      scheme: wsScheme,
      host: host,
      port: port,
      path: '/app/$_appKey',
      queryParameters: const {
        'protocol': '7',
        'client': 'walkwin-mobile',
        'version': '1.0.0',
        'flash': 'false',
      },
    );
  }

  void _onRawMessage(dynamic rawMessage) {
    try {
      final envelope = _decodeEnvelope(rawMessage);
      final eventName = envelope['event']?.toString() ?? '';
      if (eventName.isEmpty) return;

      if (eventName == 'pusher:connection_established') {
        _subscribeToRequiredChannels();
        return;
      }

      if (eventName == 'pusher:ping') {
        _socket?.sink.add(jsonEncode({
          'event': 'pusher:pong',
          'data': <String, dynamic>{},
        }));
        return;
      }

      if (eventName.startsWith('pusher:')) {
        if (eventName == 'pusher:error') {
          debugPrint('WS pusher error payload: ${envelope['data']}');
        }
        return;
      }

      _onEvent(
        eventName: eventName,
        payload: _decodePayload(envelope['data']),
      );
    } catch (e) {
      debugPrint('WS message parse failed: $e');
    }
  }

  Map<String, dynamic> _decodeEnvelope(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }

    if (rawData is String && rawData.isNotEmpty) {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }

    return <String, dynamic>{};
  }

  void _subscribeToRequiredChannels() {
    final channels = <String>[
      if (_userChannel != null) _userChannel!,
      'exploration',
      'missions',
    ];

    for (final channel in channels) {
      _socket?.sink.add(
        jsonEncode({
          'event': 'pusher:subscribe',
          'data': <String, dynamic>{
            'channel': channel,
          },
        }),
      );
      debugPrint('WS subscribe sent: $channel');
    }
  }

  // All events from all subscribed channels pass through this global handler.
  Future<void> _onEvent({
    required String eventName,
    required Map<String, dynamic> payload,
  }) async {

    _eventController.add({'event': eventName, 'payload': payload});

    String type;
    String title;
    String body;

    switch (eventName) {
      case 'achievement_unlocked':
        type = 'achievement';
        title = 'Logro desbloqueado';
        body = payload['achievement_name']?.toString() ?? 'Nuevo logro';
        break;
      case 'rank_changed':
        type = 'rank';
        final newRank = payload['new_rank']?.toString() ?? '?';
        title = 'Tu ranking cambio';
        body = 'Nuevo puesto: $newRank';
        break;
      case 'collectible_spawned':
        type = 'collectible';
        title = 'Nuevo coleccionable';
        body = payload['collectible_name']?.toString() ?? 'Aparecio un nuevo item';
        break;
      case 'new_mission_available':
        type = 'mission';
        title = 'Nueva mision disponible';
        body = payload['mission_title']?.toString() ?? 'Revisa las misiones';
        break;
      default:
        debugPrint('WS unhandled event: $eventName');
        return;
    }

    await NotificationService.showLocal(title: title, body: body, type: type);
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
