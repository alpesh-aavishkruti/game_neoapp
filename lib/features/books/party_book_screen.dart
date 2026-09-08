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

final matchBookProvider =
    FutureProvider.family<MatchBook, ({GameMatch match, BookKind kind})>((ref, args) async {
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
  late final TabController _tabs = TabController(length: BookKind.values.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing the report…')),
    );
    try {
      await ref.read(reportSharingProvider).sharePdf(
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
    return Scaffold(
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
              tabs: [for (final kind in BookKind.values) Tab(text: kind.label.toUpperCase())],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final kind in BookKind.values)
            _BookTable(match: widget.match, kind: kind),
        ],
      ),
    );
  }
}

class _BookTable extends ConsumerWidget {
  const _BookTable({required this.match, required this.kind});

  final GameMatch match;
  final BookKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (match: match, kind: kind);
    final book = ref.watch(matchBookProvider(args));
    final sides = match.selectableNations;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(matchBookProvider(args).future),
      child: AsyncView(
        value: book,
        onRetry: () => ref.invalidate(matchBookProvider(args)),
        isEmpty: (data) => data.rows.isEmpty,
        emptyTitle: 'Nothing in the ${kind.label.toLowerCase()} book',
        builder: (data) => Column(
          children: [
            _BookHeader(sides: sides),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: data.rows.length,
                itemBuilder: (context, i) => _BookLine(
                  row: data.rows[i],
                  sides: sides,
                  // A book line is a summary; tapping it asks what it is made
                  // of. Test matches have no such endpoint, so there the row
                  // stays a plain row rather than a dead tap target.
                  onTap: BookRepository.supportsPartySoda(match)
                      ? () => PartySodaScreen.open(context, match: match, row: data.rows[i])
                      : null,
                ),
              ),
            ),
            _BookTotals(totals: data.totals, sides: sides),
          ],
        ),
      ),
    );
  }
}

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.sides});

  final List<String> sides;

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
        child: Row(
          children: [
            Expanded(child: Text('CLIENT', style: context.text.labelSmall)),
            for (final side in sides.take(3))
              SizedBox(
                width: 72,
                child: Text(
                  side.toUpperCase(),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall,
                ),
              ),
          ],
        ),
      );
}

class _BookLine extends StatelessWidget {
  const _BookLine({required this.row, required this.sides, this.onTap});

  final BookRow row;
  final List<String> sides;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    final line = Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      child: Row(
        children: [
          Expanded(
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
            SizedBox(
              width: 72,
              child: Text(
                i < row.figures.length ? Money.format(row.figures[i], decimals: 0) : '-',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: i < row.figures.length
                      ? book.forAmount(row.figures[i])
                      : book.muted,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return line;
    return InkWell(onTap: onTap, child: line);
  }
}

class _BookTotals extends StatelessWidget {
  const _BookTotals({required this.totals, required this.sides});

  final List<double> totals;
  final List<String> sides;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      decoration: BoxDecoration(
        color: book.brandSoft,
        border: Border(top: BorderSide(color: book.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        15,
        11,
        15,
        11 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'TOTAL',
              style: context.text.labelSmall?.copyWith(color: context.scheme.primary),
            ),
          ),
          for (var i = 0; i < sides.length && i < 3; i++)
            SizedBox(
              width: 72,
              child: Text(
                i < totals.length ? Money.format(totals[i], decimals: 0) : '-',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: i < totals.length ? book.forAmount(totals[i]) : book.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
