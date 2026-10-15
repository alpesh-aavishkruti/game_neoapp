import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/havala.dart';
import '../../data/repositories/havala_repository.dart';
import '../../core/network/api_exception.dart';
import '../../shared/widgets/async_view.dart';
import 'auto_havala_sheet.dart';
import 'havala_entry_sheet.dart';
import '../../shared/widgets/refresh_on_show.dart';

final havalaRepositoryProvider = Provider<HavalaRepository>(
  (ref) => HavalaRepository(ref.watch(apiClientProvider)),
);

/// Havala entries between two dates, as the desk lists them.
final havalaListProvider = FutureProvider.family<List<Havala>, ({DateTime from, DateTime to})>(
  (ref, range) => ref.watch(havalaRepositoryProvider).list(from: range.from, to: range.to),
);

/// Havala - money moving between two parties.
class HavalaScreen extends ConsumerStatefulWidget {
  const HavalaScreen({super.key, this.embedded = false});

  /// Inside the Reports tabs the section is already named above.
  final bool embedded;

  @override
  ConsumerState<HavalaScreen> createState() => _HavalaScreenState();
}

class _HavalaScreenState extends ConsumerState<HavalaScreen> {
  // The last month first, as the desk opens it; any range on request.
  DateTime _from = AppTime.today.subtract(const Duration(days: 30));
  DateTime _to = AppTime.today;
  final _search = TextEditingController();

  /// Ticks changed here and not yet re-read; the tick lives on the server.
  final _overrides = <int, bool>{};

  ({DateTime from, DateTime to}) get _range => (from: _from, to: _to);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => ref.invalidate(havalaListProvider(_range));

  Future<void> _share() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing the report…')),
    );
    try {
      await ref.read(reportSharingProvider).sharePdf(
            path: '/soda/havala/download_havala_report/',
            query: {'from_date': AppTime.apiDate(_from), 'to_date': AppTime.apiDate(_to)},
            name: 'Havala report',
          );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_from.year - 3),
      lastDate: DateTime(AppTime.today.year + 1),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
        _overrides.clear();
      });
    }
  }

  bool _isChecked(Havala h) => _overrides[h.id] ?? h.isChecked;

  /// Saved against the havala itself - the same tick View Party shows.
  Future<void> _toggle(Havala h) async {
    final next = !_isChecked(h);
    setState(() => _overrides[h.id] = next);
    try {
      await ref.read(apiClientProvider).post(
        '/master/parties/${h.fromId}/set_ledger_check/',
        data: {
          'checked': next,
          'rows': [
            {'source': 'havala', 'id': h.id},
          ],
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _overrides.remove(h.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the tick. Please try again.')),
      );
    }
  }

  Future<void> _delete(Havala h) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this havala?'),
        content: Text(
          '${h.voucherNo.isEmpty ? 'This havala' : h.voucherNo} - ${Money.format(h.amount)} '
          'from ${h.fromCode} to ${h.toCode}. It can be restored from the recycle bin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(apiClientProvider).delete('/soda/havala/${h.id}/');
      _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  List<Havala> _filter(List<Havala> list) {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return list;
    return [
      for (final h in list)
        if ([h.voucherNo, h.fromCode, h.fromName, h.toCode, h.toName, h.description]
            .join(' ')
            .toLowerCase()
            .contains(term))
          h,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(havalaListProvider(_range));

    return RefreshOnShow(
      providers: [havalaListProvider(_range)],
      child: Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Havala'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  tooltip: 'Auto havala',
                  onPressed: () async {
                    final saved = await AutoHavalaSheet.show(context);
                    if (saved == true) _reload();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Share as PDF',
                  onPressed: _share,
                ),
              ],
            ),
      persistentFooterAlignment: AlignmentDirectional.centerStart,
      persistentFooterButtons: widget.embedded
          ? [
              TextButton.icon(
                onPressed: () async {
                  final saved = await AutoHavalaSheet.show(context);
                  if (saved == true) _reload();
                },
                icon: const Icon(Icons.auto_fix_high_outlined, size: 17),
                label: const Text('Auto havala'),
              ),
              TextButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share, size: 17),
                label: const Text('Share as PDF'),
              ),
            ]
          : null,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-new-havala',
        onPressed: () async {
          final saved = await HavalaEntrySheet.show(context);
          if (saved == true) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('New havala'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text('${AppTime.date(_from)} – ${AppTime.date(_to)}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Party or voucher',
                      prefixIcon: Icon(Icons.search, size: 19),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(havalaListProvider(_range).future),
              child: AsyncView(
                value: entries,
                onRetry: _reload,
                isEmpty: (list) => list.isEmpty,
                emptyTitle: 'No havala in this period',
                emptyMessage: 'Change the dates to see older transfers.',
                builder: (list) {
                  final shown = _filter(list);
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _HavalaRow(
                      entry: shown[i],
                      isChecked: _isChecked(shown[i]),
                      onToggle: () => _toggle(shown[i]),
                      // Tapping a line opens it for changes, the same as the
                      // desk's Edit on the havala list; a long press deletes.
                      onTap: () async {
                        final saved = await HavalaEntrySheet.show(context, editing: shown[i]);
                        if (saved == true) _reload();
                      },
                      onLongPress: () => _delete(shown[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _HavalaRow extends StatelessWidget {
  const _HavalaRow({
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.isChecked = false,
    this.onToggle,
  });

  final Havala entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isChecked;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    final row = Container(
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
              if (onToggle != null)
                SizedBox(
                  width: 32,
                  height: 24,
                  child: Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: isChecked,
                    onChanged: (_) => onToggle!(),
                  ),
                ),
              Expanded(
                child: Text(
                  entry.voucherNo.isEmpty ? 'HAVALA' : entry.voucherNo,
                  style: const TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Money.format(entry.amount),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Payer above, receiver below, with an arrow between - the same
          // shape as the form, so a transfer can never be read backwards.
          _Leg(label: 'FROM', code: entry.fromCode, name: entry.fromName),
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
            child: Icon(Icons.south, size: 14, color: book.muted),
          ),
          _Leg(label: 'TO', code: entry.toCode, name: entry.toName),
          if (entry.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.description, style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: 5),
          Text(
            [
              if (entry.date != null) AppTime.date(entry.date),
              if (entry.createdBy.isNotEmpty) entry.createdBy.toUpperCase(),
            ].join(' · '),
            style: context.text.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );

    if (onTap == null && onLongPress == null) return row;
    return InkWell(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.label, required this.code, required this.name});

  final String label;
  final String code;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: context.text.labelSmall)),
          Expanded(
            child: Text(
              name.isEmpty ? code : '$code — $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
