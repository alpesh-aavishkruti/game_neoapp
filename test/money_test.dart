import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/util/money.dart';

/// Every figure in this app is read against the desk system on the screen
/// beside it. That prints figures ungrouped, so these do too - a separator the
/// other screen does not have is one more thing to reconcile mid-entry.
void main() {
  group('digits', () {
    test('leaves short numbers alone', () {
      expect(Money.format(0, decimals: 0), '0');
      expect(Money.format(999, decimals: 0), '999');
    });

    test('never groups, however long the figure', () {
      expect(Money.format(1234, decimals: 0), '1234');
      expect(Money.format(245000, decimals: 0), '245000');
      expect(Money.format(1123456, decimals: 0), '1123456');
      expect(Money.format(12345678, decimals: 0), '12345678');
    });

    test('keeps paise when asked', () {
      expect(Money.format(245000.5), '245000.50');
      expect(Money.format('1591.80'), '1591.80');
    });
  });

  group('sign', () {
    test('negatives use a real minus sign, not a hyphen', () {
      expect(Money.format(-112400, decimals: 0), '−112400');
    });

    test('a position always declares its direction', () {
      expect(Money.position(245000, decimals: 0), '+245000');
      expect(Money.position(-112400, decimals: 0), '−112400');
      expect(Money.position(0, decimals: 0), '0');
    });
  });

  group('parsing what the API actually sends', () {
    test('accepts numbers, numeric strings and null', () {
      expect(Money.toDouble(1591.8), 1591.8);
      expect(Money.toDouble('1591.80'), 1591.8);
      expect(Money.toDouble(' 1591.80 '), 1591.8);
      expect(Money.toDouble(null), 0);
      expect(Money.toDouble('not a number'), 0);
    });

    test('reports direction for colouring a row', () {
      expect(Money.isNegative('-88400'), isTrue);
      expect(Money.isNegative('42500'), isFalse);
    });
  });
}
