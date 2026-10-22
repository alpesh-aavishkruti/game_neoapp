import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/money.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/async_view.dart';
import '../matches/match_providers.dart';
import '../money/ledger_screen.dart';
import 'party_edit_sheet.dart';
import '../../shared/widgets/refresh_on_show.dart';
import '../../shared/widgets/status_chip.dart';
import '../auth/menu_access.dart';

/// Party master.
///
/// Opened dozens of times a day just to check a code, a category or a balance,
/// so every row answers those without opening the record.
class PartyMasterScreen extends ConsumerStatefulWidget {
  const PartyMasterScreen({super.key});

  @override
  ConsumerState<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends ConsumerState<PartyMasterScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Party> _filter(List<Party> parties) {
    final term = _search.text.trim().toUpperCase();
    if (term.isEmpty) return parties;
    return parties
        .where((p) => p.code.contains(term) || p.name.toUpperCase().contains(term))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Deactivated parties too: Party Master is where they are still shown.
    final parties = ref.watch(allPartiesProvider);

    return RefreshOnShow(
      providers: [allPartiesProvider],
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Search code or name',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // The shell keeps every tab alive at once, so each button needs its
        // own tag or opening any screen trips over two identical heroes.
        heroTag: 'fab-add-party',
        onPressed: () => PartyEditSheet.show(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add party'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(allPartiesProvider.future),
        child: AsyncView(
          value: parties,
          onRetry: () => ref.invalidate(allPartiesProvider),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'No parties yet',
          builder: (list) {
            final shown = _filter(list);
            if (shown.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 70),
                  Center(
                    child: Text(
                      'Nothing matches "${_search.text.trim()}"',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${shown.length} of ${list.length} active',
                      style: context.text.labelSmall,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 92),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _PartyRow(
                      party: shown[i],
                      canViewParty: ref.watch(menuAccessProvider).can(MenuKey.viewParty),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.party, required this.canViewParty});

  final Party party;

  /// Whether the statement may be opened. Without the right it opened only to
  /// spin and say "You do not have permission", so the tap does nothing then.
  final bool canViewParty;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return InkWell(
      onTap: canViewParty
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LedgerScreen(party: party)),
              )
          : null,
      // Tapping opens the statement, which is what this list is mostly used
      // for; editing the record itself is the rarer intent, so it sits behind
      // a long press rather than competing for the tap.
      onLongPress: () => PartyEditSheet.show(context, editing: party),
      child: Container(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          border: Border(bottom: BorderSide(color: book.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: book.brandSoft,
                borderRadius: BorderRadius.circular(AppTheme.rButton),
              ),
              alignment: Alignment.center,
              child: Text(
                party.initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    party.name.isEmpty ? party.code : party.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    party.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            // Shown here and nowhere else: a deactivated party is left out
            // of every picker in the app.
            if (!party.isActive) ...[
              const SizedBox(width: 8),
              const StatusChip('Deactivated', tone: ChipTone.down),
            ],
            if (party.balance != null) ...[
              const SizedBox(width: 8),
              Text(
                Money.position(party.balance),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: book.forAmount(party.balance!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
