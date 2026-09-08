import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/match.dart';
import '../../data/models/match_totals.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import '../books/party_book_screen.dart';
import '../dashboard/board_screen.dart';
import 'match_providers.dart';
import 'new_match_sheet.dart';

/// Every match, and where it stands.
///
/// The desk system lists a name and a date. That is not enough on a phone -
/// this gets read standing up - so each card carries the live position for
/// both sides on its face.
class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key, this.openBooks = false});

  /// The Books tab reuses this list: same matches, but tapping one opens its
  /// books rather than its board.
  final bool openBooks;

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: GameType.values.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.openBooks ? 'Books' : 'Matches'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              tabs: [
                for (final game in GameType.values) Tab(text: game.label.toUpperCase()),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final game in GameType.values)
            _MatchTab(game: game, openBooks: widget.openBooks),
        ],
      ),
      floatingActionButton: widget.openBooks
          ? null
          : AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) {
                final game = GameType.values[_tabs.index];
                return FloatingActionButton.extended(
                  onPressed: () => NewMatchSheet.show(context, game: game),
                  icon: const Icon(Icons.add),
                  label: Text('New ${game.label.toLowerCase()}'),
                );
              },
            ),
    );
  }
}

class _MatchTab extends ConsumerWidget {
  const _MatchTab({required this.game, this.openBooks = false});

  final GameType game;
  final bool openBooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(activeMatchesProvider(game));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(activeMatchesProvider(game).future),
      child: AsyncView(
        value: matches,
        onRetry: () => ref.invalidate(activeMatchesProvider(game)),
        isEmpty: (list) => list.isEmpty,
        emptyTitle: 'No open ${game.label.toLowerCase()} matches',
        emptyMessage: 'Matches you open will appear here.',
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) =>
              _MatchCard(match: list[i], openBooks: openBooks),
        ),
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({required this.match, this.openBooks = false});

  final GameMatch match;
  final bool openBooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = context.book;

    return Material(
      color: context.scheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => openBooks
                ? PartyBookScreen(match: match)
                : BoardScreen(match: match),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rCard),
            border: Border.all(color: book.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.title.toUpperCase(),
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (match.isSettled)
                    const StatusChip('Settled')
                  else
                    const StatusChip('Live', tone: ChipTone.live, dot: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  match.game.label,
                  if (match.createdAt != null) AppTime.date(match.createdAt),
                ].join(' · '),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 10),
              Divider(color: book.line, height: 1),
              const SizedBox(height: 9),
              // The live position sits on the card so the list answers "where
              // do I stand" without opening anything.
              _CardPositions(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

/// The per-side figures on a card, loaded lazily so a long list does not fire
/// a request per row before it is even scrolled into view.
class _CardPositions extends ConsumerWidget {
  const _CardPositions({required this.match});

  final GameMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(match));

    return board.when(
      loading: () => const _PositionsPlaceholder(),
      error: (_, _) => Text('Position unavailable', style: context.text.bodySmall),
      data: (data) {
        // A session is not bet on sides, so its card shows what it is actually
        // taken on - K and L - rather than two team names it does not have.
        final List<NationPosition> shown = match.game == GameType.session
            ? [
                NationPosition(
                  name: 'K',
                  profitLoss: data.sessionTotals.kTotal,
                  averageRate: 0,
                ),
                NationPosition(
                  name: 'L',
                  profitLoss: data.sessionTotals.lTotal,
                  averageRate: 0,
                ),
              ]
            : data.totals.positions.take(3).toList();

        if (shown.isEmpty) {
          return Text('No entries yet', style: context.text.bodySmall);
        }
        return Row(
          children: [
            for (final position in shown)
              Expanded(child: _PositionCell(position: position)),
            SizedBox(
              width: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ENTRIES', style: context.text.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${data.entries.length}',
                    style: const TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PositionCell extends StatelessWidget {
  const _PositionCell({required this.position});

  final NationPosition position;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            position.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall,
          ),
          const SizedBox(height: 2),
          Text(
            Money.position(position.profitLoss),
            style: TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.book.forAmount(position.profitLoss),
            ),
          ),
        ],
      );
}

class _PositionsPlaceholder extends StatelessWidget {
  const _PositionsPlaceholder();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Loading position…', style: context.text.bodySmall),
        ),
      );
}
