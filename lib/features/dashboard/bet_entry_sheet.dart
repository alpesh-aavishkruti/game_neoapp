import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bet_entry.dart';
import '../../data/models/match.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/field_label.dart';
import '../masters/party_edit_sheet.dart';
import '../matches/match_providers.dart';

/// Placing a bet, and correcting one.
///
/// This is the screen operators spend the whole day in. On the desk it is one
/// long row driven by keyboard shortcuts; there is no keyboard here, so it
/// becomes a sheet where side and type are single taps and the number pad opens
/// straight onto amount and rate.
///
/// The client's name resolves under the code as it is typed, which is what
/// catches a wrong code before the entry is saved rather than after.
///
/// Editing reuses the same sheet rather than a second one: the fields are
/// identical, and two sheets that must agree are two sheets that will not.
class BetEntrySheet extends ConsumerStatefulWidget {
  const BetEntrySheet({
    super.key,
    required this.match,
    this.lastUsed,
    this.editing,
  });

  final GameMatch match;

  /// Side and type from the previous entry, so a run of bets on the same side
  /// does not mean re-picking it every time.
  final ({String? nation, BetType type})? lastUsed;

  /// The entry being corrected. Null means a new one is being placed.
  final BetEntry? editing;

  /// Returns the side and type that were used, or null if nothing was saved.
  static Future<({String? nation, BetType type})?> show(
    BuildContext context, {
    required GameMatch match,
    ({String? nation, BetType type})? lastUsed,
    BetEntry? editing,
  }) =>
      showModalBottomSheet<({String? nation, BetType type})>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BetEntrySheet(
          match: match,
          lastUsed: lastUsed,
          editing: editing,
        ),
      );

  @override
  ConsumerState<BetEntrySheet> createState() => _BetEntrySheetState();
}

class _BetEntrySheetState extends ConsumerState<BetEntrySheet> {
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _clientCode = TextEditingController();
  final _run = TextEditingController();

  late String? _nation = widget.editing?.nation.isNotEmpty == true
      ? widget.editing!.nation
      : widget.lastUsed?.nation ?? widget.match.selectableNations.firstOrNull;
  late BetType _type = widget.editing?.betType ?? widget.lastUsed?.type ?? BetType.l;

  bool _busy = false;
  String? _error;

  bool get _isSession => widget.match.game == GameType.session;
  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;
    if (editing != null) {
      // Start from what was taken, so a correction only changes what the
      // operator actually retypes.
      _amount.text = editing.amount.toStringAsFixed(0);
      _rate.text = editing.rate.toString();
      _clientCode.text = editing.clientCode;
      if (editing.run != null) _run.text = '${editing.run}';
    } else if (_isSession) {
      // A session board prices per hundred, so that is where the rate starts.
      _rate.text = '100';
    }

