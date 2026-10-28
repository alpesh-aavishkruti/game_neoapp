import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_exception.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/data/models/havala.dart';
import 'package:game_app_flutter/data/models/ledger_row.dart';
import 'package:game_app_flutter/data/models/party.dart';
import 'package:game_app_flutter/data/repositories/havala_repository.dart';
import 'package:game_app_flutter/features/matches/match_providers.dart';
import 'package:game_app_flutter/features/money/havala_screen.dart';
import 'package:game_app_flutter/features/money/ledger_screen.dart';

/// Records which havala the screen asked to open, and opens none.
class _Havalas implements HavalaRepository {
  final opened = <int>[];

  @override
  Future<Havala> byId(int id) async {
    opened.add(id);
    throw ApiException('not opened in a test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

const _party = Party(id: 77, code: 'SHIV', name: 'SHIV');

LedgerRow _line(int id, String text, int originalId) => LedgerRow.fromJson({
      'id': id,
      'vch_date': '${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
      'description': text,
      'cr_amount': '100',
      'dr_amount': '0',
      'closing_balance': '100',
      'source': 'havala',
      'original_id': originalId,
    });

Widget _host(_Havalas havalas) => ProviderScope(
      overrides: [
        havalaRepositoryProvider.overrideWithValue(havalas),
        partiesProvider.overrideWith((ref) async => const [_party]),
        ledgerProvider.overrideWith((ref, id) async => PartyStatement(
              rows: [_line(1, 'LU : first', 501), _line(2, 'LU : second', 502)],
              balance: 200,
            )),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const LedgerScreen(party: _party),
      ),
    );

void main() {
  testWidgets('one tap lights a line; only a double tap opens it',
      (tester) async {
    final havalas = _Havalas();
    await tester.pumpWidget(_host(havalas));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LU : first'));
    await tester.pumpAndSettle();
    expect(havalas.opened, isEmpty, reason: 'a single tap must not open the edit');

    await tester.tap(find.text('LU : second'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('LU : second'));
    await tester.pumpAndSettle();
    expect(havalas.opened, [502]);
  });
}
