import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/ledger_row.dart';
import '../../data/models/party.dart';
import '../../data/repositories/book_repository.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import '../matches/match_providers.dart';

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(ref.watch(apiClientProvider)),
);

final ledgerProvider =
    FutureProvider.family<List<LedgerRow>, int>((ref, partyId) async {
  return ref.watch(bookRepositoryProvider).ledger(partyId: partyId);
});

/// A party's statement.
///
/// A desk ledger is a wide table - date, particulars, debit, credit, balance.
/// That is unreadable squeezed onto a phone, so each entry becomes a line:
/// date at the left, what happened in the middle, the amount and the running
/// balance at the right. Closing balance sits at the top, because that is the
/// number anyone opens a ledger to find.
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key, this.party, this.embedded = false});

  /// When absent the screen asks which party to show first.
  final Party? party;

  /// Inside the Reports tabs the section is already named above, so the screen
  /// drops its own app bar rather than stacking a second one.
  final bool embedded;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  Party? _party;

  @override
  void initState() {
    super.initState();
    _party = widget.party;
  }

  Future<void> _share() async {
    final party = _party;
    if (party == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing the statement…')),
    );
    try {
      await ref.read(reportSharingProvider).sharePdf(
            path: '/master/parties/${party.id}/download_party_report/',
            name: 'Ledger ${party.code}',
          );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _pickParty() async {
    final parties = await ref.read(partiesProvider.future);
    if (!mounted) return;

    final chosen = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PartyPicker(parties: parties),
    );
    if (chosen != null) setState(() => _party = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final party = _party;

    final body = party == null
        ? _ChooseFirst(onChoose: _pickParty)
        : _Statement(party: party);

    if (widget.embedded) {
      return Column(
        children: [
          _PartyBar(party: party, onChoose: _pickParty, onShare: party == null ? null : _share),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ledger'),
            if (party != null)
              Text(
                party.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (party != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share as PDF',
              onPressed: _share,
            ),
          IconButton(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'Choose party',
            onPressed: _pickParty,
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Names the party being read, and lets it be swapped, when the screen has no
/// app bar of its own to carry that.
class _PartyBar extends StatelessWidget {
  const _PartyBar({required this.party, required this.onChoose, this.onShare});

  final Party? party;
  final VoidCallback onChoose;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onChoose,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.rField),
            border: Border.all(color: context.book.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  party?.display ?? 'Choose a party',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: party == null ? FontWeight.w400 : FontWeight.w600,
                    color: party == null ? context.book.muted : context.scheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 20, color: context.book.muted),
              if (onShare != null)
                IconButton(
                  icon: const Icon(Icons.ios_share, size: 18),
                  tooltip: 'Share as PDF',
                  visualDensity: VisualDensity.compact,
                  onPressed: onShare,
                ),
            ],
          ),
        ),
      );
}

class _ChooseFirst extends StatelessWidget {
  const _ChooseFirst({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 36, color: context.book.muted),
              const SizedBox(height: 14),
              Text('Choose a party', style: context.text.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Pick whose statement to open.',
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onChoose, child: const Text('Choose party')),
            ],
          ),
        ),
      );
}

class _Statement extends ConsumerWidget {
  const _Statement({required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider(party.id));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(ledgerProvider(party.id).future),
      child: AsyncView(
        value: ledger,
        onRetry: () => ref.invalidate(ledgerProvider(party.id)),
        isEmpty: (rows) => rows.isEmpty,
        emptyTitle: 'No entries in this period',
        builder: (rows) {
          // The statement is sent oldest first; the closing balance is the
          // last row's running balance.
          final closing = rows.isEmpty ? 0.0 : rows.last.closingBalance;

          return Column(
            children: [
              _ClosingBalance(amount: closing),
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _LedgerLine(
                    row: rows[rows.length - 1 - i],
                    viewingPartyId: party.id,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClosingBalance extends StatelessWidget {
  const _ClosingBalance({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        border: Border.all(color: book.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CLOSING BALANCE', style: context.text.labelSmall),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(amount),
                    style: TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: book.forAmount(amount),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({required this.row, required this.viewingPartyId});

  final LedgerRow row;
  final int viewingPartyId;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final movement = row.movement;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Text(
                  row.date == null ? '--' : row.date!.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  row.date == null ? '' : AppTime.dateShort(row.date).split(' ').last.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.description,
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (row.isPartnershipLeg) ...[
                      // A share earned on someone else's book. Marked so it is
                      // never read as this party's own play.
                      StatusChip('PTRN${row.ptrnSlot} · ${row.ptrnSourceCode ?? ''}',
                          tone: ChipTone.open),
                      const SizedBox(width: 6),
                    ],
                    if (row.voucherNo.isNotEmpty)
                      Text(row.voucherNo, style: context.text.bodySmall?.copyWith(fontSize: 10.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Money.position(movement, decimals: 0),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: book.forAmount(movement),
                ),
              ),
              Text(
                Money.format(row.closingBalance, decimals: 0),
                style: context.text.bodySmall?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartyPicker extends StatefulWidget {
  const _PartyPicker({required this.parties});

  final List<Party> parties;

  @override
  State<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends State<_PartyPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.text.trim().toUpperCase();
    final shown = term.isEmpty
        ? widget.parties
        : widget.parties
            .where((p) => p.code.contains(term) || p.name.toUpperCase().contains(term))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _search,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search code or name',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(shown[i].display),
                onTap: () => Navigator.of(context).pop(shown[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
