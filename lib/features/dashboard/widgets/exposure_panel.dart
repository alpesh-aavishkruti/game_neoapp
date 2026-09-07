import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/util/money.dart';
import '../../../data/models/match_totals.dart';

/// Where the book stands, pinned above the ledger.
///
/// On the desk these figures sit in columns beside the entries. A phone is too
/// narrow for that, so they are lifted out and never scroll away - they are
/// the numbers an operator is actually watching.
///
/// The sides are drawn as one joined panel split by hairlines rather than
/// separate cards, because they are one reading, not several.
class ExposurePanel extends StatelessWidget {
  const ExposurePanel({super.key, required this.totals});

  final MatchTotals totals;

  @override
  Widget build(BuildContext context) {
    final positions = totals.positions;
    if (positions.isEmpty) return const SizedBox.shrink();

    final book = context.book;

    // Two or three sides sit across; a cup's many teams wrap into a grid.
    final perRow = positions.length <= 3 ? positions.length : 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        decoration: BoxDecoration(
          color: book.line,
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          border: Border.all(color: book.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Wrap(
          spacing: 1,
          runSpacing: 1,
          children: [
            for (final position in positions)
              _Cell(
                position: position,
                width: _cellWidth(context, perRow),
                compact: positions.length > 3,
              ),
          ],
        ),
      ),
    );
  }

  double _cellWidth(BuildContext context, int perRow) {
    final available = MediaQuery.sizeOf(context).width - 28 - 2;
    return (available - (perRow - 1)) / perRow;
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.position, required this.width, required this.compact});

  final NationPosition position;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      width: width,
      color: context.scheme.surface,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            position.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.position(position.profitLoss, decimals: 0),
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: compact ? 15 : 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: book.forAmount(position.profitLoss),
              ),
            ),
          ),
          if (!compact && position.averageRate > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Avg rate ${Money.format(position.averageRate)}',
              style: context.text.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}
