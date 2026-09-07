import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/general_view.dart';

void main() {
  // GET /api/v1/master/parties/view_general/
  final json = {
    'given_amounts': [
      {'party_id': 38, 'party_code': '0015', 'party_name': 'PT2', 'amount': 50959.95},
      {'party_id': 41, 'party_code': 'ABR', 'party_name': 'ABR', 'amount': 94210.20},
    ],
    'take_amounts': [
      {'party_id': 37, 'party_code': '0014', 'party_name': 'PT1', 'amount': 125966.39},
    ],
    'total_give': 145170.15,
    'total_take': 144290.15,
  };

  group('where the whole book stands', () {
    test('reads both sides and their totals', () {
      final view = GeneralView.fromJson(json);
      expect(view.give, hasLength(2));
      expect(view.take, hasLength(1));
      expect(view.totalGive, 145170.15);
      expect(view.totalTake, 144290.15);
    });

    test('lists the biggest amounts first', () {
      // The largest outstanding balance is the one worth acting on.
      expect(GeneralView.fromJson(json).give.first.code, 'ABR');
    });

    test('reports what the house is left carrying', () {
      // take − give, kept as its own figure rather than hidden in a net.
      expect(GeneralView.fromJson(json).difference, closeTo(-880.0, 0.001));
    });

    test('a party named after its own code is not doubled up', () {
      expect(GeneralView.fromJson(json).give.first.display, 'ABR');
      expect(GeneralView.fromJson(json).take.first.display, '0014 — PT1');
    });
  });

  group('nothing outstanding', () {
    test('an empty book is empty, not broken', () {
      final view = GeneralView.fromJson({
        'given_amounts': <dynamic>[],
        'take_amounts': <dynamic>[],
        'total_give': 0,
        'total_take': 0,
      });
      expect(view.isEmpty, isTrue);
      expect(view.difference, 0);
    });

    test('a missing payload does not throw', () {
      expect(GeneralView.fromJson({}).isEmpty, isTrue);
    });
  });
}
