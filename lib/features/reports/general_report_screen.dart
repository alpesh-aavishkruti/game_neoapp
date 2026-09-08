import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/app_time.dart';
import '../../data/models/party.dart';
import 'report_form.dart';

/// Where every client stands on one date, printed.
///
/// The desk's GENERAL REPORT. Same figures as the VIEW GENERAL screen, but as
/// a document that can be handed over - so it takes how names should print and
/// what order they come in, which the screen has no need of.
class GeneralReportScreen extends ConsumerStatefulWidget {
  const GeneralReportScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<GeneralReportScreen> createState() => _GeneralReportScreenState();
}

class _GeneralReportScreenState extends ConsumerState<GeneralReportScreen> {
  DateTime _asOn = AppTime.today;
  String _display = 'Name';
  String _orderBy = 'Default';
  List<Party> _members = const [];

  void _clear() => setState(() {
        _asOn = AppTime.today;
        _display = 'Name';
        _orderBy = 'Default';
        _members = const [];
      });

  Future<void> _run() => ReportRunner.run(
        context,
        ref,
        path: '/master/parties/download_general_report/',
        name: 'General report',
        query: {
          'as_on_date': AppTime.apiDate(_asOn),
          'display_format': _display,
          'order_by': _orderBy,
          'members': _members.map((p) => p.id).join(','),
        },
      );

  @override
  Widget build(BuildContext context) {
    final body = ReportForm(
      onRun: _run,
      onClear: _clear,
      children: [
        ReportSection(
          title: 'REPORT',
          children: [
            ReportDate(
              label: 'Date',
              value: _asOn,
              onChanged: (d) => setState(() => _asOn = d),
            ),
            ReportChoice(
              label: 'Code/name',
              value: _display,
              options: displayFormats,
              onChanged: (v) => setState(() => _display = v),
            ),
            ReportChoice(
              label: 'Order by',
              value: _orderBy,
              options: orderings,
              onChanged: (v) => setState(() => _orderBy = v),
            ),
          ],
        ),
        ReportSection(
          title: 'MEMBERS',
          children: [
            ReportMembers(
              chosen: _members,
              onChanged: (list) => setState(() => _members = list),
            ),
          ],
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('General report')),
      body: body,
    );
  }
}

/// How a party is printed. The server takes these words as they are.
const displayFormats = {'Both': 'Both', 'Name': 'Name', 'Code': 'Code'};

const orderings = {
  'Default': 'Default',
  'Code': 'Code',
  'Name': 'Name',
  'Low To High': 'Low to high',
  'High To Low': 'High to low',
};
