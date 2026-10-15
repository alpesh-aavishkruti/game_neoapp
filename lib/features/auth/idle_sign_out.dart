import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Signs the user out after the idle time set on their account.
///
/// The desk logs a user out after `auto_logout_minutes` without a touch; the
/// phone now does the same, counting any tap or scroll on any screen, and
/// time spent in the background. An account with no limit set is left alone.
class IdleSignOut extends ConsumerStatefulWidget {
  const IdleSignOut({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IdleSignOut> createState() => _IdleSignOutState();
}

class _IdleSignOutState extends ConsumerState<IdleSignOut> with WidgetsBindingObserver {
  DateTime _lastActive = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Duration? get _limit {
    final auth = ref.read(authControllerProvider);
    if (auth is! SignedIn) return null;
    final minutes = auth.session.autoLogoutMinutes;
    return (minutes == null || minutes <= 0) ? null : Duration(minutes: minutes);
  }

  void _check() {
    final limit = _limit;
    if (limit == null) {
      _lastActive = DateTime.now();
      return;
    }
    if (DateTime.now().difference(_lastActive) >= limit) {
      _lastActive = DateTime.now();
      ref.read(authControllerProvider.notifier).signOutIdle(limit.inMinutes);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after a long time away counts the time spent away.
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _lastActive = DateTime.now(),
        child: widget.child,
      );
}
