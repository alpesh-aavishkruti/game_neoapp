import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/field_label.dart';
import '../../shared/widgets/status_chip.dart';

final twoFactorStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return asMap(await ref.watch(apiClientProvider).get('/2fa/status/'));
});

/// Two-factor verification.
///
/// The account password is asked for before anything here changes, because
/// turning second-factor off from an unlocked handset would otherwise undo the
/// protection it exists to give.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(twoFactorStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security'),
            Text(
              'Two-factor verification',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(twoFactorStatusProvider.future),
        child: AsyncView(
          value: status,
          onRetry: () => ref.invalidate(twoFactorStatusProvider),
          builder: (data) => _Body(status: data),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.status});

  final Map<String, dynamic> status;

  String get _method => (status['two_fa_method'] ?? 'NONE').toString().toUpperCase();
  bool get _isOn => _method != 'NONE' && _method.isNotEmpty;

  String get _methodLabel => switch (_method) {
        'TELEGRAM' => 'Telegram',
        'GOOGLE_AUTH' => 'Authenticator app',
        _ => 'Off',
      };

  Future<void> _setUpTelegram(BuildContext context, WidgetRef ref) async {
    final password = await _askPassword(context, 'Connect Telegram');
    if (password == null) return;

    try {
      final body = asMap(await ref.read(apiClientProvider).post(
            '/2fa/request-telegram-code/',
            data: {'password': password},
          ));
      if (!context.mounted) return;

      final code = (body['code'] ?? '').toString();
      final bot = (body['bot_username'] ?? '').toString();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connect Telegram'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send this code to @$bot on Telegram:'),
              const SizedBox(height: 12),
              _CopyableCode(code: code),
              const SizedBox(height: 12),
              Text(
                'Once the bot replies, sign-in codes come to that chat.',
                style: context.text.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      ref.invalidate(twoFactorStatusProvider);
    } on ApiException catch (e) {
      if (context.mounted) _say(context, e.message);
    }
  }

  Future<void> _setUpAuthenticator(BuildContext context, WidgetRef ref) async {
    final password = await _askPassword(context, 'Set up authenticator');
    if (password == null) return;

    try {
      final body = asMap(await ref.read(apiClientProvider).post(
            '/2fa/request-google-setup/',
            data: {'password': password},
          ));
      if (!context.mounted) return;

      final secret = (body['secret'] ?? '').toString();
      final code = await _askCode(context, secret);
      if (code == null || !context.mounted) return;

      await ref.read(apiClientProvider).post(
        '/2fa/verify-google-setup/',
        data: {'code': code},
      );
      ref.invalidate(twoFactorStatusProvider);
      if (context.mounted) _say(context, 'Authenticator app enabled.');
    } on ApiException catch (e) {
      if (context.mounted) _say(context, e.message);
    }
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final password = await _askPassword(context, 'Turn off two-factor');
    if (password == null) return;

    try {
      await ref.read(apiClientProvider).post('/2fa/disable/', data: {'password': password});
      ref.invalidate(twoFactorStatusProvider);
      if (context.mounted) _say(context, 'Two-factor turned off.');
    } on ApiException catch (e) {
      if (context.mounted) _say(context, e.message);
    }
  }

  void _say(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<String?> _askPassword(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm your password first.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    ).then((value) => (value == null || value.isEmpty) ? null : value);
  }

  Future<String?> _askCode(BuildContext context, String secret) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set up authenticator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add this key to your authenticator app:'),
            const SizedBox(height: 12),
            _CopyableCode(code: secret),
            const SizedBox(height: 14),
            const FieldLabel('Then enter the 6-digit code'),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(hintText: '000000'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    ).then((value) => (value == null || value.length < 6) ? null : value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = context.book;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.rCard),
            border: Border.all(color: book.line),
          ),
          child: Row(
            children: [
              Icon(
                _isOn ? Icons.verified_user : Icons.gpp_maybe_outlined,
                size: 26,
                color: _isOn ? book.up : book.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isOn ? 'Two-factor is on' : 'Two-factor is off',
                      style: context.text.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isOn
                          ? 'Codes come from $_methodLabel'
                          : 'A password alone opens the book',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (_isOn) StatusChip(_methodLabel, tone: ChipTone.up),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Text('METHODS', style: context.text.labelSmall),
        const SizedBox(height: 8),

        _MethodTile(
          icon: Icons.send_outlined,
          title: 'Telegram',
          subtitle: 'A 6-digit code sent to your Telegram chat',
          selected: _method == 'TELEGRAM',
          onTap: () => _setUpTelegram(context, ref),
        ),
        const SizedBox(height: 9),
        _MethodTile(
          icon: Icons.phonelink_lock_outlined,
          title: 'Authenticator app',
          subtitle: 'A rolling code, works with no signal',
          selected: _method == 'GOOGLE_AUTH',
          onTap: () => _setUpAuthenticator(context, ref),
        ),

        if (_isOn) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _turnOff(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: book.down,
              side: BorderSide(color: book.down.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.gpp_bad_outlined, size: 18),
            label: const Text('Turn off two-factor'),
          ),
        ],
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Material(
      color: context.scheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rCard),
            border: Border.all(color: selected ? context.scheme.primary : book.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(subtitle, style: context.text.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: book.up)
              else
                Icon(Icons.chevron_right, size: 18, color: book.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A setup code is retyped into another app, so it is worth being able to copy
/// rather than read off the screen character by character.
class _CopyableCode extends StatelessWidget {
  const _CopyableCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied.')),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: book.brandSoft,
          borderRadius: BorderRadius.circular(AppTheme.rField),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.scheme.primary,
                ),
              ),
            ),
            Icon(Icons.copy, size: 16, color: context.scheme.primary),
          ],
        ),
      ),
    );
  }
}
