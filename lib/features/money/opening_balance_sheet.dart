import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/field_label.dart';
import '../../shared/widgets/party_field.dart';
import '../matches/match_providers.dart';

/// One party's opening figure.
class _Line {
  Party? party;
  final amount = TextEditingController();

  /// Which side the balance sits on. A party can start owing or being owed.
  bool isDebit = true;

  void dispose() => amount.dispose();
}

/// Entering opening balances.
///
/// A voucher carries many parties at once, and its two sides have to agree
/// before it can be saved - the same rule the clearing journal follows, and
/// for the same reason: a book that starts out of balance never comes back.
class OpeningBalanceSheet extends ConsumerStatefulWidget {
  const OpeningBalanceSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const OpeningBalanceSheet(),
      );

  @override
  ConsumerState<OpeningBalanceSheet> createState() => _OpeningBalanceSheetState();
}

class _OpeningBalanceSheetState extends ConsumerState<OpeningBalanceSheet> {
  final _voucherNo = TextEditingController();
  final _lines = <_Line>[_Line()];

  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVoucherNo();
  }

  /// The series is kept by the Document Code master, so the number comes from
  /// the server rather than being typed - the same voucher run as the desk.
  Future<void> _loadVoucherNo() async {
    try {
      final body = asMap(
        await ref.read(apiClientProvider).get('/soda/opening-balances/get_latest_item_code/'),
      );
      final number = (body['item_code'] ?? '').toString().trim();
      if (mounted && number.isNotEmpty) _voucherNo.text = number;
    } catch (_) {
      // Falls back to whatever the operator types.
    }
  }

  @override
  void dispose() {
    _voucherNo.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double _amountOf(_Line line) => double.tryParse(line.amount.text.trim()) ?? 0;

  double get _debitTotal => _lines
      .where((l) => l.isDebit)
      .fold(0, (sum, l) => sum + _amountOf(l));

  double get _creditTotal => _lines
      .where((l) => !l.isDebit)
      .fold(0, (sum, l) => sum + _amountOf(l));

  bool get _balances => (_debitTotal - _creditTotal).abs() < 0.005;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 3),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_busy) return;

    final filled = _lines.where((l) => l.party != null && _amountOf(l) > 0).toList();

    final problem = switch (null) {
      _ when _voucherNo.text.trim().isEmpty => 'Enter a voucher number',
      _ when filled.isEmpty => 'Add at least one party with an amount',
      _ when !_balances => 'Debit and credit do not agree. A book cannot open out of balance.',
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
      await ref.read(apiClientProvider).post('/soda/opening-balances/', data: {
        'voucher_no': _voucherNo.text.trim(),
        // The date the operator picked, in their own zone, so the voucher
        // lands on the day they meant.
        'voucher_date': AppTime.apiDate(_date),
        'dr_total': _debitTotal,
        'cr_total': _creditTotal,
        'details': [
          for (final line in filled)
            {
              'party_id': line.party!.id,
              'debit': line.isDebit ? _amountOf(line) : 0,
              'credit': line.isDebit ? 0 : _amountOf(line),
            },
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the voucher. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parties = ref.watch(partiesProvider);
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
              Text('New opening balance', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text('What each party was carrying', style: context.text.bodySmall),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Voucher no',
                      child: TextField(
                        controller: _voucherNo,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: 'Loading…'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: LabelledField(
                      label: 'Date',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.rField),
                        onTap: _pickDate,
                        child: Container(
                          height: AppTheme.minTouch,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: BoxDecoration(
                            color: context.scheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.rField),
                            border: Border.all(color: book.line),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppTime.date(_date),
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(Icons.calendar_today_outlined, size: 16, color: book.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Text('PARTIES', style: context.text.labelSmall),
              const SizedBox(height: 8),

              parties.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Text(
                  'Could not load the party list.',
                  style: context.text.bodyMedium?.copyWith(color: book.down),
                ),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _lines.length; i++)
                      _LineRow(
                        line: _lines[i],
                        parties: list,
                        canRemove: _lines.length > 1,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() {
                          _lines.removeAt(i).dispose();
                        }),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_Line())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add party'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              _Balance(debit: _debitTotal, credit: _creditTotal, balances: _balances),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: context.text.bodyMedium?.copyWith(color: book.down)),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: FilledButton(
                      // A voucher that does not balance cannot be saved at all,
                      // rather than being saved and found later.
                      onPressed: _busy || !parties.hasValue || !_balances ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save voucher'),
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

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.parties,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _Line line;
  final List<Party> parties;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PartyField(
                  parties: parties,
                  selected: line.party,
                  hint: 'Choose party',
                  onChanged: (p) {
                    line.party = p;
                    onChanged();
                  },
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove this line',
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text('Dr', style: TextStyle(color: book.up)),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Cr', style: TextStyle(color: book.down)),
                    ),
                  ],
                  selected: {line.isDebit},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    line.isDebit = value.first;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: line.amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(hintText: '0'),
                  style: const TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.debit, required this.credit, required this.balances});

  final double debit;
  final double credit;
  final bool balances;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    if (debit == 0 && credit == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: balances ? book.upSoft : book.downSoft,
        borderRadius: BorderRadius.circular(AppTheme.rField),
      ),
      child: Row(
        children: [
          Icon(
            balances ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: balances ? book.up : book.down,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              balances
                  ? 'Balanced at ${Money.format(debit, decimals: 0)}'
                  : 'Dr ${Money.format(debit, decimals: 0)} · Cr ${Money.format(credit, decimals: 0)} — off by ${Money.format((debit - credit).abs(), decimals: 0)}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: balances ? book.up : book.down,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
