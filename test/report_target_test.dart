import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/features/reports/ledger_report_screen.dart';

/// The ledger report form builds one of three documents, and nothing on the
/// finished PDF says which endpoint produced it - a summary and a full
/// interest report both look like interest. These pin the routing.
void main() {
  group('which report the ledger form asks for', () {
    test('plain ledger', () {
      final (path, name) = ledgerReportTarget(
        reportType: 'Ledger',
        reportGroup: 'Report',
      );
      expect(path, '/master/parties/download_ledger_report/');
      expect(name, 'Ledger report');
    });

    test('a ledger ignores the interest grouping left behind it', () {
      // The group is only shown under Interest, but it keeps whatever it was
      // last set to - it must not drag a plain ledger to another endpoint.
      final (path, _) = ledgerReportTarget(
        reportType: 'Ledger',
        reportGroup: 'Summary',
      );
      expect(path, '/master/parties/download_ledger_report/');
    });

    test('interest, in full', () {
      final (path, name) = ledgerReportTarget(
        reportType: 'Interest Report',
        reportGroup: 'Report',
      );
      expect(path, '/master/parties/download_interest_report/');
      expect(name, 'Interest report');
    });

    test('interest, summarised', () {
      final (path, name) = ledgerReportTarget(
        reportType: 'Interest Report',
        reportGroup: 'Summary',
      );
      expect(path, '/master/parties/download_interest_summary_report/');
      expect(name, 'Interest summary');
    });
  });
}
