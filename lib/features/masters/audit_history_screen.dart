import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../shared/widgets/app_dropdown.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';

typedef _AuditQuery = ({String gameType, DateTime from, DateTime to});

/// The audit trail the desk keeps of every bet or havala changed or deleted:
/// "Before Update" and "After Update" pairs, and "Deleted".
final _auditProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _AuditQuery>((ref, q) async {
  final body = await ref.read(apiClientProvider).get('/soda/audit-logs/fetch_all/', query: {
    if (q.gameType.isNotEmpty) 'game_type': q.gameType,
    'from_date': AppTime.apiDate(q.from),
    'to_date': AppTime.apiDate(q.to),
  });
  final rows = asList(body).map((e) => Map<String, dynamic>.from(e)).toList();
  // Newest first: the change being asked about is usually the last one.
  return rows.reversed.toList();
});

/// Edit / Delete History (bets) or Havala History, as the desk's reports show.
class AuditHistoryScreen extends ConsumerStatefulWidget {
  const AuditHistoryScreen({super.key, this.havala = false});

  /// True for Havala History; otherwise bet edits and deletes.
  final bool havala;

  @override
  ConsumerState<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends ConsumerState<AuditHistoryScreen> {
  DateTime _from = AppTime.today.subtract(const Duration(days: 7));
  DateTime _to = AppTime.today;

  /// '' means every game (the server leaves havala out of that list).
  String _game = '';

  static const _games = {
    '': 'All games',
    'One Day': 'One Day',
    'Session': 'Session',
    'Test': 'Test',
  };

  _AuditQuery get _query =>
      (gameType: widget.havala ? 'Havala' : _game, from: _from, to: _to);

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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(_auditProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.havala ? 'Havala history' : 'Edit / delete history'),
            Text(
              widget.havala ? 'Every havala changed or deleted' : 'Every bet changed or deleted',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
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
                if (!widget.havala) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppDropdown<String>(
                      initialValue: _game,
                      items: [
                        for (final e in _games.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _game = v ?? ''),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(_auditProvider(_query).future),
              child: AsyncView(
                value: rows,
                onRetry: () => ref.invalidate(_auditProvider(_query)),
                isEmpty: (list) => list.isEmpty,
                emptyTitle: 'Nothing changed in this period',
                emptyMessage: 'Edits and deletions appear here.',
                builder: (list) => ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) =>
                      _AuditLine(row: list[i], havala: widget.havala),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLine extends StatelessWidget {
  const _AuditLine({required this.row, required this.havala});

  final Map<String, dynamic> row;
  final bool havala;

  String _s(String key) => (row[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final action = _s('action_type');
    final tone = switch (action) {
      'Deleted' => ChipTone.down,
      'After Update' => ChipTone.warn,
      _ => ChipTone.muted,
    };
    final when = _s('action_date_formatted').isNotEmpty
        ? _s('action_date_formatted')
        : _s('action_date');

    final String title;
    final String detail;
    if (havala) {
      title = [_s('voucher_no'), _s('voucher_date_formatted')]
          .where((e) => e.isNotEmpty)
          .join(' · ');
      detail = '${_s('p_member_name')}  →  ${_s('h_member_name')}';
    } else {
      title = [_s('match_name'), if (_s('row_no').isNotEmpty) '#${_s('row_no')}']
          .where((e) => e.isNotEmpty)
          .join(' · ');
      detail = [
        [_s('client_code'), _s('client_name')].where((e) => e.isNotEmpty).join(' - '),
        [_s('nation_or_run'), _s('bet_type')].where((e) => e.isNotEmpty).join(' / '),
      ].where((e) => e.isNotEmpty).join('   ');
    }
    final figure = havala
        ? _s('amount')
        : [_s('amount'), _s('rate')].where((e) => e.isNotEmpty).join(' × ');

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (action.isNotEmpty) ...[
                StatusChip(action, tone: tone),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: context.text.bodyMedium?.copyWith(fontSize: 12.5),
                ),
              ),
              Text(
                figure,
                style: const TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (havala && _s('remarks').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_s('remarks'), style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: 4),
          Text(
            [_s('action_by').toUpperCase(), when].where((e) => e.isNotEmpty).join(' · '),
            style: context.text.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
