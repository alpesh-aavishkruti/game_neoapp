import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Nothing here is hardcoded to a machine: every value comes from
/// `--dart-define`, so the same binary can point at dev, staging or production.
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
class AppConfig {
  const AppConfig._();

  static const String _envUrl = String.fromEnvironment('API_BASE_URL');

  /// Origin of the Django backend, with no trailing slash and no path.
  static String get apiBaseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    // A release build goes to people's phones, where the dev addresses below
    // lead nowhere. The API is on api.neonacc.com (neonacc.com is only the web
    // desk's pages and turns every POST away), as the web desk's own
    // VITE_APP_API_URL says. Only debug and profile builds fall back below.
    if (kReleaseMode) return 'https://api.neonacc.com';
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  /// Versioned prefix. The backend keeps the unversioned `/api/` alive for the
  /// web app, but the phone app pins a version so a later response-shape change
  /// cannot break copies of the app already installed on people's phones.
  static const String apiPrefix = String.fromEnvironment(
    'API_PREFIX',
    defaultValue: '/api/v1',
  );

  static String get apiRoot => '$apiBaseUrl$apiPrefix';

  /// Where the web desk lives - the read-only statement links a party is
  /// sent point there, since the party opens them in a browser.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://neonacc.com',
  );

  /// A party's own read-only statement, as the web desk shares it. The token
  /// is random, so one party's link says nothing about another's.
  static String partyStatementLink(String token) =>
      '$webBaseUrl/#/statement/${Uri.encodeComponent(token)}';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
