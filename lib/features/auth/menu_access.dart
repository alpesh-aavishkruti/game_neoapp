import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match.dart';
import 'auth_controller.dart';

/// The desk's menu entries, by the key the server's sidebar gives them.
///
/// The server builds the sidebar from the user's role: an entry is in it only
/// when the role may open that screen. The app shows a screen only when its
/// entry is there, so a screen the user has no right to is not shown at all -
/// before, it opened, spun, and then said "You do not have permission".
abstract final class MenuKey {
  static const party = 'game.Master.Party';
  static const partyCategory = 'game.Master.PartyCategory';
  static const matchMaster = 'game.Master.Match';
  static const cupMaster = 'game.Master.Cup';

  static const oneDay = 'game.Soda.OneDay';
  static const session = 'game.Soda.Session';
  static const test = 'game.Soda.Test';
  static const cup = 'game.Soda.Cup';
  static const openingBalance = 'game.Soda.OpeningBalance';
  static const clearingJv = 'game.Soda.ClearingJournal';
  static const inflowClearingJv = 'game.Soda.InflowClearingJV';

  static const havala = 'game.Havala.HavalaEntry';
  static const recall = 'game.Recall.RecallEntry';

  static const havalaReport = 'game.Report.HavalaReport';
  static const viewGeneral = 'game.Report.ViewGeneral';
  static const viewParty = 'game.Report.ViewParty';
  static const ledgerReport = 'game.Report.LedgerReport';
  static const generalReport = 'game.Report.GeneralReport';
  static const matchReport = 'game.Report.MatchReport';
  static const editDeleteHistory = 'game.Report.EditDeleteHistory';
  static const havalaHistory = 'game.Report.HavalaHistory';

  static const users = 'game.Utility.UserMaster';
  static const roles = 'game.Utility.UserPrivileges';
  static const company = 'game.Utility.CompanyMaster';
  static const documentCode = 'game.Utility.DocumentCode';

  static String forGame(GameType game) => switch (game) {
        GameType.oneDay => oneDay,
        GameType.session => session,
        GameType.test => test,
        GameType.cup => cup,
      };

  static const games = [oneDay, test, session, cup];
}

/// What the signed-in user may open.
class MenuAccess {
  const MenuAccess(this._keys, [this._rights]);

  /// Null when the sidebar could not be read (or came back empty): nothing is
  /// hidden then, as before, rather than locking someone out of everything.
  final Set<String>? _keys;

  /// The user's rights by name, as the server checks them; null when unknown.
  final Set<String>? _rights;

  bool can(String key) => _keys == null || _keys.contains(key);

  /// Whether the user holds [right] ("app_label.codename").
  bool has(String right) => _rights == null || _rights.contains(right);

  /// A game's tab needs more than its menu entry. The desk's role template
  /// grants "view one day entry" with Match Master's read as well, so the
  /// menu entry shows for a role that may not list one day matches at all -
  /// the tab opened, spun, and said "You do not have permission". It now also
  /// needs the right the match list asks for, and the game's own.
  bool canGame(GameType game) =>
      can(MenuKey.forGame(game)) &&
      has('master.view_matchmaster_active') &&
      has('soda.view_${switch (game) {
        GameType.oneDay => 'onedayentry',
        GameType.session => 'sessionentry',
        GameType.test => 'testentry',
        GameType.cup => 'cupentry',
      }}');

  /// True when any of [keys] may be opened; an empty list means always.
  bool canAny(Iterable<String> keys) => keys.isEmpty || keys.any(can);
}

final menuAccessProvider = Provider<MenuAccess>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is SignedIn ? MenuAccess(auth.menuKeys, auth.rights) : const MenuAccess(null);
});
