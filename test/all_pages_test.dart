import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_client.dart';
import 'package:game_app_flutter/core/storage/token_store.dart';
import 'package:game_app_flutter/data/repositories/match_repository.dart';

/// Pages [total] rows 100 at a time, the way the Django list endpoints do.
class _PagedServer implements HttpClientAdapter {
  _PagedServer(this.total, {this.paged = true});

  final int total;
  final bool paged;
  final pagesAsked = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.tryParse('${options.queryParameters['page']}') ?? 1;
    final size = int.tryParse('${options.queryParameters['page_size']}') ?? 10;
    pagesAsked.add(page);
    final all = List.generate(
      total,
      (i) => {'id': i + 1, 'party_code': 'P${i + 1}', 'party_name': 'P${i + 1}', 'is_active': true},
    );
    final Map<String, dynamic> body;
    if (paged) {
      final start = (page - 1) * size;
      final slice = all.skip(start).take(size).toList();
      body = {
        'count': total,
        'next': start + size < total ? 'next' : null,
        'data': slice,
      };
    } else {
      body = {'status': true, 'data': all};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
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

ApiClient _client(HttpClientAdapter server) =>
    ApiClient(tokens: _NoTokens(), dio: Dio()..httpClientAdapter = server);

void main() {
  test('every page of a paged list is read', () async {
    final server = _PagedServer(250);
    final rows = await _client(server).getAll('/master/party-categories/');
    expect(rows, hasLength(250));
    expect(server.pagesAsked, [1, 2, 3]);
  });

  test('a list the server does not page is one request', () async {
    final server = _PagedServer(150, paged: false);
    final rows = await _client(server).getAll('/role/');
    expect(rows, hasLength(150));
    expect(server.pagesAsked, [1]);
  });

  test('a company with more than a hundred parties gets them all for client codes', () async {
    final server = _PagedServer(150);
    final parties = await MatchRepository(_client(server)).parties();
    expect(parties, hasLength(150));
  });
}
