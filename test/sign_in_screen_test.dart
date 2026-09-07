import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/features/auth/sign_in_screen.dart';

Widget _host(Widget child, {ThemeData? theme}) => ProviderScope(
      child: MaterialApp(theme: theme ?? AppTheme.dark(), home: child),
    );

void main() {
  testWidgets('asks for the same two things as the desk system', (tester) async {
    await tester.pumpWidget(_host(const SignInScreen()));

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('USER ID'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });

  testWidgets('will not call the API with an empty form', (tester) async {
    await tester.pumpWidget(_host(const SignInScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    // Both fields complain, and nothing was sent - the provider would have
    // thrown had it been read, since no API is wired up in this test.
    expect(find.text('Enter your user ID'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('says why the session ended when it ended on its own', (tester) async {
    await tester.pumpWidget(
      _host(const SignInScreen(notice: 'Your session has ended. Please sign in again.')),
    );

    expect(find.textContaining('session has ended'), findsOneWidget);
  });

  testWidgets('password is hidden until the reveal is tapped', (tester) async {
    await tester.pumpWidget(_host(const SignInScreen()));

    EditableText passwordField() => tester.widget<EditableText>(
          find.byType(EditableText).last,
        );

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('renders in both themes', (tester) async {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      await tester.pumpWidget(_host(const SignInScreen(), theme: theme));
      expect(tester.takeException(), isNull);
    }
  });
}
