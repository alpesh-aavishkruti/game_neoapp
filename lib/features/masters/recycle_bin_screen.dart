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
      await ref.read(masterRepositoryProvider).restoreDeleted(
            recordType: (row['record_type'] ?? '').toString(),
            id: id,
          );
      ref.invalidate(masterRowsProvider(_recycleBinPath));
      _say('Entry restored.');
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Removes one entry from the bin for good.
  ///
  /// Restoring is the safe half of this screen; this is the half that cannot
  /// be walked back, so it says exactly that and names the voucher.
  Future<void> _deleteForever(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;

    final label = (row['voucher_no'] ?? row['description'] ?? 'this entry').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label for good?'),
        content: const Text('It leaves the bin and cannot be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete for good'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = id);
    try {
      await ref.read(masterRepositoryProvider).permanentlyDelete(
            recordType: (row['record_type'] ?? '').toString(),
            id: id,
          );
      ref.invalidate(masterRowsProvider(_recycleBinPath));
      _say('$label deleted.');
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Clears the whole bin.
  Future<void> _emptyBin(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty the bin?'),
        content: Text(
          'All $count deleted ${count == 1 ? 'entry' : 'entries'} go for good '
          'and cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Empty it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(masterRepositoryProvider).emptyRecycleBin();
      ref.invalidate(masterRowsProvider(_recycleBinPath));
      _say('Recycle bin emptied.');
    } on ApiException catch (e) {
      _say(e.message);
    }
  }

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(masterRowsProvider(_recycleBinPath));
    final term = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle bin'),
        actions: [
          if ((rows.value ?? const []).isNotEmpty)
            TextButton(
              onPressed: () => _emptyBin((rows.value ?? const []).length),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(masterRowsProvider(_recycleBinPath).future),
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(masterRowsProvider(_recycleBinPath)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'Nothing deleted',
          emptyMessage: 'Entries you delete can be put back from here.',
          builder: (list) {
            // Voucher number, what it was for, the type and who is on it -
            // the desk searches by whichever of those it remembers.
            final shown = [
              for (final row in list)
                if (term.isEmpty ||
                    [
                      row['voucher_no'],
                      row['description'],
                      row['record_type_label'],
                      row['party_names'],
                    ].join(' ').toLowerCase().contains(term))
                  row,
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
                      hintText: 'Search voucher no or party',
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
                          ? '${list.length} deleted'
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
                      itemBuilder: (context, i) => _DeletedRow(
                        row: shown[i],
                        busy: _busyId == int.tryParse('${shown[i]['id']}'),
                        onRestore: () => _restore(shown[i]),
                        onDeleteForever: () => _deleteForever(shown[i]),
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

class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    required this.row,
    required this.busy,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

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
                    if (amount != 0) Money.format(amount.abs()),
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
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, size: 20),
            color: book.down,
            tooltip: 'Delete for good',
            onPressed: busy ? null : onDeleteForever,
          ),
        ],
      ),
    );
  }
}
