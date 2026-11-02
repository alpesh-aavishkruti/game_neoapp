import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reports/general_report_screen.dart';
import '../reports/havala_report_screen.dart';
import '../reports/ledger_report_screen.dart';
import '../reports/match_report_screen.dart';
import 'general_screen.dart';
import 'havala_screen.dart';
import 'ledger_screen.dart';
import '../auth/menu_access.dart';

/// One tab per entry on the desk's REPORT bar, in the desk's order.
///
/// The first three read the book on screen; the last three build a document to
/// hand over. They are the same six an operator already knows by name, so they
/// are named the same rather than regrouped into something tidier.
///
/// Each tab names the desk menu entry behind it and the right its screen reads
/// with, and shows only when the user's role has both.
const reportTabs = <(String, String, String, Widget)>[
  ('HAVALA REPORT', MenuKey.havalaReport, 'soda.view_havala_report', HavalaReportScreen(embedded: true)),
  ('VIEW GENERAL', MenuKey.viewGeneral, 'master.view_general', GeneralScreen(embedded: true)),
  ('VIEW PARTY', MenuKey.viewParty, 'master.view_party_ledger', LedgerScreen(embedded: true)),
  ('LEDGER REPORT', MenuKey.ledgerReport, 'master.view_ledger_report', LedgerReportScreen(embedded: true)),
  ('GENERAL REPORT', MenuKey.generalReport, 'master.view_general_report', GeneralReportScreen(embedded: true)),
  ('MATCH REPORT', MenuKey.matchReport, 'master.view_match_report', MatchReportScreen(embedded: true)),
  // Not on the desk's report bar - havalas are raised from their own menu -
  // but the list of them has to live somewhere, and this is where money is.
  ('HAVALA', MenuKey.havala, 'soda.view_havala', HavalaScreen(embedded: true)),
];

/// The report tabs this user may open, in order.
List<(String, Widget)> visibleReportTabs(MenuAccess access) => [
      for (final (label, menu, right, screen) in reportTabs)
        if (access.canOpen(menu, right)) (label, screen),
    ];

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = visibleReportTabs(ref.watch(menuAccessProvider));
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Center(child: Text('No reports are open to this account.')),
      );
    }
    // Opens on VIEW GENERAL: the report builders are run occasionally, the
    // book is read all day.
    final general = tabs.indexWhere((t) => t.$1 == 'VIEW GENERAL');
    return DefaultTabController(
      // A change in what may be opened rebuilds the tabs from scratch.
      key: ValueKey(tabs.map((t) => t.$1).join('|')),
      length: tabs.length,
      initialIndex: general < 0 ? 0 : general,
      child: _ReportsTabs(tabs: tabs),
    );
  }
}

class _ReportsTabs extends StatelessWidget {
  const _ReportsTabs({required this.tabs});

  final List<(String, Widget)> tabs;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        toolbarHeight: 46,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              tabs: [for (final (label, _) in tabs) Tab(text: label)],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: controller,
        // Each keeps its own app bar off: the shell above already names the
        // section, and two stacked bars would eat the board.
        children: [for (final (_, screen) in tabs) screen],
      ),
    );
  }
}
