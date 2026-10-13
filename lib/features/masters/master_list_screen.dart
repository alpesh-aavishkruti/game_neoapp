import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import 'master_providers.dart';

/// What one row of a master list shows.
///
/// Every master is the same shape underneath - a title, some detail, and
/// sometimes a status - so they share one screen rather than ten that would
/// slowly drift apart.
class MasterRowSpec {
  const MasterRowSpec({
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone,
  });

  final String title;
  final String? subtitle;

  /// A short figure or date on the right.
  final String? trailing;

  /// Set to mark state - inactive, unbalanced, and so on.
  final ChipTone? tone;
}

class MasterListScreen extends ConsumerStatefulWidget {
  const MasterListScreen({
    super.key,
    required this.title,
    required this.path,
    required this.rowOf,
    this.emptyTitle,
    this.emptyMessage,
    this.subtitle,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.trailingAction,
    this.addLabel = 'Add',
  });

  final String title;

  /// The API path this master lives at.
  final String path;

  final MasterRowSpec Function(Map<String, dynamic> row) rowOf;

  final String? emptyTitle;
  final String? emptyMessage;
  final String? subtitle;

  /// Set on the masters this app can change. The rest stay read-only, and
  /// simply having no button says so more clearly than a disabled one.
  final Future<void> Function(BuildContext context)? onAdd;
  final Future<void> Function(BuildContext context, Map<String, dynamic> row)? onEdit;

  /// How a row is named when confirming its removal. Set only on the masters
  /// that may be deleted; the rest show no bin at all, which says so more
  /// plainly than one that refuses.
  final String Function(Map<String, dynamic> row)? onDelete;

  /// One more thing a row can do, beside opening and being deleted.
  final ({IconData icon, String tooltip, VoidCallback onTap}) Function(
    BuildContext context,
    Map<String, dynamic> row,
  )? trailingAction;

  final String addLabel;

  @override
  ConsumerState<MasterListScreen> createState() => _MasterListScreenState();
}

class _MasterListScreenState extends ConsumerState<MasterListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Matches on everything the row puts on screen, so whatever the operator
  /// can read they can also search for.
  bool _matches(Map<String, dynamic> row, String term) {
    if (term.isEmpty) return true;
    final spec = widget.rowOf(row);
    return '${spec.title} ${spec.subtitle ?? ''} ${spec.trailing ?? ''}'
        .toLowerCase()
        .contains(term);
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final rows = ref.watch(masterRowsProvider(path));
    final term = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      ),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => widget.onAdd!(context),
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(masterRowsProvider(path).future),
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(masterRowsProvider(path)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: widget.emptyTitle ?? 'Nothing set up yet',
          emptyMessage: widget.emptyMessage,
          builder: (list) {
            final shown = [
              for (final row in list)
                if (_matches(row, term)) row,
            ];

            return Column(
            children: [
              // On every list, however short - the desk puts one on each page
              // and an operator should not have to learn which ones have it.
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search',
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                    child: Text('Nothing matches that', style: context.text.bodyMedium),
                  ),
                )
              else
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: widget.onAdd == null ? 24 : 92),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => MasterRow(
                    spec: widget.rowOf(shown[i]),
                    onTap: widget.onEdit == null ? null : () => widget.onEdit!(context, shown[i]),
                    onDelete: widget.onDelete == null
                        ? null
                        : () => _confirmDelete(context, ref, shown[i]),
                    action: widget.trailingAction?.call(context, shown[i]),
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

  /// Confirms, then removes the row.
  ///
  /// Named by what it is rather than "this item", because a master row is easy
  /// to mistake for its neighbour in a list of short codes.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final label = widget.onDelete!(row);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text('It stops being offered anywhere it can be chosen.'),
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
    if (ok != true) return;

    try {
      await ref.read(apiClientProvider).delete('${widget.path}${row['id']}/');
      refreshMasterRows(ref, widget.path);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete $label.')),
      );
    }
  }
}

class MasterRow extends StatelessWidget {
  const MasterRow({
    super.key,
    required this.spec,
    this.onTap,
    this.leading,
    this.onDelete,
    this.action,
  });

  final MasterRowSpec spec;
  final VoidCallback? onTap;
  final Widget? leading;
  final VoidCallback? onDelete;
  final ({IconData icon, String tooltip, VoidCallback onTap})? action;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          border: Border(bottom: BorderSide(color: book.line)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 11)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spec.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (spec.subtitle?.isNotEmpty == true) ...[
                    const SizedBox(height: 1),
                    Text(
                      spec.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            if (spec.tone != null) ...[
              const SizedBox(width: 8),
              StatusChip(spec.trailing ?? '', tone: spec.tone!),
            ] else if (spec.trailing?.isNotEmpty == true) ...[
              const SizedBox(width: 8),
              Text(
                spec.trailing!,
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12,
                  color: book.muted,
                ),
              ),
            ],
            if (action != null)
              IconButton(
                icon: Icon(action!.icon, size: 20),
                color: context.scheme.primary,
                tooltip: action!.tooltip,
                onPressed: action!.onTap,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: book.muted,
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
