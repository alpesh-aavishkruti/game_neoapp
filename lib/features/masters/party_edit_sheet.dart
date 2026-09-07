import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/field_label.dart';
import '../matches/match_providers.dart';

/// Adding a party, or correcting one.
///
/// Only the code and the name are required - the same two the desk asks for.
/// Everything else has a working default, so a client can be added mid-match
/// without stopping to fill a form.
class PartyEditSheet extends ConsumerStatefulWidget {
  const PartyEditSheet({super.key, this.editing});

  /// Null when adding.
  final Party? editing;

  static Future<Party?> show(BuildContext context, {Party? editing}) =>
      showModalBottomSheet<Party>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PartyEditSheet(editing: editing),
      );

  @override
  ConsumerState<PartyEditSheet> createState() => _PartyEditSheetState();
}

class _PartyEditSheetState extends ConsumerState<PartyEditSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _mobile = TextEditingController();
  final _creditLimit = TextEditingController();

  bool _isBookie = false;
  bool _showInBook = false;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final party = widget.editing;
    if (party != null) {
      _code.text = party.code;
      _name.text = party.name;
      _isBookie = party.isBookie;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _city.dispose();
    _mobile.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    final code = _code.text.trim().toUpperCase();
    final name = _name.text.trim();

    final problem = switch (null) {
      _ when code.isEmpty => 'Enter a party code',
      _ when name.isEmpty => 'Enter the party name',
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
      final payload = {
        'party_code': code,
        'party_name': name,
        'city': _city.text.trim(),
        'mobile': _mobile.text.trim(),
        'credit_limit': double.tryParse(_creditLimit.text.trim()) ?? 0,
        'is_bookie': _isBookie,
        'show_in_book': _showInBook,
        'is_active': true,
      };

      final body = _isEditing
          ? await api.patch('/master/parties/${widget.editing!.id}/', data: payload)
          : await api.post('/master/parties/', data: payload);

      // Every client-code field reads this list, so it has to be refreshed
      // before the new party can be bet for.
      ref.invalidate(partiesProvider);

      final saved = Party.fromJson(asMap(body));
      if (mounted) Navigator.of(context).pop(saved.id == 0 ? null : saved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.fieldErrors?['party_code'] ?? e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the party. Please try again.');
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
              Text(_isEditing ? 'Edit party' : 'New party', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                _isEditing ? widget.editing!.display : 'Only the code and name are needed',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: LabelledField(
                      label: 'Party code',
                      child: TextField(
                        controller: _code,
                        autofocus: !_isEditing,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'RAJ01'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    flex: 3,
                    child: LabelledField(
                      label: 'Party name',
                      child: TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'Rajesh Traders'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'City',
                      child: TextField(
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: LabelledField(
                      label: 'Mobile',
                      child: TextField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              LabelledField(
                label: 'Credit limit',
                child: TextField(
                  controller: _creditLimit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                  style: const TextStyle(fontFamily: 'Roboto Mono', fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Is bookie', style: TextStyle(fontSize: 14)),
                value: _isBookie,
                onChanged: (v) => setState(() => _isBookie = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show in book', style: TextStyle(fontSize: 14)),
                value: _showInBook,
                onChanged: (v) => setState(() => _showInBook = v),
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
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Add party'),
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
