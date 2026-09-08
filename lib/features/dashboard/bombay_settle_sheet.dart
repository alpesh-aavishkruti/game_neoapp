import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bet_entry.dart';
import '../../data/models/match.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/field_label.dart';
import '../../shared/widgets/party_field.dart';
import '../matches/match_providers.dart';

/// Settling a client's Bombay position.
///
/// A Bombay leg is not a bet on a side - it is a figure carried per side that
/// settles elsewhere. So this asks for one number against each side rather than
/// an amount and a rate, and the row it writes is never edited from the board.
class BombaySettleSheet extends ConsumerStatefulWidget {
  const BombaySettleSheet({super.key, required this.match});

  final GameMatch match;

  static Future<bool?> show(BuildContext context, {required GameMatch match}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BombaySettleSheet(match: match),
      );

  @override
  ConsumerState<BombaySettleSheet> createState() => _BombaySettleSheetState();
}

class _BombaySettleSheetState extends ConsumerState<BombaySettleSheet> {
  Party? _client;
  final _controllers = <TextEditingController>[];
  bool _busy = false;
  String? _error;

  /// One figure per side. A test carries a third for the draw.
  List<String> get _sides => widget.match.selectableNations;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _sides.length; i++) {
      _controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double? _valueAt(int i) =>
      double.tryParse(_controllers[i].text.trim().replaceAll(',', ''));

  Future<void> _save() async {
    if (_busy) return;

    final client = _client;
    final a = _valueAt(0);
    final b = _valueAt(1);

    final problem = switch (null) {
      _ when client == null => 'Choose the client',
      _ when a == null || b == null => 'Enter a figure for each side',
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
      // A Bombay row is recognised by its bet type, never by this string - it
      // is a label. A test's third figure rides along in it, the way the desk
      // writes it; a one day carries the plain word.
      final nation =
          _sides.length > 2 ? 'BOMBAY:${_valueAt(2) ?? 0}' : 'BOMBAY';

      await ref.read(matchRepositoryProvider).createEntry(
            match: widget.match,
            clientId: client!.id,
            betType: BetType.bombay,
            amount: a!,
            rate: b!,
            nation: nation,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the settlement. Please try again.');
      }
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
              Text('Bombay settle', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                'One figure per side · ${widget.match.title}',
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
                data: (list) => LabelledField(
                  label: 'Client',
                  child: PartyField(
                    parties: list,
                    selected: _client,
                    onChanged: (p) => setState(() => _client = p),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              for (var i = 0; i < _sides.length; i++) ...[
                LabelledField(
                  label: _sides[i].toUpperCase(),
                  child: TextField(
                    controller: _controllers[i],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: const TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ),
                if (i < _sides.length - 1) const SizedBox(height: 12),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: context.text.bodyMedium?.copyWith(color: book.down)),
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
                      onPressed: _busy || !parties.hasValue ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save settlement'),
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
