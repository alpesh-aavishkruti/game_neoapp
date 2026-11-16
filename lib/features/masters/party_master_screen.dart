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
///
/// The bottom-bar tab is for looking up: a tap opens the statement. Opened
/// from More as Party master ([manage]) it is for keeping the records: a tap
/// opens the party itself, and the list can be narrowed to active or
/// deactivated accounts.
class PartyMasterScreen extends ConsumerStatefulWidget {
  const PartyMasterScreen({super.key, this.manage = false});

  final bool manage;

  @override
  ConsumerState<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends ConsumerState<PartyMasterScreen> {
  final _search = TextEditingController();

  /// Null shows every party; otherwise only active (true) or deactivated.
  bool? _activeOnly;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Party> _filter(List<Party> parties) {
    final term = _search.text.trim().toUpperCase();
    return parties
        .where((p) => _activeOnly == null || p.isActive == _activeOnly)
        .where((p) =>
            term.isEmpty || p.code.contains(term) || p.name.toUpperCase().contains(term))
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
        title: Text(widget.manage ? 'Party master' : 'Parties'),
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
        heroTag: widget.manage ? 'fab-add-party-master' : 'fab-add-party',
        onPressed: () => PartyEditSheet.page(context),
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
            final off = list.where((p) => !p.isActive).length;
            final filters = widget.manage
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final (value, label) in [
                          (null, 'All ${list.length}'),
                          (true, 'Active ${list.length - off}'),
                          (false, 'Deactivated $off'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: _activeOnly == value,
                            onSelected: (_) => setState(() => _activeOnly = value),
                          ),
                      ],
                    ),
                  )
                : null;
            if (shown.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ?filters,
                  const SizedBox(height: 70),
                  Center(
                    child: Text(
                      _search.text.trim().isEmpty
                          ? 'No parties here'
                          : 'Nothing matches "${_search.text.trim()}"',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                ?filters,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      // The list holds deactivated parties too, so it says
                      // how many rather than calling them all active.
                      [
                        '${shown.length} of ${list.length} parties',
                        if (off > 0) '$off deactivated',
                      ].join(' · '),
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
                      manage: widget.manage,
                      canViewParty: ref.watch(menuAccessProvider).canViewParty,
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
  const _PartyRow({required this.party, required this.canViewParty, this.manage = false});

  final Party party;

  /// Opened from Party master: the record is what a tap is for.
  final bool manage;

  /// Whether the statement may be opened. Without the right it opened only to
  /// spin and say "You do not have permission", so the tap does nothing then.
  final bool canViewParty;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    void statement() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LedgerScreen(party: party)),
        );
    void record() => PartyEditSheet.page(context, editing: party);

    return InkWell(
      // On the tab, tapping opens the statement, which is what that list is
      // mostly used for, and the record sits behind a long press. Party
      // master is for the records, so there the two swap.
      onTap: manage ? record : (canViewParty ? statement : null),
      onLongPress: manage ? (canViewParty ? statement : null) : record,
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
