import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/bet_entry.dart';
import 'package:game_app_flutter/data/models/match.dart';
import 'package:game_app_flutter/data/models/match_totals.dart';

/// The API is loosely typed - numbers arrive as strings, optional columns are
/// absent rather than null. These pin what the app does with real payloads,
/// because a parsing slip here shows up as a wrong figure on a live board.
void main() {
  group('GameMatch', () {
    test('a one day match offers its two sides', () {
      final match = GameMatch.fromJson({
        'id': 77,
        'game': 'ONE_DAY',
        'nation_a': 'lanka',
        'nation_b': 'india',
        'is_active': true,
      });

      expect(match.selectableNations, ['LANKA', 'INDIA']);
      expect(match.title, 'LANKA vs INDIA');
      expect(match.isSettled, isFalse);
    });

    test('a test match adds the draw as a third outcome', () {
      final match = GameMatch.fromJson({
        'id': 3,
        'game': 'TEST',
        'nation_a': 'IND',
        'nation_b': 'ENG',
        'nation_c': '',
        'is_active': true,
      });

      // An empty third column still means a draw is bettable.
      expect(match.selectableNations, ['IND', 'ENG', 'DRAW']);
    });

    test('a cup carries its teams rather than two sides', () {
      final match = GameMatch.fromJson({
        'id': 9,
        'game': 'CUP',
        'cup_name': 'T20 World Cup',
        'nation1': 'INDIA',
        'nation2': 'AUSTRALIA',
        'nation3': '',
        'nation4': 'ENGLAND',
        'is_active': true,
      });

      expect(match.selectableNations, ['INDIA', 'AUSTRALIA', 'ENGLAND']);
      expect(match.title, 'T20 World Cup');
    });

    test('a closed match reports itself as settled', () {
      final match = GameMatch.fromJson({
        'id': 1,
        'game': 'ONE_DAY',
        'nation_a': 'A',
        'nation_b': 'B',
        'is_active': false,
        'win_nation': 'N1',
      });

      expect(match.isSettled, isTrue);
      expect(match.winNation, 'N1');
    });
  });

  group('BetEntry', () {
    test('reads a row the way the board shows it', () {
      final entry = BetEntry.fromJson({
        'id': 5,
        'row_no': 7,
        'nation': 'india',
        'bet_type': 'L',
        'bet_label': 'I/L',
        'amount': '50000',
        'rate': '1.85',
        'client_code': 'raj01',
        'client_name': 'Rajesh Traders',
      });

      expect(entry.betType, BetType.l);
      expect(entry.amount, 50000);
      expect(entry.rate, 1.85);
      expect(entry.clientCode, 'RAJ01');
      expect(entry.label, 'I/L');
    });

    test('an edited entry stays flagged', () {
      final entry = BetEntry.fromJson({'id': 1, 'is_edited': true});
      expect(entry.isEdited, isTrue);
    });

    test('a Bombay leg is recognised and labelled apart', () {
      final entry = BetEntry.fromJson({'id': 2, 'bet_type': 'B'});
      expect(entry.isBombay, isTrue);
      expect(entry.label, 'BOMBAY');
    });

    test('a session row is subjected by its run, not a side', () {
      final entry = BetEntry.fromJson({
        'id': 3,
        'run': 122,
        'bet_type': 'K',
        'amount': 25000,
        'rate': 95,
      });

      expect(entry.subject, '122');
      expect(entry.label, '122 / K');
    });

    test('builds a label when the server did not send one', () {
      final entry = BetEntry.fromJson({'id': 4, 'nation': 'INDIA', 'bet_type': 'K'});
      expect(entry.label, 'I/K');
    });
  });

  group('MatchTotals', () {
    test('pairs each side with its position and average rate', () {
      final totals = MatchTotals.fromJson({
        'full_match_totals': {
          'nation1_pl': '245000',
          'nation2_pl': '-112400',
          'avg_rate_n1': '1.86',
          'avg_rate_n2': '2.04',
        },
      }, nationNames: ['INDIA', 'AUSTRALIA']);

      expect(totals.positions, hasLength(2));
      expect(totals.positions.first.name, 'INDIA');
      expect(totals.positions.first.profitLoss, 245000);
      expect(totals.positions.first.isNegative, isFalse);
      expect(totals.positions.last.profitLoss, -112400);
      expect(totals.positions.last.isNegative, isTrue);
      expect(totals.positions.last.averageRate, 2.04);
    });

    test("reads a test's third column from draw_pl", () {
      final totals = MatchTotals.fromJson({
        'full_match_totals': {
          'nation1_pl': 186000,
          'nation2_pl': -94500,
          'draw_pl': 42300,
        },
      }, nationNames: ['IND', 'ENG', 'DRAW']);

      expect(totals.positions, hasLength(3));
      expect(totals.positions.last.name, 'DRAW');
      expect(totals.positions.last.profitLoss, 42300);
    });

    test('an empty board reports no positions rather than throwing', () {
      final totals = MatchTotals.fromJson({}, nationNames: []);
      expect(totals.positions, isEmpty);
    });
  });
}
