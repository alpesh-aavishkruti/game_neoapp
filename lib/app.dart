import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/two_factor_screen.dart';
import 'features/shell/app_shell.dart';

/// The app shell.
///
/// Which screen you see follows from the auth state alone, so there is one
/// answer to "am I signed in" and no route can be reached around it.
class NeonApp extends ConsumerWidget {
  const NeonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Neon Accounting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Pinned to light. Following the phone's setting meant the book showed
      // up dark for anyone whose handset is in dark mode, which is not the
      // look this was signed off on.
      themeMode: ThemeMode.light,
      builder: (context, child) {
        // Respect the reader's text-size setting, but stop at a point where
        // the ledger columns would stop lining up.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: switch (auth) {
        AuthUnknown() => const _Splash(),
        SignedOut(:final message) => SignInScreen(notice: message),
        AwaitingTwoFactor(:final challenge) => TwoFactorScreen(challenge: challenge),
        SignedIn() => const AppShell(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
