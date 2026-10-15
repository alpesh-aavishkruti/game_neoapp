import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/money.dart';
import '../../data/models/book_row.dart';
import '../../data/models/match.dart';
import '../../shared/widgets/async_view.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/repositories/book_repository.dart';
import '../money/ledger_screen.dart';
import 'party_soda_screen.dart';
import '../../shared/widgets/check_tick.dart';
import '../../shared/widgets/live_refresh.dart';

final matchBookProvider = FutureProvider.family<MatchBook, ({GameMatch match, BookKind kind})>((
  ref,
  args,
) async {
  return ref.watch(bookRepositoryProvider).book(args.match, args.kind);
});

/// The four books of a match.
///
/// Party, soda, bookie and PTRN are four separate windows on the desk. They are
/// four views of one match, so here they are tabs on one screen - one swipe
/// apart rather than one navigation apart.
///
/// The grand total stays pinned at the bottom however far the list scrolls,
/// because that is the figure the book gets checked against.
class PartyBookScreen extends ConsumerStatefulWidget {
  const PartyBookScreen({super.key, required this.match});

  final GameMatch match;

  @override
  ConsumerState<PartyBookScreen> createState() => _PartyBookScreenState();
}

class _PartyBookScreenState extends ConsumerState<PartyBookScreen>
    with SingleTickerProviderStateMixin {
  /// Only the books this match actually keeps, so no tab can open onto an
  /// endpoint that does not exist.
  late final List<BookKind> _kinds = BookKind.forGame(widget.match.game);
  late final TabController _tabs = TabController(length: _kinds.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preparing the report…')));
    try {
      await ref
          .read(reportSharingProvider)
          .sharePdf(
            path: '/master/matches/download_match_report/',
            query: {'match_id': widget.match.id},
            name: 'Match ${widget.match.id} ${widget.match.title}',
          );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveRefresh(
      // The open book follows other operators' bets as they come in.
      matchId: widget.match.id,
      onTick: () =>
          ref.invalidate(matchBookProvider((match: widget.match, kind: _kinds[_tabs.index]))),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.match.title, style: context.text.titleLarge?.copyWith(fontSize: 18)),
              Text('Books', style: context.text.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share match report',
              onPressed: _share,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
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
                tabs: [for (final kind in _kinds) Tab(text: kind.label.toUpperCase())],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [for (final kind in _kinds) _BookTable(match: widget.match, kind: kind)],
        ),
      ),
    );
  }
}

class _BookTable extends ConsumerWidget {
  const _BookTable({required this.match, required this.kind});

  final GameMatch match;
  final BookKind kind;

  /// Which books carry the reconciling tick: the party book, and the bookie
  /// book on one day and test matches, as at the desk.
  bool get _ticks =>
      kind == BookKind.party ||
      (kind == BookKind.bookie && (match.game == GameType.oneDay || match.game == GameType.test));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (match: match, kind: kind);
    final book = ref.watch(matchBookProvider(args));
    final sides = match.bookColumns;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(matchBookProvider(args).future),
      child: AsyncView(
        value: book,
        onRetry: () => ref.invalidate(matchBookProvider(args)),
        isEmpty: (data) => data.rows.isEmpty,
        emptyTitle: 'Nothing in the ${kind.label.toLowerCase()} book',
        builder: (data) => Column(
          children: [
            _BookHeader(sides: sides, withCheck: _ticks),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: data.rows.length,
                itemBuilder: (context, i) => _BookLine(
                  row: data.rows[i],
                  sides: sides,
                  // A book line is a summary; tapping it asks what it is made
                  // of - on every game, tests included.
                  onTap: BookRepository.supportsPartySoda(match)
                      ? () => PartySodaScreen.open(
                          context,
                          match: match,
                          row: data.rows[i],
                          // The party book shows a party's own bets only;
                          // what it shares as a partner is the PTRN book's.
                          ownOnly: kind == BookKind.party,
                        )
                      : null,
                  // Reconciling is done against the party book, the same as
                  // at the desk; the other books just report.
                  onToggleCheck: _ticks ? () => _toggleCheck(ref, data.rows[i]) : null,
                ),
              ),
            ),
            _BookTotals(totals: data.totals, sides: sides, withCheck: _ticks),
          ],
        ),
      ),
    );
  }
}

