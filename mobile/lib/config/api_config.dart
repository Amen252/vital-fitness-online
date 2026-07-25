import 'package:flutter/foundation.dart' show kIsWeb;

/// Central API configuration.
///
/// The mobile app talks to the deployed Express API (same backend + MongoDB
/// Atlas database used by the web app). By default it points at the production
/// Render deployment, so a plain `flutter build apk` produces a working APK.
///
/// Overrides (all optional):
///   flutter build apk --dart-define=API_URL=https://my-api.onrender.com/api
/// or piece-by-piece for local/LAN testing:
///   flutter run --dart-define=API_HOST=192.168.1.10 --dart-define=API_PORT=5050
///   flutter run --dart-define=API_HOST=10.0.2.2 --dart-define=API_PORT=5050
class ApiConfig {
  /// Full base URL override, e.g. `https://host/api`. Wins over everything else.
  static const String _urlOverride = String.fromEnvironment('API_URL');
  static const String _hostOverride = String.fromEnvironment('API_HOST');
  static const String _portOverride = String.fromEnvironment('API_PORT');
  static const String _schemeOverride = String.fromEnvironment('API_SCHEME');

  /// Production API (Render). Used when no overrides are provided.
  static const String _prodHost = 'vital-online-app-1.onrender.com';

  static const int defaultPort = 5050;

  static bool get _hasUrlOverride => _urlOverride.isNotEmpty;
  static bool get _hasHostOverride => _hostOverride.isNotEmpty;

  static int get port {
    if (_portOverride.isNotEmpty) {
      return int.tryParse(_portOverride) ?? defaultPort;
    }
    return defaultPort;
  }

  static String get host {
    if (_hasHostOverride) return _hostOverride;

    // No override → use the deployed production API for real devices/builds.
    if (kIsWeb) return _prodHost;
    return _prodHost;
  }

  /// http vs https. Explicit override wins; otherwise 443 ⇒ https.
  static String get scheme {
    if (_schemeOverride.isNotEmpty) return _schemeOverride;
    if (_hasHostOverride) {
      return port == 443 ? 'https' : 'http';
    }
    // Production Render host is always HTTPS.
    return 'https';
  }

  /// True when the effective host:port needs an explicit port in the URL.
  static bool get _includePort {
    if (_hasHostOverride) {
      return !(port == 443 || port == 80);
    }
    return false; // production https on 443
  }

  static String get _authority => _includePort ? '$host:$port' : host;

  /// Base API URL, e.g. `https://host/api` or `http://10.0.2.2:5050/api`.
  static String get baseUrl {
    if (_hasUrlOverride) {
      return _urlOverride.replaceAll(RegExp(r'/+$'), '');
    }
    return '$scheme://$_authority/api';
  }

  static String get healthUrl => '$baseUrl/health';

  /// Socket origin without the `/api` suffix.
  static String get socketUrl {
    if (_hasUrlOverride) {
      return baseUrl.replaceAll(RegExp(r'/api$'), '');
    }
    return '$scheme://$_authority';
  }
}
