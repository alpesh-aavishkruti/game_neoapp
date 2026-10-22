import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../masters/more_screen.dart';
import '../masters/party_master_screen.dart';
import '../matches/match_list_screen.dart';
import '../money/reports_screen.dart';
import '../auth/menu_access.dart';
import '../../data/models/match.dart';

/// The five places the app is organised around.
///
/// Party master earns a permanent spot because it is opened dozens of times a
/// day to check a code or a balance. Everything set up once and touched rarely
/// sits behind More.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  /// Each tab, with the desk menu entries behind it: a tab shows only when
  /// the user's role may open one of them (none listed: always - More holds
  /// Security, which every account has).
  static final _all = [
    (
      destination: (icon: Icons.sports_cricket_outlined, active: Icons.sports_cricket, label: 'Matches'),
      menu: const <String>[],
      games: true,
      screen: const MatchListScreen(),
    ),
    (
      destination: (icon: Icons.menu_book_outlined, active: Icons.menu_book, label: 'Books'),
      menu: const <String>[],
      games: true,
      screen: const MatchListScreen(openBooks: true),
    ),
    (
      destination: (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Reports'),
      menu: [for (final (_, menu, _) in reportTabs) menu],
      games: false,
      screen: const ReportsScreen(),
    ),
    (
      destination: (icon: Icons.groups_outlined, active: Icons.groups, label: 'Party'),
      menu: const [MenuKey.party],
      games: false,
      screen: const PartyMasterScreen(),
    ),
    (
      destination: (icon: Icons.more_horiz, active: Icons.more_horiz, label: 'More'),
      menu: const <String>[],
      games: false,
      screen: const MoreScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(menuAccessProvider);
    // Matches and Books show when any game's tab would; the rest by menu.
    final anyGame = GameType.values.any(access.canGame);
    final tabs = [
      for (final t in _all)
        if (t.games ? anyGame : access.canAny(t.menu)) t,
    ];
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      // IndexedStack rather than swapping children: an operator flipping to
      // check a party and back should find the board exactly as they left it,
      // scroll position and all.
      body: IndexedStack(
        index: index,
        children: [
          for (final (i, tab) in tabs.indexed)
            // Hidden tabs are kept but marked as not on screen, so each one
            // reads its figures again when it is switched back to.
            TickerMode(
              key: ValueKey(tab.destination.label),
              enabled: i == index,
              child: tab.screen,
            ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: index,
        destinations: [for (final t in tabs) t.destination],
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Material's own NavigationBar marks the active item with a filled pill. The
/// boards use a 2px rule above the icon instead, which is quieter and lines up
/// with how the rest of the app marks state.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.destinations,
    required this.onChanged,
  });

  final int index;
  final List<({IconData icon, IconData active, String label})> destinations;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: book.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BarItem(
                    destination: destinations[i],
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label}) destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? context.scheme.primary : context.book.muted;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 3,
              child: selected
                  ? Center(
                      child: Container(
                        width: 24,
                        height: 2,
                        color: context.scheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 7),
            Icon(selected ? destination.active : destination.icon, size: 21, color: colour),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: colour),
            ),
          ],
        ),
      ),
    );
  }
}
