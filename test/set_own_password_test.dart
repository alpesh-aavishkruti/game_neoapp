import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/data/models/session.dart';
import 'package:game_app_flutter/features/auth/set_own_password_screen.dart';

void main() {
  group('sign-in answer', () {
    test('an admin-given password is flagged for a change', () {
      final result = LoginResult.fromJson({
        'access': 'a',
        'refresh': 'r',
        'must_change_password': true,
      });
      expect((result as LoggedIn).session.mustChangePassword, isTrue);
    });

    test('an own password, or an older server, opens as before', () {
      expect(Session.fromJson({'access': 'a', 'refresh': 'r'}).mustChangePassword, isFalse);
      expect(
        Session.fromJson({'access': 'a', 'refresh': 'r', 'must_change_password': false})
            .mustChangePassword,
        isFalse,
      );
    });
  });

  group('set your own password', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SetOwnPasswordScreen(givenPassword: '1234'),
        ),
      ));
    }

    testWidgets('refuses the password it was given', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '1234');
      await tester.enterText(find.byType(TextFormField).at(1), '1234');
      await tester.tap(find.text('Save new password'));
      await tester.pump();
      expect(find.textContaining('different from the one you were given'), findsOneWidget);
    });

    testWidgets('asks for the same password twice', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'mine-5678');
      await tester.enterText(find.byType(TextFormField).at(1), 'mine-0000');
      await tester.tap(find.text('Save new password'));
      await tester.pump();
      expect(find.text('The two passwords do not match'), findsOneWidget);
    });
  });
}
