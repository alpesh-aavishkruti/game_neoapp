import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class MasterListScreen extends ConsumerWidget {
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
  final String addLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(masterRowsProvider(path));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null)
              Text(subtitle!, style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      ),
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => onAdd!(context),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(masterRowsProvider(path).future),
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(masterRowsProvider(path)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: emptyTitle ?? 'Nothing set up yet',
          emptyMessage: emptyMessage,
          builder: (list) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${list.length} records', style: context.text.labelSmall),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: onAdd == null ? 24 : 92),
                  itemCount: list.length,
                  itemBuilder: (context, i) => MasterRow(
                    spec: rowOf(list[i]),
                    onTap: onEdit == null ? null : () => onEdit!(context, list[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MasterRow extends StatelessWidget {
  const MasterRow({super.key, required this.spec, this.onTap, this.leading});

  final MasterRowSpec spec;
  final VoidCallback? onTap;
  final Widget? leading;

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
          ],
        ),
      ),
    );
  }
}
