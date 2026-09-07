import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/session.dart';

/// Where the user stands with the app right now.
sealed class AuthState {
  const AuthState();
}

/// Before we know - the splash sits on this while a saved session is checked.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut({this.message});

  /// Set when the session ended on its own, so the sign-in screen can say why.
  final String? message;
}

/// Credentials accepted, second factor still outstanding.
class AwaitingTwoFactor extends AuthState {
  const AwaitingTwoFactor(this.challenge);
  final TwoFactorChallenge challenge;
}

class SignedIn extends AuthState {
  const SignedIn(this.session, {this.permissions = const {}});
  final Session session;
  final Map<String, dynamic> permissions;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // When a refresh fails there is no session left to save, and the client is
    // the first to know. It reports back here rather than the other way round,
    // which keeps the network layer unaware of any feature.
    ref.read(apiClientProvider).onSessionExpired = forceSignOut;

    // Kick off the session restore, but answer `unknown` immediately so the
    // first frame can render a splash rather than flashing the sign-in form.
    Future.microtask(restore);
    return const AuthUnknown();
  }

  Future<void> restore() async {
    final session = await ref.read(authRepositoryProvider).restore();
    if (session == null) {
      state = const SignedOut();
      return;
    }
    state = SignedIn(session, permissions: await _permissions());
  }

  /// Throws [ApiException] so the form can show the message against the field
  /// that caused it; state only moves on success.
  Future<void> signIn({required String username, required String password}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .login(username: username, password: password);

    state = switch (result) {
      LoggedIn(:final session) => SignedIn(session, permissions: await _permissions()),
      TwoFactorChallenge challenge => AwaitingTwoFactor(challenge),
    };
  }

  Future<void> submitTwoFactorCode(String code) async {
    final current = state;
    if (current is! AwaitingTwoFactor) return;
    final session = await ref.read(authRepositoryProvider).verifyTwoFactor(
          tempToken: current.challenge.tempToken,
          code: code,
        );
    state = SignedIn(session, permissions: await _permissions());
  }

  /// Steps back from the code screen to the sign-in form.
  void cancelTwoFactor() => state = const SignedOut();

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SignedOut();
  }

  /// Called by the API client when a refresh fails and the session is gone.
  void forceSignOut() {
    if (state is SignedOut) return;
    state = const SignedOut(message: 'Your session has ended. Please sign in again.');
  }

  Future<Map<String, dynamic>> _permissions() async {
    try {
      return await ref.read(authRepositoryProvider).permissions();
    } on ApiException {
      // A missing permission list should not block sign-in; screens fall back
      // to hiding what they cannot confirm.
      return const {};
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
