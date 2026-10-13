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
import 'package:game_app_flutter/features/masters/edit_history_screen.dart';
import 'package:game_app_flutter/features/masters/more_screen.dart';

/// Answers each list with rows shaped as the backend sends them.
class _Server implements HttpClientAdapter {
  _Server(this.rowsByPath);

  final Map<String, List<Map<String, dynamic>>> rowsByPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceFirst('/api/v1', '');
    return ResponseBody.fromString(
      jsonEncode({'status': true, 'data': rowsByPath[path] ?? <dynamic>[]}),
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

Future<void> _pump(WidgetTester tester, Widget home, Map<String, List<Map<String, dynamic>>> rows) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  final dio = Dio()..httpClientAdapter = _Server(rows);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWith((ref) => ApiClient(tokens: _NoTokens(), dio: dio)),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final editLog = {
    'id': 1,
    'voucher_type': 'HAVALA',
    'voucher_type_label': 'Havala',
    'voucher_no': 'HAVALA0104',
    'voucher_date': '25-09-2026',
    'edited_by': 'MAH',
    'edited_at': '03-10-2026 18:29',
    'party': 'OLD - OLD SOFTWARE',
    'other_party': 'MB - MAMA BHAG',
    'description': 'H11 OLD 750',
    'changes': [
      {'field': 'Amount', 'old': '-38969528', 'new': '-39037893'},
    ],
  };

  testWidgets('an edit says whose figure it was and what it was for', (tester) async {
    await _pump(tester, const EditHistoryScreen(), {
      '/soda/edit-logs/': [editLog],
    });

    expect(find.text('OLD - OLD SOFTWARE  ↔  MB - MAMA BHAG'), findsOneWidget);
    expect(find.text('H11 OLD 750'), findsOneWidget);
    expect(find.text('-39037893'), findsOneWidget);
  });

  testWidgets('the edit can be found by the other party', (tester) async {
    await _pump(tester, const EditHistoryScreen(), {
      '/soda/edit-logs/': [editLog],
    });

    await tester.enterText(find.byType(TextField).first, 'mama bhag');
    await tester.pumpAndSettle();
    expect(find.text('HAVALA0104'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('HAVALA0104'), findsNothing);
  });

  testWidgets('match master leads each match with its number, as View Party does', (tester) async {
    await _pump(tester, const MoreScreen(), {
      '/master/matches/': [
        {'id': 231, 'game': 'SESSION', 'nation_a': 'Pakistan', 'nation_b': '20 Over', 'is_active': false},
      ],
    });
    await tester.tap(find.text('Match master'));
    await tester.pumpAndSettle();

    expect(find.text('231 - PAKISTAN VS 20 OVER'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '231');
    await tester.pumpAndSettle();
    expect(find.text('231 - PAKISTAN VS 20 OVER'), findsOneWidget);
  });
}
