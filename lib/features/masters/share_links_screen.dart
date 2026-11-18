import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/refresh_on_show.dart';
import '../../shared/widgets/status_chip.dart';
import '../money/statement_link_sheet.dart';
import 'master_providers.dart';

const _shareLinksPath = '/master/statement-links/';

enum _LinkFilter { all, active, deactivated }

/// Every ledger link the desk has shared, in one place.
///
/// How many there are, which are on and which are off - without opening each
/// party. A party gets its link the first time Share Link is opened for it in
/// the ledger; from here it can be copied, shared, switched off and on, or
/// reset. Admin only, like the recycle bin.
class ShareLinksScreen extends ConsumerStatefulWidget {
  const ShareLinksScreen({super.key});

  @override
  ConsumerState<ShareLinksScreen> createState() => _ShareLinksScreenState();
}

class _ShareLinksScreenState extends ConsumerState<ShareLinksScreen> {
  final _search = TextEditingController();
  _LinkFilter _filter = _LinkFilter.all;
  int? _busyPartyId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _code(Map<String, dynamic> row) => (row['party_code'] ?? '').toString();

  String _url(Map<String, dynamic> row) =>
      AppConfig.partyStatementLink((row['token'] ?? '').toString());

  Future<void> _copy(Map<String, dynamic> row) async {
    await Clipboard.setData(ClipboardData(text: _url(row)));
    _say('Link for ${_code(row)} copied.');
  }

  Future<void> _run(Map<String, dynamic> row, Future<void> Function(int partyId) call,
      String done) async {
    final partyId = int.tryParse('${row['party_id']}');
    if (partyId == null) return;
    setState(() => _busyPartyId = partyId);
    try {
      await call(partyId);
      ref.invalidate(masterRowsProvider(_shareLinksPath));
      _say(done);
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busyPartyId = null);
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool on) => _run(
        row,
        (id) => ref.read(statementLinkRepositoryProvider).setActive(id, on),
        on
            ? 'Link for ${_code(row)} turned on.'
            : 'Link for ${_code(row)} turned off. It will not open until turned on.',
      );

  Future<void> _reset(Map<String, dynamic> row) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset link - ${_code(row)}?'),
        content: const Text(
          'A new link will be made and the old one stops opening. '
          'The party sets a new password when they open the new link.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (sure != true) return;
    final partyId = int.tryParse('${row['party_id']}');
    if (partyId == null) return;
    setState(() => _busyPartyId = partyId);
    try {
      final link = await ref.read(statementLinkRepositoryProvider).reset(partyId);
      await Clipboard.setData(ClipboardData(text: AppConfig.partyStatementLink(link.token)));
      ref.invalidate(masterRowsProvider(_shareLinksPath));
      _say('New link for ${_code(row)} made and copied. The old link no longer opens.');
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busyPartyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(masterRowsProvider(_shareLinksPath));
    final term = _search.text.trim().toLowerCase();

    return RefreshOnShow(
      providers: [masterRowsProvider(_shareLinksPath)],
      child: Scaffold(
        appBar: AppBar(title: const Text('Share links')),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(masterRowsProvider(_shareLinksPath).future),
          child: AsyncView(
            value: rows,
            onRetry: () => ref.invalidate(masterRowsProvider(_shareLinksPath)),
            isEmpty: (list) => list.isEmpty,
            emptyTitle: 'No links shared yet',
            emptyMessage:
                'A party gets a link the first time Share Link is opened for it in the ledger.',
            builder: (list) {
              final active = list.where((r) => r['is_active'] == true).length;
              final shown = [
                for (final row in list)
                  if ((_filter == _LinkFilter.all ||
                          (_filter == _LinkFilter.active) == (row['is_active'] == true)) &&
                      (term.isEmpty ||
                          '${row['party_code']} ${row['party_name']}'
                              .toLowerCase()
                              .contains(term)))
                    row,
              ];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: Row(
                      children: [
                        _CountCard(
                          label: 'Total',
                          value: list.length,
                          color: context.scheme.primary,
                          selected: _filter == _LinkFilter.all,
                          onTap: () => setState(() => _filter = _LinkFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _CountCard(
                          label: 'Active',
                          value: active,
                          color: context.book.up,
                          selected: _filter == _LinkFilter.active,
                          onTap: () => setState(() => _filter = _LinkFilter.active),
                        ),
                        const SizedBox(width: 8),
                        _CountCard(
                          label: 'Deactivated',
                          value: list.length - active,
                          color: context.book.down,
                          selected: _filter == _LinkFilter.deactivated,
                          onTap: () => setState(() => _filter = _LinkFilter.deactivated),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search party code or name',
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
                  if (shown.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('No links match', style: context.text.bodyMedium),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final row = shown[i];
                          return _LinkRow(
                            row: row,
                            busy: _busyPartyId == int.tryParse('${row['party_id']}'),
                            onToggle: (on) => _toggle(row, on),
                            onCopy: () => _copy(row),
                            onShare: () => SharePlus.instance.share(
                              ShareParams(text: _url(row), subject: 'Statement - ${_code(row)}'),
                            ),
                            onReset: () => _reset(row),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    return Expanded(
      child: Material(
        color: selected ? context.scheme.primary.withValues(alpha: 0.08) : context.scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? context.scheme.primary : book.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.row,
    required this.busy,
    required this.onToggle,
    required this.onCopy,
    required this.onShare,
    required this.onReset,
  });

  final Map<String, dynamic> row;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final isActive = row['is_active'] == true;
    final details = [
      row['password_set'] == true ? 'Password set' : 'Password not set',
      if (row['is_locked'] == true) 'Locked',
      if ((row['created_at'] ?? '').toString().isNotEmpty) 'Made ${row['created_at']}',
      if (row['party_is_active'] == false) 'Party inactive',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 9, 4, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (row['party_code'] ?? '—').toString().toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    StatusChip(
                      isActive ? 'Active' : 'Deactivated',
                      tone: isActive ? ChipTone.up : ChipTone.down,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  (row['party_name'] ?? '').toString().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(details, style: context.text.bodySmall?.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Switch(value: isActive, onChanged: onToggle),
          PopupMenuButton<String>(
            enabled: !busy,
            tooltip: 'Link actions',
            onSelected: (choice) {
              switch (choice) {
                case 'copy':
                  onCopy();
                case 'share':
                  onShare();
                case 'reset':
                  onReset();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'copy', child: Text('Copy link')),
              PopupMenuItem(value: 'share', child: Text('Share link')),
              PopupMenuItem(value: 'reset', child: Text('Reset link')),
            ],
          ),
        ],
      ),
    );
  }
}
