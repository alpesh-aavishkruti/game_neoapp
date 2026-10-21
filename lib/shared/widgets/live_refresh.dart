import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/network/match_live_feed.dart';

/// Re-reads a screen's data as soon as anyone changes the match, and on a
/// timer as a fallback.
///
/// Several operators work one match at once; without this a phone kept
/// showing the book as it was when opened until someone pulled to refresh.
/// Given a [matchId] it listens on the same live socket as the web desk, so a
/// bet typed on the desk shows here within a moment; the timer only matters
/// while that line is down, and as an occasional safety read.
///
/// It only fires when the screen is the top route - an entry sheet, dialog or
/// another screen on top pauses it, so nothing being typed is disturbed - and
/// only while the app is in the foreground. The data refreshes in place: the
/// previous figures stay on screen until the new ones arrive.
class LiveRefresh extends StatefulWidget {
  const LiveRefresh({
    super.key,
    required this.onTick,
    required this.child,
    this.matchId,
    this.socketPath,
    this.every = const Duration(seconds: 15),
    this.connector,
  });

  final VoidCallback onTick;
  final Widget child;

  /// The match whose live changes to follow; without one (or a [socketPath])
  /// only the timer runs.
  final int? matchId;

  /// Another live channel to follow instead, by its path - a company's list
  /// of matches, say.
  final String? socketPath;
  final Duration every;

  /// Stands in for the real socket in tests.
  final LiveSocketConnector? connector;

  /// Off under `flutter test`, where no backend is listening for sockets.
  static bool socketsEnabled = !Platform.environment.containsKey('FLUTTER_TEST');

  /// With the socket up, the timer still reads once in this long, in case a
  /// change reached the database without being announced.
  static const Duration safetyRead = Duration(seconds: 60);

  @override
  State<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends State<LiveRefresh> with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _pendingCheck;
  MatchLiveFeed? _feed;
  DateTime _lastRead = DateTime.now();

  /// A change heard while something sat on top, read once it is gone.
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.every, (_) => _onTimer());
    _startFeed();
  }

  /// False while this sits in a tab that is switched away from; the tab
  /// reads its figures again when it comes back (see RefreshOnShow).
  bool _tabShown = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabShown = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(LiveRefresh old) {
    super.didUpdateWidget(old);
    if (old.matchId != widget.matchId || old.socketPath != widget.socketPath) {
      _stopFeed();
      _startFeed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopFeed();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startFeed() {
    final id = widget.matchId;
    final path = widget.socketPath;
    if (id == null && path == null) return;
    if (widget.connector == null && !LiveRefresh.socketsEnabled) return;
    _feed = MatchLiveFeed(
      matchId: id,
      path: path,
      onChange: _onLive,
      connector: widget.connector,
    )..start();
    _pendingCheck = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_pending && _inFront) _tick();
    });
  }

  void _stopFeed() {
    _pendingCheck?.cancel();
    _pendingCheck = null;
    _feed?.stop();
    _feed = null;
  }

  void _onLive() {
    if (_inFront) {
      _tick();
    } else {
      _pending = true;
    }
  }

  void _onTimer() {
    final live = _feed?.isOpen ?? false;
    if (live && DateTime.now().difference(_lastRead) < LiveRefresh.safetyRead) return;
    _tick();
  }

  bool get _inFront {
    if (!mounted || !_tabShown) return false;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  void _tick() {
    if (!_inFront) return;
    _pending = false;
    _lastRead = DateTime.now();
    widget.onTick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: catch up at once rather than on the next tick.
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
