import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The reconcile tick used by the books: empty, half (some of the bets behind
/// a line) or full.
///
/// Drawn by hand rather than with a Checkbox so the half state reads as itself
/// instead of as off, and so it sits at the same size as the figures beside it.
class CheckTick extends StatelessWidget {
  const CheckTick({
    super.key,
    required this.checked,
    required this.onTap,
    this.partial = false,
  });

  final bool checked;
  final bool partial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour =
        checked || partial ? context.scheme.primary : context.book.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? context.scheme.primary : Colors.transparent,
            border: Border.all(color: colour, width: 1.5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: checked
              ? Icon(Icons.check, size: 15, color: context.scheme.onPrimary)
              : partial
                  ? Icon(Icons.remove, size: 15, color: colour)
                  : null,
        ),
      ),
    );
  }
}
