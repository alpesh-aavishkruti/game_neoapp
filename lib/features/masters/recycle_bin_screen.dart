import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import 'master_providers.dart';

const _recycleBinPath = '/soda/recycle-bin/';

/// Deleted entries, and putting one back.
///
/// Restoring re-enters the amount into the book, so it confirms first - the
/// same care the delete itself takes.
class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  int? _busyId;

  Future<void> _restore(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;

    final label = (row['voucher_no'] ?? row['description'] ?? 'this entry').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this entry?'),
        content: Text('$label goes back into the book and the position is recalculated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = id);
    try {
      await ref.read(masterRepositoryProvider).restoreDeleted(id);
      ref.invalidate(masterRowsProvider(_recycleBinPath));
      _say('Entry restored.');
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
    final rows = ref.watch(masterRowsProvider(_recycleBinPath));

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle bin')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(masterRowsProvider(_recycleBinPath).future),
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(masterRowsProvider(_recycleBinPath)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'Nothing deleted',
          emptyMessage: 'Entries you delete can be put back from here.',
          builder: (list) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, i) => _DeletedRow(
              row: list[i],
              busy: _busyId == int.tryParse('${list[i]['id']}'),
              onRestore: () => _restore(list[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletedRow extends StatelessWidget {
  const _DeletedRow({required this.row, required this.busy, required this.onRestore});

  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    final kind = (row['record_type_label'] ?? row['record_type'] ?? '').toString().trim();
    final parties = (row['party_names'] ?? '').toString().trim();
    final deletedAt = AppTime.toLocal(row['deleted_at']);
    final deletedBy = (row['deleted_by'] is Map
            ? row['deleted_by']['username']
            : row['deleted_by'])
        ?.toString()
        .trim();
    final amount = Money.toDouble(row['dr_amount']) - Money.toDouble(row['cr_amount']);

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (kind.isNotEmpty) ...[
                      StatusChip(kind),
                      const SizedBox(width: 7),
                    ],
                    Expanded(
                      child: Text(
                        (row['voucher_no'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  (row['description'] ?? parties).toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (amount != 0) Money.format(amount.abs(), decimals: 0),
                    if (deletedAt != null) 'deleted ${AppTime.date(deletedAt)}',
                    if (deletedBy?.isNotEmpty == true) deletedBy!.toUpperCase(),
                  ].join(' · '),
                  style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          else
            OutlinedButton(
              onPressed: onRestore,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                foregroundColor: context.scheme.primary,
                side: BorderSide(color: context.scheme.primary.withValues(alpha: 0.5)),
              ),
              child: const Text('Restore', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
