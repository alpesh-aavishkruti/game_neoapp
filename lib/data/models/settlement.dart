import '../../core/util/money.dart';

/// One party's side of a settlement: what they pay, or what they are paid.
class SettlementLine {
  const SettlementLine({
    required this.partyId,
    required this.code,
    required this.name,
    required this.amount,
  });

  final int partyId;
  final String code;
  final String name;
  final double amount;

  factory SettlementLine.fromJson(Map<String, dynamic> json) => SettlementLine(
        partyId: int.tryParse('${json['party_id']}') ?? 0,
        code: (json['party_code'] ?? '').toString().trim().toUpperCase(),
        name: (json['party_name'] ?? '').toString().trim(),
        amount: Money.toDouble(json['amount']),
      );

  String get display => (name.isEmpty || name.toUpperCase() == code) ? code : '$code — $name';
}

/// What closing a match will move.
///
/// Shown before anything is committed: the two columns have to agree, and if
/// they do not, that is a reason to stop rather than to carry on.
class Settlement {
  const Settlement({
    required this.matchName,
    required this.winNationName,
    required this.take,
    required this.give,
    required this.takeTotal,
    required this.giveTotal,
  });

  final String matchName;
  final String winNationName;

  /// Parties who owe the house.
  final List<SettlementLine> take;

  /// Parties the house owes.
  final List<SettlementLine> give;

  final double takeTotal;
  final double giveTotal;

  factory Settlement.fromJson(Map<String, dynamic> json) {
    List<SettlementLine> read(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => SettlementLine.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Settlement(
      matchName: (json['match_name'] ?? '').toString().trim(),
      winNationName: (json['win_nation_name'] ?? json['win_nation'] ?? '').toString().trim(),
      take: read('take_money'),
      give: read('give_money'),
      takeTotal: Money.toDouble(json['take_total']),
      giveTotal: Money.toDouble(json['give_total']),
    );
  }

  /// The two sides must come out equal. They are computed by the server, so a
  /// mismatch here means something is wrong upstream and the close should not
  /// go ahead on the strength of this screen.
  bool get balances => (takeTotal - giveTotal).abs() < 0.005;

  bool get isEmpty => take.isEmpty && give.isEmpty;
}

/// Where a cup stands part-way through being declared.
///
/// A cup is not settled by naming a winner. Teams are knocked out one at a
/// time, each elimination settling that team's trades, and when a single team
/// is left the backend declares it champion by itself. Asking an operator who
/// won would let a cup be settled on a team that has not actually won yet.
class CupProgress {
  const CupProgress({
    required this.pending,
    required this.out,
    this.winner,
    this.winnerAutoDeclared = false,
  });

  /// Teams still in.
  final List<String> pending;

  /// Teams already knocked out, in the order they went.
  final List<String> out;

  /// Set once the cup has resolved.
  final String? winner;
  final bool winnerAutoDeclared;

  factory CupProgress.fromJson(Map<String, dynamic> json) {
    List<String> names(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .map((e) => e.toString().trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final winner = (json['winner_nation'] ?? '').toString().trim();
    return CupProgress(
      pending: names('pending_nations'),
      out: names('out_nations'),
      winner: winner.isEmpty ? null : winner.toUpperCase(),
      winnerAutoDeclared: json['winner_auto_declared'] == true,
    );
  }

  bool get isComplete => winner != null;

  /// True when knocking out one more team leaves a single side standing - so
  /// this elimination is also what crowns the champion.
  bool get isLastElimination => pending.length == 2;
}

/// A house account a match can be settled against.
class LedgerAccount {
  const LedgerAccount({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory LedgerAccount.fromJson(Map<String, dynamic> json) => LedgerAccount(
        id: int.tryParse('${json['id']}') ?? 0,
        code: (json['account_code'] ?? '').toString().trim(),
        name: (json['account_name'] ?? '').toString().trim(),
      );

  String get display => name.isEmpty ? code : '$code — $name';
}
