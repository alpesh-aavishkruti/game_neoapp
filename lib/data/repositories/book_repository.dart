import '../../core/network/api_client.dart';
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

  String _apiDate(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}
