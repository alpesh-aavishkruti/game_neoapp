import 'package:flutter/material.dart';

import '../reports/general_report_screen.dart';
import '../reports/havala_report_screen.dart';
import '../reports/ledger_report_screen.dart';
import '../reports/match_report_screen.dart';
import 'general_screen.dart';
import 'havala_screen.dart';
import 'ledger_screen.dart';

/// One tab per entry on the desk's REPORT bar, in the desk's order.
///
/// The first three read the book on screen; the last three build a document to
/// hand over. They are the same six an operator already knows by name, so they
/// are named the same rather than regrouped into something tidier.
const _tabs = <(String, Widget)>[
  ('HAVALA REPORT', HavalaReportScreen(embedded: true)),
  ('VIEW GENERAL', GeneralScreen(embedded: true)),
  ('VIEW PARTY', LedgerScreen(embedded: true)),
  ('LEDGER REPORT', LedgerReportScreen(embedded: true)),
  ('GENERAL REPORT', GeneralReportScreen(embedded: true)),
  ('MATCH REPORT', MatchReportScreen(embedded: true)),
  // Not on the desk's report bar - havalas are raised from their own menu -
  // but the list of them has to live somewhere, and this is where money is.
  ('HAVALA', HavalaScreen(embedded: true)),
];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: _tabs.length,
    vsync: this,
    // Opens on VIEW GENERAL: the report builders are run occasionally, the
    // book is read all day.
    initialIndex: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        toolbarHeight: 46,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _controller,
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
              tabs: [for (final (label, _) in _tabs) Tab(text: label)],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        // Each keeps its own app bar off: the shell above already names the
        // section, and two stacked bars would eat the board.
        children: [for (final (_, screen) in _tabs) screen],
      ),
    );
  }
}
