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
}
