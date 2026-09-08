import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/bet_entry.dart';
import '../../data/models/book_row.dart';
import '../../data/models/match.dart';
import '../../shared/widgets/async_view.dart';
import '../dashboard/widgets/entry_row.dart';
import '../money/ledger_screen.dart';

final _partySodaProvider = FutureProvider.autoDispose
    .family<List<BetEntry>, ({GameMatch match, int partyId})>((ref, args) {
  return ref.watch(bookRepositoryProvider).partySoda(
        match: args.match,
        partyId: args.partyId,
      );
});

/// Every bet one party holds on this match.
///
/// The books show a party as a single line. When a figure is queried - and it
/// is, constantly - the answer is the bets behind that line, so this is opened
/// straight from the row rather than filed under a menu somewhere.
class PartySodaScreen extends ConsumerWidget {
  const PartySodaScreen({super.key, required this.match, required this.row});

  final GameMatch match;
  final BookRow row;

  static Future<void> open(
    BuildContext context, {
    required GameMatch match,
    required BookRow row,
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PartySodaScreen(match: match, row: row),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (match: match, partyId: row.partyId);
    final entries = ref.watch(_partySodaProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.name.isEmpty || row.name.toUpperCase() == row.code
                  ? row.code
                  : '${row.code} — ${row.name}',
              style: context.text.titleLarge?.copyWith(fontSize: 17),
            ),
            Text(
              '${match.title} · this party only',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_partySodaProvider(args).future),
        child: AsyncView(
          value: entries,
          onRetry: () => ref.invalidate(_partySodaProvider(args)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'No bets for this party',
          emptyMessage: 'They hold a figure on the book but nothing on this match.',
          builder: (list) => Column(
            children: [
              EntryHeader(
                subjectLabel: match.game == GameType.session
                    ? 'Run / client'
                    : 'Nation / client',
                // Read-only here: a bet is edited on the board it was placed
                // from, so there are no buttons to leave room for.
                hasActions: false,
              ),
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: list.length,
                  // Read-only: a bet is edited on the board it was placed
                  // from, so there is one place where that happens.
                  itemBuilder: (context, i) => EntryRow(entry: list[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
