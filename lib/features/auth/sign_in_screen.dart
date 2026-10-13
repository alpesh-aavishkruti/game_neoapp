import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/field_label.dart';
import 'auth_controller.dart';

/// Sign in.
///
/// Deliberately the same three things the desk system asks for - user ID and
/// password - so nobody has to learn a new way in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.notice});

  /// Shown when the session ended by itself rather than by signing out.
  final String? notice;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(username: _username.text, password: _password.text);
      // On success the app shell swaps this screen out; nothing to do here.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = _error ?? widget.notice;
    final book = context.book;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the navy band.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // The card colour fills the screen; the navy band sits on top of it,
        // so however tall the phone, there is no seam below the form.
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              const _BrandBand(),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Sign in',
                                  style: context.text.titleLarge?.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Welcome back. Use the same ID as the desk.',
                                  style: context.text.bodySmall?.copyWith(fontSize: 13),
                                ),
                                if (notice != null) ...[
                                  const SizedBox(height: 18),
                                  _Notice(notice),
                                ],
                                const SizedBox(height: 24),
                                LabelledField(
                                  label: 'User ID',
                                  child: TextFormField(
                                    controller: _username,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.characters,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      hintText: 'Your user ID',
                                      prefixIcon: Icon(Icons.person_outline, size: 20),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Enter your user ID'
                                        : null,
                                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LabelledField(
                                  label: 'Password',
                                  child: TextFormField(
                                    controller: _password,
                                    focusNode: _passwordFocus,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      hintText: '••••••••',
                                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                        tooltip: _obscure ? 'Show password' : 'Hide password',
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                                    onFieldSubmitted: (_) => _submit(),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _busy ? null : _submit,
                                    child: _busy
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('Sign in', style: TextStyle(fontSize: 15)),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward, size: 18),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_user_outlined, size: 14, color: book.muted),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Secure sign-in  ·  Neon Accounting',
                                        textAlign: TextAlign.center,
                                        style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top of the screen: the amber wordmark on navy, as in the web header,
/// lit by two soft glows so it reads as a brand rather than a flat block.
class _BrandBand extends StatelessWidget {
  const _BrandBand();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.brandNavy,
    child: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.9, -0.8),
          radius: 1.2,
          colors: [Color(0x33FDB022), Color(0x00FDB022)],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-1.0, 1.0),
            radius: 1.1,
            colors: [Color(0x332E5BFF), Color(0x002E5BFF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 44, 26, 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandAmber.withValues(alpha: 0.35)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'N',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandAmber,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Image.asset('assets/brand/neon_acc.png', height: 26, semanticLabel: 'Neon Acc'),
                const SizedBox(height: 12),
                Text(
                  'MATCH BOOK  ·  HAVALA  ·  LEDGER',
                  style: TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: AppColors.brandAmber.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: book.downSoft,
        borderRadius: BorderRadius.circular(AppTheme.rField),
        border: Border(left: BorderSide(color: book.down, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 17, color: book.down),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: context.text.bodyMedium?.copyWith(color: book.down)),
          ),
        ],
      ),
    );
  }
}
