/// Money formatting.
///
/// Figures are printed ungrouped - 245000, not 2,45,000 - because that is how
/// the desk system prints them, and an operator checking a phone against the
/// screen beside it should be comparing the same characters.
class Money {
  const Money._();

  /// Parses whatever the API sent - number, numeric string, or null.
  static double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  /// `245000.00`. [decimals] of 0 drops the paise for figures that are
  /// always whole, such as a bet amount.
  static String format(dynamic value, {int decimals = 2, bool sign = false}) {
    final amount = toDouble(value);
    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(decimals);
    final dot = fixed.indexOf('.');
    final whole = dot == -1 ? fixed : fixed.substring(0, dot);
    final fraction = dot == -1 ? '' : fixed.substring(dot);

    final body = '$whole$fraction';
    if (negative) return '−$body'; // real minus sign, not a hyphen
    return sign && amount > 0 ? '+$body' : body;
  }

  /// A position: always carries its sign, so +245000 and −112400 read as
  /// opposites at a glance rather than needing the colour alone to say so.
  static String position(dynamic value, {int decimals = 2}) =>
      format(value, decimals: decimals, sign: true);

  static bool isNegative(dynamic value) => toDouble(value) < 0;
}
