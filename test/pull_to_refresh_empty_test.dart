import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_exception.dart';
import 'package:game_app_flutter/core/theme/app_theme.dart';
import 'package:game_app_flutter/shared/widgets/async_view.dart';

Widget _page(AsyncValue<List<int>> value, Future<void> Function() onRefresh) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: AsyncView<List<int>>(
            value: value,
            onRetry: () {},
            isEmpty: (l) => l.isEmpty,
            emptyTitle: 'No open one day matches',
            builder: (l) => ListView(children: [for (final i in l) Text('$i')]),
          ),
        ),
      ),
    );

void main() {
  testWidgets('an empty list can be pulled down to refresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(_page(const AsyncData(<int>[]), () async => refreshed++));
    expect(find.text('No open one day matches'), findsOneWidget);

    await tester.fling(find.text('No open one day matches'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  testWidgets('a failed load can be pulled down to refresh too', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(_page(
      AsyncError<List<int>>(ApiException('Network down'), StackTrace.empty),
      () async => refreshed++,
    ));
    await tester.fling(find.text('Network down'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });
}
