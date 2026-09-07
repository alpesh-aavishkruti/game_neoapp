import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/util/money.dart';

/// Every figure in this app is read against a printed book that uses Indian
/// digit grouping. Getting the grouping wrong makes an operator re-read the
/// number, which is exactly what a book on a phone must not cost them.
void main() {
  group('Indian digit grouping', () {
    test('leaves short numbers alone', () {
      expect(Money.format(0, decimals: 0), '0');
      expect(Money.format(999, decimals: 0), '999');
    });

    test('groups the last three digits, then in pairs', () {
      expect(Money.format(1234, decimals: 0), '1,234');
      expect(Money.format(245000, decimals: 0), '2,45,000');
      expect(Money.format(1123456, decimals: 0), '11,23,456');
      expect(Money.format(12345678, decimals: 0), '1,23,45,678');
    });

    test('keeps paise when asked', () {
      expect(Money.format(245000.5), '2,45,000.50');
      expect(Money.format('1591.80'), '1,591.80');
    });
  });

  group('sign', () {
    test('negatives use a real minus sign, not a hyphen', () {
      expect(Money.format(-112400, decimals: 0), '−1,12,400');
    });

    test('a position always declares its direction', () {
      expect(Money.position(245000, decimals: 0), '+2,45,000');
      expect(Money.position(-112400, decimals: 0), '−1,12,400');
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
