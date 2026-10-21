import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/book_row.dart';

void main() {
  test("a session's partner book reads each partner's value, as the desk does", () {
    final book = MatchBook.fromJson({
      'parties': [
        {'party_id': 1, 'party_code': 'LK', 'party_name': 'LK', 'value': -6400.0, 'value_total': -6400.0, 'partner_value': -6400.0},
        {'party_id': 2, 'party_code': 'MAS', 'party_name': 'MASTAN', 'value': -6400.0, 'value_total': -6400.0, 'partner_value': -6400.0},
        {'party_id': 3, 'party_code': 'ZXV', 'party_name': 'ZXV IKP', 'value': -3200.0, 'value_total': -3200.0, 'partner_value': -3200.0},
      ],
    });

    expect(book.columns, ['PARTNER VALUE']);
    expect(book.rows.map((r) => r.figures), [
      [-6400.0],
      [-6400.0],
      [-3200.0],
    ]);
    expect(book.totals, [-16000.0]);
  });

  test('a session party book keeps its K and L columns', () {
    final book = MatchBook.fromJson({
      'parties': [
        {'party_id': 1, 'party_code': 'LK', 'party_name': 'LK', 'k_total': 100.0, 'l_total': -50.0},
      ],
    });
    expect(book.columns, isNull);
    expect(book.rows.single.figures, [100.0, -50.0]);
  });

  test('a one day book keeps its side columns', () {
    final book = MatchBook.fromJson({
      'parties': [
        {'party_id': 1, 'party_code': 'LK', 'party_name': 'LK', 'nation1_pl': 10.0, 'nation2_pl': -5.0},
      ],
      'total_a': 10.0,
      'total_b': -5.0,
    });
    expect(book.columns, isNull);
    expect(book.rows.single.figures, [10.0, -5.0]);
  });
}
