import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/match.dart';
import '../../data/models/settlement.dart';
import '../../shared/widgets/field_label.dart';
import '../matches/match_providers.dart';

final accountsProvider = FutureProvider<List<LedgerAccount>>((ref) async {
  return ref.watch(matchRepositoryProvider).accounts();
});

/// Settling a match.
///
/// Closing writes a figure into every party's ledger, so nothing is committed
/// until the operator has seen exactly what will move: the result is declared,
/// the settlement is fetched and shown in full, and only then can it be
/// closed. If the two columns do not agree, closing is blocked rather than
/// left to judgement.
class CloseMatchSheet extends ConsumerStatefulWidget {
  const CloseMatchSheet({super.key, required this.match});

  final GameMatch match;

  static Future<bool?> show(BuildContext context, {required GameMatch match}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CloseMatchSheet(match: match),
      );

  @override
  ConsumerState<CloseMatchSheet> createState() => _CloseMatchSheetState();
}

class _CloseMatchSheetState extends ConsumerState<CloseMatchSheet> {
  final _runController = TextEditingController();

  String? _winSelection;
  LedgerAccount? _account;
  Settlement? _preview;

  bool _loadingPreview = false;
  bool _closing = false;
  String? _error;

  bool get _isSession => widget.match.game == GameType.session;

  @override
  void dispose() {
    _runController.dispose();
    super.dispose();
  }

  /// The value the backend wants for the winning side. One day and test boards
  /// are settled by position - N1, N2 or the draw - rather than by name.
  String? get _selectionCode {
    if (_isSession) {
      final run = _runController.text.trim();
      return run.isEmpty ? null : run;
    }
    return _winSelection;
  }

  Future<void> _loadPreview() async {
    final selection = _selectionCode;
    if (selection == null || selection.isEmpty) return;

    setState(() {
      _loadingPreview = true;
      _error = null;
      _preview = null;
    });

    try {
      final preview = await ref.read(matchRepositoryProvider).settlementPreview(
            match: widget.match,
            winSelection: selection,
            plAccountId: _account?.id,
          );
      if (mounted) setState(() => _preview = preview);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _close() async {
    final selection = _selectionCode;
    final account = _account;
    final preview = _preview;

    final problem = switch (null) {
      _ when selection == null || selection.isEmpty =>
        _isSession ? 'Enter the run the session settled at' : 'Declare the result first',
      _ when account == null => 'Choose the P&L account',
      _ when preview == null => 'Check the settlement before closing',
      _ when !preview.balances =>
        'The two sides do not agree. Do not close - check the book first.',
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close ${widget.match.title}?'),
        content: Text(
          'Every party gets a settlement line in their ledger. '
          'Reopening it afterwards is a recall, not an edit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close match'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _closing = true;
      _error = null;
    });

    try {
      await ref.read(matchRepositoryProvider).closeMatch(
            match: widget.match,
            winSelection: selection!,
            plAccountId: account!.id,
            date: DateTime.now(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final book = context.book;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: book.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Close match', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${widget.match.title} · ${AppTime.date(DateTime.now())}',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 16),

              if (_isSession)
                LabelledField(
                  label: 'Settled at run',
                  child: TextField(
                    controller: _runController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _preview = null),
                    onSubmitted: (_) => _loadPreview(),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                )
              else
                LabelledField(
                  label: 'Result',
                  child: _ResultPicker(
                    match: widget.match,
                    selected: _winSelection,
                    onChanged: (value) => setState(() {
                      _winSelection = value;
                      _preview = null;
                    }),
                  ),
                ),

              const SizedBox(height: 14),
              LabelledField(
                label: 'P&L account',
                child: accounts.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(
                    'Could not load the accounts list.',
                    style: context.text.bodyMedium?.copyWith(color: book.down),
                  ),
                  data: (list) => _AccountPicker(
                    accounts: list,
                    selected: _account,
                    onChanged: (a) => setState(() {
                      _account = a;
                      _preview = null;
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              if (_preview == null)
                OutlinedButton.icon(
                  onPressed: _loadingPreview ? null : _loadPreview,
                  icon: _loadingPreview
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate_outlined, size: 18),
                  label: const Text('Check settlement'),
                )
              else
                _SettlementPreview(settlement: _preview!),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: context.text.bodyMedium?.copyWith(color: book.down)),
              ],

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closing ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: FilledButton(
                      // Nothing can be closed before its settlement has been
                      // seen and found to balance.
                      onPressed: (_closing || _preview == null || !_preview!.balances)
                          ? null
                          : _close,
                      child: _closing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Close match'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Declaring the result. A test carries the draw as a third outcome, and a cup
/// declares one team at a time.
class _ResultPicker extends StatelessWidget {
  const _ResultPicker({
    required this.match,
    required this.selected,
    required this.onChanged,
  });

  final GameMatch match;
  final String? selected;
  final ValueChanged<String> onChanged;

  /// The backend settles by position rather than by name.
  List<({String code, String label})> get _options {
    if (match.game == GameType.cup) {
      return [for (final team in match.cupNations) (code: team, label: team)];
    }
    return [
      (code: 'N1', label: match.nationA),
      (code: 'N2', label: match.nationB),
      if (match.game == GameType.test) (code: 'N3', label: match.drawName),
    ];
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in _options)
            ChoiceChip(
              label: Text(option.label),
              selected: selected == option.code,
              onSelected: (_) => onChanged(option.code),
            ),
        ],
      );
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.selected,
    required this.onChanged,
  });

  final List<LedgerAccount> accounts;
  final LedgerAccount? selected;
  final ValueChanged<LedgerAccount> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<LedgerAccount>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Choose an account'),
        items: [
          for (final account in accounts)
            DropdownMenuItem(value: account, child: Text(account.display)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
}

class _SettlementPreview extends StatelessWidget {
  const _SettlementPreview({required this.settlement});

  final Settlement settlement;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    if (settlement.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          border: Border.all(color: book.line),
        ),
        child: Text('Nothing to settle on this result.', style: context.text.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!settlement.balances)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: book.downSoft,
              borderRadius: BorderRadius.circular(AppTheme.rField),
              border: Border(left: BorderSide(color: book.down, width: 2)),
            ),
            child: Text(
              'Take and give do not agree. Check the book before closing.',
              style: TextStyle(fontSize: 12, color: book.down, fontWeight: FontWeight.w600),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Column(
                title: 'TAKE MONEY',
                lines: settlement.take,
                total: settlement.takeTotal,
                tone: book.up,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Column(
                title: 'GIVE MONEY',
                lines: settlement.give,
                total: settlement.giveTotal,
                tone: book.down,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.lines,
    required this.total,
    required this.tone,
  });

  final String title;
  final List<SettlementLine> lines;
  final double total;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        border: Border.all(color: book.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: context.text.labelSmall),
          const SizedBox(height: 7),
          if (lines.isEmpty)
            Text('—', style: context.text.bodySmall)
          else
            for (final line in lines.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      Money.format(line.amount),
                      style: const TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          if (lines.length > 8)
            Text('+${lines.length - 8} more', style: context.text.bodySmall?.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Divider(color: book.line, height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('TOTAL', style: context.text.labelSmall)),
              Text(
                Money.format(total),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
