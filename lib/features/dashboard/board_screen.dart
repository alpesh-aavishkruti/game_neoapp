import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/bet_entry.dart';
import '../../data/models/match.dart';
import '../../shared/widgets/async_view.dart';
import '../matches/match_providers.dart';
import '../books/party_book_screen.dart';
import 'bet_entry_sheet.dart';
import 'close_match_sheet.dart';
import 'bombay_settle_sheet.dart';
import 'cup_declare_sheet.dart';
import 'run_wise_screen.dart';
import 'widgets/entry_row.dart';
import 'widgets/exposure_panel.dart';
import 'widgets/match_flags_bar.dart';
import 'widgets/run_ladder_strip.dart';
import '../../shared/widgets/live_refresh.dart';
import '../../shared/widgets/refresh_on_show.dart';

/// A match board: position first, entries below.
///
/// One screen serves all four game types. They differ in how many sides they
/// carry and whether a bet names a side or a run, and both of those come from
/// the match itself - so a session and a cup do not need boards of their own
/// that then drift apart.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.match});

  final GameMatch match;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  ({String? nation, BetType type})? _lastUsed;

  /// Set while a switch is being saved, so the board reads back the new state
  /// immediately instead of waiting for the round trip.
  GameMatch? _pendingFlags;
  bool _savingFlags = false;

  GameMatch get match => _pendingFlags ?? widget.match;

  /// Flipping a switch has to look instant - the operator flips it and types
  /// the next bet. So the new state is shown at once and written behind it; if
  /// the write fails the switch goes back and says so, because a bet entered
  /// against a flag that never saved would be wrong.
  Future<void> _setFlags({
    bool? commissionEnabled,
    bool? ptrnEnabled,
    bool? partyBookEnabled,
  }) async {
    if (_savingFlags) return;

    final previous = match;
    setState(() {
      _pendingFlags = previous.copyWith(
        commissionEnabled: commissionEnabled,
        ptrnEnabled: ptrnEnabled,
        partyBookEnabled: partyBookEnabled,
      );
      _savingFlags = true;
    });

    try {
      await ref
          .read(matchRepositoryProvider)
          .setMatchFlags(
            match: previous,
            commissionEnabled: commissionEnabled,
            ptrnEnabled: ptrnEnabled,
            partyBookEnabled: partyBookEnabled,
          );
      // The match list carries these flags too, so it has to be re-read or the
      // card behind this screen would still show the old state.
      ref.invalidate(activeMatchesProvider(previous.game));
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingFlags = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save that. Please try again.')));
    } finally {
      if (mounted) setState(() => _savingFlags = false);
    }
  }

  Future<void> _refresh() => ref.refresh(boardProvider(match).future);

  Future<void> _addEntry() async {
    final used = await BetEntrySheet.show(context, match: match, lastUsed: _lastUsed);
    if (used == null) return;

    // A run of bets on the same side should be one tap each, not three, so the
    // next sheet opens where this one left off.
    setState(() => _lastUsed = used);
    await _refresh();
  }

  Future<void> _editEntry(BetEntry entry) async {
    final saved = await BetEntrySheet.show(context, match: match, editing: entry);
    if (saved == null) return;
    await _refresh();
  }

  Future<void> _delete(BetEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          '${entry.label} · ${entry.clientCode} · '
          '${entry.amount.toStringAsFixed(0)} at ${entry.rate}\n\n'
          'It moves to the recycle bin and the match position is recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.book.down),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(matchRepositoryProvider).deleteEntry(match: match, entryId: entry.id);
      await _refresh();
    } on ApiException catch (e) {
      _say(e.message);
    }
  }

  Future<void> _closeMatch() async {
    // A cup is not closed by naming a winner - teams are knocked out one at a
    // time - so it gets its own flow rather than being forced into this one.
    final bool? closed;
    if (match.game == GameType.cup) {
      closed = await CupDeclareSheet.show(context, cup: match);
    } else {
      closed = await CloseMatchSheet.show(context, match: match);
    }
    if (closed != true) return;

    // The match has left the open lists and joined the closed ones, so both
    // have to be told rather than showing a match that is no longer there.
    ref.invalidate(activeMatchesProvider(match.game));
    await _refresh();
    // A settled match has left the board behind; a cup mid-declaration has
    // not, so it stays open for the next elimination.
    if (mounted && match.game != GameType.cup) Navigator.of(context).pop();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider(match));

    return RefreshOnShow(
      providers: [boardProvider(match)],
      child: LiveRefresh(
      // Other operators' bets appear the moment they are saved.
      matchId: match.id,
      onTick: () => ref.invalidate(boardProvider(match)),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.title, style: context.text.titleLarge?.copyWith(fontSize: 18)),
              Text(
                [
                  match.game.label,
                  if (match.createdAt != null) AppTime.date(match.createdAt),
                ].join(' · '),
                style: context.text.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Books',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => PartyBookScreen(match: match))),
            ),
            if (!match.isSettled)
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) async {
                  switch (value) {
                    case 'close':
                      _closeMatch();
                    case 'runwise':
                      await RunWiseScreen.open(context, match: match);
                    case 'bombay':
                      final saved = await BombaySettleSheet.show(context, match: match);
                      if (saved == true) await _refresh();
                  }
                },
                itemBuilder: (context) => [
                  // A session's position is read off run figures, so the full
                  // table belongs to it and to nothing else.
                  if (match.game == GameType.session)
                    const PopupMenuItem(value: 'runwise', child: Text('Run wise')),
                  // Bombay legs settle elsewhere; a cup and a session have none.
                  if (match.game == GameType.oneDay || match.game == GameType.test)
                    const PopupMenuItem(value: 'bombay', child: Text('Bombay settle')),
                  PopupMenuItem(
                    value: 'close',
                    child: Text(match.game == GameType.cup ? 'Declare result' : 'Close match'),
                  ),
                ],
              ),
          ],
        ),
        floatingActionButton: match.isSettled
            ? null
            : FloatingActionButton.extended(
                onPressed: _addEntry,
                icon: const Icon(Icons.add),
                label: Text(match.game == GameType.session ? 'Add run' : 'Add bet'),
              ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: AsyncView(
            value: board,
            onRetry: () => ref.invalidate(boardProvider(match)),
            builder: (data) => Column(
              children: [
                // Commission, partnerships and the party book decide how the next
                // entry is written, so they sit above the board rather than
                // behind a menu.
                MatchFlagsBar(match: match, busy: _savingFlags, onChanged: _setFlags),
                // A session stands on run figures, not on two sides, so it gets
                // the ladder where the other boards get exposure tiles.
                if (match.game == GameType.session)
                  RunLadderStrip(ladder: data.ladder, totals: data.sessionTotals)
                else
                  ExposurePanel(totals: data.totals),
                EntryHeader(
                  subjectLabel: match.game == GameType.session ? 'Run / client' : 'Nation / client',
                  // A settled board takes no more changes, so its rows carry no
                  // buttons and the heading reclaims the room.
                  hasActions: !match.isSettled,
                ),
                Expanded(
                  child: data.entries.isEmpty
                      ? _NoEntriesYet(isSettled: match.isSettled)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: data.entries.length,
                          itemBuilder: (context, i) {
                            final entry = data.entries[i];
                            return EntryRow(
                              entry: entry,
                              onEdit: match.isSettled ? null : () => _editEntry(entry),
                              onDelete: match.isSettled ? null : () => _delete(entry),
                            );
                          },
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
}

class _NoEntriesYet extends StatelessWidget {
  const _NoEntriesYet({required this.isSettled});

  final bool isSettled;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 70),
      Center(
        child: Text(
          isSettled ? 'This match was settled with no entries.' : 'No entries yet',
          style: context.text.titleMedium,
        ),
      ),
      if (!isSettled) ...[
        const SizedBox(height: 6),
        Center(child: Text('Tap Add to place the first bet.', style: context.text.bodySmall)),
      ],
    ],
  );
}
