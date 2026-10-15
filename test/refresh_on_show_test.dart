import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/shared/widgets/refresh_on_show.dart';

void main() {
  late int reads;
  late FutureProvider<int> counter;

  setUp(() {
    reads = 0;
    counter = FutureProvider<int>((ref) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return ++reads;
    });
  });

  Widget screen() => Consumer(
        builder: (context, ref, _) => RefreshOnShow(
          providers: [counter],
          child: Scaffold(
            body: ref.watch(counter).when(
                  data: (n) => Text('read $n'),
                  loading: () => const Text('loading'),
                  error: (_, _) => const Text('error'),
                ),
          ),
        ),
      );

  testWidgets('a screen is read once on first open, again on coming back', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(navigatorKey: nav, home: screen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('read 1'), findsOneWidget, reason: 'the first open is not read twice');

    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('top'))));
    await tester.pumpAndSettle();
    expect(reads, 1, reason: 'nothing is read while another screen is in front');

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('read 1'), findsOneWidget, reason: 'the old figures stay while the new load');
    await tester.pumpAndSettle();
    expect(find.text('read 2'), findsOneWidget);
  });

  testWidgets('a screen opened again shows fresh figures, not the first visit', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('home'))),
    ));

    nav.currentState!.push(MaterialPageRoute(builder: (_) => screen()));
    await tester.pumpAndSettle();
    expect(find.text('read 1'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();

    nav.currentState!.push(MaterialPageRoute(builder: (_) => screen()));
    await tester.pumpAndSettle();
    expect(find.text('read 2'), findsOneWidget);
  });

  testWidgets('switching back to a tab reads it again', (tester) async {
    var tab = 0;
    late StateSetter setTab;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: StatefulBuilder(builder: (context, setState) {
          setTab = setState;
          return IndexedStack(index: tab, children: [
            // As the app's tab bar does.
            TickerMode(enabled: tab == 0, child: screen()),
            TickerMode(enabled: tab == 1, child: const Text('other')),
          ]);
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(reads, 1);

    setTab(() => tab = 1);
    await tester.pumpAndSettle();
    expect(reads, 1, reason: 'a hidden tab is left alone');

    setTab(() => tab = 0);
    await tester.pumpAndSettle();
    expect(reads, 2);
  });
}
