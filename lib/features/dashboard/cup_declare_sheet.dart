import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/match.dart';
import '../../data/models/settlement.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/field_label.dart';
import '../../shared/widgets/status_chip.dart';
import '../matches/match_providers.dart';
import 'close_match_sheet.dart';

final cupProgressProvider =
    FutureProvider.family<CupProgress, GameMatch>((ref, cup) async {
  return ref.watch(matchRepositoryProvider).cupProgress(cup);
});

/// Declaring a cup result.
///
/// Teams are knocked out one at a time and each elimination settles that
/// team's trades. That holds until two teams are left: at that point there is
/// no losing team to report - the result is simply who won - so this screen
/// asks for the winner instead, and the other side goes out alongside it.
class CupDeclareSheet extends ConsumerStatefulWidget {
  const CupDeclareSheet({super.key, required this.cup});

  final GameMatch cup;

  static Future<bool?> show(BuildContext context, {required GameMatch cup}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CupDeclareSheet(cup: cup),
      );

  @override
  ConsumerState<CupDeclareSheet> createState() => _CupDeclareSheetState();
}

class _CupDeclareSheetState extends ConsumerState<CupDeclareSheet> {
  String? _nation;
  LedgerAccount? _account;
  bool _busy = false;
  String? _error;
  bool _declaredSomething = false;

  Future<void> _declare(CupProgress progress) async {
    final nation = _nation;
    final account = _account;

    final problem = switch (null) {
      _ when nation == null => progress.asksForWinner
          ? 'Choose the team that won'
          : 'Choose the team that is out',
      _ when account == null => 'Choose the P&L account',
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    // On the closing declaration the team named is the winner, so the one that
    // goes out is whichever of the two is left over.
    final loser = progress.asksForWinner
        ? progress.pending.firstWhere((n) => n != nation, orElse: () => '')
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(progress.asksForWinner ? 'Declare $nation winner?' : 'Knock $nation out?'),
        content: Text(
          progress.asksForWinner
              ? "$nation wins the cup and $loser goes out. Both sides are "
                  "settled into every party's ledger and the cup completes."
              : "The trades on $nation are settled into every party's ledger.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(progress.asksForWinner ? 'Declare winner & finish' : 'Knock out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(matchRepositoryProvider).declareCupResult(
            cup: widget.cup,
            nation: nation!,
            plAccountId: account!.id,
          );
      _declaredSomething = true;
      setState(() => _nation = null);
      ref.invalidate(cupProgressProvider(widget.cup));
      ref.invalidate(boardProvider(widget.cup));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(cupProgressProvider(widget.cup));
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
              Text('Declare result', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(widget.cup.title, style: context.text.bodySmall),
              const SizedBox(height: 16),

              SizedBox(
                height: 280,
                child: AsyncView(
                  value: progress,
                  onRetry: () => ref.invalidate(cupProgressProvider(widget.cup)),
                  builder: (data) => data.isComplete
                      ? _Champion(progress: data)
                      : _Eliminate(
                          progress: data,
                          selected: _nation,
                          onSelected: (n) => setState(() => _nation = n),
                          account: _account,
                          accounts: accounts,
                          onAccount: (a) => setState(() => _account = a),
                        ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: context.text.bodyMedium?.copyWith(color: book.down)),
              ],

              const SizedBox(height: 16),
              progress.maybeWhen(
                data: (data) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(_declaredSomething),
                        child: Text(data.isComplete ? 'Close' : 'Done for now'),
                      ),
                    ),
                    if (!data.isComplete) ...[
                      const SizedBox(width: 11),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : () => _declare(data),
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Knock out'),
                        ),
                      ),
                    ],
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eliminate extends StatelessWidget {
  const _Eliminate({
    required this.progress,
    required this.selected,
    required this.onSelected,
    required this.account,
    required this.accounts,
    required this.onAccount,
  });

  final CupProgress progress;
  final String? selected;
  final ValueChanged<String> onSelected;
  final LedgerAccount? account;
  final AsyncValue<List<LedgerAccount>> accounts;
  final ValueChanged<LedgerAccount> onAccount;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.out.isNotEmpty) ...[
            Text('ALREADY OUT', style: context.text.labelSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final team in progress.out) StatusChip(team, tone: ChipTone.muted),
              ],
            ),
            const SizedBox(height: 14),
          ],

          if (progress.isLastElimination)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: book.brandSoft,
                borderRadius: BorderRadius.circular(AppTheme.rField),
                border: Border(left: BorderSide(color: context.scheme.primary, width: 2)),
              ),
              child: Text(
                'Two teams left - name the one that won. The other goes out with it.',
                style: TextStyle(fontSize: 12, color: context.scheme.primary),
              ),
            ),

          LabelledField(
            label: progress.asksForWinner ? 'Team that won' : 'Team that is out',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final team in progress.pending)
                  ChoiceChip(
                    label: Text(team),
                    selected: selected == team,
                    onSelected: (_) => onSelected(team),
                  ),
              ],
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
              data: (list) => DropdownButtonFormField<LedgerAccount>(
                initialValue: account,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Choose an account'),
                items: [
                  for (final a in list) DropdownMenuItem(value: a, child: Text(a.display)),
                ],
                onChanged: (value) {
                  if (value != null) onAccount(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Champion extends StatelessWidget {
  const _Champion({required this.progress});

  final CupProgress progress;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 38, color: book.warn),
          const SizedBox(height: 12),
          Text(progress.winner ?? '', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            progress.winnerAutoDeclared
                ? 'Last team standing — declared champion automatically'
                : 'Champion',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          if (progress.out.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('KNOCKED OUT', style: context.text.labelSmall),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final team in progress.out) StatusChip(team, tone: ChipTone.muted),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
