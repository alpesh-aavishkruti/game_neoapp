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

      ref.invalidate(closedMatchesProvider);
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
    final matches = ref.watch(closedMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recall entry'),
            Text(
              'Closed matches and cups',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(closedMatchesProvider.future),
        child: AsyncView(
          value: matches,
          onRetry: () => ref.invalidate(closedMatchesProvider),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'Nothing closed yet',
          emptyMessage: 'Matches you settle will appear here.',
          builder: (list) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, i) => _ClosedMatchRow(
              match: list[i],
              busy: _busyId == list[i].id,
              onRecall: () => _recall(list[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedMatchRow extends StatelessWidget {
  const _ClosedMatchRow({
    required this.match,
    required this.busy,
    required this.onRecall,
  });

  final GameMatch match;
  final bool busy;
  final VoidCallback onRecall;

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
                    if (match.winNation?.isNotEmpty == true) 'Won by ${match.winNation}',
                    if (match.closeDate != null) 'closed ${AppTime.date(match.closeDate)}',
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
        ],
      ),
    );
  }
}
