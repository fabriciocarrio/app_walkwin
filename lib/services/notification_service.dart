import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_store.dart';

/// Maneja notificaciones locales (sin Firebase — agregar google-services.json para FCM).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'walkwin_main';
  static const _channelName = 'WalkWin';
  static const _persistentChannelId = 'walkwin_lockscreen';
  static const _persistentChannelName = 'WalkWin';
  static const _persistentNotificationId = 1;

  static String _formatInt(int value) {
    final raw = value.toString();
    return raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    // Canal para notificación persistente visible en lock screen
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _persistentChannelId,
            _persistentChannelName,
            importance: Importance.high,
          ),
        );
  }

  /// Muestra una notificación local (ej: logro de racha)
  /// y la guarda en el historial local de la app.
  static Future<void> showLocal({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );

    if (NotificationStore.instance.initialized) {
      NotificationStore.instance.add(
        NotificationItem(title: title, body: body, type: type),
      );
    }
  }

  /// Muestra/actualiza una notificación persistente con progreso de pasos
  /// Visible tanto en la barra de notificaciones como en la pantalla de bloqueo
  static Future<void> showProgressNotification({
    required int steps,
    required int coins,
    required int dailyGoal,
  }) async {
    final safeGoal = dailyGoal <= 0 ? 1 : dailyGoal;
    final stepsLeft = safeGoal - steps;
    final reachedGoal = steps >= dailyGoal;
    final clampedSteps = steps.clamp(0, safeGoal);
    final progressPct = ((clampedSteps / safeGoal) * 100).round();

    final titleText = '${_formatInt(steps)} pasos hoy';

    final statusText = reachedGoal
        ? 'Meta alcanzada ✓'
        : 'Faltan ${_formatInt(stepsLeft.clamp(0, 999999))} pasos';

    final coinsText = coins > 0 ? '${_formatInt(coins)} PE | ' : '';

    final bodyText = reachedGoal
      ? '✓ Meta alcanzada | $coinsText${_formatInt(safeGoal)} / ${_formatInt(safeGoal)} pasos'
      : '$progressPct% de tu meta | $coinsText${_formatInt(clampedSteps)} / ${_formatInt(safeGoal)} pasos';

    final expandedText = reachedGoal
      ? '✓ Completaste tu meta diaria de ${_formatInt(safeGoal)} pasos.${coins > 0 ? ' ${_formatInt(coins)} PE acumulados.' : ''}'
      : 'Llevas ${_formatInt(clampedSteps)} de ${_formatInt(safeGoal)} pasos. $statusText.${coins > 0 ? " PE acumulados: ${_formatInt(coins)}." : ""}';

    await _plugin.show(
      _persistentNotificationId,
      titleText,
      bodyText,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _persistentChannelId,
          _persistentChannelName,
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.progress,
          showProgress: true,
          maxProgress: safeGoal,
          progress: clampedSteps,
          subText: 'WalkWin',
          styleInformation: BigTextStyleInformation(
            expandedText,
            contentTitle: titleText,
            summaryText: statusText,
            htmlFormatContentTitle: false,
            htmlFormatSummaryText: false,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  /// Cancela la notificación persistente de progreso
  static Future<void> cancelProgressNotification() async {
    await _plugin.cancel(_persistentNotificationId);
  }
}
