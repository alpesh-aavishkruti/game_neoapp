import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session lives between app launches.
///
/// Tokens go in the platform keychain / keystore rather than shared
/// preferences: this app opens a book of live money positions, and a token
/// lifted off a lost handset would open it for someone else.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Android encrypts by default from v11 on; on iOS, first_unlock
              // keeps a background refresh working after a reboot while still
              // keeping the token out of reach on a locked handset.
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kProfile = 'profile';

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
  }

  Future<Map<String, dynamic>?> readProfile() async {
    final raw = await _storage.read(key: _kProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(Map<String, dynamic>? profile) async {
    if (profile == null) {
      await _storage.delete(key: _kProfile);
      return;
    }
    await _storage.write(key: _kProfile, value: jsonEncode(profile));
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kProfile),
    ]);
  }
}
