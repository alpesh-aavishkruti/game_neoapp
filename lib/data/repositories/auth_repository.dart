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
    final access = await _tokens.readAccess();
    final refresh = await _tokens.readRefresh();
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
    return Session(
      access: access,
      refresh: refresh,
      profile: await _tokens.readProfile(),
    );
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
