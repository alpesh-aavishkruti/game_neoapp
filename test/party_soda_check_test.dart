import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/data/models/bet_entry.dart';
import 'package:game_app_flutter/data/models/book_row.dart';
import 'package:game_app_flutter/data/models/match.dart';
import 'package:game_app_flutter/data/repositories/book_repository.dart';
import 'package:game_app_flutter/features/books/party_soda_screen.dart';
import 'package:game_app_flutter/features/money/ledger_screen.dart';
import 'package:game_app_flutter/shared/widgets/check_tick.dart';

/// A stand-in for the server: it remembers what the screen asked it to tick
/// and answers with entries that carry that tick, the way the API does.
class _FakeBooks implements BookRepository {
  _FakeBooks(this._checked);

  bool _checked;

  final calls = <({int? partyId, List<int> entryIds, bool checked})>[];

  @override
  Future<List<BetEntry>> partySoda({
    required GameMatch match,
    required int partyId,
    bool ownOnly = false,
  }) async =>
      [
        BetEntry.fromJson({
          'id': 11,
          'row_no': 3,
          'nation': 'GDFG',
          'bet_type': 'L',
          'amount': '23',
          'rate': '23',
          'client_code': 'LS',
          'client_name': 'LS',
          'is_checked': _checked,
        }),
      ];

  @override
  Future<void> setChecked({
    required GameMatch match,
    required bool checked,
    int? partyId,
    List<int> entryIds = const [],
  }) async {
    calls.add((partyId: partyId, entryIds: entryIds, checked: checked));
    _checked = checked;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

const _match = GameMatch(
  id: 62,
  game: GameType.oneDay,
  nationA: 'GDFG',
  nationB: 'DFG',
  isActive: true,
);

const _row = BookRow(
  partyId: 15,
  code: 'LS',
  name: 'LS',
  figures: [111401.40, -32800],
);

Widget _host(_FakeBooks books) => ProviderScope(
      overrides: [bookRepositoryProvider.overrideWithValue(books)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const PartySodaScreen(match: _match, row: _row),
      ),
    );

void main() {
  testWidgets('a bet arrives showing the tick the book already holds',
      (tester) async {
    await tester.pumpWidget(_host(_FakeBooks(true)));
    await tester.pumpAndSettle();

    expect(tester.widget<CheckTick>(find.byType(CheckTick)).checked, isTrue);
  });

  testWidgets('tapping the tick tells the server about that one bet',
      (tester) async {
    final books = _FakeBooks(false);
    await tester.pumpWidget(_host(books));
    await tester.pumpAndSettle();

    expect(tester.widget<CheckTick>(find.byType(CheckTick)).checked, isFalse);

    await tester.tap(find.byType(CheckTick));
    await tester.pumpAndSettle();

    expect(books.calls, hasLength(1));
    expect(books.calls.single.entryIds, [11]);
    expect(books.calls.single.checked, isTrue);
    // and the row is re-read, so it now shows ticked
    expect(tester.widget<CheckTick>(find.byType(CheckTick)).checked, isTrue);
  });

  testWidgets('tapping a ticked bet unticks it', (tester) async {
    final books = _FakeBooks(true);
    await tester.pumpWidget(_host(books));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckTick));
    await tester.pumpAndSettle();

    expect(books.calls.single.checked, isFalse);
    expect(tester.widget<CheckTick>(find.byType(CheckTick)).checked, isFalse);
  });
}
