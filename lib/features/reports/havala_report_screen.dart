import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/app_time.dart';
import 'report_form.dart';

/// Every havala raised in a period, printed.
///
/// The desk's HAVALA REPORT. It takes nothing but a date range - the report
/// itself is one fixed layout - so this is the smallest of the six.
class HavalaReportScreen extends ConsumerStatefulWidget {
  const HavalaReportScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<HavalaReportScreen> createState() => _HavalaReportScreenState();
}

class _HavalaReportScreenState extends ConsumerState<HavalaReportScreen> {
  DateTime _from = AppTime.today;
  DateTime _to = AppTime.today;

  void _clear() => setState(() {
        _from = AppTime.today;
        _to = AppTime.today;
      });

  Future<void> _run() => ReportRunner.run(
        context,
        ref,
        path: '/soda/havala/download_havala_report/',
        name: 'Havala report',
        query: {
          'from_date': AppTime.apiDate(_from),
          'to_date': AppTime.apiDate(_to),
        },
      );

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
        ReportSection(
          title: 'REPORT TYPE',
          children: [
            RadioGroup<String>(
              groupValue: 'havala',
              onChanged: (_) {},
              child: const RadioListTile<String>(
                value: 'havala',
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Havala', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Havala report')),
      body: body,
    );
  }
}
