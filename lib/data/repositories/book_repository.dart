import '../../core/network/api_client.dart';
import '../models/bet_entry.dart';
import '../models/book_row.dart';
import '../models/ledger_row.dart';
import '../models/match.dart';

/// The books and the ledgers - everything that reads the money rather than
/// placing it.
class BookRepository {
  BookRepository(this._api);

  final ApiClient _api;

  Future<MatchBook> book(GameMatch match, BookKind kind) async {
    final slug = match.game.slug;
    final body = await _api.get('/soda/$slug/${match.id}/${slug}_${kind.suffix}/');
    return MatchBook.fromJson(asMap(body));
  }

  /// Every bet one party has on this match.
  ///
  /// The books show a party as a single line; this is what that line is made
  /// of, which is what gets asked for when a figure is queried. Test matches
  /// have no such endpoint, so the books do not offer the drill-down there.
  Future<List<BetEntry>> partySoda({
    required GameMatch match,
    required int partyId,
  }) async {
    final slug = match.game.slug;
    final body = await _api.get(
      '/soda/$slug/${match.id}/${slug}_party_soda/',
      query: {'party_id': partyId},
    );
    final rows = asMap(body)['entries'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((e) => BetEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Whether [match] supports the per-party drill-down at all.
  static bool supportsPartySoda(GameMatch match) => match.game != GameType.test;

  /// A party's statement, newest first.
  Future<List<LedgerRow>> ledger({
    required int partyId,
    DateTime? from,
    DateTime? to,
  }) async {
    final body = await _api.get('/master/parties/$partyId/ledger/', query: {
      if (from != null) 'from_date': _apiDate(from),
      if (to != null) 'to_date': _apiDate(to),
    });
    return asList(body).map(LedgerRow.fromJson).toList();
  }

  /// Removes the record a statement line was rendered from.
  ///
  /// The line itself is not a record - it comes from a havala, a clearing
  /// voucher or an opening balance, and each lives in its own book. [row] knows
  /// which; a line settled out of a match knows none and is refused here rather
  /// than sent somewhere it does not belong.
  Future<void> deleteLedgerRow(LedgerRow row) async {
    final target = row.deleteTarget;
    if (target == null) {
      throw StateError('This line was settled from a match and cannot be '
          'removed here. Recall the match instead.');
    }
    await _api.delete('${target.path}${target.id}/');
  }

  String _apiDate(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}
