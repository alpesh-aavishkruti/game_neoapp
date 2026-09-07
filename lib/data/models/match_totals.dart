import '../../core/util/money.dart';

/// Where the book stands on one side of a match.
class NationPosition {
  const NationPosition({
    required this.name,
    required this.profitLoss,
    required this.averageRate,
  });

  final String name;

  /// Positive means the book is up if this side wins.
  final double profitLoss;
  final double averageRate;

  bool get isNegative => profitLoss < 0;
}

/// The pinned figures at the top of a match board.
///
/// These are the numbers an operator actually watches, so they are read
/// straight from the server's own settlement maths - the app never recomputes
/// a position it can fetch.
class MatchTotals {
  const MatchTotals({required this.positions, this.commission = 0});

  /// One per side: two for a one day, three for a test, one per team for a cup.
  final List<NationPosition> positions;
  final double commission;

  static const empty = MatchTotals(positions: []);

  /// Reads `oneday_totals` / `test_totals` and friends, which all answer with
  /// `full_match_totals` holding `nation{n}_pl` and `avg_rate_n{n}`.
  factory MatchTotals.fromJson(
    Map<String, dynamic> json, {
    required List<String> nationNames,
  }) {
    final totals = json['full_match_totals'];
    final map = totals is Map ? Map<String, dynamic>.from(totals) : json;

    final positions = <NationPosition>[];
    for (var i = 0; i < nationNames.length; i++) {
      final n = i + 1;
      // A test's third column is reported as the draw rather than nation3.
      final plKey = map.containsKey('nation${n}_pl')
          ? 'nation${n}_pl'
          : (n == 3 && map.containsKey('draw_pl') ? 'draw_pl' : 'nation${n}_pl');
      final rateKey = map.containsKey('avg_rate_n$n')
          ? 'avg_rate_n$n'
          : 'avg_rate_n$n';

      positions.add(NationPosition(
        name: nationNames[i],
        profitLoss: Money.toDouble(map[plKey]),
        averageRate: Money.toDouble(map[rateKey]),
      ));
    }

    return MatchTotals(
      positions: positions,
      commission: Money.toDouble(json['commission_total'] ?? map['comm_total']),
    );
  }
}