extension on _BookTable {
  /// Ticks or unticks every bet behind a party's line. A part-ticked line
  /// ticks the rest, which is what an operator working down the book means.
  Future<void> _toggleCheck(WidgetRef ref, BookRow row) async {
    final args = (match: match, kind: kind);
    try {
      await ref
          .read(bookRepositoryProvider)
          .setChecked(
            match: match,
            partyId: row.partyId,
            checked: row.checkState != CheckState.all,
          );
    } finally {
      ref.invalidate(matchBookProvider(args));
      // The party book and bookie book share the same tick.
      for (final other in [BookKind.party, BookKind.bookie]) {
        if (other != kind) ref.invalidate(matchBookProvider((match: match, kind: other)));
      }
    }
  }
}

/// Column shares across the book: the client takes one share, each side
/// one more, so two long team names still fit in full on a phone.
const _clientFlex = 3;
const _sideFlex = 3;

/// The tick's footprint - 22 box plus its 8 padding either side - kept
/// free in the header and totals so every column lines up with the rows.
const _checkWidth = 38.0;

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.sides, required this.withCheck});

  final List<String> sides;
  final bool withCheck;

  @override
  Widget build(BuildContext context) {
    final label = context.text.labelSmall?.copyWith(letterSpacing: 0.5, height: 1.25);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(12, 6, withCheck ? 4 : 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: _clientFlex,
            child: Text('CLIENT', style: label),
          ),
          for (final side in sides.take(3))
            Expanded(
              flex: _sideFlex,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                // The whole name, on two lines if it needs them - a side
                // cut to "AUSTRAL..." leaves the reader guessing.
                child: Text(
                  side.toUpperCase(),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: label,
                ),
              ),
            ),
          if (withCheck) const SizedBox(width: _checkWidth),
        ],
      ),
    );
  }
}

/// A figure that shrinks to fit its column rather than being cut short.
class _Figure extends StatelessWidget {
  const _Figure(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: _sideFlex,
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(text, maxLines: 1, style: style),
      ),
    ),
  );
}

class _BookLine extends StatelessWidget {
  const _BookLine({required this.row, required this.sides, this.onTap, this.onToggleCheck});

  final BookRow row;
  final List<String> sides;
  final VoidCallback? onTap;
  final VoidCallback? onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    final line = Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, onToggleCheck == null ? 12 : 4, 8),
      child: Row(
        children: [
          Expanded(
            flex: _clientFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.code,
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (row.name.isNotEmpty)
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < sides.length && i < 3; i++)
            _Figure(
              i < row.figures.length ? Money.format(row.figures[i]) : '-',
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: i < row.figures.length ? book.forAmount(row.figures[i]) : book.muted,
              ),
            ),
          if (onToggleCheck != null)
            CheckTick(
              checked: row.checkState == CheckState.all,
              partial: row.checkState == CheckState.some,
              onTap: onToggleCheck!,
            ),
        ],
      ),
    );

    if (onTap == null) return line;
    return InkWell(onTap: onTap, child: line);
  }
}

class _BookTotals extends StatelessWidget {
  const _BookTotals({required this.totals, required this.sides, required this.withCheck});

  final List<double> totals;
  final List<String> sides;
  final bool withCheck;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      decoration: BoxDecoration(
        color: book.brandSoft,
        border: Border(top: BorderSide(color: book.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        withCheck ? 4 : 12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _clientFlex,
            child: Text(
              'TOTAL',
              style: context.text.labelSmall?.copyWith(color: context.scheme.primary),
            ),
          ),
          for (var i = 0; i < sides.length && i < 3; i++)
            _Figure(
              i < totals.length ? Money.format(totals[i]) : '-',
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: i < totals.length ? book.forAmount(totals[i]) : book.muted,
              ),
            ),
          if (withCheck) const SizedBox(width: _checkWidth),
        ],
      ),
    );
  }
}