    _clientCode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _clientCode.dispose();
    _run.dispose();
    super.dispose();
  }

  Party? _matchedParty(List<Party> parties) {
    final code = _clientCode.text.trim().toUpperCase();
    if (code.isEmpty) return null;
    for (final party in parties) {
      if (party.code == code) return party;
    }
    return null;
  }

  Future<void> _submit(List<Party> parties) async {
    if (_busy) return;

    final party = _matchedParty(parties);
    final amount = double.tryParse(_amount.text.trim());
    final rate = double.tryParse(_rate.text.trim());
    final run = int.tryParse(_run.text.trim());

    final problem = switch (null) {
      _ when _isSession && run == null => 'Enter the run figure',
      _ when !_isSession && (_nation == null || _nation!.isEmpty) => 'Pick a side',
      _ when amount == null || amount <= 0 => 'Enter the amount',
      _ when rate == null || rate <= 0 => 'Enter the rate',
      _ when party == null => 'That client code was not found',
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
      final repo = ref.read(matchRepositoryProvider);
      final editing = widget.editing;

      if (editing == null) {
        await repo.createEntry(
          match: widget.match,
          clientId: party!.id,
          betType: _type,
          amount: amount!,
          rate: rate!,
          nation: _isSession ? null : _nation,
          run: _isSession ? run : null,
        );
      } else {
        // Only the fields a correction can touch; entry_date and match stay
        // as they were taken.
        await repo.updateEntry(
          match: widget.match,
          entryId: editing.id,
          changes: {
            'bet_type': _type.code,
            'amount': amount,
            'rate': rate,
            'client': party!.id,
            if (_isSession) 'run': run else 'nation': _nation,
          },
        );
      }
      if (mounted) Navigator.of(context).pop((nation: _nation, type: _type));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not place the bet. Please try again.');
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
              Text(_isEditing ? 'Edit entry' : 'New entry', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                _isEditing
                    ? '${widget.match.title} · Sr ${widget.editing!.rowNo}'
                    : widget.match.title,
                style: context.text.bodySmall,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                // An edited entry stays marked in every list afterwards, so
                // say that here rather than letting it be a surprise.
                _EditNotice(),
              ],
              const SizedBox(height: 16),

              if (_isSession)
                LabelledField(
                  label: 'Run',
                  child: TextField(
                    controller: _run,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                )
              else
                LabelledField(
                  label: 'Nation',
                  child: _Segmented<String>(
                    values: widget.match.selectableNations,
                    selected: _nation,
                    labelOf: (n) => n,
                    onChanged: (n) => setState(() => _nation = n),
                  ),
                ),

              const SizedBox(height: 14),
              LabelledField(
                label: 'Type',
                child: _Segmented<BetType>(
                  values: BetType.selectable,
                  selected: _type,
                  labelOf: (t) => t.label,
                  colorOf: (t) => t == BetType.l ? book.up : book.down,
                  onChanged: (t) => setState(() => _type = t),
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
                        autofocus: !_isSession,
                        style: _figureStyle(context),
                        decoration: const InputDecoration(hintText: '0'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: LabelledField(
                      label: 'Rate',
                      child: TextField(
                        controller: _rate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: _figureStyle(context).copyWith(color: context.scheme.primary),
                        decoration: const InputDecoration(hintText: '0.00'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              LabelledField(
                label: 'Client code',
                child: TextField(
                  controller: _clientCode,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'CODE'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: book.down,
                  ),
                ),
              ),

              // Naming the client back confirms the code landed on the party
              // the operator meant, before any money is committed to it.
              parties.when(
                loading: () => const SizedBox(height: 38),
                error: (_, _) => const SizedBox(height: 38),
                data: (list) {
                  final matched = _matchedParty(list);
                  if (matched != null) return _ClientConfirmation(party: matched);

                  // A code that matches nothing is usually a new client, and
                  // stopping mid-entry to go and add one loses the bet.
                  final typed = _clientCode.text.trim();
                  if (typed.isEmpty) return const SizedBox(height: 38);
                  return _AddClientPrompt(
                    code: typed,
                    onAdd: () async {
                      final created = await PartyEditSheet.show(context);
                      if (created != null) _clientCode.text = created.code;
                    },
                  );
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
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
                      onPressed: _busy || !parties.hasValue
                          ? null
                          : () => _submit(parties.requireValue),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Add entry'),
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

  TextStyle _figureStyle(BuildContext context) => TextStyle(
        fontFamily: 'Roboto Mono',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: context.scheme.onSurface,
      );
}

/// A one-tap chooser. Used for the side and for L/K, both of which are
/// dropdowns on the desk and should not be on a phone.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final Color Function(T)? colorOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.rButton),
        border: Border.all(color: book.line),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: _Segment(
                label: labelOf(value),
                selected: value == selected,
                color: colorOf?.call(value),
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.scheme.onSurface;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? tone.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: selected ? tone : context.book.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final book = context.book;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: book.warnSoft,
        borderRadius: BorderRadius.circular(AppTheme.rField),
        border: Border(left: BorderSide(color: book.warn, width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, size: 16, color: book.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This entry will stay marked as edited in the book.',
              style: TextStyle(fontSize: 11.5, color: book.warn),
            ),
          ),
        ],
      ),
    );
  }
}

/// Offers to add the party when the typed code matches nothing.
class _AddClientPrompt extends StatelessWidget {
  const _AddClientPrompt({required this.code, required this.onAdd});

  final String code;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 15, color: book.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'No client with code $code',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: book.muted),
            ),
          ),
          TextButton(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Add client', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ClientConfirmation extends StatelessWidget {
  const _ClientConfirmation({required this.party});

  final Party? party;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    if (party == null) return const SizedBox(height: 38);

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: book.upSoft,
          borderRadius: BorderRadius.circular(AppTheme.rField),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 15, color: book.up),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                party!.confirmation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: book.up),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
