import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/ledger_row.dart';

/// The partnership legs the backend now writes have to survive the trip into
/// the app: a leg shows whose book it came from, and its Edit drills into that
/// client's trades rather than the party being read.
void main() {
  group('partnership legs', () {
    test('a leg reports the slot and the book it came from', () {
      final row = LedgerRow.fromJson({
        'id': 3,
        'vch_date': '21-08-2026',
        'description': 'PTRN3 : ABR - 77 - LANKA VS INDIA - WINNER : LANKA',
        'cr_amount': '92.00',
        'dr_amount': 0,
        'ptrn_slot': 3,
        'ptrn_source_id': 41,
        'ptrn_source_code': 'abr',
      });

      expect(row.isPartnershipLeg, isTrue);
      expect(row.ptrnSlot, 3);
      expect(row.ptrnSourceCode, 'ABR');
      // Editing this line must show ABR's trades, not the viewer's.
      expect(row.drillIntoPartyId(999), 41);
    });

    test("a party's own result is not a leg", () {
      final row = LedgerRow.fromJson({
        'id': 1,
        'description': '77 - LANKA VS INDIA - WINNER : LANKA',
        'dr_amount': '2340.00',
      });

      expect(row.isPartnershipLeg, isFalse);
      expect(row.drillIntoPartyId(999), 999);
    });

    test('rows settled before legs existed read as own results', () {
      // Those rows carry neither column, which is what they were.
      final row = LedgerRow.fromJson({'id': 2, 'ptrn_slot': null});
      expect(row.isPartnershipLeg, isFalse);
    });
  });

  group('movement', () {
    test('credit is money owed to the party', () {
      final row = LedgerRow.fromJson({'id': 1, 'cr_amount': '318.36'});
      expect(row.movement, 318.36);
    });

    test('debit is money the party owes', () {
      final row = LedgerRow.fromJson({'id': 1, 'dr_amount': '2340'});
      expect(row.movement, -2340);
    });
  });

  group('dates', () {
    test('reads the day-first voucher date the backend sends', () {
      final row = LedgerRow.fromJson({'id': 1, 'vch_date': '21-08-2026'});
      expect(row.date, DateTime(2026, 8, 21));
    });

    test('a malformed date does not take the row down', () {
      final row = LedgerRow.fromJson({'id': 1, 'vch_date': 'not a date'});
      expect(row.date, isNull);
    });
  });

  group('which book a statement line has to be deleted from', () {
    LedgerRow row(Map<String, dynamic> extra) => LedgerRow.fromJson({
          'id': 1,
          'description': 'x',
          'cr_amount': '0',
          'dr_amount': '0',
          'closing_balance': '0',
          ...extra,
        });

    test('a havala goes back to the havala book', () {
      final t = row({'vch_no': 'HAVALA0018', 'original_id': 7}).deleteTarget;
      expect(t?.path, '/soda/havala/');
      expect(t?.id, 7);
    });

    test('an RGML line is a havala too, whatever its voucher reads', () {
      final t = row({'vch_type': 'RGML', 'vch_no': 'X1', 'original_id': 9}).deleteTarget;
      expect(t?.path, '/soda/havala/');
      expect(t?.id, 9);
    });

    test('an 03515 daybook line is an inflow voucher', () {
      final t = row({'daybook_code': '03515/26', 'voucher_id': 4}).deleteTarget;
      expect(t?.path, '/soda/inflow-clearing-jv/');
    });

    test('the clearing daybooks all route to the clearing book', () {
      for (final code in ['03501', '03511', '03525', '03535']) {
        expect(
          row({'daybook_code': '$code/26', 'voucher_id': 4}).deleteTarget?.path,
          '/soda/clearing-jv/',
          reason: code,
        );
      }
      expect(
        row({'daybook_code': 'CLOSE JV 12', 'voucher_id': 4}).deleteTarget?.path,
        '/soda/clearing-jv/',
      );
    });

    test('anything else carrying a voucher is an opening balance', () {
      final t = row({'daybook_code': '09999', 'voucher_id': 3}).deleteTarget;
      expect(t?.path, '/soda/opening-balances/');
    });

    test('a settled match line cannot be deleted from the statement', () {
      // It has no record of its own - it was produced by closing a match.
      final r = row({'vch_no': 'MATCH-77', 'match_id': 77});
      expect(r.deleteTarget, isNull);
      expect(r.canDelete, isFalse);
    });

    test('a havala with no id of its own is refused rather than misrouted', () {
      expect(row({'vch_no': 'HAVALA0018'}).canDelete, isFalse);
    });
  });
}
