import '../../core/util/money.dart';
import 'match.dart';

/// How much of a party's line has been ticked off.
enum CheckState {
  none,
  some,
  all;

  static CheckState parse(dynamic raw) => switch (raw?.toString().toLowerCase()) {
        'all' => CheckState.all,
        'some' || 'partial' => CheckState.some,
        _ => CheckState.none,
      };
}

/// One party's line in a book, with a figure per side of the match.
class BookRow {
  const BookRow({
    required this.partyId,
    required this.code,
    required this.name,
    required this.figures,
    this.commission = 0,
    this.checkState = CheckState.none,
  });

  final int partyId;
  final String code;
  final String name;

  /// One per side, in the same order as the match's sides.
  final List<double> figures;

  final double commission;

  /// Whether every bet behind this line has been ticked, some of them, or
  /// none. Kept on the server, so the desk and the phone agree.
  final CheckState checkState;

  factory BookRow.fromJson(Map<String, dynamic> json) {
    // A session's books are ruled K and L rather than by team, and its rows
    // say so - there is no nation figure on them at all.
    if (json.containsKey('k_total') || json.containsKey('l_total')) {
      return BookRow(
        partyId: int.tryParse('${json['party_id']}') ?? 0,
        code: (json['party_code'] ?? '').toString().trim().toUpperCase(),
        name: (json['party_name'] ?? json['code_party_name'] ?? '').toString().trim(),
        figures: [
          Money.toDouble(json['k_total']),
          Money.toDouble(json['l_total']),
        ],
        commission: Money.toDouble(json['comm_total'] ?? json['comm']),
        checkState: CheckState.parse(json['check_status']),
      );
    }

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
      checkState: CheckState.parse(json['check_status']),
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
    // A test's third column is the draw and is named for it; a cup numbers
    // its teams. Reading only `total_c` left the draw total blank while its
    // own rows plainly showed figures.
    if (json.containsKey('total_draw')) {
      totals.add(Money.toDouble(json['total_draw']));
    } else if (json.containsKey('total_c')) {
      totals.add(Money.toDouble(json['total_c']));
    }
    for (var i = 3; i <= 10; i++) {
      if (json.containsKey('total_$i')) totals.add(Money.toDouble(json['total_$i']));
    }

    // A session's book sends no totals of its own, so they are added up from
    // the rows rather than left reading zero under figures that are not.
    if (totals.every((t) => t == 0) && rows.isNotEmpty) {
      final width = rows.first.figures.length;
      return MatchBook(
        rows: rows,
        totals: [
          for (var i = 0; i < width; i++)
            rows.fold<double>(
              0,
              (sum, r) => sum + (i < r.figures.length ? r.figures[i] : 0),
            ),
        ],
      );
    }

    return MatchBook(rows: rows, totals: totals);
  }

  /// The soda book, which answers with the bets rather than a line per party.
  ///
  /// Each bet becomes a row carrying the client who placed it and what it does
  /// to each side, so the tab reads like the other three books instead of
  /// showing nothing at all.
  factory MatchBook.fromSodaJson(Map<String, dynamic> json) {
    final entries = json['entries'];
    final rows = entries is List
        ? entries.whereType<Map>().map((raw) {
            final e = Map<String, dynamic>.from(raw);
            return BookRow(
              partyId: int.tryParse('${e['client']}') ?? 0,
              code: (e['client_code'] ?? '').toString().trim().toUpperCase(),
              // The bet itself, so a row says what it is and not only whose.
              name: [
                e['bet_label'] ??
                    (e.containsKey('run') ? 'Run ${e['run']} ${e['bet_type']}' : null),
                e['amount'],
                '@',
                e['rate'],
              ]
                  .where((x) => (x ?? '').toString().trim().isNotEmpty)
                  .join(' '),
              // A session bet is taken one way or the other on a run figure,
              // so it lands in the K column or the L one - the same two the
              // rest of a session's books are ruled by.
              figures: e.containsKey('run')
                  ? [
                      if ((e['bet_type'] ?? '').toString().toUpperCase() == 'K')
                        Money.toDouble(e['amount'])
                      else
                        0.0,
                      if ((e['bet_type'] ?? '').toString().toUpperCase() == 'L')
                        Money.toDouble(e['amount'])
                      else
                        0.0,
                    ]
                  : [
                      Money.toDouble(e['nation1_pl']),
                      Money.toDouble(e['nation2_pl']),
                      if (e.containsKey('nation3_pl'))
                        Money.toDouble(e['nation3_pl']),
                    ],
              commission: Money.toDouble(e['commission_amount']),
            );
          }).toList()
        : <BookRow>[];

    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};

    return MatchBook(
      rows: rows,
      totals: [
        Money.toDouble(totals['nation1_pl']),
        Money.toDouble(totals['nation2_pl']),
        if (totals.containsKey('nation3_pl')) Money.toDouble(totals['nation3_pl']),
      ],
    );
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

  /// The books this match actually keeps.
  ///
  /// A session has no bookie book - the desk does not offer one and the server
  /// has no endpoint for it, so showing the tab left it loading for ever.
  static List<BookKind> forGame(GameType game) => game == GameType.session
      ? const [BookKind.party, BookKind.soda, BookKind.partner]
      : BookKind.values;

  final String label;

  /// The action name under `/soda/{game}/{id}/{game}_{suffix}/`.
  final String suffix;
}
