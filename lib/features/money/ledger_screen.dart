import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/ledger_row.dart';
import '../../data/models/party.dart';
import '../../data/repositories/book_repository.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import '../matches/match_providers.dart';
import 'havala_entry_sheet.dart';

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(ref.watch(apiClientProvider)),
);

final ledgerProvider =
    FutureProvider.family<PartyStatement, int>((ref, partyId) async {
  return ref.watch(bookRepositoryProvider).ledger(partyId: partyId);
});

/// Set on each dropdown item rather than on the field. A style handed to the
/// field replaces the theme's, colour and all, and the selected value comes
/// out unpainted.
const _filterText = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);

/// Which rows the check column is being used to pick out.
enum _Shown {
  all('All'),
  checked('Check'),
  unchecked('Uncheck');

  const _Shown(this.label);
  final String label;
}

/// A party's statement - the desk's VIEW PARTY.
///
/// A desk ledger is a wide table: date, particulars, credit, debit, balance,
/// voucher, who entered it. That is unreadable squeezed onto a phone, so each
/// entry becomes a block - date at the left, what happened in the middle, the
/// two figures at the right. The balance sits above the list, because it is
/// the number anyone opens a ledger to find.
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key, this.party, this.embedded = false});

  /// When absent the screen asks which party to show first.
  final Party? party;

  /// Inside the Reports tabs the section is already named above, so the screen
  /// drops its own app bar rather than stacking a second one.
  final bool embedded;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  Party? _party;

  final _description = TextEditingController();

  DateTime? _from;
  DateTime? _to;

  /// Once the operator picks a range it is theirs, and switching party must
  /// not quietly move it back to the last seven days.
  bool _ownDates = false;

  String _vchType = 'All';
  _Shown _shown = _Shown.all;

  /// Ticked off while reconciling. Session-only, like the desk's own column.
  final _checked = <int>{};

  @override
  void initState() {
    super.initState();
    _party = widget.party;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final party = _party;
    if (party == null) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing the statement…')));
    try {
      await ref.read(reportSharingProvider).sharePdf(
            path: '/master/parties/${party.id}/download_party_report/',
            name: 'Ledger ${party.code}',
            query: {
              if (_from != null) 'from_date': AppTime.apiDate(_from!),
              if (_to != null) 'to_date': AppTime.apiDate(_to!),
            },
          );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickParty() async {
    final parties = await ref.read(partiesProvider.future);
    if (!mounted) return;

    final chosen = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PartyPicker(parties: parties),
    );
    if (chosen != null) _open(chosen);
  }

  void _open(Party party) => setState(() {
        _party = party;
        _checked.clear();
        if (!_ownDates) {
          _from = null;
          _to = null;
        }
      });

  /// Follows the party code a line names into that party's own statement.
  ///
  /// The desk's JUMP: a settlement line says who it was against, and the next
  /// question is always what that side's book looks like.
  Future<void> _jump(String code) async {
    final parties = await ref.read(partiesProvider.future);
    if (!mounted) return;
    final target = parties.where((p) => p.code.toUpperCase() == code).firstOrNull;
    if (target == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No party with code $code')));
      return;
    }
    _open(target);
  }

  Future<void> _pickRange() async {
    final now = AppTime.today;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
        _ownDates = true;
      });
    }
  }

  void _clear() => setState(() {
        _description.clear();
        _vchType = 'All';
        _shown = _Shown.all;
        _from = null;
        _to = null;
        _ownDates = false;
        _checked.clear();
      });

  /// The week ending at the newest entry, which is what the desk opens on.
  ///
  /// A statement can run for years; showing all of it by default means
  /// scrolling to the bottom before reading anything useful.
  ({DateTime from, DateTime to})? _defaultRange(List<LedgerRow> rows) {
    final dated = rows.map((r) => r.date).whereType<DateTime>().toList();
    if (dated.isEmpty) return null;
    final latest = dated.reduce((a, b) => a.isAfter(b) ? a : b);
    return (from: latest.subtract(const Duration(days: 7)), to: latest);
  }

  List<LedgerRow> _apply(List<LedgerRow> rows, DateTime? from, DateTime? to) {
    final term = _description.text.trim().toLowerCase();

    return [
      for (final row in rows)
        if (_keep(row, term, from, to)) row,
    ];
  }

  bool _keep(LedgerRow row, String term, DateTime? from, DateTime? to) {
    if (term.isNotEmpty && !row.description.toLowerCase().contains(term)) {
      return false;
    }
    if (_vchType != 'All' && row.voucherType != _vchType) return false;

    final on = _checked.contains(row.id);
    if (_shown == _Shown.checked && !on) return false;
    if (_shown == _Shown.unchecked && on) return false;

    final at = row.date;
    if (from != null && to != null && at != null) {
      final day = DateTime(at.year, at.month, at.day);
      if (day.isBefore(DateTime(from.year, from.month, from.day)) ||
          day.isAfter(DateTime(to.year, to.month, to.day))) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final party = _party;

    final body = party == null
        ? _ChooseFirst(onChoose: _pickParty)
        : _statement(party);

    if (widget.embedded) {
      return Column(
        children: [
          _PartyBar(
            party: party,
            onChoose: _pickParty,
            onShare: party == null ? null : _share,
            onAddHavala: party == null ? null : _addHavala,
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('View party'),
            if (party != null)
              Text(
                party.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (party != null) ...[
            IconButton(
              icon: const Icon(Icons.add_card_outlined),
              tooltip: 'Add havala',
              onPressed: _addHavala,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share as PDF',
              onPressed: _share,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'Choose party',
            onPressed: _pickParty,
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _addHavala() async {
    final saved = await HavalaEntrySheet.show(context);
    final party = _party;
    if (saved == true && party != null) ref.invalidate(ledgerProvider(party.id));
  }

  Widget _statement(Party party) {
    final statement = ref.watch(ledgerProvider(party.id));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(ledgerProvider(party.id).future),
      child: AsyncView(
        value: statement,
        onRetry: () => ref.invalidate(ledgerProvider(party.id)),
        isEmpty: (data) => data.rows.isEmpty,
        emptyTitle: 'Nothing on this statement',
        emptyMessage: 'Entries appear here as matches settle and havalas are raised.',
        builder: (data) {
          // A range the operator has not set follows the data; one they have
          // set is left exactly where they put it.
          final fallback = _ownDates ? null : _defaultRange(data.rows);
          final from = _ownDates ? _from : fallback?.from;
          final to = _ownDates ? _to : fallback?.to;

          final shown = _apply(data.rows, from, to);

          final types = <String>{
            for (final row in data.rows)
              if (row.voucherType.isNotEmpty) row.voucherType,
          }.toList()
            ..sort();

          final credit = shown.fold<double>(0, (s, r) => s + r.credit);
          final debit = shown.fold<double>(0, (s, r) => s + r.debit.abs());
          final ticked = shown
              .where((r) => _checked.contains(r.id))
              .fold<double>(0, (s, r) => s + r.movement);

          return Column(
            children: [
              _LedgerFilters(
                from: from,
                to: to,
                onPickRange: _pickRange,
                description: _description,
                onDescriptionChanged: () => setState(() {}),
                types: types,
                vchType: _vchType,
                onType: (v) => setState(() => _vchType = v),
                shown: _shown,
                onShown: (v) => setState(() => _shown = v),
                allChecked: shown.isNotEmpty &&
                    shown.every((r) => _checked.contains(r.id)),
                onCheckAll: (on) => setState(() {
                  for (final row in shown) {
                    on ? _checked.add(row.id) : _checked.remove(row.id);
                  }
                }),
                onClear: _clear,
                balance: data.balance,
                count: shown.length,
                total: data.rows.length,
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'No entries in this range',
                            style: context.text.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          // Newest first: the last thing entered is the thing
                          // most often being checked.
                          final row = shown[shown.length - 1 - i];
                          return _LedgerLine(
                            row: row,
                            isChecked: _checked.contains(row.id),
                            onToggle: () => setState(() {
                              _checked.contains(row.id)
                                  ? _checked.remove(row.id)
                                  : _checked.add(row.id);
                            }),
                            onJump: _jumpCode(row) == null
                                ? null
                                : () => _jump(_jumpCode(row)!),
                            // Only lines that came out of a book can go back
                            // into it; a settlement line has no record to
                            // remove.
                            onDelete: row.canDelete
                                ? () => _deleteRow(context, ref, row, party.id)
                                : null,
                          );
                        },
                      ),
              ),
              _Totals(credit: credit, debit: debit, ticked: ticked),
            ],
          );
        },
      ),
    );
  }

  /// The party code a line names, when it names one this book knows.
  String? _jumpCode(LedgerRow row) {
    final source = row.ptrnSourceCode;
    if (source != null && source.isNotEmpty) return source;

    // The desk reads the leading token of the description; it is a code on a
    // havala line and a match number on a settlement, so it is only offered
    // when it actually resolves.
    final match = RegExp(r'^[\w\d]+').firstMatch(row.description);
    final token = match?.group(0)?.toUpperCase();
    if (token == null || token.isEmpty) return null;

    final parties = ref.read(partiesProvider).value ?? const <Party>[];
    return parties.any((p) => p.code.toUpperCase() == token) ? token : null;
  }
}

/// The desk's filter row, folded onto a phone.
class _LedgerFilters extends StatefulWidget {
  const _LedgerFilters({
    required this.from,
    required this.to,
    required this.onPickRange,
    required this.description,
    required this.onDescriptionChanged,
    required this.types,
    required this.vchType,
    required this.onType,
    required this.shown,
    required this.onShown,
    required this.allChecked,
    required this.onCheckAll,
    required this.onClear,
    required this.balance,
    required this.count,
    required this.total,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPickRange;
  final TextEditingController description;
  final VoidCallback onDescriptionChanged;
  final List<String> types;
  final String vchType;
  final ValueChanged<String> onType;
  final _Shown shown;
  final ValueChanged<_Shown> onShown;
  final bool allChecked;
  final ValueChanged<bool> onCheckAll;
  final VoidCallback onClear;
  final double balance;
  final int count;
  final int total;

  @override
  State<_LedgerFilters> createState() => _LedgerFiltersState();
}

class _LedgerFiltersState extends State<_LedgerFilters> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final extras = (widget.vchType != 'All' ? 1 : 0) +
        (widget.shown != _Shown.all ? 1 : 0) +
        (widget.description.text.trim().isEmpty ? 0 : 1);

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.rField),
                  onTap: widget.onPickRange,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.rField),
                      border: Border.all(color: book.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_outlined, size: 14, color: book.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.from == null || widget.to == null
                                ? 'All dates'
                                : '${AppTime.date(widget.from)} → ${AppTime.date(widget.to)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'More filters',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _open = !_open),
                icon: Badge(
                  isLabelVisible: extras > 0,
                  label: Text('$extras'),
                  child: Icon(_open ? Icons.tune : Icons.tune_outlined, size: 20),
                ),
              ),
              Tooltip(
                message: 'Check all',
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: widget.allChecked,
                  onChanged: (v) => widget.onCheckAll(v == true),
                ),
              ),
            ],
          ),
          if (_open) ...[
            SizedBox(
              height: 38,
              child: TextField(
                controller: widget.description,
                onChanged: (_) => widget.onDescriptionChanged(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search remarks…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: widget.description.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            widget.description.clear();
                            widget.onDescriptionChanged();
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.vchType,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      const DropdownMenuItem(
                        value: 'All',
                        child: Text('All types', style: _filterText),
                      ),
                      for (final type in widget.types)
                        DropdownMenuItem(
                          value: type,
                          child: Text(type, style: _filterText),
                        ),
                    ],
                    onChanged: (v) => widget.onType(v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<_Shown>(
                    initialValue: widget.shown,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      for (final option in _Shown.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label, style: _filterText),
                        ),
                    ],
                    onChanged: (v) => widget.onShown(v ?? _Shown.all),
                  ),
                ),
                TextButton(onPressed: widget.onClear, child: const Text('Clear')),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                widget.count == widget.total
                    ? '${widget.total} entries'
                    : '${widget.count} of ${widget.total}',
                style: context.text.labelSmall,
              ),
              const Spacer(),
              Text('BALANCE', style: context.text.labelSmall),
              const SizedBox(width: 6),
              Text(
                Money.format(widget.balance),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: book.forAmount(widget.balance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The figures for whatever the filters have left on screen.
class _Totals extends StatelessWidget {
  const _Totals({required this.credit, required this.debit, required this.ticked});

  final double credit;
  final double debit;
  final double ticked;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final net = credit - debit;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
      child: Row(
        children: [
          Expanded(child: _Total(label: 'CR (LENA)', value: credit, tone: book.up)),
          Expanded(child: _Total(label: 'DR (DENA)', value: debit, tone: book.down)),
          Expanded(
            child: _Total(
              label: 'NET',
              value: net,
              tone: book.forAmount(net),
              signed: true,
            ),
          ),
          Expanded(
            child: _Total(
              label: 'CHECKED',
              value: ticked,
              tone: book.forAmount(ticked),
              signed: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.tone,
    this.signed = false,
  });

  final String label;
  final double value;
  final Color tone;
  final bool signed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: context.text.labelSmall?.copyWith(fontSize: 8.5)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              signed ? Money.position(value) : Money.format(value),
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
        ],
      );
}

/// Names the party being read, and lets it be swapped, when the screen has no
/// app bar of its own to carry that.
class _PartyBar extends StatelessWidget {
  const _PartyBar({
    required this.party,
    required this.onChoose,
    this.onShare,
    this.onAddHavala,
  });

  final Party? party;
  final VoidCallback onChoose;
  final VoidCallback? onShare;
  final VoidCallback? onAddHavala;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.rField),
                onTap: onChoose,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.rField),
                    border: Border.all(color: context.book.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          party?.display ?? 'Choose a client',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: party == null ? FontWeight.w400 : FontWeight.w600,
                            color: party == null
                                ? context.book.muted
                                : context.scheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more, size: 19, color: context.book.muted),
                    ],
                  ),
                ),
              ),
            ),
            if (onAddHavala != null)
              IconButton(
                icon: const Icon(Icons.add_card_outlined, size: 19),
                tooltip: 'Add havala',
                visualDensity: VisualDensity.compact,
                onPressed: onAddHavala,
              ),
            if (onShare != null)
              IconButton(
                icon: const Icon(Icons.ios_share, size: 18),
                tooltip: 'Share as PDF',
                visualDensity: VisualDensity.compact,
                onPressed: onShare,
              ),
          ],
        ),
      );
}

