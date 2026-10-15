import '../../core/network/api_client.dart';
import '../../core/util/app_time.dart';
import '../models/bet_entry.dart';
import '../models/match.dart';
import '../models/match_totals.dart';
import '../models/run_ladder.dart';
import '../models/settlement.dart';
import '../models/party.dart';

/// Reading and writing the match book.
///
/// The four game types share one shape here on purpose: the endpoints differ
/// only by a slug, so one board screen can serve all of them rather than four
/// near-copies drifting apart.
class MatchRepository {
  MatchRepository(this._api);

  final ApiClient _api;

  Future<List<GameMatch>> activeMatches(GameType game) async {
    final body = await _api.get(game.activeListPath);
    // Each of these paths returns one kind of match, and the cup ones carry no
    // `game` field - so the kind is stamped from the path that was asked for
    // rather than guessed from the payload.
    return asList(body)
        .whereType<Map>()
        .map((e) => GameMatch.fromJson(Map<String, dynamic>.from(e), game: game))
        .toList();
  }

  Future<MatchTotals> totals(GameMatch match) async {
    final slug = match.game.slug;
    final body = await _api.get('/soda/$slug/${match.id}/${slug}_totals/');
    return MatchTotals.fromJson(asMap(body), nationNames: match.selectableNations);
  }

