import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/field_label.dart';
import '../../shared/widgets/party_field.dart';
import '../matches/match_providers.dart';
import 'havala_screen.dart';

/// Raising a havala.
///
/// A havala is a transfer, so the form is drawn as one: payer on top, receiver
/// below, an arrow between them. There is no way to misread which direction
/// the money went, which is the mistake this form exists to prevent.
class HavalaEntrySheet extends ConsumerStatefulWidget {
  const HavalaEntrySheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const HavalaEntrySheet(),
      );

  @override
  ConsumerState<HavalaEntrySheet> createState() => _HavalaEntrySheetState();
}

class _HavalaEntrySheetState extends ConsumerState<HavalaEntrySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  Party? _from;
  Party? _to;
  DateTime _date = DateTime.now();

  /// Fetched up front so the operator sees which voucher this will become
  /// before saving, the same as on the desk.
  String? _voucherNo;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVoucherNo();
  }

  Future<void> _loadVoucherNo() async {
    try {
      final number = await ref.read(havalaRepositoryProvider).nextVoucherNo();
      if (mounted) setState(() => _voucherNo = number);
    } catch (_) {
      // Not fatal - the repository asks again at save time.
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_busy) return;

    final amount = double.tryParse(_amount.text.trim());
    final problem = switch (null) {
      _ when _from == null => 'Choose who is paying',
      _ when _to == null => 'Choose who is receiving',
      _ when _from!.id == _to!.id => 'A havala needs two different parties',
      _ when amount == null || amount <= 0 => 'Enter the amount',
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
      await ref.read(havalaRepositoryProvider).create(
            fromPartyId: _from!.id,
            toPartyId: _to!.id,
            amount: amount!,
            date: _date,
            description: _note.text,
            voucherNo: _voucherNo,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the havala. Please try again.');
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
              Text('New havala', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                _voucherNo == null
                    ? 'A transfer between two parties'
                    : 'A transfer between two parties · $_voucherNo',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 16),

              parties.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'Could not load the party list.',
                    style: context.text.bodyMedium?.copyWith(color: book.down),
                  ),
                ),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabelledField(
                      label: 'From party — pays',
                      child: PartyField(
                        parties: list,
                        selected: _from,
                        onChanged: (p) => setState(() => _from = p),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Icon(Icons.south, size: 22, color: context.scheme.primary),
                    ),
                    LabelledField(
                      label: 'To party — receives',
                      child: PartyField(
                        parties: list,
                        selected: _to,
                        onChanged: (p) => setState(() => _to = p),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Amount',
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(hintText: '0'),
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
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

              const SizedBox(height: 14),
              LabelledField(
                label: 'Narration',
                child: TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'What this transfer is for',
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: context.text.bodyMedium?.copyWith(color: book.down)),
              ],

              const SizedBox(height: 18),
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
                      onPressed: _busy || !parties.hasValue ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save havala'),
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
