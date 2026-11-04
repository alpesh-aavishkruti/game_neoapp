import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/data/models/havala.dart';
import 'package:game_app_flutter/data/models/party.dart';
import 'package:game_app_flutter/data/repositories/havala_repository.dart';
import 'package:game_app_flutter/features/matches/match_providers.dart';
import 'package:game_app_flutter/features/money/havala_entry_sheet.dart';
import 'package:game_app_flutter/features/money/havala_screen.dart';
import 'package:game_app_flutter/shared/widgets/party_field.dart';

class _FakeHavalas implements HavalaRepository {
  final updates = <({int id, double amount, String description, int from, int to})>[];
  final creates = <({double amount, String description})>[];

  @override
  Future<void> update({
    required int id,
    required int fromPartyId,
    required int toPartyId,
    required double amount,
    required DateTime date,
    String description = '',
  }) async {
    updates.add((
      id: id,
      amount: amount,
      description: description,
      from: fromPartyId,
      to: toPartyId,
    ));
  }

  @override
  Future<void> create({
    required int fromPartyId,
    required int toPartyId,
    required double amount,
    required DateTime date,
    String description = '',
    String? voucherNo,
  }) async {
    creates.add((amount: amount, description: description));
  }

  @override
  Future<String> nextVoucherNo() async => 'HAVALA0099';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

const _parties = [
  Party(id: 15, code: '0015', name: 'PT2'),
  Party(id: 21, code: 'SUS', name: 'SUSPENSE'),
];

/// A Dena havala: held as a minus figure, with the desk's working in its line.
final _dena = Havala(
  id: 27,
  voucherNo: 'HAVALA0027',
  date: DateTime(2026, 9, 28),
  fromId: 15,
  fromCode: '0015',
  fromName: 'PT2',
  toId: 21,
  toCode: 'SUS',
  toName: 'SUSPENSE',
  amount: -1476,
  description: '123 X 12 cash',
);

Widget _host(_FakeHavalas havalas, {Havala? editing, int? fromPartyId}) => ProviderScope(
      overrides: [
        havalaRepositoryProvider.overrideWithValue(havalas),
        partiesProvider.overrideWith((ref) async => _parties),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: HavalaEntrySheet(editing: editing, fromPartyId: fromPartyId)),
      ),
    );

String _boxText(WidgetTester tester, String label) {
  final field = find.ancestor(
    of: find.text(label.toUpperCase()),
    matching: find.byType(Column),
  );
  return tester
      .widget<EditableText>(
        find.descendant(of: field.first, matching: find.byType(EditableText)),
      )
      .controller
      .text;
}

void main() {
  testWidgets('an edit opens on the entry as it stands, minus and all',
      (tester) async {
    await tester.pumpWidget(_host(_FakeHavalas(), editing: _dena));
    await tester.pumpAndSettle();

    expect(find.text('Edit havala'), findsOneWidget);
    // The minus is shown, not hidden: this is a Dena entry.
    expect(_boxText(tester, 'Amount'), '-1476.00');
    // and the desk's working is back in its own boxes
    expect(_boxText(tester, 'Qty'), '123');
    expect(_boxText(tester, 'Rate'), '12');
    // The whole line, working and all, as the desk's description box shows it.
    expect(_boxText(tester, 'Narration'), '123 X 12 cash');
  });

  testWidgets('saving an untouched edit keeps the entry Dena', (tester) async {
    final havalas = _FakeHavalas();
    await tester.pumpWidget(_host(havalas, editing: _dena));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save havala'));
    await tester.pumpAndSettle();

    expect(havalas.creates, isEmpty);
    expect(havalas.updates, hasLength(1));
    final sent = havalas.updates.single;
    expect(sent.id, 27);
    expect(sent.amount, -1476);
    expect(sent.description, '123 X 12 cash');
  });

  testWidgets('typing a working fills the amount and writes the line',
      (tester) async {
    final havalas = _FakeHavalas();
    await tester.pumpWidget(_host(havalas));
    await tester.pumpAndSettle();

    expect(find.text('New havala'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '44'); // qty
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), '133'); // rate
    await tester.pump();

    expect(_boxText(tester, 'Amount'), '5852.00');
    expect(_boxText(tester, 'Narration'), '44 X 133',
        reason: 'the working shows in the narration as it is typed, as on the desk');
  });

  testWidgets('a remark typed after the working stays when the working changes',
      (tester) async {
    final havalas = _FakeHavalas();
    await tester.pumpWidget(_host(havalas, fromPartyId: 15));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('SUSPENSE').last);
    await tester.pumpAndSettle();

    final qty = find.byType(TextField).at(1);
    final rate = find.byType(TextField).at(2);
    final narration = find.byType(TextField).at(3);
    await tester.enterText(qty, '-724215');
    await tester.enterText(rate, '0.01');
    await tester.pump();
    expect(_boxText(tester, 'Narration'), '-724215 X 0.01');

    await tester.enterText(narration, '-724215 X 0.01 cash');
    await tester.enterText(rate, '0.02');
    await tester.pump();
    expect(_boxText(tester, 'Narration'), '-724215 X 0.02 cash');
    expect(_boxText(tester, 'Amount'), '-14484.30');

    await tester.tap(find.widgetWithText(FilledButton, 'Save havala'));
    await tester.pumpAndSettle();
    expect(havalas.creates.single.description, '-724215 X 0.02 cash');
  });

  testWidgets('clearing the working takes it out of the narration', (tester) async {
    await tester.pumpWidget(_host(_FakeHavalas()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.enterText(find.byType(TextField).at(3), '10 X 5 bank');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.enterText(find.byType(TextField).at(2), '');
    await tester.pump();
    expect(_boxText(tester, 'Narration'), 'bank');
  });

  testWidgets('raised from an open statement, that party pays and the receiver search opens',
      (tester) async {
    final havalas = _FakeHavalas();
    await tester.pumpWidget(_host(havalas, fromPartyId: 15));
    await tester.pumpAndSettle();

    // The receiver search is already up, over the form.
    expect(find.byType(PartyPickerSheet), findsOneWidget);
    await tester.tap(find.textContaining('SUSPENSE').last);
    await tester.pumpAndSettle();
    expect(find.byType(PartyPickerSheet), findsNothing);

    // The payer was filled in from the open statement; the receiver as chosen.
    expect(find.text(_parties[0].display), findsOneWidget);
    expect(find.text(_parties[1].display), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '500');
    await tester.tap(find.widgetWithText(FilledButton, 'Save havala'));
    await tester.pumpAndSettle();
    expect(havalas.creates.single.amount, 500);
  });

  testWidgets('a havala raised elsewhere starts with no party chosen', (tester) async {
    await tester.pumpWidget(_host(_FakeHavalas()));
    await tester.pumpAndSettle();
    expect(find.text('Tap to choose'), findsNWidgets(2));
  });
}
