import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/match.dart';
import '../../data/repositories/master_repository.dart';

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

final closedMatchesProvider = FutureProvider<List<GameMatch>>((ref) async {
  return ref.watch(masterRepositoryProvider).closedMatches();
});
