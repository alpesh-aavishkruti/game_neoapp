import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_client.dart';
import 'package:game_app_flutter/core/providers.dart';
import 'package:game_app_flutter/core/storage/token_store.dart';
import 'package:game_app_flutter/data/repositories/auth_repository.dart';
import 'package:game_app_flutter/features/auth/auth_controller.dart';
import 'package:game_app_flutter/data/models/match.dart';
import 'package:game_app_flutter/features/auth/menu_access.dart';

/// Answers /side-bar as the server does: the root, its features, their entries.
class _Sidebar implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async =>
      ResponseBody.fromString(
        jsonEncode({
          'status': true,
          'data': [
            {
              'key': 'game',
              'subMenu': [
                {
                  'key': 'game.Soda',
                  'subMenu': [
                    {'key': 'game.Soda.OneDay', 'subMenu': []},
                  ],
                },
                {
                  'key': 'game.Report',
                  'subMenu': [
                    {'key': 'game.Report.ViewParty', 'subMenu': []},
                  ],
                },
              ],
            },
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

/// A saved login that cannot be read - the restored-phone case.
class _BrokenStore extends TokenStore {
  @override
  Future<String?> readAccess() async => throw Exception('BadPaddingException');
  @override
  Future<String?> readRefresh() async => throw Exception('BadPaddingException');
  @override
  Future<void> clear() async {}
}

ApiClient _client(HttpClientAdapter server, TokenStore tokens) =>
    ApiClient(tokens: tokens, dio: Dio()..httpClientAdapter = server);

void main() {
  test('the menu keys are read from the sidebar, every level of it', () async {
    final tokens = _NoTokens();
    final keys = await AuthRepository(api: _client(_Sidebar(), tokens), tokens: tokens).menuKeys();
    expect(keys, containsAll(['game.Soda.OneDay', 'game.Report.ViewParty']));
    expect(keys.contains('game.Soda.Session'), isFalse);
  });

  test('a screen shows only when its menu entry is open to the user', () {
    const access = MenuAccess({'game.Soda.OneDay', 'game.Report.ViewParty'});
    expect(access.can(MenuKey.oneDay), isTrue);
    expect(access.can(MenuKey.session), isFalse);
    expect(access.canAny([MenuKey.viewGeneral, MenuKey.viewParty]), isTrue);
    expect(access.canAny([MenuKey.users]), isFalse);
    expect(access.canAny(const []), isTrue, reason: 'nothing listed: always shown');
  });

  test('when the menu could not be read, nothing is hidden', () {
    const access = MenuAccess(null);
    expect(access.can(MenuKey.users), isTrue);
  });

  test('an unreadable saved login opens the sign-in form instead of spinning', () async {
    final tokens = _BrokenStore();
    expect(
      await AuthRepository(api: _client(_Sidebar(), tokens), tokens: tokens).restore(),
      isNull,
    );

    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(_client(_Sidebar(), tokens)),
    ]);
    addTearDown(container.dispose);
    expect(container.read(authControllerProvider), isA<AuthUnknown>());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(authControllerProvider), isA<SignedOut>());
  });

  test("a game's tab needs the match list's right too, not only its menu entry", () {
    // Match Master's read grants "view one day entry", so the menu entry shows,
    // but without "view active matches" the list cannot be read.
    const matchMasterOnly = MenuAccess(
      {'game.Soda.OneDay', 'game.Soda.Session'},
      {'master.view_matchmaster', 'soda.view_onedayentry', 'soda.view_sessionentry'},
    );
    expect(matchMasterOnly.canGame(GameType.oneDay), isFalse);
    expect(matchMasterOnly.canGame(GameType.session), isFalse);

    const sessionDesk = MenuAccess(
      {'game.Soda.OneDay', 'game.Soda.Session'},
      {'master.view_matchmaster_active', 'soda.view_sessionentry'},
    );
    expect(sessionDesk.canGame(GameType.session), isTrue);
    expect(sessionDesk.canGame(GameType.oneDay), isFalse, reason: 'no one day entry right');

    const unknown = MenuAccess(null);
    expect(unknown.canGame(GameType.oneDay), isTrue, reason: 'rights not known: hide nothing');
  });
}
