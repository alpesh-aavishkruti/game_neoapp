import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum ChipTone { live, open, muted, up, down, warn }

/// The small uppercase pill used for status and totals across the boards.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.muted, this.dot = false});

  final String label;
  final ChipTone tone;

  /// A leading dot, used to mark a match that is live right now.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final (fg, bg) = switch (tone) {
      ChipTone.live => (book.down, book.downSoft),
      ChipTone.down => (book.down, book.downSoft),
      ChipTone.up => (book.up, book.upSoft),
      ChipTone.warn => (book.warn, book.warnSoft),
      ChipTone.open => (context.scheme.primary, book.brandSoft),
      ChipTone.muted => (book.muted, book.line),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
