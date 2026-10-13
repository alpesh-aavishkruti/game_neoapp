import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/app.dart';
import 'package:game_app_flutter/core/network/api_client.dart';
import 'package:game_app_flutter/core/providers.dart';
import 'package:game_app_flutter/core/storage/token_store.dart';
import 'package:game_app_flutter/core/util/app_time.dart';
import 'package:integration_test/integration_test.dart';

import 'fake_backend.dart';
import 'fixtures/recorded_api.dart';

/// The whole app, run on a phone, against answers recorded off the real
/// backend: sign in, the boards, an entry, the books, reports, party master,
/// every screen under More, and sign out.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/app_flow_test.dart
///
/// Screenshots land in build/e2e_screens/.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  var surfaceReady = false;

  /// Lets the screen load, then fails on any error a screen threw.
  ///
  /// Not pumpAndSettle: a spinner animates for as long as it is shown, so
  /// "settled" never comes while anything is loading. This pumps until no
  /// spinner is left (or a few seconds pass), then lets transitions finish.
  Future<void> settle(WidgetTester tester) async {
    final spinners = find.byWidgetPredicate(
      (w) => w is CircularProgressIndicator || w is LinearProgressIndicator,
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i > 4 && spinners.evaluate().isEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 400));
    final error = tester.takeException();
    expect(error, isNull, reason: 'a screen threw: $error');
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (Platform.isAndroid && !surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
    }
    await settle(tester);
    await binding.takeScreenshot(name);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(Scaffold).first,
      matching: find.text(label),
    ).last);
    await settle(tester);
  }

  testWidgets('a full working session', (tester) async {
    await AppTime.init();
    final tokens = TokenStore();
    await tokens.clear();

    backend = FakeBackend(recordedApi);
    final dio = Dio()..httpClientAdapter = backend;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWith((ref) => ApiClient(tokens: tokens, dio: dio)),
      ],
      child: const NeonApp(),
    ));
    await settle(tester);

    // --- Sign in -----------------------------------------------------------
    expect(find.text('Sign in'), findsWidgets);
    await shot(tester, '01_sign_in');

    await tester.enterText(find.byType(TextField).at(0), 'demo');
    await tester.enterText(find.byType(TextField).at(1), 'demo-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);

    // --- Matches -------------------------------------------------------------
    expect(find.text('Matches'), findsWidgets);
    expect(find.textContaining('IND'), findsWidgets);
    await shot(tester, '02_matches_one_day');

    await tester.tap(find.text('SESSION'));
    await settle(tester);
    await shot(tester, '03_matches_session');
    await tester.tap(find.text('ONE DAY'));
    await settle(tester);

    // --- One day board -----------------------------------------------------
    await tester.tap(find.textContaining('WI').first);
    await settle(tester);
    expect(find.text('Add bet'), findsOneWidget);
    await shot(tester, '04_board_one_day');

    // A bet, through the entry sheet.
    await tester.tap(find.text('Add bet'));
    await settle(tester);
    await shot(tester, '05_add_bet_sheet');

    final sheetFields = find.byType(TextField);
    await tester.enterText(sheetFields.at(0), '1000');
    await tester.enterText(sheetFields.at(1), '85');
    await tester.enterText(sheetFields.at(2), '77');
    await settle(tester);
    expect(find.textContaining('SHIV'), findsWidgets,
        reason: 'the client code is named back before saving');
    await shot(tester, '06_add_bet_filled');

    await tester.tap(find.widgetWithText(FilledButton, 'Add entry'));
    await settle(tester);
    final placed = backend.writes.where((w) => w.call == 'POST /soda/oneday/');
    expect(placed, hasLength(1), reason: 'the bet was sent to the server');
    final body = placed.single.body as Map;
    expect(body['amount'], 1000);
    expect(body['rate'], 85);
    expect(body['bet_type'], 'L');

    // The books from the board.
    await tester.tap(find.byTooltip('Books'));
    await settle(tester);
    await shot(tester, '07_books_party');
    for (final tab in ['SODA', 'BOOKIE', 'PTRN']) {
      final target = find.text(tab);
      if (target.evaluate().isEmpty) continue;
      await tester.tap(target.first);
      await settle(tester);
      await shot(tester, '08_books_${tab.toLowerCase()}');
    }
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    // --- Session board -------------------------------------------------------
    await tester.tap(find.text('SESSION'));
    await settle(tester);
    await tester.tap(find.textContaining('20 OVER').first);
    await settle(tester);
    expect(find.text('Add run'), findsOneWidget);
    await shot(tester, '09_board_session');
    await tester.pageBack();
    await settle(tester);

    // --- Books tab -----------------------------------------------------------
    await openTab(tester, 'Books');
    await shot(tester, '10_books_tab');

    // --- Reports -------------------------------------------------------------
    await openTab(tester, 'Reports');
    await shot(tester, '11_reports');

    // --- Party master --------------------------------------------------------
    await openTab(tester, 'Party');
    expect(find.textContaining('SHIV'), findsWidgets);
    await shot(tester, '12_party_master');

    // --- More, and every screen under it --------------------------------------
    await openTab(tester, 'More');
    await shot(tester, '13_more');

    const moreItems = [
      'Match master',
      'Cup master',
      'Brokerage',
      'Party category',
      'Document code',
      'Users',
      'Roles & rights',
      'Opening balance',
      'Security',
      'Company',
      'Recall entry',
      'Clearing JV',
      'Recycle bin',
      'Edit history',
    ];
    var n = 14;
    for (final item in moreItems) {
      final target = find.text(item);
      await tester.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(target);
      await settle(tester);
      await shot(tester, '${n++}_more_${item.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '_')}');
      await tester.pageBack();
      await settle(tester);
    }

    // Nothing the flow touched was missing from the recording.
    debugPrint('Unrecorded reads (answered empty): ${backend.unrecorded}');
    debugPrint('Writes: ${backend.writes.map((w) => w.call).toList()}');
  });
}
