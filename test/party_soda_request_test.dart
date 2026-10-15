import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_client.dart';
import 'package:game_app_flutter/core/storage/token_store.dart';
import 'package:game_app_flutter/data/models/match.dart';
import 'package:game_app_flutter/data/repositories/book_repository.dart';

class _Recorder implements HttpClientAdapter {
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode({'status': true, 'entries': <dynamic>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NoTokens extends TokenStore {
  @override
  Future<String?> readAccess() async => null;
}

GameMatch _match(GameType game) => GameMatch(
      id: 71,
      game: game,
      nationA: 'IND',
      nationB: 'AUS',
      isActive: true,
    );

void main() {
  late _Recorder server;
  late BookRepository books;

  setUp(() {
    server = _Recorder();
    books = BookRepository(
      ApiClient(tokens: _NoTokens(), dio: Dio()..httpClientAdapter = server),
    );
  });

  test('the party book asks for the party\'s own bets only', () async {
    await books.partySoda(match: _match(GameType.oneDay), partyId: 5, ownOnly: true);
    final uri = server.requests.single;
    expect(uri.path, endsWith('/soda/oneday/71/oneday_party_soda/'));
    expect(uri.queryParameters['own_only'], 'true');
  });

  test('other books still bring the partner bets along', () async {
    await books.partySoda(match: _match(GameType.session), partyId: 5);
    final uri = server.requests.single;
    expect(uri.path, endsWith('/soda/session/71/session_party_soda/'));
    expect(uri.queryParameters.containsKey('own_only'), isFalse);
  });

  test('a test match is read through the one day endpoint, as the desk does', () async {
    expect(BookRepository.supportsPartySoda(_match(GameType.test)), isTrue);
    await books.partySoda(match: _match(GameType.test), partyId: 5, ownOnly: true);
    expect(server.requests.single.path, endsWith('/soda/oneday/71/oneday_party_soda/'));
  });
}
