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
class EditHistoryScreen extends ConsumerStatefulWidget {
  const EditHistoryScreen({super.key});

  @override
  ConsumerState<EditHistoryScreen> createState() => _EditHistoryScreenState();
}

class _EditHistoryScreenState extends ConsumerState<EditHistoryScreen> {
  final _search = TextEditingController();

  /// Null means every kind. The desk filters by voucher type first and then
  /// looks for the number, which is the order this follows.
  String? _type;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> row, String term) {
    if (_type != null && (row['voucher_type'] ?? '').toString() != _type) {
      return false;
    }
    if (term.isEmpty) return true;
    return [
      row['voucher_no'],
      row['voucher_type_label'],
      row['edited_by'],
      row['party'],
      row['other_party'],
      row['description'],
      row['changes'],
    ].join(' ').toLowerCase().contains(term);
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(masterRowsProvider(_editLogPath));
    final term = _search.text.trim().toLowerCase();

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
          builder: (list) {
            // Offered from the data rather than a fixed list, so a kind that
            // was never edited does not sit there as a dead chip.
            final types = <String, String>{
              for (final row in list)
                if ((row['voucher_type'] ?? '').toString().isNotEmpty)
                  row['voucher_type'].toString():
                      (row['voucher_type_label'] ?? row['voucher_type']).toString(),
            };

            final shown = [
              for (final row in list)
                if (_matches(row, term)) row,
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
                      hintText: 'Search voucher, field or who changed it',
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
                if (types.length > 1)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: [
                        _TypeChip(
                          label: 'All',
                          selected: _type == null,
                          onTap: () => setState(() => _type = null),
                        ),
                        for (final entry in types.entries)
                          _TypeChip(
                            label: entry.value,
                            selected: _type == entry.key,
                            onTap: () => setState(() => _type = entry.key),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      shown.length == list.length
                          ? '${list.length} changes'
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
                      itemBuilder: (context, i) => _EditRow(row: shown[i]),
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
    // Whom the figure was with and what it was for - an amount-only edit
    // said neither, so the desk could not tell whose figure had moved.
    final party = (row['party'] ?? '').toString().trim();
    final other = (row['other_party'] ?? '').toString().trim();
    final description = (row['description'] ?? '').toString().trim();
    final parties = [party, other].where((p) => p.isNotEmpty).join('  ↔  ');

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
          if (parties.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                parties.toUpperCase(),
                style: context.text.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(description, style: context.text.bodySmall?.copyWith(fontSize: 11)),
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rField),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? context.scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.rField),
            border: Border.all(color: selected ? context.scheme.primary : book.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : book.muted,
            ),
          ),
        ),
      ),
    );
  }
}
