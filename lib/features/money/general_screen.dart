import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/general_view.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/async_view.dart';
import '../masters/master_providers.dart';
import '../matches/match_providers.dart';
import 'ledger_screen.dart';
import '../../shared/widgets/app_dropdown.dart';

/// `dd-MM-yyyy`, which is the only shape this endpoint's `from_date` accepts.
String _asOfParam(DateTime at) =>
    '${at.day.toString().padLeft(2, '0')}-'
    '${at.month.toString().padLeft(2, '0')}-'
    '${at.year}';

/// Set on each dropdown item rather than on the field, so the selected value
/// keeps the theme's colour instead of coming out unpainted.
const _filterText = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);

/// The whole book as at one date.
///
/// Keyed on the date rather than fetched once: "where did we stand on the 3rd"
/// is a different question from "where do we stand now", and the server is the
/// only thing that can answer the first.
final generalViewProvider = FutureProvider.family<GeneralView, DateTime?>((
  ref,
  asOf,
) async {
  final body = await ref
      .watch(apiClientProvider)
      .get(
        '/master/parties/view_general/',
        query: {if (asOf != null) 'from_date': _asOfParam(asOf)},
      );
  return GeneralView.fromJson(asMap(body));
});

/// Where the whole book stands - the desk's VIEW GENERAL.
///
/// Every other screen answers for one match or one party. This one answers for
/// all of them at once: who the house owes (dena), who owes the house (lena),
/// and the gap between them. The two sides are shown separately rather than
/// netted, because the gap is the thing worth looking at.
class GeneralScreen extends ConsumerStatefulWidget {
  const GeneralScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends ConsumerState<GeneralScreen> {
  final _search = TextEditingController();

  DateTime? _asOf = AppTime.today;
  int? _categoryId;
  bool _byAmount = false;

  /// Ticked off as the list is worked through. Held for the session only: it
  /// is a reconciling scratch-pad, not a record, and the desk clears it the
  /// same way every time it reopens the screen.
  final _checked = <int>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final start = _asOf ?? AppTime.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(start.year - 3),
      lastDate: DateTime(start.year + 2),
    );
    if (picked != null) setState(() => _asOf = picked);
  }

  void _clear() => setState(() {
    _asOf = AppTime.today;
    _search.clear();
    _categoryId = null;
    _byAmount = false;
    _checked.clear();
  });

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing the report…')),
    );
    try {
      await ref
          .read(reportSharingProvider)
          .sharePdf(
            path: '/master/parties/download_general_report/',
            name: 'General report',
            query: {
              if (_asOf != null) 'from_date': _asOfParam(_asOf!),
              if (_search.text.trim().isNotEmpty)
                'party_name': _search.text.trim(),
              if (_categoryId != null) 'category_id': _categoryId,
              if (_byAmount) 'order_by_amount': 'true',
            },
          );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Applies the filter bar to one side of the book.
  List<GeneralLine> _apply(List<GeneralLine> lines) {
    final term = _search.text.trim().toLowerCase();
    final out = [
      for (final line in lines)
        if ((term.isEmpty ||
                line.name.toLowerCase().contains(term) ||
                line.code.toLowerCase().contains(term)) &&
            (_categoryId == null || line.categoryId == _categoryId))
          line,
    ];
    if (_byAmount) out.sort((a, b) => b.amount.compareTo(a.amount));
    return out;
  }

  void _toggle(int partyId) => setState(() {
    _checked.contains(partyId)
        ? _checked.remove(partyId)
        : _checked.add(partyId);
  });

  void _toggleAll(List<GeneralLine> lines, bool on) => setState(() {
    for (final line in lines) {
      on ? _checked.add(line.partyId) : _checked.remove(line.partyId);
    }
  });

  @override
  Widget build(BuildContext context) {
    final general = ref.watch(generalViewProvider(_asOf));

    final body = RefreshIndicator(
      onRefresh: () => ref.refresh(generalViewProvider(_asOf).future),
      child: AsyncView(
        value: general,
        onRetry: () => ref.invalidate(generalViewProvider(_asOf)),
        isEmpty: (data) => data.isEmpty,
        emptyTitle: 'Nothing outstanding',
        emptyMessage: 'Balances appear here once matches are settled.',
        builder: (data) {
          final given = _apply(data.give);
          final take = _apply(data.take);

          // Totals follow the filter: a total that counted rows the operator
          // has just filtered away could not be reconciled against anything.
          final totalGiven = given.fold<double>(0, (s, l) => s + l.amount);
          final totalTake = take.fold<double>(0, (s, l) => s + l.amount);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _Side(
                      title: 'GIVEN AMOUNTS (DENA)',
                      lines: given,
                      total: totalGiven,
                      isCredit: true,
                      checked: _checked,
                      onToggle: _toggle,
                      onToggleAll: (on) => _toggleAll(given, on),
                    ),
                    _Side(
                      title: 'TAKE AMOUNTS (LENA)',
                      lines: take,
                      total: totalTake,
                      isCredit: false,
                      checked: _checked,
                      onToggle: _toggle,
                      onToggleAll: (on) => _toggleAll(take, on),
                    ),
                  ],
                ),
              ),
              _Footer(totalDena: totalGiven, totalLena: totalTake),
            ],
          );
        },
      ),
    );

    final filters = _FilterBar(
      asOf: _asOf,
      onPickDate: _pickDate,
      search: _search,
      onSearchChanged: () => setState(() {}),
      categoryId: _categoryId,
      onCategory: (id) => setState(() => _categoryId = id),
      byAmount: _byAmount,
      onByAmount: (v) => setState(() => _byAmount = v),
      onClear: _clear,
      onShare: _share,
    );

    if (widget.embedded) {
      return Column(
        children: [
          filters,
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('View general'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share as PDF',
            onPressed: _share,
          ),
        ],
      ),
      body: Column(
        children: [
          filters,
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// The desk's filter row, folded onto a phone.
///
/// The date and the search box stay visible because they are used constantly;
/// category and ordering sit one tap behind, because they are set once and
/// then left alone.
class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({
    required this.asOf,
    required this.onPickDate,
    required this.search,
    required this.onSearchChanged,
    required this.categoryId,
    required this.onCategory,
    required this.byAmount,
    required this.onByAmount,
    required this.onClear,
    required this.onShare,
  });

  final DateTime? asOf;
  final VoidCallback onPickDate;
  final TextEditingController search;
  final VoidCallback onSearchChanged;
  final int? categoryId;
  final ValueChanged<int?> onCategory;
  final bool byAmount;
  final ValueChanged<bool> onByAmount;
  final VoidCallback onClear;
  final VoidCallback onShare;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final categories = ref.watch(
      masterRowsProvider('/master/party-categories/'),
    );
    final extras =
        (widget.categoryId != null ? 1 : 0) + (widget.byAmount ? 1 : 0);

    return Container(
      color: context.scheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              _DatePill(date: widget.asOf, onTap: widget.onPickDate),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: widget.search,
                    onChanged: (_) => widget.onSearchChanged(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Filter by name',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: widget.search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                widget.search.clear();
                                widget.onSearchChanged();
                              },
                            ),
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
                  child: Icon(
                    _open ? Icons.tune : Icons.tune_outlined,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Share as PDF',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onShare,
                icon: const Icon(Icons.ios_share, size: 19),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  // Left to size itself: pinned to 40 the field clipped the
                  // bottom of its own selected value.
                  child: AppDropdown<int?>(
                    initialValue: widget.categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    hint: const Text('-- ALL --', style: _filterText),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('-- ALL --', style: _filterText),
                      ),
                      for (final row
                          in categories.value ?? const <Map<String, dynamic>>[])
                        DropdownMenuItem<int?>(
                          value: int.tryParse('${row['id']}'),
                          child: Text(
                            (row['category_name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _filterText,
                          ),
                        ),
                    ],
                    onChanged: widget.onCategory,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            Row(
              children: [
                Text('ORDER BY AMOUNT', style: context.text.labelSmall),
                const Spacer(),
                Switch(value: widget.byAmount, onChanged: widget.onByAmount),
              ],
            ),
          ],
          if (!_open && extras > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$extras filter${extras == 1 ? '' : 's'} on',
                  style: context.text.labelSmall?.copyWith(color: book.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppTheme.rField),
    onTap: onTap,
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.rField),
        border: Border.all(color: context.book.line),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: context.book.muted,
          ),
          const SizedBox(width: 6),
          Text(
            AppTime.date(date),
            style: const TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One side of the book, with its own header, check-all and total.
class _Side extends ConsumerWidget {
  const _Side({
    required this.title,
    required this.lines,
    required this.total,
    required this.isCredit,
    required this.checked,
    required this.onToggle,
    required this.onToggleAll,
  });

  final String title;
  final List<GeneralLine> lines;
  final double total;
  final bool isCredit;
  final Set<int> checked;
  final ValueChanged<int> onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = context.book;
    final tone = isCredit ? book.down : book.up;
    final allOn =
        lines.isNotEmpty && lines.every((l) => checked.contains(l.partyId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.labelSmall?.copyWith(color: tone),
                ),
              ),
              Text(
                Money.format(total),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
              SizedBox(
                width: 36,
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: allOn,
                  onChanged: lines.isEmpty
                      ? null
                      : (v) => onToggleAll(v == true),
                ),
              ),
            ],
          ),
        ),
        if (lines.isEmpty)
          Container(
            color: context.scheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nothing on this side',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ),
        for (final line in lines)
          _GeneralRow(
            line: line,
            tone: tone,
            isChecked: checked.contains(line.partyId),
            onToggle: () => onToggle(line.partyId),
          ),
      ],
    );
  }
}

