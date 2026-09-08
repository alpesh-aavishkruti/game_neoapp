import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/party.dart';
import '../masters/master_providers.dart';
import 'report_form.dart';

/// Which book a line came out of. These codes are the desk's own, and the
/// server matches on them exactly.
const _daybooks = {
  '': 'All daybooks',
  '03001': '03001 JOURNAL VOUCHER',
  '03251': '03251 HAVALA',
  '03501': '03501 ONEDAY CLOSE JV',
  '03511': '03511 SESSION CLOSE JV',
  '03515': '03515 INFLOW CLOSE JV',
  '03525': '03525 CUP CLOSE JV',
  '03535': '03535 TEST CLOSE JV',
};

const _calcTypes = {
  'Monthly': 'Monthly',
  'Daily': 'Daily',
  'Quarterly': 'Quarterly',
  'Half-Yearly': 'Half-yearly',
  'Yearly': 'Yearly',
};

/// Which document the form is asking for.
///
/// Three reports sit behind one button, and the desk picks between them the
/// same way: Interest splits off from Ledger, and inside Interest a Summary is
/// its own endpoint. Getting this wrong prints a plausible-looking report that
/// answers a different question, so it is separated out to be tested.
(String, String) ledgerReportTarget({
  required String reportType,
  required String reportGroup,
}) =>
    switch ((reportType, reportGroup)) {
      ('Interest Report', 'Summary') => (
          '/master/parties/download_interest_summary_report/',
          'Interest summary'
        ),
      ('Interest Report', _) => (
          '/master/parties/download_interest_report/',
          'Interest report'
        ),
      _ => ('/master/parties/download_ledger_report/', 'Ledger report'),
    };

/// Statements and interest, printed.
///
/// The desk's LEDGER REPORT, which is really two reports behind one form: a
/// plain statement, or interest worked out on it. Picking Interest opens the
/// rates and the basis, because they mean nothing to the other one - showing
/// them always would invite someone to set a rate that never gets used.
class LedgerReportScreen extends ConsumerStatefulWidget {
  const LedgerReportScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends ConsumerState<LedgerReportScreen> {
  DateTime _from = AppTime.today.subtract(const Duration(days: 7));
  DateTime _to = AppTime.today;
  DateTime _posting = AppTime.today;

  String _daybookFrom = '';
  String _daybookTo = '';
  String _account = '';

  bool _pageBreak = false;
  String _reportType = 'Ledger';
  String _reportGroup = 'Report';

  final _receivable = TextEditingController(text: '0.00');
  final _payable = TextEditingController(text: '0.00');
  final _daysInYear = TextEditingController(text: '365');
  String _calcType = 'Monthly';

  List<Party> _members = const [];

  bool get _isInterest => _reportType == 'Interest Report';

  @override
  void dispose() {
    _receivable.dispose();
    _payable.dispose();
    _daysInYear.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _from = AppTime.today.subtract(const Duration(days: 7));
        _to = AppTime.today;
        _posting = AppTime.today;
        _daybookFrom = '';
        _daybookTo = '';
        _account = '';
        _pageBreak = false;
        _reportType = 'Ledger';
        _reportGroup = 'Report';
        _receivable.text = '0.00';
        _payable.text = '0.00';
        _daysInYear.text = '365';
        _calcType = 'Monthly';
        _members = const [];
      });

  Future<void> _run() {
    final (path, name) = ledgerReportTarget(
      reportType: _reportType,
      reportGroup: _reportGroup,
    );

    return ReportRunner.run(
      context,
      ref,
      path: path,
      name: name,
      query: {
        'from_date': AppTime.apiDate(_from),
        'to_date': AppTime.apiDate(_to),
        'posting_date': AppTime.apiDate(_posting),
        'daybook_code_from': _daybookFrom,
        'daybook_code_to': _daybookTo,
        'account': _account,
        'members': _members.map((p) => p.id).join(','),
        'clientwise_page_break': _pageBreak,
        'record_type': 'Client Ledger',
        'report_type': _reportType,
        'report_group': _reportGroup,
        'receivable_int': _receivable.text.trim(),
        'payable_int': _payable.text.trim(),
        'calc_type': _calcType,
        'days_in_year': _daysInYear.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(masterRowsProvider('/master/accounts/'));

    final body = ReportForm(
      onRun: _run,
      onClear: _clear,
      children: [
        ReportSection(
          title: 'PERIOD',
          children: [
            ReportDate(
              label: 'From date',
              value: _from,
              onChanged: (d) => setState(() => _from = d),
            ),
            ReportDate(
              label: 'To date',
              value: _to,
              onChanged: (d) => setState(() => _to = d),
            ),
            ReportDate(
              label: 'Posting date',
              value: _posting,
              onChanged: (d) => setState(() => _posting = d),
            ),
          ],
        ),
        ReportSection(
          title: 'WHAT TO INCLUDE',
          children: [
            ReportChoice(
              label: 'Daybook from',
              value: _daybookFrom,
              options: _daybooks,
              onChanged: (v) => setState(() => _daybookFrom = v),
            ),
            ReportChoice(
              label: 'Daybook to',
              value: _daybookTo,
              options: _daybooks,
              onChanged: (v) => setState(() => _daybookTo = v),
            ),
            ReportChoice(
              label: 'Account',
              value: _account,
              options: {
                '': 'All accounts',
                for (final row in accounts.value ?? const <Map<String, dynamic>>[])
                  (row['account_code'] ?? '').toString():
                      '${row['account_code']} ${row['account_name']}',
              },
              onChanged: (v) => setState(() => _account = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _pageBreak,
              onChanged: (v) => setState(() => _pageBreak = v),
              title: const Text(
                'A new page per client',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        ReportSection(
          title: 'REPORT TYPE',
          children: [
            RadioGroup<String>(
              groupValue: _reportType,
              onChanged: (v) => setState(() => _reportType = v ?? 'Ledger'),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'Ledger',
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Ledger', style: TextStyle(fontSize: 13)),
                  ),
                  RadioListTile<String>(
                    value: 'Interest Report',
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Interest report', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_isInterest)
          ReportSection(
            title: 'INTEREST',
            children: [
              RadioGroup<String>(
                groupValue: _reportGroup,
                onChanged: (v) => setState(() => _reportGroup = v ?? 'Report'),
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      value: 'Report',
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Report', style: TextStyle(fontSize: 13)),
                    ),
                    RadioListTile<String>(
                      value: 'Summary',
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Summary', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _Rate(label: 'Receivable %', controller: _receivable),
              _Rate(label: 'Payable %', controller: _payable),
              _Rate(label: 'Days in year', controller: _daysInYear, decimal: false),
              ReportChoice(
                label: 'Calculate',
                value: _calcType,
                options: _calcTypes,
                onChanged: (v) => setState(() => _calcType = v),
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
      appBar: AppBar(title: const Text('Ledger report')),
      body: body,
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.label, required this.controller, this.decimal = true});

  final String label;
  final TextEditingController controller;
  final bool decimal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text(label, style: context.text.labelSmall)),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
