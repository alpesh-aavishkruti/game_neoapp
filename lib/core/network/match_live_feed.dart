import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

/// The bare socket the feed talks through, so tests can stand in for it.
abstract class LiveSocket {
  Stream<dynamic> get messages;
  void send(String text);
  Future<void> close();
}

typedef LiveSocketConnector = Future<LiveSocket> Function(Uri uri);

class _IoLiveSocket implements LiveSocket {
  _IoLiveSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<dynamic> get messages => _socket;

  @override
  void send(String text) => _socket.add(text);

  @override
  Future<void> close() => _socket.close();
}

Future<LiveSocket> _connectIo(Uri uri) async => _IoLiveSocket(
      await WebSocket.connect(uri.toString()).timeout(AppConfig.connectTimeout),
    );

/// Hears the moment a bet on a match is saved, changed or deleted - by this
/// phone, another phone, or the web desk.
///
/// The server announces every change to a match on `/ws/match/<id>/`, the same
/// line the web desk listens on. Before this the phone only re-read the board
/// on a 15-second timer, so a bet typed on the desk took up to that long to
/// show here while the desk saw the phone's bets at once.
///
/// Mirrors the desk: a burst of changes is read once, a dropped line
/// reconnects after 3 seconds and re-reads (anything said while it was down
/// was missed), and a line gone silent for a minute is treated as dead.
class MatchLiveFeed {
  MatchLiveFeed({
    required this.matchId,
    required this.onChange,
    LiveSocketConnector? connector,
    this.debounce = const Duration(milliseconds: 250),
    this.reconnectAfter = const Duration(seconds: 3),
    this.pingEvery = const Duration(seconds: 25),
    this.silentLimit = const Duration(seconds: 60),
  }) : _connector = connector ?? _connectIo;

  final int matchId;

  /// Called when the match's book has changed and should be read again.
  final void Function() onChange;

  final LiveSocketConnector _connector;
  final Duration debounce;
  final Duration reconnectAfter;
  final Duration pingEvery;
  final Duration silentLimit;

  LiveSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  DateTime _lastHeard = DateTime.now();
  bool _serverAnswersPing = false;
  bool _hasConnectedBefore = false;
  bool _connecting = false;
  bool _stopped = true;

  /// True while the line is up, so a fallback timer can stand down.
  bool get isOpen => _socket != null;

  /// `wss://api.example.com/ws/match/12/` for an `https://api.example.com` backend.
  static Uri socketUri(int matchId, {String? apiBaseUrl}) {
    final api = Uri.parse(apiBaseUrl ?? AppConfig.apiBaseUrl);
    return Uri(
      scheme: api.scheme == 'https' ? 'wss' : 'ws',
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: '/ws/match/$matchId/',
    );
  }

  void start() {
    if (!_stopped) return;
    _stopped = false;
    _pingTimer = Timer.periodic(pingEvery, (_) => _ping());
    _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _debounceTimer?.cancel();
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _drop();
  }

  Future<void> _connect() async {
    if (_stopped || _connecting || _socket != null) return;
    _connecting = true;
    try {
      final socket = await _connector(socketUri(matchId));
      if (_stopped) {
        await socket.close();
        return;
      }
      _socket = socket;
      _lastHeard = DateTime.now();
      _sub = socket.messages.listen(
        _onMessage,
        onError: (_) => _lost(),
        onDone: _lost,
        cancelOnError: true,
      );
      // Bets entered while the line was down were never announced.
      if (_hasConnectedBefore) _changed();
      _hasConnectedBefore = true;
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onMessage(dynamic raw) {
    _lastHeard = DateTime.now();
    if (raw is! String) return;
    Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (data is! Map) return;
    final type = data['type'] ?? data['event_type'];
    if (type == 'pong') {
      _serverAnswersPing = true;
      return;
    }
    if (type == 'entry_change' || type == 'broadcast_update') _changed();
  }

  void _changed() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (!_stopped) onChange();
    });
  }

  void _ping() {
    final socket = _socket;
    if (socket == null) return;
    // Once the server has shown it answers, a minute of silence means the
    // line died without closing: drop it so it reconnects and re-reads.
    if (_serverAnswersPing && DateTime.now().difference(_lastHeard) > silentLimit) {
      _lost();
      return;
    }
    try {
      socket.send(jsonEncode({'type': 'ping'}));
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    _drop();
    _scheduleReconnect();
  }

  Future<void> _drop() async {
    final socket = _socket;
    _socket = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await socket?.close();
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectAfter, _connect);
  }
}
