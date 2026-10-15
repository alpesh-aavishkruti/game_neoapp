import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/field_label.dart';
import 'auth_controller.dart';

/// First sign-in with a password an admin gave.
///
/// The server holds the account until the user chooses their own, so this is
/// the only thing on screen. Once saved, the user signs in again with it.
class SetOwnPasswordScreen extends ConsumerStatefulWidget {
  const SetOwnPasswordScreen({super.key, required this.givenPassword});

  final String givenPassword;

  @override
  ConsumerState<SetOwnPasswordScreen> createState() => _SetOwnPasswordScreenState();
}

class _SetOwnPasswordScreenState extends ConsumerState<SetOwnPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).setOwnPassword(_password.text);
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_reset_outlined, size: 40, color: context.scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Set your own password',
                      style: context.text.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This is your first sign-in with the password you were given. '
                      'Choose your own to continue - you will then sign in again with it.',
                      style: context.text.bodySmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    LabelledField(
                      label: 'New password',
                      child: TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Your new password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter a new password';
                          if (v == widget.givenPassword) {
                            return 'Choose a password different from the one you were given';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    LabelledField(
                      label: 'Confirm new password',
                      child: TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Enter it again',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        validator: (v) =>
                            v != _password.text ? 'The two passwords do not match' : null,
                        onFieldSubmitted: (_) => _save(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: context.text.bodyMedium?.copyWith(color: book.down)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save new password', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => ref.read(authControllerProvider.notifier).signOut(),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
