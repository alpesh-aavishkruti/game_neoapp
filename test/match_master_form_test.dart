import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_client.dart';
import 'package:game_app_flutter/core/providers.dart';
import 'package:game_app_flutter/core/storage/token_store.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/data/models/match.dart';
import 'package:game_app_flutter/features/masters/more_screen.dart';
import 'package:game_app_flutter/features/matches/match_providers.dart';

/// Accepts every write and keeps it, so the test can read what was sent.
class _Server implements HttpClientAdapter {
  final sent = <({String method, String path, Map body})>[];
  final reads = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') reads.add(options.uri.path);
    if (options.method != 'GET') {
      sent.add((
        method: options.method,
        path: options.uri.path,
        body: Map.from(options.data as Map),
      ));
    }
    return ResponseBody.fromString(
      jsonEncode({'status': true, 'message': 'ok', 'data': <dynamic>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokens extends TokenStore {
  @override
  Future<String?> readAccess() async => null;
}

void main() {
  late _Server server;

  Future<void> openNewMatch(WidgetTester tester) async {
    server = _Server();
    final tokens = _MemoryTokens();
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWith(
          (ref) => ApiClient(tokens: tokens, dio: Dio()..httpClientAdapter = server),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        // The Matches tab, alive behind the bottom bar as in the app shell.
        home: Consumer(
          builder: (context, ref, child) {
            ref.watch(activeMatchesProvider(GameType.oneDay));
            return child!;
          },
          child: const MoreScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Match master'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New match'));
    await tester.pumpAndSettle();
  }

  Future<void> pickGame(WidgetTester tester, String game) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(game).last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    final field = find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );
    await tester.enterText(field, value);
  }

  testWidgets('offers all four games, cup included, as the desk does', (tester) async {
    await openNewMatch(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    for (final game in ['One Day', 'Session', 'Test', 'Cup']) {
      expect(find.text(game), findsWidgets, reason: '$game is a choice');
    }
  });

  testWidgets('a session asks for a name and a code', (tester) async {
    await openNewMatch(tester);
    await pickGame(tester, 'Session');

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('CODE'), findsOneWidget);
    expect(find.text('NATION A'), findsNothing);
    expect(find.text('NATION C'), findsNothing);
  });

  testWidgets('a test asks for the two nations and the draw', (tester) async {
    await openNewMatch(tester);
    await pickGame(tester, 'Test');

    expect(find.text('NATION A'), findsOneWidget);
    expect(find.text('NATION B'), findsOneWidget);
    expect(find.text('NATION C'), findsOneWidget);
  });

  testWidgets('a cup is saved as a cup with its two nations', (tester) async {
    await openNewMatch(tester);
    await pickGame(tester, 'Cup');

    expect(find.text('NATION C'), findsNothing);
    await type(tester, 'NATION A', 'india');
    await type(tester, 'NATION B', 'australia');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(server.sent, hasLength(1));
    final body = server.sent.single.body;
    expect(server.sent.single.path, endsWith('/master/matches/'));
    expect(body['game'], 'CUP');
    expect(body['nation_a'], 'INDIA');
    expect(body['nation_b'], 'AUSTRALIA');
    expect(body['is_active'], true);
  });

  testWidgets('two sides starting with the same letter are refused', (tester) async {
    await openNewMatch(tester);
    await pickGame(tester, 'One Day');
    await type(tester, 'NATION A', 'India');
    await type(tester, 'NATION B', 'Ireland');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('First letters'), findsOneWidget);
    expect(server.sent, isEmpty);
  });

  testWidgets('a session may share letters between its name and code', (tester) async {
    await openNewMatch(tester);
    await pickGame(tester, 'Session');
    await type(tester, 'NAME', 'Over 1');
    await type(tester, 'CODE', 'Over');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(server.sent, hasLength(1));
    expect(server.sent.single.body['game'], 'SESSION');
    expect(server.sent.single.body['nation_a'], 'OVER 1');
  });

  testWidgets('a match saved here shows on the Matches tab straight away', (tester) async {
    await openNewMatch(tester);
    int boardReads() =>
        server.reads.where((p) => p.endsWith('/oneday_active_match/')).length;
    final before = boardReads();

    await pickGame(tester, 'One Day');
    await type(tester, 'NATION A', 'India');
    await type(tester, 'NATION B', 'Australia');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(server.sent, hasLength(1));

    // Back to where the Matches tab is on screen again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(boardReads(), greaterThan(before),
        reason: 'the open matches were fetched again after the save');
  });
}
