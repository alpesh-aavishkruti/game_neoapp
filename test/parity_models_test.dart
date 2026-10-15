import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/general_view.dart';
import 'package:game_app_flutter/data/models/havala.dart';
import 'package:game_app_flutter/data/models/ledger_row.dart';
import 'package:game_app_flutter/data/models/session.dart';

void main() {
  test('a ledger line carries its record, tick and game', () {
    final row = LedgerRow.fromJson({
      'id': 250012,
      'original_id': 12,
      'source': 'havala',
      'check': true,
      'game_code': 'session',
      'vch_date': '06-10-2026',
      'cr_amount': 10,
      'dr_amount': 0,
    });
    expect(row.source, 'havala');
    expect(row.originalId, 12);
    expect(row.isChecked, isTrue);
    expect(row.gameCode, 'SESSION');
  });

  test('an old ledger line without those fields still reads', () {
    final row = LedgerRow.fromJson({'id': 1, 'vch_date': '06-10-2026'});
    expect(row.source, '');
    expect(row.isChecked, isFalse);
  });

  test('a View General line reads the shared tick', () {
    expect(GeneralLine.fromJson({'party_id': 3, 'check': true}).isChecked, isTrue);
    expect(GeneralLine.fromJson({'party_id': 3}).isChecked, isFalse);
  });

  test('a havala reads its tick', () {
    expect(Havala.fromJson({'id': 1, 'is_checked': true}).isChecked, isTrue);
  });

  test('the idle limit comes from the sign-in profile', () {
    Session at(Object? minutes) => Session.fromJson({
          'access': 'a',
          'refresh': 'r',
          'profile': {'auto_logout_minutes': minutes},
        });
    expect(at(15).autoLogoutMinutes, 15);
    expect(at(null).autoLogoutMinutes, isNull);
  });
}
