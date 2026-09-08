import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/money.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/async_view.dart';
import '../matches/match_providers.dart';
import '../money/ledger_screen.dart';
import 'party_edit_sheet.dart';

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
    final parties = ref.watch(partiesProvider);

    return Scaffold(
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
        onPressed: () => PartyEditSheet.show(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add party'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(partiesProvider.future),
        child: AsyncView(
          value: parties,
          onRetry: () => ref.invalidate(partiesProvider),
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
                    itemBuilder: (context, i) => _PartyRow(party: shown[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.party});

  final Party party;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LedgerScreen(party: party)),
      ),
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
