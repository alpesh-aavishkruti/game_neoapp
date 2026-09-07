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
}
