class AppConfig {
  const AppConfig._();

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://walkwin.site/api/v1',
  );

  static const String wsAppKey = String.fromEnvironment(
    'WS_APP_KEY',
    defaultValue: '',
  );

  static const String wsCluster = String.fromEnvironment(
    'WS_CLUSTER',
    defaultValue: 'mt1',
  );

  static const String wsHost = String.fromEnvironment(
    'WS_HOST',
    defaultValue: '',
  );

  static const int wsPort = int.fromEnvironment('WS_PORT', defaultValue: 443);

  static const String wsScheme = String.fromEnvironment(
    'WS_SCHEME',
    defaultValue: 'https',
  );

  static const bool wsEnable = bool.fromEnvironment(
    'WS_ENABLE',
    defaultValue: true,
  );

  // PostHog
  static const String posthogApiKey = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: '',
  );

  static const String posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.posthog.com',
  );

  /// Converts a relative path (e.g. /storage/...) into a full URL using apiBaseUrl.
  static String? resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    if (trimmed.startsWith('/')) {
      return '$base$trimmed';
    }
    return '$base/$trimmed';
  }
}
