import '../../core/util/money.dart';

/// One rung of a session ladder: a run figure and where the book stands if
/// the session settles there.
class RunRung {
  const RunRung({required this.run, required this.profitLoss});

  final int run;
  final double profitLoss;

  bool get isNegative => profitLoss < 0;
}

/// Where a session book stands across the whole run range.
///
/// A session has no two sides to weigh against each other - it has a column of
/// run figures and a position at each. That column is the whole left side of
/// the desk screen; on a phone it becomes a strip that scrolls across the top.
class RunLadder {
  const RunLadder(this.rungs);

  final List<RunRung> rungs;

  static const empty = RunLadder([]);

  /// `run_exposure` answers `{match_id, match_name, run_pl_json}` where the
  /// json is a map of run figure to net position.
  factory RunLadder.fromJson(Map<String, dynamic> json) {
    final raw = json['run_pl_json'];
    if (raw is! Map) return empty;

    final rungs = <RunRung>[];
    raw.forEach((key, value) {
      final run = int.tryParse(key.toString());
      if (run != null) {
        rungs.add(RunRung(run: run, profitLoss: Money.toDouble(value)));
      }
    });
    rungs.sort((a, b) => a.run.compareTo(b.run));
    return RunLadder(rungs);
  }

  bool get isEmpty => rungs.isEmpty;

  /// The run the book stands to lose most on. That is the figure an operator
  /// is watching, so the strip flags it rather than making them scan for it.
  RunRung? get worst {
    if (rungs.isEmpty) return null;
    return rungs.reduce((a, b) => a.profitLoss <= b.profitLoss ? a : b);
  }
}

/// The four figures a session is settled on.
class SessionTotals {
  const SessionTotals({
    required this.kTotal,
    required this.lTotal,
    required this.ourKl,
    required this.commission,
  });

  final double kTotal;
  final double lTotal;
  final double ourKl;
  final double commission;

  static const empty = SessionTotals(kTotal: 0, lTotal: 0, ourKl: 0, commission: 0);

  factory SessionTotals.fromJson(Map<String, dynamic> json) => SessionTotals(
        kTotal: Money.toDouble(json['k_total']),
        lTotal: Money.toDouble(json['l_total']),
        ourKl: Money.toDouble(json['our_kl']),
        commission: Money.toDouble(json['com_total']),
      );
}
