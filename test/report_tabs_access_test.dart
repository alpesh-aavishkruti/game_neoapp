import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/features/auth/menu_access.dart';
import 'package:game_app_flutter/features/money/reports_screen.dart';

void main() {
  test('a report tab shows only with its menu entry and its right', () {
    const access = MenuAccess(
      {'game.Report.ViewGeneral', 'game.Report.ViewParty', 'game.Report.MatchReport'},
      {'master.view_general', 'master.view_match_report'},
    );
    expect(
      visibleReportTabs(access).map((t) => t.$1),
      ['VIEW GENERAL', 'MATCH REPORT'],
      reason: 'VIEW PARTY has its menu entry but not master.view_party_ledger',
    );
  });

  test('with no report open, the Reports tab has nothing to show', () {
    expect(visibleReportTabs(const MenuAccess({'game.Soda.OneDay'}, {})), isEmpty);
  });

  test('when access could not be read, every report shows, as before', () {
    expect(visibleReportTabs(const MenuAccess(null)).length, reportTabs.length);
  });
}
