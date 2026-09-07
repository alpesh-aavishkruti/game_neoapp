import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/match.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/field_label.dart';
import '../../shared/widgets/party_field.dart';
import '../matches/match_providers.dart';
import 'master_providers.dart';

/// Setting a party's brokerage for one game.
///
/// This is the record the whole partnership split is worked out from: a
/// partner's share of a client's book, and the commission taken off the top.
/// It is per party, per game and per date, so a rate can change without
/// rewriting what already settled at the old one.
class BrokerageEditSheet extends ConsumerStatefulWidget {
  const BrokerageEditSheet({super.key, this.editing});

  /// The row being corrected, or null when adding.
  final Map<String, dynamic>? editing;

  static Future<bool?> show(BuildContext context, {Map<String, dynamic>? editing}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BrokerageEditSheet(editing: editing),
      );

  @override
  ConsumerState<BrokerageEditSheet> createState() => _BrokerageEditSheetState();
}

/// One partner slot on the form.
class _Slot {
  _Slot(this.index);

  final int index;
  Party? party;
  final percent = TextEditingController();

  /// Slots 2 to 5 carry a type; slot 1 is the primary allocation and has none.
  String? type;

  bool get isPrimary => index == 1;
  bool get isFilled => party != null;

  void dispose() => percent.dispose();
}

class _BrokerageEditSheetState extends ConsumerState<BrokerageEditSheet> {
  final _commPercent = TextEditingController();
  final _commCodePercent = TextEditingController();
  final _slots = [for (var i = 1; i <= 5; i++) _Slot(i)];

  Party? _party;
  Party? _commCode;
  GameType _game = GameType.oneDay;
  DateTime _date = DateTime.now();

  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  static const _partnerTypes = ['Same as PTNR', 'Without PTNR'];

  @override
  void initState() {
    super.initState();
    final row = widget.editing;
    if (row == null) return;

    _game = GameType.parse(row['game_code']);
    _date = AppTime.toLocal(row['date']) ?? DateTime.now();
    _commPercent.text = _text(row['comm_percent']);
    _commCodePercent.text = _text(row['comm_code_percent']);
    for (final slot in _slots) {
      slot.percent.text = _text(row['partner${slot.index}_percent']);
      if (!slot.isPrimary) {
        final type = (row['partner${slot.index}_type'] ?? '').toString();
        slot.type = _partnerTypes.contains(type) ? type : null;
      }
    }
  }

