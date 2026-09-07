import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/run_ladder.dart';
import 'package:game_app_flutter/data/models/settlement.dart';

void main() {
  group('run ladder', () {
    // GET /api/v1/soda/session/run_exposure/?match=70
    final json = {
      'match_id': 70,
      'match_name': 'DF vs DFH (SESSION)',
      'run_pl_json': {
        '120': -4600.0,
        '118': 12500.0,
        '121': -31400.0,
        '119': 8200.0,
      },
    };

    test('reads the rungs in run order, whatever order they arrived in', () {
      final ladder = RunLadder.fromJson(json);
      expect(ladder.rungs.map((r) => r.run), [118, 119, 120, 121]);
    });

    test('flags the run the book stands to lose most on', () {
      // That is the figure an operator watches, so it must not be hunted for.
      expect(RunLadder.fromJson(json).worst?.run, 121);
    });

    test('an untouched session has no ladder rather than a broken one', () {
      final ladder = RunLadder.fromJson({'run_pl_json': <String, dynamic>{}});
      expect(ladder.isEmpty, isTrue);
      expect(ladder.worst, isNull);
    });

    test('a missing ladder does not throw', () {
      expect(RunLadder.fromJson({'match_id': 1}).isEmpty, isTrue);
    });
  });

  group('session totals', () {
    test('reads the four figures a session settles on', () {
      // GET /api/v1/soda/session/70/session_totals/
      final totals = SessionTotals.fromJson({
        'k_total': 185000.0,
        'l_total': 240000.0,
        'client_kl': 0,
        'com_total': 4250.0,
        'our_kl': 55000.0,
      });

      expect(totals.kTotal, 185000);
      expect(totals.lTotal, 240000);
      expect(totals.ourKl, 55000);
      expect(totals.commission, 4250);
    });
  });

  group('settlement', () {
    Settlement build({required double take, required double give}) =>
        Settlement.fromJson({
          'match_name': '77 - LANKA VS INDIA OneDay',
          'win_nation_name': 'LANKA',
          'take_money': [
            {'party_id': 40, 'party_code': '0017', 'party_name': 'KR', 'amount': 2340.0},
          ],
          'give_money': [
            {'party_id': 14, 'party_code': '0014', 'party_name': 'PT1', 'amount': 3981.44},
          ],
          'take_total': take,
          'give_total': give,
        });

    test('reads both columns and their totals', () {
      final s = build(take: 4391.80, give: 4391.80);
      expect(s.take.single.code, '0017');
      expect(s.give.single.amount, 3981.44);
      expect(s.takeTotal, 4391.80);
    });

    test('a settlement whose sides agree may be closed', () {
      expect(build(take: 4391.80, give: 4391.80).balances, isTrue);
    });

    test('a settlement that does not balance is refused, not rounded away', () {
      // The close button is disabled on this, which is the whole point: a book
      // that does not add up is a reason to stop.
      expect(build(take: 4391.80, give: 4000.00).balances, isFalse);
    });

    test('rounding noise below a paisa still counts as balanced', () {
      expect(build(take: 4391.80, give: 4391.801).balances, isTrue);
    });

    test('a party named after its own code is not doubled up', () {
      final line = SettlementLine.fromJson(
        {'party_id': 1, 'party_code': 'PDG', 'party_name': 'PDG', 'amount': 1},
      );
      expect(line.display, 'PDG');
    });
  });
}
