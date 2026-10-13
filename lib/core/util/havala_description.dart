/// The qty/rate figures an operator typed, and whatever else they wrote.
class HavalaNarration {
  const HavalaNarration({this.qty = '', this.rate = '', this.note = ''});

  final String qty;
  final String rate;
  final String note;

  bool get hasFigures => qty.isNotEmpty;
}

/// Reading and writing the desk's narration format.
///
/// The desk writes a havala's working into the narration - `67 X 65` for
/// sixty-seven at sixty-five - and often a remark around it. The phone has to
/// read the same line back into its two boxes, and write it the same way, or
/// the two systems would disagree about what an entry says.
class HavalaDescription {
  const HavalaDescription._();

  static final _qtyTimesRate =
      RegExp(r'(-?\d+(?:\.\d+)?)\s*[xX×]\s*(-?\d+(?:\.\d+)?)');
  static final _figure = RegExp(r'-?\d+(?:\.\d+)?');

  static String _tidy(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Splits [description] into qty, rate and the remark around them.
  ///
  /// The figures are only trusted when they multiply out to [amount], since
  /// the narration is free text: a line that happens to hold numbers is left
  /// alone as a remark rather than being mistaken for a working.
  static HavalaNarration parse(String description, double amount) {
    final desc = description.trim();
    final target = amount.abs();
    bool matches(double value) => (value.abs() - target).abs() < 0.005;

    String without(RegExpMatch match) => _tidy(
          '${desc.substring(0, match.start)} ${desc.substring(match.end)}',
        );

    for (final match in _qtyTimesRate.allMatches(desc)) {
      final qty = double.tryParse(match.group(1)!) ?? 0;
      final rate = double.tryParse(match.group(2)!) ?? 0;
      if (matches(qty * rate)) {
        return HavalaNarration(
          qty: match.group(1)!,
          rate: match.group(2)!,
          note: without(match),
        );
      }
    }

    for (final match in _figure.allMatches(desc)) {
      if (matches(double.tryParse(match.group(0)!) ?? 0)) {
        return HavalaNarration(
          qty: match.group(0)!,
          rate: '',
          note: without(match),
        );
      }
    }

    return HavalaNarration(note: desc);
  }

  /// Builds the narration back up: `67 X 65 cash` for qty, rate and remark.
  static String compose({
    required String qty,
    required String rate,
    required String note,
  }) {
    final working = qty.trim().isEmpty
        ? ''
        : rate.trim().isEmpty
            ? qty.trim()
            : '${qty.trim()} X ${rate.trim()}';
    return _tidy('$working ${note.trim()}');
  }

  /// What the amount box should read for a qty and rate, or null when the
  /// operator has not given enough to work one out.
  static double? amountFor(String qty, String rate) {
    final q = double.tryParse(qty.trim());
    if (q == null) return null;
    final r = double.tryParse(rate.trim());
    if (r == null || r == 0) return q;
    return q * r;
  }
}
