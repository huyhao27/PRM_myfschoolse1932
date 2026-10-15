import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the backend. Override with --dart-define=API_BASE_URL=...
  /// Defaults: Android emulator -> 10.0.2.2 (host loopback); web/others -> localhost.
  /// Note: on web (kIsWeb) the backend must allow CORS; defaultTargetPlatform
  /// can report android in mobile browsers, so web always uses localhost.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
