import '../../core/util/money.dart';

/// One party's standing across the whole book.
class GeneralLine {
  const GeneralLine({
    required this.partyId,
    required this.code,
    required this.name,
    required this.amount,
    this.categoryId,
  });

  final int partyId;
  final String code;
  final String name;
  final double amount;

  /// Which category the party sits under, so the screen can be narrowed to one
  /// class of client the way the desk narrows it.
  final int? categoryId;

  factory GeneralLine.fromJson(Map<String, dynamic> json) => GeneralLine(
        partyId: int.tryParse('${json['party_id']}') ?? 0,
        code: (json['party_code'] ?? '').toString().trim().toUpperCase(),
        name: (json['party_name'] ?? '').toString().trim(),
        amount: Money.toDouble(json['amount']),
        categoryId: int.tryParse('${json['category_id']}'),
      );

  String get display => (name.isEmpty || name.toUpperCase() == code) ? code : '$code — $name';
}

/// Who owes the house and who the house owes, across every match.
///
/// This is the one screen that answers "where does the whole book stand"
/// rather than one match or one party. The two totals rarely match exactly -
/// the difference is what the house is carrying - so both are shown along
/// with that gap rather than a single net figure that hides it.
class GeneralView {
  const GeneralView({
    required this.give,
    required this.take,
    required this.totalGive,
    required this.totalTake,
  });

  /// Parties the house owes.
  final List<GeneralLine> give;

  /// Parties who owe the house.
  final List<GeneralLine> take;

  final double totalGive;
  final double totalTake;

  static const empty = GeneralView(give: [], take: [], totalGive: 0, totalTake: 0);

  factory GeneralView.fromJson(Map<String, dynamic> json) {
    List<GeneralLine> read(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => GeneralLine.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
    }

    return GeneralView(
      give: read('given_amounts'),
      take: read('take_amounts'),
      totalGive: Money.toDouble(json['total_give']),
      totalTake: Money.toDouble(json['total_take']),
    );
  }

  /// What the house is left holding once both sides are settled.
  double get difference => totalTake - totalGive;

  bool get isEmpty => give.isEmpty && take.isEmpty;
}
