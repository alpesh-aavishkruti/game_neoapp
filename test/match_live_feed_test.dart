import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/match_live_feed.dart';
import 'package:game_app_flutter/shared/widgets/live_refresh.dart';

class _FakeSocket implements LiveSocket {
  final controller = StreamController<dynamic>();
  final sent = <String>[];
  bool closed = false;

  void say(Map<String, dynamic> message) => controller.add(jsonEncode(message));

  @override
  Stream<dynamic> get messages => controller.stream;

  @override
  void send(String text) => sent.add(text);

  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) await controller.close();
  }
}

const _change = {
  'type': 'entry_change',
  'game_type': 'oneday',
  'match_id': '7',
  'data': {'entry_id': 1, 'is_deleted': false},
};

void main() {
  test('the socket address follows the backend the app points at', () {
    expect(
      MatchLiveFeed.socketUri(7, apiBaseUrl: 'https://api.neonacc.com').toString(),
      'wss://api.neonacc.com/ws/match/7/',
    );
    expect(
      MatchLiveFeed.socketUri(12, apiBaseUrl: 'http://10.0.2.2:8000').toString(),
      'ws://10.0.2.2:8000/ws/match/12/',
    );
  });

  test('a burst of changes is read once; a pong is not a change', () async {
    final sockets = <_FakeSocket>[];
    final uris = <Uri>[];
    var reads = 0;
    final feed = MatchLiveFeed(
      matchId: 7,
      onChange: () => reads++,
      debounce: const Duration(milliseconds: 20),
      connector: (uri) async {
        uris.add(uri);
        return sockets.last;
      },
    );
    sockets.add(_FakeSocket());
    feed.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(uris.single.path, '/ws/match/7/');
    expect(feed.isOpen, isTrue);

    sockets.last.say({'type': 'pong'});
    sockets.last.say(_change);
    sockets.last.say(_change);
    sockets.last.say(_change);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(reads, 1);

    await feed.stop();
    expect(sockets.last.closed, isTrue);
  });

  test('a dropped line reconnects and reads again', () async {
    final sockets = [_FakeSocket(), _FakeSocket()];
    var connects = 0;
    var reads = 0;
    final feed = MatchLiveFeed(
      matchId: 7,
      onChange: () => reads++,
      debounce: const Duration(milliseconds: 5),
      reconnectAfter: const Duration(milliseconds: 20),
      connector: (_) async => sockets[connects++],
    );
    feed.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(reads, 0, reason: 'the first connect has nothing to catch up on');

    await sockets[0].controller.close();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(feed.isOpen, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(connects, 2);
    expect(feed.isOpen, isTrue);
    expect(reads, 1, reason: 'bets made while the line was down are read');

    await feed.stop();
  });

  testWidgets('a change on the desk refreshes the screen, but not under a sheet', (tester) async {
    final socket = _FakeSocket();
    var ticks = 0;
    final nav = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: LiveRefresh(
        matchId: 7,
        onTick: () => ticks++,
        connector: (_) async => socket,
        child: const Scaffold(body: Text('board')),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));

    await tester.runAsync(() async {
      socket.say(_change);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(ticks, 1, reason: 'well before the 15-second timer');

    // Something on top: the change waits until it is closed.
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('sheet'))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      socket.say(_change);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(ticks, 1);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(ticks, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  });

  testWidgets('a card in a tab switched away from waits until the tab is back', (tester) async {
    final socket = _FakeSocket();
    var ticks = 0;
    var shown = true;
    late StateSetter setShown;

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        setShown = setState;
        return TickerMode(
          enabled: shown,
          child: LiveRefresh(
            matchId: 7,
            onTick: () => ticks++,
            connector: (_) async => socket,
            child: const Scaffold(body: Text('card')),
          ),
        );
      }),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));

    setShown(() => shown = false);
    await tester.pump();
    await tester.runAsync(() async {
      socket.say(_change);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(ticks, 0, reason: 'a hidden tab is not read');

    setShown(() => shown = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(ticks, 1, reason: 'the change heard while hidden is read on return');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  });
}
