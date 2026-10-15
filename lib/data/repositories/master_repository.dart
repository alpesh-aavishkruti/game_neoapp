import '../../core/network/api_client.dart';
import '../models/match.dart';

/// The masters and the audit trails - everything behind More.
///
/// They are all list-shaped and read-only in this app, so one repository
/// serves them rather than ten near-identical ones.
class MasterRepository {
  MasterRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> organisationSettings() async =>
      asMap(await _api.get('/organization-settings'));

  /// Every row of a master list - all pages, not just the first hundred.
  Future<List<Map<String, dynamic>>> rows(String path, {Map<String, dynamic>? query}) =>
      _api.getAll(path, query: query);

  /// Matches that were closed and can be reopened.
  /// Everything a result can be taken back off - matches and cups, open or
  /// settled, the way the desk lists them.
  ///
  /// Settled ones are the point of the screen, but an open one is listed too:
  /// that is what the desk shows, and recalling one simply finds nothing to
  /// reverse. Cups live at their own path and carry no `game` field, so they
  /// are fetched separately and stamped.
  Future<List<GameMatch>> recallableMatches() async {
    final matches = await rows('/master/matches/');
    final cups = await rows('/master/cups/');

    return [
      ...matches.map(GameMatch.fromJson),
      ...cups.map((row) => GameMatch.fromJson(row, game: GameType.cup)),
    ]..sort((a, b) {
        // Newest first, by when it closed if it did and when it was made if
        // it has not.
        final left = a.closeDate ?? a.createdAt;
        final right = b.closeDate ?? b.createdAt;
        if (left == null || right == null) return b.id.compareTo(a.id);
        return right.compareTo(left);
      });
  }

  /// Removes a match or cup outright. Each lives at its own path.
  Future<void> deleteMatch(GameMatch match) => _api.delete(
        match.game == GameType.cup
            ? '/master/cups/${match.id}/'
            : '/master/matches/${match.id}/',
      );

  /// Reopens a settled match. The settlement is reversed in every party
  /// ledger, which is why the screen confirms before calling this.
  Future<void> recallMatch(int matchId) =>
      _api.post('/master/matches/$matchId/recall_match/');

  Future<void> recallCup(int cupId) => _api.post('/soda/cup/$cupId/recall_cup/');

  /// The bin's three actions.
  ///
  /// All of them are list-level and name the record in the body - the bin
  /// holds several kinds of voucher, so an id alone does not say which table
  /// to look in.
  Future<void> restoreDeleted({required String recordType, required int id}) =>
      _api.post('/soda/recycle-bin/restore/',
          data: {'record_type': recordType, 'id': id});

  Future<void> permanentlyDelete({required String recordType, required int id}) =>
      _api.post('/soda/recycle-bin/permanent-delete/',
          data: {'record_type': recordType, 'id': id});

  Future<void> emptyRecycleBin() => _api.post('/soda/recycle-bin/empty/');
}
