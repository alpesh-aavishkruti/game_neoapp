import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/money.dart';
import '../../data/models/match.dart';
import '../../data/models/run_ladder.dart';
import '../../shared/widgets/async_view.dart';
import '../matches/match_providers.dart';

final _runWiseProvider =
    FutureProvider.autoDispose.family<RunLadder, GameMatch>((ref, match) {
  return ref.watch(matchRepositoryProvider).runWise(match);
});

/// The session position at every run figure the book reaches.
///
/// The strip on the board shows the window around the action, which is the
/// question being asked most of the time. This is the whole table, for when the
/// question is about a figure a long way from where play is.
class RunWiseScreen extends ConsumerStatefulWidget {
  const RunWiseScreen({super.key, required this.match});

  final GameMatch match;

  static Future<void> open(BuildContext context, {required GameMatch match}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RunWiseScreen(match: match)),
      );

  @override
  ConsumerState<RunWiseScreen> createState() => _RunWiseScreenState();
}

class _RunWiseScreenState extends ConsumerState<RunWiseScreen> {
  final _controller = ScrollController();

  /// Only show the runs where the figure actually moves, rather than thousands
  /// of identical rows. Off by default: the full table is what the desk shows.
  bool _stepsOnly = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The rungs where the position changes from the one before it - the run
  /// figures a bet actually turns on.
  List<RunRung> _steps(List<RunRung> all) {
    final out = <RunRung>[];
    double? last;
    for (final r in all) {
      if (last == null || (r.profitLoss - last).abs() > 0.005) out.add(r);
      last = r.profitLoss;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ladder = ref.watch(_runWiseProvider(widget.match));
    final book = context.book;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Run wise'),
            Text(
              '${widget.match.title} · position at every run',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_runWiseProvider(widget.match).future),
        child: AsyncView(
          value: ladder,
          onRetry: () => ref.invalidate(_runWiseProvider(widget.match)),
          isEmpty: (data) => data.rungs.isEmpty,
          emptyTitle: 'Nothing on this session yet',
          emptyMessage: 'The ladder fills in as runs are taken.',
          builder: (data) {
            final rows = _stepsOnly ? _steps(data.rungs) : data.rungs;

            return Column(
              children: [
                Container(
                  color: context.scheme.surface,
                  padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
                  child: Row(
                    children: [
                      Text(
                        '${Money.format(rows.length.toDouble(), decimals: 0)} '
                        '${_stepsOnly ? 'changes' : 'runs'}',
                        style: context.text.bodySmall,
                      ),
                      const Spacer(),
                      Text('CHANGES ONLY', style: context.text.labelSmall),
                      Switch(
                        value: _stepsOnly,
                        onChanged: (v) => setState(() => _stepsOnly = v),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
                  child: Row(
                    children: [
                      Text('RUN', style: context.text.labelSmall),
                      const Spacer(),
                      Text('POSITION', style: context.text.labelSmall),
                    ],
                  ),
                ),
                Expanded(
                  // Lazy: the desk's full table runs to thousands of rungs and
                  // only the visible ones are ever built.
                  child: ListView.builder(
                    controller: _controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    itemExtent: 38,
                    itemBuilder: (context, i) {
                      final rung = rows[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: context.scheme.surface,
                          border: Border(bottom: BorderSide(color: book.line)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            Text(
                              '${rung.run}',
                              style: const TextStyle(
                                fontFamily: 'Roboto Mono',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Money.format(rung.profitLoss),
                              style: TextStyle(
                                fontFamily: 'Roboto Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: book.forAmount(rung.profitLoss),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
