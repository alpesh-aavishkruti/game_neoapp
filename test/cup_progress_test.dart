import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/settlement.dart';

/// A cup is settled by knocking teams out, never by naming a winner. These pin
/// that rule: the champion is what is left standing, and the app must never be
/// able to declare one that has not actually won.
void main() {
  group('a cup part-way through', () {
    // GET /api/v1/soda/cup/8/close_cup/
    final fresh = CupProgress.fromJson({
      'winner_nation': null,
      'out_nations': <dynamic>[],
      'pending_nations': ['AA', 'BB', 'CC', 'DD'],
      'winner_auto_declared': false,
    });

    test('reads who is still in', () {
      expect(fresh.pending, ['AA', 'BB', 'CC', 'DD']);
      expect(fresh.out, isEmpty);
      expect(fresh.isComplete, isFalse);
    });

    test('four teams left is not the last elimination', () {
      expect(fresh.isLastElimination, isFalse);
    });

    test('two teams left means the next knockout crowns the other', () {
      final nearly = CupProgress.fromJson({
        'out_nations': ['CC', 'DD'],
        'pending_nations': ['AA', 'BB'],
      });
      expect(nearly.isLastElimination, isTrue);
      // The screen warns about this rather than letting it be a surprise.
      expect(nearly.isComplete, isFalse);
    });
  });

  group('a finished cup', () {
    test('reports the champion the backend derived', () {
      final done = CupProgress.fromJson({
        'winner_nation': 'aa',
        'out_nations': ['BB', 'CC', 'DD'],
        'pending_nations': <dynamic>[],
        'winner_auto_declared': true,
      });

      expect(done.isComplete, isTrue);
      expect(done.winner, 'AA');
      expect(done.winnerAutoDeclared, isTrue);
      expect(done.out, hasLength(3));
    });
  });

  group('missing data', () {
    test('an empty payload does not throw', () {
      final empty = CupProgress.fromJson({});
      expect(empty.pending, isEmpty);
      expect(empty.out, isEmpty);
      expect(empty.isComplete, isFalse);
      expect(empty.isLastElimination, isFalse);
    });

    test('a blank winner is no winner, not an empty champion', () {
      expect(CupProgress.fromJson({'winner_nation': '  '}).winner, isNull);
    });
  });

  group('who the last declaration names', () {
    test('with three teams left the screen still asks who is out', () {
      final p = CupProgress.fromJson({
        'pending_nations': ['IND', 'AUS', 'ENG'],
        'out_nations': ['SA'],
        'declare_mode': 'out',
      });
      expect(p.asksForWinner, isFalse);
      expect(p.isLastElimination, isFalse);
    });

    test('with two teams left it asks for the winner', () {
      final p = CupProgress.fromJson({
        'pending_nations': ['IND', 'AUS'],
        'out_nations': ['SA', 'ENG'],
        'declare_mode': 'winner',
      });
      expect(p.asksForWinner, isTrue);
      expect(p.isLastElimination, isTrue);
    });

    test('a server that does not send the mode still asks the right question', () {
      // The rule is the same one; falling back keeps an older server working.
      final two = CupProgress.fromJson({
        'pending_nations': ['IND', 'AUS'],
        'out_nations': ['SA'],
      });
      final three = CupProgress.fromJson({
        'pending_nations': ['IND', 'AUS', 'ENG'],
        'out_nations': ['SA'],
      });
      expect(two.asksForWinner, isTrue);
      expect(three.asksForWinner, isFalse);
    });

    test('a finished cup names the champion the operator declared', () {
      final p = CupProgress.fromJson({
        'pending_nations': ['IND'],
        'out_nations': ['SA', 'ENG', 'AUS'],
        'winner_nation': 'IND',
        'winner_auto_declared': false,
      });
      expect(p.isComplete, isTrue);
      expect(p.winner, 'IND');
      // The operator named it, so it is not presented as an automatic call.
      expect(p.winnerAutoDeclared, isFalse);
    });
  });
}
