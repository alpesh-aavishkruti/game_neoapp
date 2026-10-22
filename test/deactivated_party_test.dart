import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_client.dart';
import 'package:game_app_flutter/core/providers.dart';
import 'package:game_app_flutter/core/storage/token_store.dart';
import 'package:game_app_flutter/features/matches/match_providers.dart';

class _Parties implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async =>
      ResponseBody.fromString(
        jsonEncode({
          'count': 3,
          'next': null,
          'data': [
            {'id': 1, 'party_code': 'SKJ', 'party_name': 'S K JAIN', 'is_active': true},
            {'id': 2, 'party_code': 'SKJ2', 'party_name': 'S K JAIN', 'is_active': false},
            {'id': 3, 'party_code': 'LXB', 'party_name': 'LEXUS', 'is_active': true},
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _NoTokens extends TokenStore {
  @override
  Future<String?> readAccess() async => null;
}

void main() {
  test('a deactivated party is in Party Master and in no picker', () async {
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(
        ApiClient(tokens: _NoTokens(), dio: Dio()..httpClientAdapter = _Parties()),
      ),
    ]);
    addTearDown(container.dispose);

    final everyone = await container.read(allPartiesProvider.future);
    final pickable = await container.read(partiesProvider.future);

    expect(everyone.map((p) => p.code), ['LXB', 'SKJ', 'SKJ2']);
    expect(everyone.firstWhere((p) => p.code == 'SKJ2').isActive, isFalse);
    expect(pickable.map((p) => p.code), ['LXB', 'SKJ'], reason: 'pickers leave SKJ2 out');
  });
}
