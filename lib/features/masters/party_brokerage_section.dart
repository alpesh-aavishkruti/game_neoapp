import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/match.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/status_chip.dart';
import '../auth/menu_access.dart';
import 'brokerage_edit_sheet.dart';

/// Everything the desk holds against one party: its brokerage for each game,
/// and the other parties' books it takes a partner's share of.
///
/// Read through the same call the desk's Party Master form uses, so the two
/// always show the same thing.
final partyFullInfoProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, code) async {
  final body = await ref.watch(apiClientProvider).get(
    '/master/parties/get_full_party_info_by_code/',
    query: {'party_code': code},
  );
  return asMap(body);
});

/// Commission and partnership for one party, one row per game.
///
/// The desk keeps a single brokerage per party per game, so each game is a
/// row that is either set or not; tapping it opens that game's figures.
class PartyBrokerageSection extends ConsumerWidget {
  const PartyBrokerageSection({super.key, required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(partyFullInfoProvider(party.code));
    final access = ref.watch(menuAccessProvider);
    final canEdit = access.has('master.add_partybrokerage') ||
        access.has('master.change_partybrokerage');
    final book = context.book;

    Future<void> open(GameType game, Map<String, dynamic>? row) async {
      final saved = await BrokerageEditSheet.show(
        context,
        editing: row,
        party: party,
        game: game,
      );
      if (saved == true) ref.invalidate(partyFullInfoProvider(party.code));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('COMMISSION & PARTNERSHIP', style: context.text.labelSmall),
        const SizedBox(height: 4),
        Text('One setting per game. Tap a game to set or change it.',
            style: context.text.bodySmall),
        const SizedBox(height: 10),
        info.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text('Could not read the commission and partners.',
                      style: context.text.bodyMedium?.copyWith(color: book.down)),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(partyFullInfoProvider(party.code)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) {
            final rows = [
              for (final r in (data['brokerages'] is List ? data['brokerages'] as List : const []))
                if (r is Map) Map<String, dynamic>.from(r),
            ];
            final partnerIn = [
              for (final r
                  in (data['partnerships'] is List ? data['partnerships'] as List : const []))
                if (r is Map) Map<String, dynamic>.from(r),
            ];

            Map<String, dynamic>? rowFor(GameType game) {
              for (final r in rows) {
                if (GameType.parse(r['game_code']) == game &&
                    (r['game_code'] ?? '').toString().isNotEmpty) {
                  return r;
                }
              }
              return null;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final game in GameType.values)
                  _GameRow(
                    game: game,
                    row: rowFor(game),
                    onTap: canEdit ? () => open(game, rowFor(game)) : null,
                  ),
                if (!canEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Your role may not change brokerage.',
                        style: context.text.bodySmall),
                  ),
                if (partnerIn.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('PARTNER IN', style: context.text.labelSmall),
                  const SizedBox(height: 4),
                  Text("Other parties' books ${party.code} takes a share of.",
                      style: context.text.bodySmall),
                  const SizedBox(height: 8),
                  for (final p in partnerIn) _PartnerInRow(row: p),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// `20`, `2.5`: a stored `"20.00"` without the noise.
String _pct(dynamic raw) {
  final n = double.tryParse('${raw ?? ''}') ?? 0;
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
}

bool _isZero(dynamic raw) => (double.tryParse('${raw ?? ''}') ?? 0) == 0;

String _codeOf(dynamic ref) =>
    ref is Map ? (ref['party_code'] ?? '').toString().trim().toUpperCase() : '';

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.row, required this.onTap});

  final GameType game;
  final Map<String, dynamic>? row;
  final VoidCallback? onTap;

  /// What is set, in the order the desk form lists it.
  List<String> _summary(Map<String, dynamic> r) {
    final commCode = _codeOf(r['comm_code']);
    return [
      if (!_isZero(r['comm_percent'])) 'Comm ${_pct(r['comm_percent'])}%',
      if (commCode.isNotEmpty || !_isZero(r['comm_code_percent']))
        [
          'Code',
          if (commCode.isNotEmpty) commCode,
          '${_pct(r['comm_code_percent'])}%',
        ].join(' '),
      for (var i = 1; i <= 5; i++)
        if (_codeOf(r['partner$i']).isNotEmpty)
          'P$i ${_codeOf(r['partner$i'])} ${_pct(r['partner${i}_percent'])}%',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final r = row;
    final summary = r == null ? const <String>[] : _summary(r);
    final off = r != null && r['is_active'] == false;
    final from = r == null ? null : AppTime.toLocal(r['date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rField),
        border: Border.all(color: book.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rField),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.label,
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      r == null
                          ? 'Not set'
                          : [
                              if (summary.isEmpty) 'Nothing set' else summary.join(' · '),
                              if (from != null) 'from ${AppTime.date(from)}',
                            ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: r == null ? book.muted : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (off) ...[
                const SizedBox(width: 8),
                const StatusChip('Off', tone: ChipTone.muted),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(r == null ? Icons.add : Icons.edit_outlined, size: 18, color: book.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerInRow extends StatelessWidget {
  const _PartnerInRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final code = (row['party_code'] ?? '').toString().trim().toUpperCase();
    final name = (row['party_name'] ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                (name.isEmpty || name.toUpperCase() == code) ? code : '$code — $name',
                GameType.parse(row['game_code']).label,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium,
            ),
          ),
          Text(
            '${row['role'] ?? ''} ${_pct(row['percent'])}%',
            style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
