class AppConfig {
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://51.102.206.161',
  );

  static String get apiUrl => '$backendBaseUrl/api';

  static String get staticBaseUrl => '$backendBaseUrl/static/';

  static String staticUrlForPath(String path) {
    final trimmedPath = path.trim();

    if (trimmedPath.startsWith('http://') ||
        trimmedPath.startsWith('https://')) {
      final absolute = Uri.tryParse(trimmedPath);
      return absolute?.toString() ?? trimmedPath;
    }

    final normalizedPath = trimmedPath.startsWith('/')
        ? trimmedPath.substring(1)
        : trimmedPath;

    final encodedPath = normalizedPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');

    return '$staticBaseUrl$encodedPath';
  }
}
