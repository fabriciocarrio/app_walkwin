import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../config/app_config.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  static final FirebaseAnalytics _firebase = FirebaseAnalytics.instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final config = PostHogConfig(AppConfig.posthogApiKey)
      ..host = AppConfig.posthogHost
      ..captureApplicationLifecycleEvents = true;

    await Posthog().setup(config);

    _initialized = true;
  }

  // ── Screen tracking ──

  Future<void> trackScreen(String screenName) async {
    await _firebase.logScreenView(screenName: screenName);
    await Posthog().screen(
      screenName: screenName,
    );
  }

  // ── Event tracking ──

  Future<void> trackEvent(
    String name, {
    Map<String, Object>? properties,
  }) async {
    await _firebase.logEvent(
      name: name,
      parameters: properties,
    );
    await Posthog().capture(eventName: name, properties: properties);
  }

  // ── User identification ──

  Future<void> identifyUser({
    required String userId,
    String? email,
    String? name,
    Map<String, Object>? properties,
  }) async {
    await _firebase.setUserId(id: userId);
    if (email != null) {
      await _firebase.setUserProperty(name: 'email', value: email);
    }

    final allProperties = <String, Object>{
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (properties != null) ...properties,
    };

    await Posthog().identify(
      userId: userId,
      userProperties: allProperties,
    );
  }

  Future<void> resetUser() async {
    await _firebase.setUserId(id: null);
    await Posthog().reset();
  }
}