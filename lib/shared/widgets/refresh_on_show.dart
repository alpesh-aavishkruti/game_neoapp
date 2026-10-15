import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads a screen's data again every time the screen comes into view.
///
/// The app keeps what it has read, so a screen opened a second time, a tab
/// switched back to, or a screen returned to from the one above it used to
/// show the figures from the first visit - a bet, havala or match made since,
/// on this phone or on the desk, appeared only after a pull to refresh.
///
/// Now each of those moments re-reads [providers]. What is on screen stays
/// there while the new figures load, so nothing blanks or jumps; a provider
/// that is still loading (its first read, or one already under way) is left
/// to finish rather than being asked twice.
class RefreshOnShow extends ConsumerStatefulWidget {
  const RefreshOnShow({super.key, required this.providers, required this.child});

  final List<FutureProvider<Object?>> providers;
  final Widget child;

  @override
  ConsumerState<RefreshOnShow> createState() => _RefreshOnShowState();
}

class _RefreshOnShowState extends ConsumerState<RefreshOnShow> {
  /// Null until the first look, so the first one is treated as "came into view".
  bool? _wasShown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hidden tabs sit under a TickerMode that is off; a screen with another
    // route over it (a screen, sheet or dialog) is not the current route.
    final shown = TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (shown && _wasShown != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
    _wasShown = shown;
  }

  void _refresh() {
    if (!mounted) return;
    for (final provider in widget.providers) {
      if (!ref.read(provider).isLoading) ref.invalidate(provider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
