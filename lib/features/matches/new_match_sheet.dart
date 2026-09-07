import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/match.dart';
import '../../shared/widgets/field_label.dart';
import 'match_providers.dart';

/// Opening a new match.
///
/// Only the things that differ per match are asked for. Commission and PTRN
/// default to on, matching how the desk creates one, so a new board is ready
/// to take entries without a settings pass first.
class NewMatchSheet extends ConsumerStatefulWidget {
  const NewMatchSheet({super.key, required this.game});

  final GameType game;

  static Future<bool?> show(BuildContext context, {required GameType game}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => NewMatchSheet(game: game),
      );

  @override
  ConsumerState<NewMatchSheet> createState() => _NewMatchSheetState();
}

class _NewMatchSheetState extends ConsumerState<NewMatchSheet> {
  final _nationA = TextEditingController();
  final _nationB = TextEditingController();
  final _nationC = TextEditingController();
  final _cupName = TextEditingController();
  final _cupTeams = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  bool _commission = true;
  bool _ptrn = true;
  bool _busy = false;
  String? _error;

  bool get _isCup => widget.game == GameType.cup;
  bool get _isTest => widget.game == GameType.test;

  @override
  void dispose() {
    _nationA.dispose();
    _nationB.dispose();
    _nationC.dispose();
    _cupName.dispose();
    for (final c in _cupTeams) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;

    final teams = _cupTeams.map((c) => c.text.trim().toUpperCase()).where((t) => t.isNotEmpty).toList();
    final a = _nationA.text.trim().toUpperCase();
    final b = _nationB.text.trim().toUpperCase();

    final problem = switch (null) {
      _ when _isCup && _cupName.text.trim().isEmpty => 'Name the cup',
      _ when _isCup && teams.length < 2 => 'A cup needs at least two teams',
      _ when !_isCup && a.isEmpty => 'Enter the first side',
      _ when !_isCup && b.isEmpty => 'Enter the second side',
      _ when !_isCup && a == b => 'The two sides cannot be the same',
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
      final api = ref.read(apiClientProvider);
      if (_isCup) {
        await api.post('/master/cups/', data: {
          'cup_name': _cupName.text.trim(),
          for (var i = 0; i < teams.length; i++) 'nation_${String.fromCharCode(97 + i)}': teams[i],
          'commission_enabled': _commission,
        });
      } else {
        await api.post('/master/matches/', data: {
          'game': widget.game.code,
          'nation_a': a,
          'nation_b': b,
          if (_isTest && _nationC.text.trim().isNotEmpty)
            'nation_c': _nationC.text.trim().toUpperCase(),
          'commission_enabled': _commission,
          'ptrn_enabled': _ptrn,
        });
      }

      ref.invalidate(activeMatchesProvider(widget.game));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the match. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text('New ${widget.game.label.toLowerCase()}', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text('Opens a board ready to take entries', style: context.text.bodySmall),
              const SizedBox(height: 16),

              if (_isCup) ...[
                LabelledField(
                  label: 'Cup name',
                  child: TextField(
                    controller: _cupName,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'T20 WORLD CUP'),
                  ),
                ),
                const SizedBox(height: 14),
                Text('TEAMS', style: context.text.labelSmall),
                const SizedBox(height: 6),
                for (var i = 0; i < _cupTeams.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _cupTeams[i],
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(hintText: 'Team ${i + 1}'),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    // Six is where the backend's own columns stop.
                    onPressed: _cupTeams.length >= 6
                        ? null
                        : () => setState(() => _cupTeams.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add team'),
                  ),
                ),
              ] else ...[
                LabelledField(
                  label: 'First side',
                  child: TextField(
                    controller: _nationA,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'INDIA'),
                  ),
                ),
                const SizedBox(height: 14),
                LabelledField(
                  label: 'Second side',
                  child: TextField(
                    controller: _nationB,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'AUSTRALIA'),
                  ),
                ),
                if (_isTest) ...[
                  const SizedBox(height: 14),
                  LabelledField(
                    label: 'Third outcome',
                    child: TextField(
                      controller: _nationC,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'DRAW'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A test can end three ways. Left empty this is recorded as DRAW.',
                    style: context.text.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ],

              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Commission', style: TextStyle(fontSize: 14)),
                value: _commission,
                onChanged: (v) => setState(() => _commission = v),
              ),
              if (!_isCup)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('PTRN', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'Partner shares are worked out on every entry',
                    style: context.text.bodySmall?.copyWith(fontSize: 11),
                  ),
                  value: _ptrn,
                  onChanged: (v) => setState(() => _ptrn = v),
                ),

              if (_error != null) ...[
                const SizedBox(height: 10),
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
                      onPressed: _busy ? null : _create,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Open match'),
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