class _GeneralRow extends ConsumerWidget {
  const _GeneralRow({
    required this.line,
    required this.tone,
    required this.isChecked,
    required this.onToggle,
  });

  final GeneralLine line;
  final Color tone;
  final bool isChecked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = context.book;

    return InkWell(
      // A figure here is a question - "why does this party owe that?" - and
      // the statement is the answer, so it is one tap away.
      onTap: () async {
        final parties = await ref.read(partiesProvider.future);
        if (!context.mounted) return;
        final party = parties.firstWhere(
          (p) => p.id == line.partyId,
          orElse: () =>
              Party(id: line.partyId, code: line.code, name: line.name),
        );
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => LedgerScreen(party: party)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          border: Border(bottom: BorderSide(color: book.line)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                line.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line.name.isEmpty ? line.code : line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              Money.format(line.amount),
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
            SizedBox(
              width: 36,
              child: Checkbox(
                visualDensity: VisualDensity.compact,
                value: isChecked,
                onChanged: (_) => onToggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three figures the screen exists to produce, pinned where they cannot
/// scroll away from the rows they belong to.
class _Footer extends StatelessWidget {
  const _Footer({required this.totalDena, required this.totalLena});

  final double totalDena;
  final double totalLena;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final net = totalLena - totalDena;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: _Figure(
              label: 'TOTAL DENA',
              value: totalDena,
              tone: book.down,
            ),
          ),
          Expanded(
            child: _Figure(
              label: 'NET BALANCE',
              value: net,
              tone: book.forAmount(net),
              signed: true,
            ),
          ),
          Expanded(
            child: _Figure(
              label: 'TOTAL LENA',
              value: totalLena,
              tone: book.up,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
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
      Text(label, style: context.text.labelSmall),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          signed ? Money.position(value) : Money.format(value),
          style: TextStyle(
            fontFamily: 'Roboto Mono',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: tone,
          ),
        ),
      ),
    ],
  );
}
