import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/field_label.dart';
import 'master_providers.dart';

const rolePath = '/role/';

/// Naming a role, or renaming one.
///
/// What the role may actually open is set separately - there are dozens of
/// switches and they do not belong in the same breath as naming the thing.
class RoleEditSheet extends ConsumerStatefulWidget {
  const RoleEditSheet({super.key, this.editing});

  final Map<String, dynamic>? editing;

  static Future<bool?> show(BuildContext context,
          {Map<String, dynamic>? editing}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RoleEditSheet(editing: editing),
      );

  @override
  ConsumerState<RoleEditSheet> createState() => _RoleEditSheetState();
}

class _RoleEditSheetState extends ConsumerState<RoleEditSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final row = widget.editing;
    if (row == null) return;
    _name.text = (row['name'] ?? '').toString();
    _description.text = (row['description'] ?? '').toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the role a name');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final payload = {'name': name, 'description': _description.text.trim()};
      final api = ref.read(apiClientProvider);
      if (_isEditing) {
        await api.patch('$rolePath${widget.editing!['id']}/', data: payload);
      } else {
        await api.post(rolePath, data: payload);
      }
      ref.invalidate(masterRowsProvider(rolePath));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors?['name'] ?? e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the role. Please try again.');
      }
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
              Text(_isEditing ? 'Edit role' : 'New role',
                  style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                _isEditing
                    ? 'What it may open is set from the key on its row'
                    : 'Name it now, then set what it may open',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 16),

              LabelledField(
                label: 'Role name',
                child: TextField(
                  controller: _name,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Operator'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 14),
              LabelledField(
                label: 'Description',
                child: TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'What this role is for',
                  ),
                ),
              ),

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
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Add role'),
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
