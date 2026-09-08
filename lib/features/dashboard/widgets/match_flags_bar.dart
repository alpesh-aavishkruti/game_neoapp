import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/match.dart';

/// The three desk switches that sit above every board.
///
/// They are not display preferences: an entry is written against whatever
/// these read at the moment it is saved, so a bet placed with PTRN off stays
/// off even after the switch goes back on. That is why they live on the board
/// itself rather than behind a settings screen - the operator has to be able
/// to see their state without leaving the entry flow.
class MatchFlagsBar extends StatelessWidget {
  const MatchFlagsBar({
    super.key,
    required this.match,
    required this.onChanged,
    this.busy = false,
  });

  final GameMatch match;

  /// Fired with only the flag that changed.
  final void Function({
    bool? commissionEnabled,
    bool? ptrnEnabled,
    bool? partyBookEnabled,
  }) onChanged;

  /// A save is in flight; the switches stay readable but stop accepting taps.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    // The party book is a one-day idea. Session, test and cup boards do not
    // carry one, and the desk system does not offer the switch there either.
    final showPartyBook = match.game == GameType.oneDay;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _Flag(
              label: 'COMMISSION',
              value: match.commissionEnabled,
              enabled: !match.isSettled && !busy,
              onTap: () => onChanged(commissionEnabled: !match.commissionEnabled),
            ),
          ),
          Expanded(
            child: _Flag(
              label: 'PTRN',
              value: match.ptrnEnabled,
              enabled: !match.isSettled && !busy,
              onTap: () => onChanged(ptrnEnabled: !match.ptrnEnabled),
            ),
          ),
          if (showPartyBook)
            Expanded(
              child: _Flag(
                label: 'PARTY BOOK',
                value: match.partyBookEnabled,
                enabled: !match.isSettled && !busy,
                onTap: () => onChanged(partyBookEnabled: !match.partyBookEnabled),
              ),
            ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final on = value;

    return Semantics(
      toggled: on,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rField),
        onTap: enabled ? onTap : null,
        child: Padding(
          // Half the minimum target height each side of a 24px box keeps the
          // whole row tappable without making the strip tall.
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: on ? context.scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: on ? context.scheme.primary : book.line,
                    width: 1.5,
                  ),
                ),
                child: on
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: enabled
                        ? (on ? context.scheme.onSurface : book.muted)
                        : book.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
