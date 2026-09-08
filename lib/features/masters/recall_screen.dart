import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/match.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import '../matches/match_providers.dart';
import 'master_providers.dart';

/// Reopening a match that was closed too early.
///
/// A recall reverses the settlement across every party ledger, so this never
/// happens on a single tap: the dialog states what will change, and who closed
/// the match and when, before anything is undone.
class RecallScreen extends ConsumerStatefulWidget {
  const RecallScreen({super.key});

  @override
  ConsumerState<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends ConsumerState<RecallScreen> {
  int? _busyId;

  /// Removes the match or cup itself.
  ///
  /// Recalling reopens a result; this takes the whole game away, along with
  /// every entry on it - so it is named plainly and asked for separately.
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(GameMatch match) async {
    // Taken before the dialog: after it, this context may be gone.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${match.title}?'),
        content: const Text(
          'The game and every entry on it go to the recycle bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = match.id);
    try {
      await ref.read(masterRepositoryProvider).deleteMatch(match);
      ref.invalidate(recallableMatchesProvider);
      for (final game in GameType.values) {
        ref.invalidate(activeMatchesProvider(game));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete that game.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _recall(GameMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.history, color: context.scheme.primary),
        title: Text('Recall ${match.title}?'),
        content: Text(
          'The match reopens for entries and its settlement is reversed in '
          'every party ledger.'
          '${match.closeDate == null ? '' : '\n\nClosed ${AppTime.date(match.closeDate)}.'}'
          '\n\nThis is recorded in edit history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Recall'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = match.id);
    try {
      final repo = ref.read(masterRepositoryProvider);
      if (match.game == GameType.cup) {
        await repo.recallCup(match.id);
      } else {
        await repo.recallMatch(match.id);
      }

      ref.invalidate(recallableMatchesProvider);
      // The match is open again, so the lists that only show open matches
      // have to be told.
      for (final game in GameType.values) {
        ref.invalidate(activeMatchesProvider(game));
      }
      _say('${match.title} reopened.');
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(recallableMatchesProvider);
    final term = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recall entry'),
            Text(
              'Matches and cups',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(recallableMatchesProvider.future),
        child: AsyncView(
          value: matches,
          onRetry: () => ref.invalidate(recallableMatchesProvider),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'Nothing closed yet',
          emptyMessage: 'Matches you settle will appear here.',
          builder: (list) {
            final shown = [
              for (final m in list)
                if (term.isEmpty ||
                    '${m.title} ${m.game.label} ${m.winNation ?? ''}'
                        .toLowerCase()
                        .contains(term))
                  m,
            ];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search a match or cup',
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: term.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      term.isEmpty
                          ? '${list.length} records'
                          : '${shown.length} of ${list.length}',
                      style: context.text.labelSmall,
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('Nothing matches that',
                          style: context.text.bodyMedium),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: shown.length,
                      itemBuilder: (context, i) => _RecallRow(
                        match: shown[i],
                        busy: _busyId == shown[i].id,
                        onRecall: () => _recall(shown[i]),
                        onDelete: () => _delete(shown[i]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecallRow extends StatelessWidget {
  const _RecallRow({
    required this.match,
    required this.busy,
    required this.onRecall,
    required this.onDelete,
  });

  final GameMatch match;
  final bool busy;
  final VoidCallback onRecall;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          StatusChip(match.game.label),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    if (!match.isSettled)
                      'Open'
                    else if (match.winNation?.isNotEmpty == true)
                      'Won by ${match.winNation}',
                    if (match.closeDate != null) 'closed ${AppTime.date(match.closeDate)}',
                    if (match.isSettled && match.closeDate == null) 'settled',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            OutlinedButton(
              onPressed: onRecall,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: context.scheme.primary,
                side: BorderSide(color: context.scheme.primary.withValues(alpha: 0.5)),
              ),
              child: const Text('Recall', style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: book.muted,
            tooltip: 'Delete',
            onPressed: busy ? null : onDelete,
          ),
        ],
      ),
    );
  }
}