class _ChooseFirst extends StatelessWidget {
  const _ChooseFirst({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 36, color: context.book.muted),
              const SizedBox(height: 14),
              Text('Choose a client', style: context.text.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Pick whose statement to open.',
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onChoose, child: const Text('Choose client')),
            ],
          ),
        ),
      );
}

/// Confirms, then removes the record a statement line came from.
///
/// Named plainly and shown with its figure, because the line on screen is a
/// rendering and what is actually being deleted is the voucher behind it.
Future<void> _deleteRow(
  BuildContext context,
  WidgetRef ref,
  LedgerRow row,
  int partyId,
) async {
  final label = row.voucherNo.isEmpty ? 'this entry' : row.voucherNo;
  // Taken before the dialog: after it, this context may be gone.
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $label?'),
      content: Text(
        '${row.description}\n\n'
        'It comes off this statement and every other book it appears in.',
      ),
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
    await ref.read(bookRepositoryProvider).deleteLedgerRow(row);
    ref.invalidate(ledgerProvider(partyId));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not delete that entry.')),
    );
  }
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({
    required this.row,
    required this.isChecked,
    required this.onToggle,
    this.onJump,
    this.onDelete,
  });

  final LedgerRow row;
  final bool isChecked;
  final VoidCallback onToggle;
  final VoidCallback? onJump;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    final voucher = '${row.voucherType} ${row.voucherNo}'.trim();
    final byline = [voucher, row.createdBy].where((s) => s.isNotEmpty).join('  ');

    return Container(
      decoration: BoxDecoration(
        color: isChecked
            ? context.scheme.primary.withValues(alpha: 0.06)
            : context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(2, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 34,
            child: Checkbox(
              visualDensity: VisualDensity.compact,
              value: isChecked,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: 32,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                children: [
                  Text(
                    row.date == null
                        ? '--'
                        : row.date!.day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    row.date == null
                        ? ''
                        : AppTime.dateShort(row.date).split(' ').last.toUpperCase(),
                    style: context.text.labelSmall?.copyWith(fontSize: 9, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.description,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                ),
                // One strip of a fixed height, whether or not this line has
                // buttons. Letting the buttons add their own height made every
                // havala row taller than the settlement above it, and the list
                // read as ragged rather than as a column of figures.
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      if (row.isPartnershipLeg) ...[
                        // A share earned on someone else's book. Marked so it
                        // is never read as this party's own play.
                        StatusChip('PTRN${row.ptrnSlot} · ${row.ptrnSourceCode ?? ''}',
                            tone: ChipTone.open),
                        const SizedBox(width: 6),
                      ],
                      if (row.isEdited) ...[
                        StatusChip('EDITED', tone: ChipTone.open),
                        const SizedBox(width: 6),
                      ],
                      // Expanded, not Flexible beside a Spacer: two flex
                      // children split the free space evenly, which left the
                      // voucher number reading "RGML HAVAL..." next to a strip
                      // of nothing.
                      Expanded(
                        child: Text(
                          byline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                        ),
                      ),
                      // Shown rather than hidden behind a swipe: an action
                      // nobody can see is an action nobody uses.
                      if (onJump != null)
                        _RowAction(
                          icon: Icons.open_in_new,
                          tooltip: 'Jump to that party',
                          colour: book.muted,
                          onTap: onJump!,
                        ),
                      if (onDelete != null)
                        _RowAction(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete entry',
                          colour: book.down,
                          onTap: onDelete!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Fixed width, so the figures form a straight column down the page
          // instead of stepping in and out with the length of each number.
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      Money.position(row.movement),
                      style: TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: book.forAmount(row.movement),
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      Money.format(row.closingBalance),
                      style: context.text.bodySmall
                          ?.copyWith(fontSize: 10.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet action on a statement line.
///
/// Sized to the strip it sits in rather than to Material's default button,
/// which is tall enough to change the height of the whole row.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.colour,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.rField),
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 24,
            child: Icon(icon, size: 16, color: colour),
          ),
        ),
      );
}

class _PartyPicker extends StatefulWidget {
  const _PartyPicker({required this.parties});

  final List<Party> parties;

  @override
  State<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends State<_PartyPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.text.trim().toUpperCase();
    final shown = term.isEmpty
        ? widget.parties
        : widget.parties
            .where((p) => p.code.contains(term) || p.name.toUpperCase().contains(term))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _search,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search code or name',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(shown[i].display),
                onTap: () => Navigator.of(context).pop(shown[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
