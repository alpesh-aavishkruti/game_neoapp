import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/party.dart';
import '../../data/models/statement_link.dart';
import '../../data/repositories/statement_link_repository.dart';

final statementLinkRepositoryProvider = Provider<StatementLinkRepository>(
  (ref) => StatementLinkRepository(ref.watch(apiClientProvider)),
);

/// A party's shared statement link, as the desk asked for it.
///
/// The link is copied as soon as this opens. A switch turns it off and on - off,
/// the link the party holds does not open. Reset makes a new link with no
/// password; the party sets one the first time they open it. The password is
/// the party's own and never shown here.
class StatementLinkSheet extends ConsumerStatefulWidget {
  const StatementLinkSheet({super.key, required this.party});

  final Party party;

  static Future<void> show(BuildContext context, {required Party party}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => StatementLinkSheet(party: party),
      );

  @override
  ConsumerState<StatementLinkSheet> createState() => _StatementLinkSheetState();
}

class _StatementLinkSheetState extends ConsumerState<StatementLinkSheet> {
  StatementLink? _link;
  String? _error;
  bool _busy = false;

  StatementLinkRepository get _repo => ref.read(statementLinkRepositoryProvider);

  String get _url => AppConfig.partyStatementLink(_link!.token);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final link = await _repo.get(widget.party.id);
      if (!mounted) return;
      setState(() => _link = link);
      await _copy('Link for ${widget.party.code} copied.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _copy(String message) async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<StatementLink> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      final link = await call();
      if (!mounted) return;
      setState(() => _link = link);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password?'),
        content: const Text(
          'A new link will be made and the old one stops opening. '
          'The party sets a new password when they open the new link.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (sure != true) return;
    await _run(() => _repo.reset(widget.party.id), 'New link made. The old link no longer opens.');
    if (mounted && _link != null) await _copy('New link copied.');
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final book = context.book;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share link - ${widget.party.code}', style: context.text.titleMedium),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: TextStyle(color: book.down))
          else if (link == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: book.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _url,
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12,
                  decoration: link.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: () => _copy('Link copied.'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: _url, subject: 'Statement - ${widget.party.code}'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(link.isActive ? 'Link active' : 'Link deactivated'),
              subtitle: Text(link.isActive
                  ? 'The party can open it with their password.'
                  : 'The link the party holds will not open.'),
              value: link.isActive,
              onChanged: _busy
                  ? null
                  : (on) => _run(
                        () => _repo.setActive(widget.party.id, on),
                        on ? 'Link turned on.' : 'Link turned off.',
                      ),
            ),
            // A row rather than a ListTile: the app's buttons are full width
            // by default, which a ListTile's trailing slot cannot hold.
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Password', style: context.text.bodyLarge),
                      Text(
                        link.passwordSet
                            ? 'Set by the party.'
                            : 'Not set yet - the party sets it when they first open the link.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: book.down,
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: _busy ? null : _reset,
                  child: const Text('Reset password'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
