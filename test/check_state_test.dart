import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/bet_entry.dart';
import 'package:game_app_flutter/data/models/book_row.dart';

void main() {
  group('a party line carries how much of it is ticked', () {
    test('every bet ticked', () {
      final row = BookRow.fromJson({
        'party_id': 7,
        'party_code': 'sh',
        'party_name': 'Shiv',
        'nation1_pl': '125000.00',
        'nation2_pl': '-102350.00',
        'check_status': 'all',
      });
      expect(row.checkState, CheckState.all);
    });

    test('some of them', () {
      final row = BookRow.fromJson({'party_id': 7, 'check_status': 'some'});
      expect(row.checkState, CheckState.some);
    });

    test('none, and an absent status reads as none too', () {
      expect(
        BookRow.fromJson({'party_id': 7, 'check_status': 'none'}).checkState,
        CheckState.none,
      );
      expect(BookRow.fromJson({'party_id': 7}).checkState, CheckState.none);
    });

    test('a session line keeps its tick as well', () {
      final row = BookRow.fromJson({
        'party_id': 9,
        'k_total': '0',
        'l_total': '-35890.00',
        'check_status': 'all',
      });
      expect(row.figures, [0, -35890]);
      expect(row.checkState, CheckState.all);
    });
  });

  group('a bet carries its own tick', () {
    test('ticked', () {
      final entry = BetEntry.fromJson({
        'id': 11,
        'row_no': 3,
        'nation': 'gdfg',
        'bet_type': 'L',
        'amount': '23',
        'rate': '23',
        'is_checked': true,
      });
      expect(entry.isChecked, isTrue);
    });

    test('not ticked, and a missing flag is not ticked', () {
      expect(
        BetEntry.fromJson({'id': 11, 'is_checked': false}).isChecked,
        isFalse,
      );
      expect(BetEntry.fromJson({'id': 11}).isChecked, isFalse);
    });
  });
}
