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
import 'package:game_app_flutter/data/models/party.dart';
import 'package:game_app_flutter/features/auth/menu_access.dart';
import 'package:game_app_flutter/features/masters/party_edit_sheet.dart';

/// Stands in for the server: one party, RAJ, with a One Day brokerage and a
/// share of another party's Test book. Every write is kept for the test.
class _Server implements HttpClientAdapter {
  _Server({this.active = true});

  final bool active;
  final writes = <(String, String, Map<String, dynamic>)>[];

  Map<String, dynamic> get _raj => {
        'id': 5,
        'party_code': 'RAJ',
        'party_name': 'Rajesh Traders',
        'city': 'Surat',
        'mobile': '',
        'credit_limit': '0.00',
        'rec_int': '0.00',
        'pay_int': '0.00',
        'category': [],
        'ref_member': null,
        'is_bookie': false,
        'is_own': false,
        'show_in_book': true,
        'is_active': active,
      };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? _) async {
    final path = options.path;
    Object reply = {'data': []};

    if (options.method != 'GET') {
      final data = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : Map<String, dynamic>.from(jsonDecode('${options.data}') as Map);
      writes.add((options.method, path, data));
      reply = {'data': {..._raj, ...data, 'id': 5}};
    } else if (path.endsWith('/get_full_party_info_by_code/')) {
      reply = {
        'data': {
          'party': _raj,
          'brokerages': [
            {
              'id': 41,
              'party': {'id': 5, 'party_code': 'RAJ', 'party_name': 'Rajesh Traders'},
              'date': '2026-04-01',
              'game_code': 'ONE_DAY',
              'comm_percent': '2.00',
              'comm_code': null,
              'comm_code_percent': '0.00',
              'partner1': {'id': 7, 'party_code': 'KIR', 'party_name': 'Kiran'},
              'partner1_percent': '20.00',
              'is_active': true,
            },
          ],
          'partnerships': [
            {
              'id': 90,
              'party_code': 'ABC',
              'party_name': 'Abc Co',
              'date': '2026-04-01',
              'game_code': 'TEST',
              'role': 'Partner 2',
              'percent': 10.0,
            },
          ],
        },
      };
    } else if (path == '/master/parties/5/') {
      reply = {'data': _raj};
    }

    return ResponseBody.fromString(jsonEncode(reply), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _NoTokens extends TokenStore {
  @override
  Future<String?> readAccess() async => null;
}

void main() {
  Future<void> open(WidgetTester tester, _Server server, {bool active = true}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(tokens: _NoTokens(), dio: Dio()..httpClientAdapter = server),
        ),
        menuAccessProvider.overrideWithValue(const MenuAccess(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => PartyEditSheet.page(
                context,
                editing: Party(id: 5, code: 'RAJ', name: 'Rajesh Traders', isActive: active),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the party page shows each game and where it is a partner', (tester) async {
    final server = _Server();
    await open(tester, server);

    expect(find.text('COMMISSION & PARTNERSHIP'), findsOneWidget);
    expect(find.textContaining('Comm 2% · P1 KIR 20%'), findsOneWidget);
    expect(find.text('Not set'), findsNWidgets(3), reason: 'Test, Session and Cup have none');
    expect(find.text('PARTNER IN'), findsOneWidget);
    expect(find.text('Partner 2 10%'), findsOneWidget);
  });

  testWidgets('deactivating asks first and is saved as it stands', (tester) async {
    final server = _Server();
    await open(tester, server);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(find.text('Deactivate RAJ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final patch = server.writes.single;
    expect(patch.$1, 'PATCH');
    expect(patch.$2, '/master/parties/5/');
    expect(patch.$3['is_active'], isFalse);
  });

  testWidgets('editing a deactivated party no longer switches it back on', (tester) async {
    final server = _Server(active: false);
    await open(tester, server, active: false);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(server.writes.single.$3['is_active'], isFalse);
  });
}