  /// Percentages arrive as `"20.00"`; a trailing `.00` is noise on a form.
  String _text(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw == '0' || raw == '0.00') return '';
    final asNumber = double.tryParse(raw);
    if (asNumber == null) return raw;
    return asNumber == asNumber.roundToDouble()
        ? asNumber.toStringAsFixed(0)
        : raw;
  }

  /// Re-attaches the parties once the list has loaded, since the stored row
  /// only carries their ids.
  void _hydrate(List<Party> parties) {
    final row = widget.editing;
    if (row == null || _party != null) return;

    Party? byId(dynamic id) {
      final value = int.tryParse('$id');
      if (value == null) return null;
      for (final p in parties) {
        if (p.id == value) return p;
      }
      return null;
    }

    _party = byId(row['party']);
    _commCode = byId(row['comm_code']);
    for (final slot in _slots) {
      slot.party = byId(row['partner${slot.index}']);
    }
  }

  @override
  void dispose() {
    _commPercent.dispose();
    _commCodePercent.dispose();
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  double? _percentOf(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _save() async {
    if (_busy) return;

    final filled = _slots.where((s) => s.isFilled).toList();
    final missingPercent = filled.where((s) => (_percentOf(s.percent) ?? 0) <= 0).toList();
    final totalShare = filled.fold<double>(0, (sum, s) => sum + (_percentOf(s.percent) ?? 0));

    final problem = switch (null) {
      _ when _party == null => 'Choose the party this brokerage belongs to',
      _ when missingPercent.isNotEmpty =>
        'Partner ${missingPercent.first.index} has no percentage',
      // The partners divide the client's book between them; more than all of
      // it is a typo, and one worth catching before it reaches a settlement.
      _ when totalShare > 100 => 'Partner shares add up to more than 100%',
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
      final payload = <String, dynamic>{
        'party': _party!.id,
        'game_code': _game.code,
        'date': AppTime.apiDate(_date),
        'comm_percent': _percentOf(_commPercent) ?? 0,
        'comm_code': _commCode?.id,
        'comm_code_percent': _percentOf(_commCodePercent) ?? 0,
        'is_active': true,
      };
      for (final slot in _slots) {
        payload['partner${slot.index}'] = slot.party?.id;
        payload['partner${slot.index}_percent'] = _percentOf(slot.percent) ?? 0;
        if (!slot.isPrimary) {
          payload['partner${slot.index}_type'] = slot.party == null ? null : slot.type;
        }
      }

      final api = ref.read(apiClientProvider);
      if (_isEditing) {
        await api.patch('/master/brokerages/${widget.editing!['id']}/', data: payload);
      } else {
        await api.post('/master/brokerages/', data: payload);
      }

      ref.invalidate(masterRowsProvider('/master/brokerages/'));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the brokerage. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 3),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
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
              Text(_isEditing ? 'Edit brokerage' : 'New brokerage',
                  style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text('Commission and partner splits for one game',
                  style: context.text.bodySmall),
              const SizedBox(height: 16),

              parties.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'Could not load the party list.',
                    style: context.text.bodyMedium?.copyWith(color: book.down),
                  ),
                ),
                data: (list) {
                  _hydrate(list);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LabelledField(
                        label: 'Party',
                        child: PartyField(
                          parties: list,
                          selected: _party,
                          onChanged: (p) => setState(() => _party = p),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LabelledField(
                              label: 'Game',
                              child: DropdownButtonFormField<GameType>(
                                initialValue: _game,
                                isExpanded: true,
                                items: [
                                  for (final g in GameType.values)
                                    DropdownMenuItem(value: g, child: Text(g.label)),
                                ],
                                onChanged: (v) => setState(() => _game = v ?? _game),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: LabelledField(
                              label: 'From date',
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
                                      Icon(Icons.calendar_today_outlined,
                                          size: 16, color: book.muted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Text('COMMISSION', style: context.text.labelSmall),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LabelledField(
                              label: 'Comm %',
                              child: _PercentField(controller: _commPercent),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: LabelledField(
                              label: 'Code %',
                              child: _PercentField(controller: _commCodePercent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LabelledField(
                        label: 'Comm code party',
                        child: PartyField(
                          parties: list,
                          selected: _commCode,
                          hint: 'Optional',
                          onChanged: (p) => setState(() => _commCode = p),
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Text('PARTNERS', style: context.text.labelSmall)),
                          _ShareTotal(slots: _slots, percentOf: _percentOf),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final slot in _slots)
                        _SlotRow(
                          slot: slot,
                          parties: list,
                          types: _partnerTypes,
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  );
                },
              ),

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
                      onPressed: _busy || !parties.hasValue ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Add brokerage'),
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

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.parties,
    required this.types,
    required this.onChanged,
  });

  final _Slot slot;
  final List<Party> parties;
  final List<String> types;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LabelledField(
                  label: slot.isPrimary ? 'Partner 1 (primary)' : 'Partner ${slot.index}',
                  child: PartyField(
                    parties: parties,
                    selected: slot.party,
                    hint: 'None',
                    onChanged: (p) {
                      slot.party = p;
                      onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabelledField(
                  label: 'PTNR ${slot.index} %',
                  child: _PercentField(controller: slot.percent, onChanged: onChanged),
                ),
              ),
            ],
          ),
          // The type only means something once a partner is actually in the
          // slot, so it stays out of the way until then.
          if (!slot.isPrimary && slot.isFilled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<String>(
                initialValue: types.contains(slot.type) ? slot.type : null,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Partner type'),
                items: [
                  for (final type in types)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) {
                  slot.type = value;
                  onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows what the filled slots add up to, so an over-allocation is visible
/// while it is being typed rather than at save time.
class _ShareTotal extends StatelessWidget {
  const _ShareTotal({required this.slots, required this.percentOf});

  final List<_Slot> slots;
  final double? Function(TextEditingController) percentOf;

  @override
  Widget build(BuildContext context) {
    final total = slots
        .where((s) => s.isFilled)
        .fold<double>(0, (sum, s) => sum + (percentOf(s.percent) ?? 0));
    if (total == 0) return const SizedBox.shrink();

    final over = total > 100;
    return Text(
      '${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 2)}% allocated',
      style: TextStyle(
        fontFamily: 'Roboto Mono',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: over ? context.book.down : context.book.muted,
      ),
    );
  }
}

class _PercentField extends StatelessWidget {
  const _PercentField({required this.controller, this.onChanged});

  final TextEditingController controller;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged?.call(),
        decoration: const InputDecoration(hintText: '0', suffixText: '%'),
        style: const TextStyle(
          fontFamily: 'Roboto Mono',
          fontWeight: FontWeight.w700,
        ),
      );
}
