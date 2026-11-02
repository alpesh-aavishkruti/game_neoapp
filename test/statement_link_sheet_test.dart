import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/data/models/party.dart';
import 'package:game_app_flutter/data/models/statement_link.dart';
import 'package:game_app_flutter/data/repositories/statement_link_repository.dart';
import 'package:game_app_flutter/features/money/statement_link_sheet.dart';

/// Stands in for the server: one link per party, switched and reset on ask.
class _Links implements StatementLinkRepository {
  var link = const StatementLink(token: 'tok1', isActive: true, passwordSet: true);
  final calls = <String>[];

  @override
  Future<StatementLink> get(int partyId) async {
    calls.add('get');
    return link;
  }

  @override
  Future<StatementLink> setActive(int partyId, bool isActive) async {
    calls.add('active:$isActive');
    return link = StatementLink(token: link.token, isActive: isActive, passwordSet: link.passwordSet);
  }

  @override
  Future<StatementLink> reset(int partyId) async {
    calls.add('reset');
    return link = const StatementLink(token: 'tok2', isActive: true, passwordSet: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

const _party = Party(id: 9, code: 'CB', name: 'CB');

void main() {
  late List<String> copied;

  setUp(() {
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  Future<void> open(WidgetTester tester, _Links links) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [statementLinkRepositoryProvider.overrideWithValue(links)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => StatementLinkSheet.show(context, party: _party),
              child: const Text('share'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
  }

  testWidgets('opening it copies the link straight away', (tester) async {
    await open(tester, _Links());
    expect(copied, ['https://neonacc.com/#/statement/tok1']);
    expect(find.text('Link active'), findsOneWidget);
    expect(find.text('Set by the party.'), findsOneWidget);
  });

  testWidgets('the switch turns the link off', (tester) async {
    final links = _Links();
    await open(tester, links);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(links.calls, contains('active:false'));
    expect(find.text('Link deactivated'), findsOneWidget);
  });

  testWidgets('reset asks first, then makes and copies a new link', (tester) async {
    final links = _Links();
    await open(tester, links);

    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(links.calls, isNot(contains('reset')));

    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset').last);
    await tester.pumpAndSettle();
    expect(links.calls, contains('reset'));
    expect(copied.last, 'https://neonacc.com/#/statement/tok2');
    expect(find.textContaining('Not set yet'), findsOneWidget);
  });
}
