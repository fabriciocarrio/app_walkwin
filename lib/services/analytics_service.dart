import 'package:flutter/foundation.dart';
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

    try {
      final config = PostHogConfig(AppConfig.posthogApiKey)
        ..host = AppConfig.posthogHost
        ..captureApplicationLifecycleEvents = true;

      await Posthog().setup(config);
      _initialized = true;
    } catch (e) {
      debugPrint('AnalyticsService init error: $e');
    }
  }

  // ── Screen tracking ──

  Future<void> trackScreen(String screenName) async {
    try {
      await _firebase.logScreenView(screenName: screenName);
      await Posthog().screen(screenName: screenName);
    } catch (e) {
      debugPrint('AnalyticsService trackScreen error: $e');
    }
  }

  // ── Event tracking ──

  Future<void> trackEvent(
    String name, {
    Map<String, Object>? properties,
  }) async {
    try {
      await _firebase.logEvent(
        name: name,
        parameters: properties,
      );
      await Posthog().capture(eventName: name, properties: properties);
    } catch (e) {
      debugPrint('AnalyticsService trackEvent error: $e');
    }
  }

  // ── User identification ──

  Future<void> identifyUser({
    required String userId,
    String? email,
    String? name,
    Map<String, Object>? properties,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('AnalyticsService identifyUser error: $e');
    }
  }

  Future<void> resetUser() async {
    try {
      await _firebase.setUserId(id: null);
      await Posthog().reset();
    } catch (e) {
      debugPrint('AnalyticsService resetUser error: $e');
    }
  }
}