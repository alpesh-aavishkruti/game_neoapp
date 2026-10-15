/// How the backend answers a sign-in attempt.
///
/// Two shapes come back from `/login`: either the tokens, or a challenge
/// saying second-factor verification is still needed.
sealed class LoginResult {
  const LoginResult();

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    if (json['requires_2fa'] == true) {
      return TwoFactorChallenge(
        tempToken: (json['temp_token'] ?? '').toString(),
        method: TwoFactorMethod.parse(json['two_fa_method']),
      );
    }
    return LoggedIn(Session.fromJson(json));
  }
}

class LoggedIn extends LoginResult {
  const LoggedIn(this.session);
  final Session session;
}

class TwoFactorChallenge extends LoginResult {
  const TwoFactorChallenge({required this.tempToken, required this.method});
  final String tempToken;
  final TwoFactorMethod method;
}

enum TwoFactorMethod {
  telegram,
  authenticator,
  unknown;

  static TwoFactorMethod parse(dynamic raw) => switch (raw?.toString().toUpperCase()) {
        'TELEGRAM' => TwoFactorMethod.telegram,
        'GOOGLE_AUTH' => TwoFactorMethod.authenticator,
        _ => TwoFactorMethod.unknown,
      };

  /// What to tell the user about where their code is.
  String get hint => switch (this) {
        TwoFactorMethod.telegram => 'Enter the 6-digit code sent to your Telegram',
        TwoFactorMethod.authenticator => 'Enter the 6-digit code from your authenticator app',
        TwoFactorMethod.unknown => 'Enter your 6-digit verification code',
      };
}

class Session {
  const Session({
    required this.access,
    required this.refresh,
    this.profile,
    this.mustChangePassword = false,
  });

  final String access;
  final String refresh;
  final Map<String, dynamic>? profile;

  /// Signed in with a password an admin gave: the user has to choose their
  /// own before anything else opens.
  final bool mustChangePassword;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        access: (json['access'] ?? '').toString(),
        refresh: (json['refresh'] ?? '').toString(),
        profile: json['profile'] is Map
            ? Map<String, dynamic>.from(json['profile'] as Map)
            : null,
        mustChangePassword: json['must_change_password'] == true,
      );

  bool get isValid => access.isNotEmpty;

  /// The employee payload nests the account: `profile.user.username`. Older
  /// shapes put a name at the top level, so both are read.
  String get displayName {
    final p = profile;
    if (p == null) return 'User';

    final user = p['user'];
    if (user is Map) {
      final first = (user['first_name'] ?? '').toString().trim();
      final last = (user['last_name'] ?? '').toString().trim();
      final full = [first, last].where((e) => e.isNotEmpty).join(' ');
      if (full.isNotEmpty) return full;
      final username = (user['username'] ?? '').toString().trim();
      if (username.isNotEmpty) return username;
    }

    for (final key in ['user_short_name', 'employee_name', 'name', 'full_name', 'username']) {
      final value = p[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return 'User';
  }

  /// The organisation this account works in, from the sign-in profile.
  Object? get organizationId {
    final org = profile?['organization'];
    if (org is Map) return org['id'];
    return org;
  }

  /// True when this account administers its organisation. Screens use it to
  /// hide what the account could not open anyway.
  bool get isOrgAdmin => profile?['is_org_admin'] == true;

  /// Minutes without a touch before the app signs this user out, as set in
  /// User Master. Null or 0 means no limit.
  int? get autoLogoutMinutes => int.tryParse('${profile?['auto_logout_minutes']}');
}
