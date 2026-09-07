import '../../core/util/app_time.dart';
import '../../core/util/money.dart';

/// Which way a bet was taken.
enum BetType {
  /// Lena - taken in your favour.
  l('L', 'L — Lena'),

  /// Khana - taken against.
  k('K', 'K — Khana'),

  /// A Bombay leg, which settles differently and is never edited here.
  bombay('B', 'Bombay');

  const BetType(this.code, this.label);
  final String code;
  final String label;

  static BetType parse(dynamic raw) => switch (raw?.toString().toUpperCase()) {
        'K' => BetType.k,
        'B' => BetType.bombay,
        _ => BetType.l,
      };

  /// The two an operator can actually pick.
  static const selectable = [BetType.l, BetType.k];
}

/// One line in the book.
class BetEntry {
  const BetEntry({
    required this.id,
    required this.rowNo,
    required this.nation,
    required this.betType,
    required this.betLabel,
    required this.amount,
    required this.rate,
    required this.nation1Pl,
    required this.nation2Pl,
    required this.clientId,
    required this.clientCode,
    required this.clientName,
    this.run,
    this.isEdited = false,
    this.createdAt,
  });

  final int id;
  final int rowNo;

  /// The side the bet is on. On a session board this is empty and [run]
  /// carries the figure instead.
  final String nation;

  final BetType betType;

  /// The board's own shorthand, e.g. `I/L`. Comes from the server so the app
  /// never has to re-derive it.
  final String betLabel;

  final double amount;
  final double rate;

  final double nation1Pl;
  final double nation2Pl;

  final int? clientId;
  final String clientCode;
  final String clientName;

  /// Session boards bet on a run figure rather than a side.
  final int? run;

  /// Changed after it was taken. This has to stay visible - an edited entry
  /// must never be mistaken for an original.
  final bool isEdited;

  final DateTime? createdAt;

  factory BetEntry.fromJson(Map<String, dynamic> json) => BetEntry(
        id: int.tryParse('${json['id']}') ?? 0,
        rowNo: int.tryParse('${json['row_no']}') ?? 0,
        nation: (json['nation'] ?? '').toString().trim().toUpperCase(),
        betType: BetType.parse(json['bet_type'] ?? json['type']),
        betLabel: (json['bet_label'] ?? '').toString().trim(),
        amount: Money.toDouble(json['amount']),
        rate: Money.toDouble(json['rate'] ?? json['res']),
        nation1Pl: Money.toDouble(json['nation1_pl']),
        nation2Pl: Money.toDouble(json['nation2_pl']),
        clientId: int.tryParse('${json['client']}'),
        clientCode: (json['client_code'] ?? json['code'] ?? '').toString().trim().toUpperCase(),
        clientName: (json['client_name'] ?? '').toString().trim(),
        run: int.tryParse('${json['run']}'),
        isEdited: json['is_edited'] == true,
        createdAt: AppTime.toLocal(json['created_at']),
      );

  bool get isBombay => betType == BetType.bombay;

  /// What the row shows in its type column.
  String get label {
    if (isBombay) return 'BOMBAY';
    if (betLabel.isNotEmpty) return betLabel;
    if (run != null) return '$run / ${betType.code}';
    final initial = nation.isEmpty ? '' : nation[0];
    return '$initial/${betType.code}';
  }

  /// The heading a row sits under - the run on a session board, the side
  /// everywhere else.
  String get subject => run?.toString() ?? nation;
}
