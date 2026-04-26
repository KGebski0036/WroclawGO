class AppConfig {
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://35.158.243.188',
  );

  static String get apiUrl => '$backendBaseUrl/api';
}