  /// The book itself - today's list, newest first the way the board reads.
  Future<List<BetEntry>> entries(GameMatch match) async {
    final slug = match.game.slug;
    final body = await _api.get('/soda/$slug/${match.id}/${slug}_soda/');
    final data = asMap(body);

    // The soda endpoints wrap their rows under `entries`; some answer with a
    // bare list, so both are accepted.
    final rows = data['entries'] is List
        ? (data['entries'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : asList(body);

    final entries = rows.map(BetEntry.fromJson).toList()
      ..sort((a, b) => b.rowNo.compareTo(a.rowNo));
    return entries;
  }

  /// Places a bet. [nation] is a side for a one day, test or cup; [run] is the
  /// figure for a session.
  Future<void> createEntry({
    required GameMatch match,
    required int clientId,
    required BetType betType,
    required double amount,
    required double rate,
    String? nation,
    int? run,
  }) async {
    final payload = <String, dynamic>{
      'match': match.id,
      // Sent in the operator's own timezone, so the entry lands on the day
      // they are actually working.
      'entry_date': AppTime.apiDate(DateTime.now()),
      'bet_type': betType.code,
      'amount': amount,
      'rate': rate,
      'client': clientId,
      'is_ptrn_entry': match.ptrnEnabled,
    };
    if (run != null) {
      payload['run'] = run;
    } else if (nation != null) {
      payload['nation'] = nation;
    }
    // A Bombay leg on a one day names no side: the key is left out entirely so
    // the server fills it in. Sending it as null is rejected before that
    // fallback is ever reached.

    await _api.post('/soda/${match.game.slug}/', data: payload);
  }

  Future<void> updateEntry({
    required GameMatch match,
    required int entryId,
    required Map<String, dynamic> changes,
  }) =>
      _api.patch('/soda/${match.game.slug}/$entryId/', data: changes);

  Future<void> deleteEntry({required GameMatch match, required int entryId}) =>
      _api.delete('/soda/${match.game.slug}/$entryId/');

  /// A session's ladder - the position at every run figure in range.
  ///
  /// This is a list-level action taking the match as a query parameter, unlike
  /// the other board endpoints, so it does not follow the `{id}` shape.
  Future<RunLadder> runLadder(GameMatch match) async {
    final body = await _api.get('/soda/session/run_exposure/', query: {'match': match.id});
    return RunLadder.fromJson(asMap(body));
  }

  /// The same ladder, over every run the book reaches rather than the window
  /// around the action.
  ///
  /// `run_exposure` trims to what matters right now, which is what the board
  /// strip wants. This is the whole table - thousands of rungs - for when the
  /// question is about a figure far from where play currently is.
  Future<RunLadder> runWise(GameMatch match) async {
    final body = await _api.get('/soda/session/run_wise/', query: {'match': match.id});
    return RunLadder.fromJson(asMap(body));
  }

  /// The four figures a session settles on.
  Future<SessionTotals> sessionTotals(GameMatch match) async {
    final body = await _api.get('/soda/session/${match.id}/session_totals/');
    return SessionTotals.fromJson(asMap(body));
  }

  /// House accounts a match can be settled against.
  Future<List<LedgerAccount>> accounts() async {
    // Every page: the list is paged ten at a time, which hid accounts past
    // the tenth from the close-match picker.
    final rows = await _api.getAll('/master/accounts/');
    return rows.map(LedgerAccount.fromJson).toList();
  }

  /// What closing the match would move, without closing it.
  ///
  /// The same endpoint answers GET as a preview and POST as the close, so the
  /// figures an operator approves are the figures that get written.
  Future<Settlement> settlementPreview({
    required GameMatch match,
    required String winSelection,
    int? plAccountId,
  }) async {
    final slug = match.game.slug;
    final body = await _api.get('/soda/$slug/${match.id}/settlement/', query: {
      'win_nation': winSelection,
      'pl_account_id': ?plAccountId,
    });
    return Settlement.fromJson(asMap(body));
  }

  /// Settles the match. Everything after this is a recall, not an edit.
  Future<void> closeMatch({
    required GameMatch match,
    required String winSelection,
    required int plAccountId,
    DateTime? date,
  }) async {
    final slug = match.game.slug;
    await _api.post('/soda/$slug/${match.id}/close_$slug/', data: {
      'win_score': winSelection,
      'pl_account_id': plAccountId,
      if (date != null) 'date': AppTime.apiDate(date),
    });
  }

  /// Where a cup stands: who is still in, who is out, and whether it has
  /// already resolved.
  Future<CupProgress> cupProgress(GameMatch cup) async {
    final body = await _api.get('/soda/cup/${cup.id}/close_cup/');
    return CupProgress.fromJson(asMap(body));
  }

  /// Declares one cup result.
  ///
  /// [nation] is the team going OUT for every round but the last; with two
  /// teams left it is the WINNER instead. The server knows which of the two it
  /// is being told from how many teams are still pending, and settles the
  /// other side accordingly.
  Future<void> declareCupResult({
    required GameMatch cup,
    required String nation,
    required int plAccountId,
  }) async {
    await _api.post('/soda/cup/${cup.id}/close_cup/', data: {
      'win_score': nation,
      'pl_account_id': plAccountId,
    });
  }

  /// Flips one of the desk switches on a match.
  ///
  /// Commission, partnerships and the party book are properties of the match,
  /// not of a single bet: every entry placed afterwards is written against
  /// whatever they read at that moment. Only the changed flag is sent, so this
  /// cannot disturb anything else on the match.
  Future<void> setMatchFlags({
    required GameMatch match,
    bool? commissionEnabled,
    bool? ptrnEnabled,
    bool? partyBookEnabled,
  }) async {
    final data = <String, dynamic>{
      'commission_enabled': ?commissionEnabled,
      'ptrn_enabled': ?ptrnEnabled,
      'party_book_enabled': ?partyBookEnabled,
    };
    if (data.isEmpty) return;

    final path = match.game == GameType.cup ? 'cups' : 'matches';
    await _api.patch('/master/$path/${match.id}/', data: data);
  }

  /// Parties available to bet for. Loaded once and searched on the device, so
  /// the client-code field answers instantly rather than per keystroke.
  Future<List<Party>> parties() async {
    // Every page: a company with more than a hundred parties had the rest
    // missing from client codes, Party Master and every picker.
    final rows = await _api.getAll('/master/parties/');
    return rows
        .map(Party.fromJson)
        .where((p) => p.isActive)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }
}
