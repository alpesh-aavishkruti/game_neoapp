import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/util/money.dart';
import '../../../data/models/bet_entry.dart';
import '../../../shared/widgets/check_tick.dart';

/// One line of the book.
///
/// Every row carries a 2px rail down its left edge in its own colour - green
/// for L, red for K, amber when the entry was edited after it was taken. The
/// colour is never the only signal: the type is spelled out in the label too,
/// so the row still reads correctly to someone who cannot separate the hues.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.onToggleCheck,
  });

  final BetEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Ticking a bet off against the book. Only the drill-down offers this; on
  /// the board itself a row is placed and edited, not reconciled.
  final VoidCallback? onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    // A Bombay leg settles elsewhere and is never edited from the board.
    final canAct = !entry.isBombay && (onEdit != null || onDelete != null);
    final tone = entry.isEdited
        ? book.warn
        : entry.isBombay
            ? context.scheme.primary
            : entry.betType == BetType.l
                ? book.up
                : book.down;

    final row = Container(
      decoration: BoxDecoration(
        color: entry.isEdited ? book.warnSoft : context.scheme.surface,
        border: Border(
          left: BorderSide(color: tone, width: 2),
          bottom: BorderSide(color: book.line),
        ),
      ),
      padding: EdgeInsets.fromLTRB(14, 9, canAct ? 4 : 14, 9),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${entry.rowNo}',
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
                Text(
                  [
                    entry.clientCode,
                    if (entry.clientName.isNotEmpty) entry.clientName,
                    if (entry.isEdited) 'edited',
                  ].join(' — '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              // A stake is always a whole figure and the desk prints it that
              // way; the rate and the position beside it carry paise.
              Money.format(entry.amount, decimals: 0),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              Money.format(entry.rate),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 12,
                color: book.muted,
              ),
            ),
          ),
          if (onToggleCheck != null)
            CheckTick(checked: entry.isChecked, onTap: onToggleCheck!),
          if (canAct) ...[
            const SizedBox(width: 2),
            _RowAction(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              colour: context.scheme.primary,
              onTap: onEdit,
            ),
            _RowAction(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              colour: book.down,
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );

    if (!canAct) return row;

    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      background: _SwipeHint(
        alignment: Alignment.centerLeft,
        color: context.scheme.primary,
        icon: Icons.edit_outlined,
        label: 'Edit',
      ),
      secondaryBackground: _SwipeHint(
        alignment: Alignment.centerRight,
        color: book.down,
        icon: Icons.delete_outline,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit?.call();
        } else {
          onDelete?.call();
        }
        // Never actually remove the row here: the list redraws from the server
        // once the change lands, so the board and the book cannot disagree.
        return false;
      },
      child: row,
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        color: color.withValues(alpha: 0.15),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      );
}

/// The column headings above the ledger.
class EntryHeader extends StatelessWidget {
  const EntryHeader({super.key, required this.subjectLabel, this.hasActions = true});

  /// "Nation / client" on a match board, "Run / client" on a session.
  final String subjectLabel;

  /// Whether the rows below carry edit and delete buttons. The heading has to
  /// leave the same room or the columns stop lining up with their figures.
  final bool hasActions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, hasActions ? 4 : 14, 6),
        child: Row(
          children: [
            SizedBox(width: 34, child: Text('SR', style: context.text.labelSmall)),
            Expanded(child: Text(subjectLabel.toUpperCase(), style: context.text.labelSmall)),
            SizedBox(
              width: 78,
              child: Text('AMOUNT', textAlign: TextAlign.right, style: context.text.labelSmall),
            ),
            SizedBox(
              width: 52,
              child: Text('RATE', textAlign: TextAlign.right, style: context.text.labelSmall),
            ),
            if (hasActions) const SizedBox(width: 70),
          ],
        ),
      );
}

/// An action on a bet row.
///
/// Small and unlabelled: the row already carries four figures, and on a phone
/// the words "Edit" and "Delete" would push them off. Swiping still works for
/// anyone who prefers it - these exist so the operator knows it can be done.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.colour,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.rField),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: onTap == null ? null : colour),
          ),
        ),
      );
}
