import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/field_label.dart';
import 'havala_screen.dart';
import '../../shared/widgets/app_dropdown.dart';

final _balancesProvider = FutureProvider.autoDispose<List<PartyBalanceRow>>(
  (ref) => ref.watch(havalaRepositoryProvider).partiesWithBalances(),
);

/// Squaring several clients off against one party at once.
///
/// Doing this by hand means raising one havala per client and getting the
/// direction right every time - the mistake this screen exists to remove. Each
/// client's own balance decides who pays whom, so the operator picks who is
/// settling and which clients, and never types an amount.
class AutoHavalaSheet extends ConsumerStatefulWidget {
  const AutoHavalaSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const AutoHavalaSheet(),
      );

  @override
  ConsumerState<AutoHavalaSheet> createState() => _AutoHavalaSheetState();
}

class _AutoHavalaSheetState extends ConsumerState<AutoHavalaSheet> {
  PartyBalanceRow? _target;
  final _picked = <int>{};
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit(List<PartyBalanceRow> all) async {
    if (_busy) return;

    final target = _target;
    final chosen = all.where((p) => _picked.contains(p.id) && !p.isSquare);

    final problem = switch (null) {
      _ when target == null => 'Choose who they are settling against',
      _ when chosen.isEmpty => 'Choose at least one client with a balance',
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(havalaRepositoryProvider).autoHavala(
            targetPartyId: target!.id,
            date: _date,
            amountByClientId: {for (final p in chosen) p.id: p.balance},
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not raise the havalas. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(_balancesProvider);
    final book = context.book;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: AsyncView(
            value: rows,
            onRetry: () => ref.invalidate(_balancesProvider),
            builder: (all) {
              // A party with nothing to settle is noise here, and the target
              // cannot be one of the clients being settled.
              final clients = all
                  .where((p) => !p.isSquare && p.id != _target?.id)
                  .toList()
                ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

              final chosen =
                  clients.where((p) => _picked.contains(p.id)).toList();
              final total = chosen.fold<double>(0, (s, p) => s + p.balance);

              return Column(
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
                  Text('Auto havala', style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Settle several clients against one party at once',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: LabelledField(
                          label: 'Settle against',
                          child: AppDropdown<PartyBalanceRow>(
                            initialValue: _target,
                            isExpanded: true,
                            hint: const Text('Choose a party'),
                            items: [
                              for (final p in all)
                                DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.display,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (p) => setState(() {
                              _target = p;
                              _picked.remove(p?.id);
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        flex: 2,
                        child: LabelledField(
                          label: 'Date',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppTheme.rField),
                            onTap: _pickDate,
                            child: Container(
                              height: AppTheme.minTouch,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.scheme.surface,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.rField),
                                border: Border.all(color: book.line),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppTime.date(_date),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today_outlined,
                                      size: 15, color: book.muted),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('CLIENTS TO SETTLE', style: context.text.labelSmall),
                      const Spacer(),
                      if (clients.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            if (_picked.length == clients.length) {
                              _picked.clear();
                            } else {
                              _picked
                                ..clear()
                                ..addAll(clients.map((p) => p.id));
                            }
                          }),
                          child: Text(
                            _picked.length == clients.length
                                ? 'Clear all'
                                : 'Select all',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),

                  Flexible(
                    child: clients.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'Everyone is square. There is nothing to settle.',
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: clients.length,
                            itemBuilder: (context, i) {
                              final p = clients[i];
                              final on = _picked.contains(p.id);
                              return CheckboxListTile(
                                dense: true,
                                value: on,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (v) => setState(() {
                                  v == true ? _picked.add(p.id) : _picked.remove(p.id);
                                }),
                                title: Text(
                                  p.display,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  // Saying which way it goes matters more than
                                  // the sign: this is the whole decision.
                                  p.balance < 0 ? 'pays' : 'receives',
                                  style: context.text.bodySmall
                                      ?.copyWith(fontSize: 10.5),
                                ),
                                secondary: Text(
                                  Money.format(p.balance.abs()),
                                  style: TextStyle(
                                    fontFamily: 'Roboto Mono',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: book.forAmount(p.balance),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  if (chosen.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${chosen.length} selected',
                          style: context.text.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          'Net ${Money.format(total.abs())}',
                          style: TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: book.forAmount(total),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: context.text.bodyMedium?.copyWith(color: book.down)),
                  ],

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : () => _submit(all),
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  chosen.isEmpty
                                      ? 'Raise havalas'
                                      : 'Raise ${chosen.length} havala'
                                          '${chosen.length == 1 ? '' : 's'}',
                                ),
                        ),
                      ),
                    ],
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
