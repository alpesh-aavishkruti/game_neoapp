import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/bet_entry.dart';
import '../../data/models/match.dart';
import '../../data/models/match_totals.dart';
import '../../data/models/party.dart';
import '../../data/models/run_ladder.dart';
import '../../data/repositories/match_repository.dart';

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref.watch(apiClientProvider)),
);

/// Open matches of one kind. Keyed by game so all four tabs can be in memory
/// at once and switching between them is instant.
final activeMatchesProvider =
    FutureProvider.family<List<GameMatch>, GameType>((ref, game) async {
  return ref.watch(matchRepositoryProvider).activeMatches(game);
});

/// Every party, deactivated ones included. Only Party Master shows these; the
/// rest of the app reads [partiesProvider]. Invalidate this one to re-read
/// parties - [partiesProvider] follows it.
final allPartiesProvider = FutureProvider<List<Party>>((ref) async {
  return ref.watch(matchRepositoryProvider).allParties();
});

/// The parties list, loaded once and reused by every client-code field and
/// picker. A deactivated party is left out of all of them.
final partiesProvider = FutureProvider<List<Party>>((ref) async {
  final all = await ref.watch(allPartiesProvider.future);
  return all.where((p) => p.isActive).toList();
});

/// Everything one board needs, fetched together so the tiles and the rows
/// never disagree about which state of the book they are showing.
class BoardData {
  const BoardData({
    required this.totals,
    required this.entries,
    this.ladder = RunLadder.empty,
    this.sessionTotals = SessionTotals.empty,
  });

  final MatchTotals totals;
  final List<BetEntry> entries;

  /// Only a session board carries these; the others leave them empty.
  final RunLadder ladder;
  final SessionTotals sessionTotals;
}

final boardProvider =
    FutureProvider.family<BoardData, GameMatch>((ref, match) async {
  final repo = ref.watch(matchRepositoryProvider);

  // A session board reads a run ladder instead of per-side positions, so it
  // fetches two more things - all at once, so the figures on screen always
  // describe the same state of the book.
  if (match.game == GameType.session) {
    final results = await Future.wait([
      repo.totals(match),
      repo.entries(match),
      repo.runLadder(match),
      repo.sessionTotals(match),
    ]);
    return BoardData(
      totals: results[0] as MatchTotals,
      entries: results[1] as List<BetEntry>,
      ladder: results[2] as RunLadder,
      sessionTotals: results[3] as SessionTotals,
    );
  }

  final results = await Future.wait([repo.totals(match), repo.entries(match)]);
  return BoardData(
    totals: results[0] as MatchTotals,
    entries: results[1] as List<BetEntry>,
  );
});
