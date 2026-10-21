import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/money.dart';

/// One of the two Lena / Dena switches at the head of a statement - a pill
/// like a scorecard's innings tabs, carrying its side's total and line count.
/// Used by View Party and View General.
class SidePill extends StatelessWidget {
  const SidePill({
    super.key,
    required this.label,
    required this.total,
    required this.count,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final double total;
  final int count;
  final bool selected;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.scheme.primary;
    final fg = selected ? Colors.white : context.scheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label $count lines',
      child: Material(
        color: selected ? brand : context.scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? brand : context.book.line),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Money.format(total),
                    style: TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : tone,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '($count)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white70 : context.book.muted,
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
