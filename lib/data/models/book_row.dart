import '../../core/util/money.dart';

/// One party's line in a book, with a figure per side of the match.
class BookRow {
  const BookRow({
    required this.partyId,
    required this.code,
    required this.name,
    required this.figures,
    this.commission = 0,
  });

  final int partyId;
  final String code;
  final String name;

  /// One per side, in the same order as the match's sides.
  final List<double> figures;

  final double commission;

  factory BookRow.fromJson(Map<String, dynamic> json) {
    final figures = <double>[
      Money.toDouble(json['nation1_pl']),
      Money.toDouble(json['nation2_pl']),
    ];
    // A test board carries a third column; a cup carries one per team.
    if (json.containsKey('draw_pl')) figures.add(Money.toDouble(json['draw_pl']));
    for (var i = 3; i <= 10; i++) {
      if (json.containsKey('nation${i}_pl')) {
        figures.add(Money.toDouble(json['nation${i}_pl']));
      }
    }

    return BookRow(
      partyId: int.tryParse('${json['party_id']}') ?? 0,
      code: (json['party_code'] ?? '').toString().trim().toUpperCase(),
      name: (json['party_name'] ?? json['code_party_name'] ?? '').toString().trim(),
      figures: figures,
      commission: Money.toDouble(json['comm']),
    );
  }
}

/// A whole book: the rows, plus the totals that must stay pinned.
class MatchBook {
  const MatchBook({required this.rows, required this.totals});

  final List<BookRow> rows;

  /// The grand total per side. Kept in view however far the list scrolls,
  /// because it is the figure the book is checked against.
  final List<double> totals;

  static const empty = MatchBook(rows: [], totals: []);

  factory MatchBook.fromJson(Map<String, dynamic> json) {
    final rows = (json['parties'] is List)
        ? (json['parties'] as List)
            .whereType<Map>()
            .map((e) => BookRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <BookRow>[];

    final totals = <double>[
      Money.toDouble(json['total_a']),
      Money.toDouble(json['total_b']),
    ];
    if (json.containsKey('total_c')) totals.add(Money.toDouble(json['total_c']));

    return MatchBook(rows: rows, totals: totals);
  }
}

/// The four books a match keeps. They are separate windows on the desk; here
/// they are tabs on one screen, because they are four views of one thing.
enum BookKind {
  party('Party', 'partybook'),
  soda('Soda', 'soda'),
  bookie('Bookie', 'bookie_book'),
  partner('PTRN', 'partnerbook');

  const BookKind(this.label, this.suffix);

  final String label;

  /// The action name under `/soda/{game}/{id}/{game}_{suffix}/`.
  final String suffix;
}
