import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/field_label.dart';
import 'master_providers.dart';
import '../../shared/widgets/app_dropdown.dart';

/// One field on a small master form.
sealed class MasterField {
  const MasterField({required this.key, required this.label, this.showIf});

  final String key;
  final String label;

  /// Whether this field applies, given what has been chosen so far. A field
  /// that does not apply is hidden, is not required, and is sent empty - so
  /// narrowing a choice clears what the wider one had filled in.
  final bool Function(Map<String, String?> choices)? showIf;
}

class TextMasterField extends MasterField {
  const TextMasterField({
    required super.key,
    required super.label,
    super.showIf,
    this.hint,
    this.required = false,
    this.uppercase = false,
    this.labelWhen,
    this.hintWhen,
  });

  final String? hint;
  final bool required;
  final bool uppercase;

  /// The same box can mean different things by what was chosen above it - a
  /// match's first side is a team, but a session's is its name.
  final String Function(Map<String, String?> choices)? labelWhen;
  final String? Function(Map<String, String?> choices)? hintWhen;
}

class ChoiceMasterField extends MasterField {
  const ChoiceMasterField({
    required super.key,
    required super.label,
    super.showIf,
    required this.options,
    this.required = false,
  });

  /// value → what the operator reads.
  final Map<String, String> options;
  final bool required;
}

class NumberMasterField extends MasterField {
  const NumberMasterField({
    required super.key,
    required super.label,
    super.showIf,
    this.hint,
  });

  final String? hint;
}

class SwitchMasterField extends MasterField {
  const SwitchMasterField({
    required super.key,
    required super.label,
    super.showIf,
    this.initial = false,
  });

  final bool initial;
}

/// A small master, added or corrected.
///
/// The short masters - a category name, a voucher format - are the same form
/// with different fields, so they share one sheet described by a field list
/// rather than each getting a screen that then drifts.
class SimpleMasterSheet extends ConsumerStatefulWidget {
  const SimpleMasterSheet({
    super.key,
    required this.title,
    required this.path,
    required this.fields,
    this.editing,
    this.derive,
    this.validate,
  });

  final String title;
  final String path;
  final List<MasterField> fields;
  final Map<String, dynamic>? editing;

  /// A last pass over the payload before it is sent, for a value the server
  /// needs but nobody should have to type - one that can be worked out from
  /// what was already filled in, and would quietly break things if it were
  /// typed wrong.
  final void Function(Map<String, dynamic> payload)? derive;

  /// A rule across fields, checked on the finished payload before it is sent.
  /// Returns the message to show, or null when the form may be saved.
  final String? Function(Map<String, dynamic> payload)? validate;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String path,
    required List<MasterField> fields,
    Map<String, dynamic>? editing,
    void Function(Map<String, dynamic> payload)? derive,
    String? Function(Map<String, dynamic> payload)? validate,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SimpleMasterSheet(
          title: title,
          path: path,
          fields: fields,
          editing: editing,
          derive: derive,
          validate: validate,
        ),
      );

  @override
  ConsumerState<SimpleMasterSheet> createState() => _SimpleMasterSheetState();
}

class _SimpleMasterSheetState extends ConsumerState<SimpleMasterSheet> {
  final _text = <String, TextEditingController>{};
  final _choice = <String, String?>{};
  final _flags = <String, bool>{};

  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final row = widget.editing;

    for (final field in widget.fields) {
      switch (field) {
        case TextMasterField() || NumberMasterField():
          _text[field.key] =
              TextEditingController(text: (row?[field.key] ?? '').toString().trim());
        case ChoiceMasterField(:final options):
          final current = (row?[field.key] ?? '').toString();
          _choice[field.key] = options.containsKey(current) ? current : null;
        case SwitchMasterField(:final initial):
          // A stored row that carries no value for this switch is not off - it
          // simply predates the flag, so it falls back to the declared default.
          // Reading it as off would turn it off the next time the row is saved.
          _flags[field.key] =
              row?[field.key] == null ? initial : row![field.key] == true;
      }
    }
  }

  bool _applies(MasterField field) => field.showIf?.call(_choice) ?? true;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    for (final field in widget.fields) {
      if (!_applies(field)) continue;
      final missing = switch (field) {
        TextMasterField(:final required) =>
          required && (_text[field.key]?.text.trim().isEmpty ?? true),
        ChoiceMasterField(:final required) => required && _choice[field.key] == null,
        _ => false,
      };
      if (missing) {
        setState(() => _error = 'Enter the ${field.label.toLowerCase()}');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{};
      for (final field in widget.fields) {
        if (!_applies(field)) {
          // Deliberately blank rather than skipped: a team dropped by
          // narrowing the count has to be cleared, not left behind.
          payload[field.key] = '';
          continue;
        }
        switch (field) {
          case TextMasterField(:final uppercase):
            final value = _text[field.key]!.text.trim();
            payload[field.key] = uppercase ? value.toUpperCase() : value;
          case NumberMasterField():
            final raw = _text[field.key]!.text.trim();
            payload[field.key] = raw.isEmpty ? 0 : num.tryParse(raw) ?? 0;
          case ChoiceMasterField():
            payload[field.key] = _choice[field.key];
          case SwitchMasterField():
            payload[field.key] = _flags[field.key];
        }
      }

      widget.derive?.call(payload);

      final problem = widget.validate?.call(payload);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }

      final api = ref.read(apiClientProvider);
      if (_isEditing) {
        await api.patch('${widget.path}${widget.editing!['id']}/', data: payload);
      } else {
        await api.post(widget.path, data: payload);
      }

      refreshMasterRows(ref, widget.path);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
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
              Text(
                '${_isEditing ? 'Edit' : 'New'} ${widget.title.toLowerCase()}',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 16),

              for (final field in widget.fields)
                if (_applies(field)) ...[
                  _fieldWidget(field),
                  const SizedBox(height: 12),
                ],

              if (_error != null) ...[
                Text(_error!, style: context.text.bodyMedium?.copyWith(color: book.down)),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 4),
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
                          : Text(_isEditing ? 'Save changes' : 'Add'),
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

  Widget _fieldWidget(MasterField field) => switch (field) {
        TextMasterField(:final hint, :final uppercase, :final labelWhen, :final hintWhen) =>
          LabelledField(
            label: labelWhen?.call(_choice) ?? field.label,
            child: TextField(
              controller: _text[field.key],
              textCapitalization:
                  uppercase ? TextCapitalization.characters : TextCapitalization.sentences,
              decoration: InputDecoration(hintText: hintWhen?.call(_choice) ?? hint),
            ),
          ),
        NumberMasterField(:final hint) => LabelledField(
            label: field.label,
            child: TextField(
              controller: _text[field.key],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: hint ?? '0'),
              style: const TextStyle(fontFamily: 'Roboto Mono', fontWeight: FontWeight.w700),
            ),
          ),
        ChoiceMasterField(:final options) => LabelledField(
            label: field.label,
            child: AppDropdown<String>(
              initialValue: _choice[field.key],
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Choose'),
              items: [
                for (final entry in options.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _choice[field.key] = value),
            ),
          ),
        SwitchMasterField() => SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(field.label, style: const TextStyle(fontSize: 14)),
            value: _flags[field.key] ?? false,
            onChanged: (v) => setState(() => _flags[field.key] = v),
          ),
      };
}
