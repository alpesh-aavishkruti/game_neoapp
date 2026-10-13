import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/util/havala_description.dart';

void main() {
  group('reading the desk narration back into its boxes', () {
    test('a plain working fills both boxes and leaves no remark', () {
      final read = HavalaDescription.parse('43 X 23', 989);
      expect(read.qty, '43');
      expect(read.rate, '23');
      expect(read.note, '');
    });

    test('a working wrapped in a remark still reads, remark kept', () {
      final read = HavalaDescription.parse('AED : -3000 X 27.60 CASH', 82800);
      expect(read.qty, '-3000');
      expect(read.rate, '27.60');
      expect(read.note, 'AED : CASH');
    });

    test('a single figure that matches the amount is the qty', () {
      final read = HavalaDescription.parse('CASH 5000', 5000);
      expect(read.qty, '5000');
      expect(read.rate, '');
      expect(read.note, 'CASH');
    });

    test('figures that do not multiply out are left as a remark', () {
      // 35 is not the amount, so it is the operator writing "35", not a qty.
      final read = HavalaDescription.parse('35', 4534);
      expect(read.hasFigures, isFalse);
      expect(read.note, '35');
    });

    test('a party code in the line is not mistaken for a working', () {
      final read = HavalaDescription.parse('0015', 1231);
      expect(read.hasFigures, isFalse);
      expect(read.note, '0015');
    });

    test('a Dena entry is read off its minus amount', () {
      final read = HavalaDescription.parse('123 X 12', -1476);
      expect(read.qty, '123');
      expect(read.rate, '12');
    });

    test('an empty narration reads as nothing at all', () {
      final read = HavalaDescription.parse('', 1231);
      expect(read.hasFigures, isFalse);
      expect(read.note, '');
    });
  });

  group('writing the narration back', () {
    test('qty and rate are written the way the desk writes them', () {
      expect(
        HavalaDescription.compose(qty: '67', rate: '65', note: 'cash'),
        '67 X 65 cash',
      );
    });

    test('a qty on its own carries no X', () {
      expect(
        HavalaDescription.compose(qty: '5000', rate: '', note: ''),
        '5000',
      );
    });

    test('with no working the remark stands alone', () {
      expect(
        HavalaDescription.compose(qty: '', rate: '', note: 'opening'),
        'opening',
      );
    });

    test('what is written can be read back', () {
      final line = HavalaDescription.compose(qty: '44', rate: '133', note: 'note');
      final read = HavalaDescription.parse(line, 44 * 133);
      expect(read.qty, '44');
      expect(read.rate, '133');
      expect(read.note, 'note');
    });
  });

  group('the amount the working comes to', () {
    test('qty times rate', () {
      expect(HavalaDescription.amountFor('44', '133'), 5852);
    });

    test('a qty with no rate is the amount itself', () {
      expect(HavalaDescription.amountFor('5000', ''), 5000);
    });

    test('a rate of zero does not wipe the amount', () {
      expect(HavalaDescription.amountFor('5000', '0'), 5000);
    });

    test('nothing typed yet means nothing to fill in', () {
      expect(HavalaDescription.amountFor('', '65'), isNull);
    });
  });
}
