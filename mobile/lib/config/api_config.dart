import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Central API configuration.
///
/// **One backend, one online database for web + mobile:**
/// - Web (`frontend/.env` → `VITE_API_URL`): `http://127.0.0.1:5050/api`
/// - Mobile (this file):                 `http://127.0.0.1:5050/api`
/// - Backend (`backend/.env` → `PORT`):   `5050`
/// - Database (`backend/.env` → `MONGO_URI`): existing Atlas `vitalguide`
///
/// The mobile app does **not** open its own database. All reads/writes go
/// through the existing Express API, which is the same API used by the web app.
///
/// Override only when testing on a physical device / LAN:
///   flutter run --dart-define=API_HOST=192.168.1.10 --dart-define=API_PORT=5050
class ApiConfig {
  static const String _hostOverride = String.fromEnvironment('API_HOST');
  static const String _portOverride = String.fromEnvironment('API_PORT');

  /// Must match backend `PORT` and web `VITE_API_URL` port.
  static const int defaultPort = 5050;

  static int get port {
    if (_portOverride.isNotEmpty) {
      return int.tryParse(_portOverride) ?? defaultPort;
    }
    return defaultPort;
  }

  static String get host {
    if (_hostOverride.isNotEmpty) return _hostOverride;

    // Same machine as the Express API + MongoDB (shared with the web admin).
    if (kIsWeb) return '127.0.0.1';
    // Android emulator loopback → host machine localhost
    if (Platform.isAndroid) return '10.0.2.2';
    // iOS simulator / desktop → host localhost
    return '127.0.0.1';
  }

  /// Same base path as web: `http://<host>:5050/api`
  static String get baseUrl => 'http://$host:$port/api';

  static String get healthUrl => 'http://$host:$port/api/health';

  /// Socket origin without `/api` — matches web `VITE_SOCKET_URL`.
  static String get socketUrl => 'http://$host:$port';
}
