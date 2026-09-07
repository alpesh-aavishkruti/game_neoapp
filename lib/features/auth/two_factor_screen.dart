import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/session.dart';
import 'auth_controller.dart';

/// Second-factor verification.
///
/// The system already runs two-factor for the web client, so this reuses it
/// rather than inventing anything: a six-digit code from Telegram or from an
/// authenticator app, whichever the account is set up for.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key, required this.challenge});

  final TwoFactorChallenge challenge;

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter all six digits');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).submitTwoFactorCode(code);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _code.clear();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not verify the code. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to sign in',
          onPressed: () => ref.read(authControllerProvider.notifier).cancelTwoFactor(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Verify device', style: context.text.titleLarge?.copyWith(fontSize: 25)),
                const SizedBox(height: 6),
                Text(widget.challenge.method.hint, style: context.text.bodySmall),
                const SizedBox(height: 24),
                _CodeField(
                  controller: _code,
                  hasError: _error != null,
                  onCompleted: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: context.text.bodyMedium?.copyWith(color: context.book.down),
                  ),
                ],
                if (widget.challenge.method == TwoFactorMethod.telegram) ...[
                  const SizedBox(height: 14),
                  Text('The code is valid for five minutes.', style: context.text.bodySmall),
                ],
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Six boxes that behave like one field: a single input underneath, with the
/// digits drawn above it, so paste and autofill keep working.
class _CodeField extends StatefulWidget {
  const _CodeField({
    required this.controller,
    required this.onCompleted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final VoidCallback onCompleted;
  final bool hasError;

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.trim().length == 6) widget.onCompleted();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.controller.text.trim();
    final book = context.book;

    return Stack(
      children: [
        // The real field, invisible but fully functional.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: _focus.requestFocus,
            child: Row(
              children: List.generate(6, (i) {
                final filled = i < digits.length;
                final isNext = i == digits.length && _focus.hasFocus;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.scheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.rField),
                        border: Border.all(
                          color: widget.hasError
                              ? book.down
                              : isNext
                                  ? context.scheme.primary
                                  : book.line,
                          width: isNext || widget.hasError ? 1.6 : 1,
                        ),
                      ),
                      child: Text(
                        filled ? digits[i] : '',
                        style: TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: context.scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
