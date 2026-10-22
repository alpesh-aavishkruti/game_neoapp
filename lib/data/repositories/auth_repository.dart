import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';
import '../models/session.dart';

/// Signing in, staying signed in, and signing out.
///
/// The permissions the backend returns are kept here too: every menu and
/// action in the app is driven by them rather than by hardcoded roles, exactly
/// as the web client does.
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore tokens})
      : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final body = await _api.post('/login', data: {
      'username': username.trim(),
      'password': password,
    });
    final result = LoginResult.fromJson(_raw(body));
    if (result is LoggedIn) await _persist(result.session);
    return result;
  }

  Future<Session> verifyTwoFactor({
    required String tempToken,
    required String code,
  }) async {
    final body = await _api.post('/verify-2fa', data: {
      'temp_token': tempToken,
      'code': code.trim(),
    });
    final session = Session.fromJson(_raw(body));
    await _persist(session);
    return session;
  }

  /// Brings back a session saved on a previous launch, if it still works.
  Future<Session?> restore() async {
    final String? access;
    final String? refresh;
    try {
      access = await _tokens.readAccess();
      refresh = await _tokens.readRefresh();
    } catch (_) {
      // The saved login could not be read (see TokenStore): start signed out
      // rather than wait on it for ever.
      try {
        await _tokens.clear();
      } catch (_) {}
      return null;
    }
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      return null;
    }
    try {
      // Any authenticated call proves the token is still good, and the client
      // silently refreshes it if it is not.
      await _api.get('/permission');
    } catch (_) {
      await _tokens.clear();
      return null;
    }
    Map<String, dynamic>? profile;
    try {
      profile = await _tokens.readProfile();
    } catch (_) {
      profile = null;
    }
    return Session(access: access, refresh: refresh, profile: profile);
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.post('/logout', data: {'refresh': refresh});
      }
    } catch (_) {
      // A failed logout call must never trap someone in the app; the local
      // tokens are cleared either way.
    }
    await _tokens.clear();
  }

  /// What this user is allowed to do, as the backend sees it.
  Future<Map<String, dynamic>> permissions() async =>
      asMap(await _api.get('/permission'));

  /// The user's rights by name ("app_label.codename"), as the server checks
  /// them. Null from a server too old to send them.
  Future<Set<String>?> rights() async {
    final body = await _api.get('/permission');
    final names = body is Map ? body['codenames'] : null;
    if (names is! List) return null;
    return {for (final n in names) n.toString()};
  }

  /// The keys of every menu entry the user's role may open, from the same
  /// sidebar the desk builds its menu from.
  Future<Set<String>> menuKeys() async {
    final keys = <String>{};
    void walk(dynamic node) {
      if (node is List) {
        for (final child in node) {
          walk(child);
        }
      } else if (node is Map) {
        final key = node['key'];
        if (key is String && key.isNotEmpty) keys.add(key);
        walk(node['subMenu']);
      }
    }

    final body = await _api.get('/side-bar');
    walk(body is Map ? (body['data'] ?? body) : body);
    return keys;
  }

  Future<void> _persist(Session session) async {
    await _tokens.saveTokens(access: session.access, refresh: session.refresh);
    await _tokens.saveProfile(session.profile);
  }

  /// `/login` answers plainly rather than in the usual `{status, data}`
  /// envelope, so take the body as-is when there is no `data` key.
  Map<String, dynamic> _raw(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}
