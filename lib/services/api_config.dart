import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Path prefix of the mobile JSON API, served by the C# web service
  /// (admin-web). The ONLY place it is defined; every service builds its paths
  /// with [path]. Override with --dart-define=API_PREFIX=...
  static const String prefix =
      String.fromEnvironment('API_PREFIX', defaultValue: '/api/m');

  /// Prefixes an endpoint suffix, e.g. path('/login') -> '/api/m/login'.
  static String path(String suffix) => '$prefix$suffix';

  /// Base URL of the C# web service (admin-web portal, port 8088).
  /// Override with --dart-define=API_BASE_URL=...
  /// Defaults: Android emulator -> 10.0.2.2 (host loopback); web/desktop -> localhost.
  /// Note: defaultTargetPlatform can report android in mobile browsers, so web
  /// always uses localhost. A web build served from another origin needs the
  /// server to allow CORS.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8088';
    }
    return 'http://localhost:8088';
  }
}
