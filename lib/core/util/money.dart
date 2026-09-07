/// Money formatting for a book that is read in India and the Gulf.
///
/// Figures use Indian digit grouping - 2,45,000 rather than 245,000 - because
/// that is how every existing report, ledger and printout in this business
/// reads, and an operator checking a phone against a printed book should not
/// have to re-parse the number.
class Money {
  const Money._();

  /// Groups the integer part the Indian way: last three digits, then pairs.
  ///   1234       -> 1,234
  ///   245000     -> 2,45,000
  ///   12345678   -> 1,23,45,678
  static String _group(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  /// Parses whatever the API sent - number, numeric string, or null.
  static double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  /// `2,45,000.00`. [decimals] of 0 drops the paise for figures that are
  /// always whole, such as a bet amount.
  static String format(dynamic value, {int decimals = 2, bool sign = false}) {
    final amount = toDouble(value);
    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(decimals);
    final dot = fixed.indexOf('.');
    final whole = dot == -1 ? fixed : fixed.substring(0, dot);
    final fraction = dot == -1 ? '' : fixed.substring(dot);

    final body = '${_group(whole)}$fraction';
    if (negative) return '−$body'; // real minus sign, not a hyphen
    return sign && amount > 0 ? '+$body' : body;
  }

  /// A position: always carries its sign, so +2,45,000 and −1,12,400 read as
  /// opposites at a glance rather than needing the colour alone to say so.
  static String position(dynamic value, {int decimals = 2}) =>
      format(value, decimals: decimals, sign: true);

  static bool isNegative(dynamic value) => toDouble(value) < 0;
}
