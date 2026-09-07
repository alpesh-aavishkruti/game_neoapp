import 'package:flutter/material.dart';

import 'general_screen.dart';
import 'havala_screen.dart';
import 'ledger_screen.dart';

/// The money side of the book, in one place.
///
/// A ledger answers "where does this party stand" and a havala moves money
/// between two of them. They are read together often enough that separating
/// them into two tabs of the bar would only cost taps.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
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
              controller: _tabs,
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
              tabs: const [Tab(text: 'GENERAL'), Tab(text: 'LEDGER'), Tab(text: 'HAVALA')],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          // Each keeps its own app bar off: the shell above already names the
          // section, and two stacked bars would eat the board.
          GeneralScreen(embedded: true),
          LedgerScreen(embedded: true),
          HavalaScreen(embedded: true),
        ],
      ),
    );
  }
}
