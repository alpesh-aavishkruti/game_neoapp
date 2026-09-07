import '../../core/util/money.dart';

/// A client, bookie or partner in the book.
class Party {
  const Party({
    required this.id,
    required this.code,
    required this.name,
    this.categoryName,
    this.brokeragePercent,
    this.balance,
    this.isBookie = false,
    this.isActive = true,
  });

  final int id;
  final String code;
  final String name;
  final String? categoryName;
  final double? brokeragePercent;

  /// Only present on the listings that carry it; null means "not loaded"
  /// rather than "zero", so a screen can tell the difference.
  final double? balance;

  final bool isBookie;
  final bool isActive;

  factory Party.fromJson(Map<String, dynamic> json) => Party(
        id: int.tryParse('${json['id']}') ?? 0,
        code: (json['party_code'] ?? '').toString().trim().toUpperCase(),
        name: (json['party_name'] ?? '').toString().trim(),
        categoryName: _readCategory(json),
        // Neither of these is on the party list endpoint today. They stay
        // nullable rather than defaulting to zero, so a row shows nothing
        // instead of claiming a balance of nil.
        brokeragePercent: json['brokerage_percent'] == null
            ? null
            : Money.toDouble(json['brokerage_percent']),
        balance: json['balance'] == null ? null : Money.toDouble(json['balance']),
        isBookie: json['is_bookie'] == true,
        isActive: json['is_active'] != false,
      );

  /// Category arrives as a many-to-many list, not a single object - and older
  /// payloads sent a flat name. Read whichever shape turned up.
  static String? _readCategory(Map<String, dynamic> json) {
    final flat = json['category_name'];
    if (flat != null && flat.toString().trim().isNotEmpty) return flat.toString().trim();

    final category = json['category'];
    if (category is List) {
      final names = category
          .map((e) => e is Map ? e['category_name'] : e)
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .map((e) => e.toString().trim());
      return names.isEmpty ? null : names.join(', ');
    }
    if (category is Map) {
      final name = category['category_name']?.toString().trim();
      return (name == null || name.isEmpty) ? null : name;
    }
    return null;
  }

  /// `RAJ01 — Rajesh Traders`, the way the desk system names a party. Some
  /// parties are entered with the code as the name; those read as just the one.
  String get display =>
      (name.isEmpty || name.toUpperCase() == code) ? code : '$code — $name';

  /// The initials shown in a list avatar.
  String get initials {
    final source = code.isNotEmpty ? code : name;
    return source.length <= 2 ? source.toUpperCase() : source.substring(0, 2).toUpperCase();
  }

  /// What to show back when someone types this party's code.
  ///
  /// The name comes first and always: the point of a confirmation is to say
  /// something the operator did not just type, so echoing the code back
  /// confirms nothing. Category and brokerage follow when the endpoint
  /// returned them, which today it does not.
  String get confirmation {
    final parts = <String>[
      if (name.isNotEmpty && name.toUpperCase() != code) name else code,
      if (categoryName?.isNotEmpty == true) 'Cat $categoryName',
      if (brokeragePercent != null) 'Brok ${Money.format(brokeragePercent, decimals: 1)}%',
      if (isBookie) 'Bookie',
    ];
    return parts.join(' · ');
  }

  /// What sits under the name on a party row: category and brokerage, when
  /// the endpoint returned them.
  String get subtitle {
    final parts = <String>[code];
    if (categoryName?.isNotEmpty == true) parts.add('Cat $categoryName');
    if (brokeragePercent != null) parts.add('Brok ${Money.format(brokeragePercent, decimals: 1)}%');
    return parts.join(' · ');
  }
}
