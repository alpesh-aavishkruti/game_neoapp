import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/field_label.dart';

/// Changing your own password.
///
/// The current password is asked for because a handset left unlocked should
/// not be enough to lock its owner out of the book.
class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const ChangePasswordSheet(),
      );

  @override
  ConsumerState<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    final current = _current.text;
    final next = _next.text;

    final problem = switch (null) {
      _ when current.isEmpty => 'Enter your current password',
      // No shape is imposed on a password here: the desk sets what it likes,
      // digits alone included. Only an empty one is refused.
      _ when next.isEmpty => 'Enter the new password',
      _ when next == current => 'The new password is the same as the current one',
      _ when _confirm.text != next => 'The two new passwords do not match',
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
      await ref.read(apiClientProvider).post('/change-password/', data: {
        'current_password': current,
        'new_password': next,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not change the password. Please try again.');
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
              Text('Change password', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text('You stay signed in on this device', style: context.text.bodySmall),
              const SizedBox(height: 16),

              LabelledField(
                label: 'Current password',
                child: TextField(
                  controller: _current,
                  obscureText: _obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LabelledField(
                label: 'New password',
                child: TextField(controller: _next, obscureText: _obscure),
              ),
              const SizedBox(height: 14),
              LabelledField(
                label: 'Repeat new password',
                child: TextField(
                  controller: _confirm,
                  obscureText: _obscure,
                  onSubmitted: (_) => _save(),
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
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Change'),
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
