import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/match.dart';
import '../../data/repositories/master_repository.dart';
import '../matches/match_providers.dart';

final masterRepositoryProvider = Provider<MasterRepository>(
  (ref) => MasterRepository(ref.watch(apiClientProvider)),
);

/// The company's own name, for the account card. Failing to load it must not
/// take the More screen down, so it answers null instead of throwing.
final organisationNameProvider = FutureProvider<String?>((ref) async {
  try {
    final settings = await ref.watch(masterRepositoryProvider).organisationSettings();
    final name = (settings['company_name'] ?? '').toString().trim();
    return name.isEmpty ? null : name;
  } on ApiException {
    return null;
  }
});

/// Any master list, keyed by its path so each is cached on its own.
final masterRowsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, path) async {
  return ref.watch(masterRepositoryProvider).rows(path, query: {'page_size': 200});
});

/// Reloads a master list after a row was added, changed or deleted.
///
/// Matches and cups also feed the Matches tab, which is kept alive behind
/// the bottom bar - so a match made from Match master stayed off it until
/// something else happened to reload it.
void refreshMasterRows(WidgetRef ref, String path) {
  ref.invalidate(masterRowsProvider(path));
  if (path == '/master/matches/' || path == '/master/cups/') {
    ref.invalidate(activeMatchesProvider);
  }
}

/// Matches and cups a result can be taken back off.
final recallableMatchesProvider = FutureProvider<List<GameMatch>>((ref) async {
  return ref.watch(masterRepositoryProvider).recallableMatches();
});
