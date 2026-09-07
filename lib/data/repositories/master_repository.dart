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

  Future<List<Map<String, dynamic>>> rows(String path, {Map<String, dynamic>? query}) async =>
      asList(await _api.get(path, query: query));

  /// Matches that were closed and can be reopened.
  Future<List<GameMatch>> closedMatches() async {
    final all = await rows('/master/matches/', query: {'page_size': 200});
    return all
        .map(GameMatch.fromJson)
        .where((m) => m.isSettled)
        .toList()
      ..sort((a, b) {
        final left = a.closeDate ?? a.createdAt;
        final right = b.closeDate ?? b.createdAt;
        if (left == null || right == null) return b.id.compareTo(a.id);
        return right.compareTo(left);
      });
  }

  /// Reopens a settled match. The settlement is reversed in every party
  /// ledger, which is why the screen confirms before calling this.
  Future<void> recallMatch(int matchId) =>
      _api.post('/master/matches/$matchId/recall_match/');

  Future<void> recallCup(int cupId) => _api.post('/soda/cup/$cupId/recall_cup/');

  Future<void> restoreDeleted(int id) => _api.post('/soda/recycle-bin/$id/restore/');
}
