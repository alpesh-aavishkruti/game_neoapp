import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import 'master_providers.dart';

const _editLogPath = '/soda/edit-logs/';

/// Who changed what.
///
/// The value before and after is the whole point of this screen, so each
/// change is shown as `was → now` rather than a summary that has to be
/// trusted.
class EditHistoryScreen extends ConsumerWidget {
  const EditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(masterRowsProvider(_editLogPath));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit history'),
            Text('Who changed what', style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(masterRowsProvider(_editLogPath).future),
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(masterRowsProvider(_editLogPath)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'No edits recorded',
          builder: (list) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, i) => _EditRow(row: list[i]),
          ),
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.row});

  final Map<String, dynamic> row;

  /// `changes` arrives either as a map of field to before/after, or as a list
  /// of such records. Both are flattened to lines the reader can check.
  List<({String field, String before, String after})> get _changes {
    final raw = row['changes'];
    final out = <({String field, String before, String after})>[];

    void add(String field, dynamic detail) {
      if (detail is Map) {
        out.add((
          field: field,
          before: (detail['old'] ?? detail['before'] ?? detail['from'] ?? '—').toString(),
          after: (detail['new'] ?? detail['after'] ?? detail['to'] ?? '—').toString(),
        ));
      } else if (detail != null) {
        out.add((field: field, before: '—', after: detail.toString()));
      }
    }

    if (raw is Map) {
      raw.forEach((key, value) => add(key.toString(), value));
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final field = (item['field'] ?? item['name'] ?? 'changed').toString();
          add(field, item);
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final at = AppTime.toLocal(row['edited_at']);
    final by = (row['edited_by'] is Map ? row['edited_by']['username'] : row['edited_by'])
        ?.toString()
        .trim();
    final kind = (row['voucher_type_label'] ?? row['voucher_type'] ?? '').toString().trim();
    final changes = _changes;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (kind.isNotEmpty) ...[
                StatusChip(kind, tone: ChipTone.warn),
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
              Text(
                [
                  if (at != null) AppTime.dateTime(at),
                  if (by?.isNotEmpty == true) by!.toUpperCase(),
                ].join(' · '),
                style: context.text.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
          if (changes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('Edited', style: context.text.bodySmall),
            )
          else
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        change.field.replaceAll('_', ' ').toUpperCase(),
                        style: context.text.labelSmall?.copyWith(fontSize: 9.5),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            change.before,
                            style: TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontSize: 11.5,
                              color: book.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 12, color: book.muted),
                          ),
                          Text(
                            change.after,
                            style: TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: book.warn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
