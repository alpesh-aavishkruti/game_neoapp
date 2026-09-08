import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/util/app_time.dart';
import '../../data/models/match.dart';
import '../auth/auth_controller.dart';
import 'clearing_jv_screen.dart';
import 'edit_history_screen.dart';
import 'master_list_screen.dart';
import 'brokerage_edit_sheet.dart';
import 'change_password_sheet.dart';
import 'company_screen.dart';
import 'security_screen.dart';

import 'master_providers.dart';
import 'simple_master_sheet.dart';
import 'role_edit_sheet.dart';
import 'role_permissions_screen.dart';
import 'user_edit_sheet.dart';
import 'recall_screen.dart';
import 'recycle_bin_screen.dart';
import '../money/opening_balance_screen.dart';

/// Everything set up once and used rarely.
///
/// The masters that get opened all day live in the bottom bar; these do not,
/// so they sit one tap further away rather than crowding it.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// Each tile names where it goes. The masters are read-only here: the app is
  /// for running the book, and setting one up is still done at the desk.
  static List<({IconData icon, String title, String subtitle, Widget Function() open})>
      get _items => [
    (
      icon: Icons.storefront_outlined,
      title: 'Match master',
      subtitle: 'Teams, dates, PTRN setting',
      open: () => MasterListScreen(
        title: 'Match master',
        subtitle: 'Every match on the book',
        path: '/master/matches/',
        addLabel: 'New match',
        onAdd: (context) => SimpleMasterSheet.show(
          context,
          title: 'Match',
          path: '/master/matches/',
          fields: _matchFields,
        ),
        onEdit: (context, row) => SimpleMasterSheet.show(
          context,
          title: 'Match',
          path: '/master/matches/',
          fields: _matchFields,
          editing: row,
        ),
        rowOf: (row) => MasterRowSpec(
          title: [row['nation_a'], row['nation_b']]
              .where((e) => (e ?? '').toString().trim().isNotEmpty)
              .join(' vs ')
              .toUpperCase(),
          subtitle: [
            // The stored code reads ONE_DAY; the desk calls it One Day.
            GameType.parse(row['game']).label,
            if ((row['win_nation'] ?? '').toString().trim().isNotEmpty)
              'won by ${row['win_nation']}',
          ].join(' · '),
          trailing: row['is_active'] == true ? 'Open' : 'Settled',
          tone: row['is_active'] == true ? ChipTone.open : ChipTone.muted,
        ),
      ),
    ),
    (
      icon: Icons.emoji_events_outlined,
      title: 'Cup master',
      subtitle: 'Cup teams and results',
      open: () => MasterListScreen(
        title: 'Cup master',
        path: '/master/cups/',
        addLabel: 'New cup',
        onAdd: (context) => SimpleMasterSheet.show(
          context,
          title: 'Cup',
          path: '/master/cups/',
          fields: _cupFields,
          derive: _countCupTeams,
        ),
        onEdit: (context, row) => SimpleMasterSheet.show(
          context,
          title: 'Cup',
          path: '/master/cups/',
          fields: _cupFields,
          editing: row,
          derive: _countCupTeams,
        ),
        rowOf: (row) => MasterRowSpec(
          title: (row['cup_name'] ?? row['nation_a'] ?? 'Cup').toString(),
          subtitle: 'Cup',
          trailing: row['is_active'] == true ? 'Open' : 'Settled',
          tone: row['is_active'] == true ? ChipTone.open : ChipTone.muted,
        ),
      ),
    ),
    (
      icon: Icons.percent,
      title: 'Brokerage',
      subtitle: 'Per party, per category',
      open: () => MasterListScreen(
        title: 'Brokerage',
        subtitle: 'Commission and partner splits',
        path: '/master/brokerages/',
        addLabel: 'Add brokerage',
        onAdd: (context) => BrokerageEditSheet.show(context),
        onEdit: (context, row) => BrokerageEditSheet.show(context, editing: row),
        rowOf: (row) => MasterRowSpec(
          title: (row['game_code'] ?? 'Brokerage').toString(),
          subtitle: 'Comm ${row['comm_percent'] ?? 0}% · code ${row['comm_code_percent'] ?? 0}%',
          trailing: (row['date'] ?? '').toString(),
        ),
      ),
    ),
    (
      icon: Icons.sell_outlined,
      title: 'Party category',
      subtitle: 'A / B / C grouping',
      open: () => MasterListScreen(
        title: 'Party category',
        path: '/master/party-categories/',
        addLabel: 'Add category',
        onAdd: (context) => SimpleMasterSheet.show(
          context,
          title: 'Category',
          path: '/master/party-categories/',
          fields: _categoryFields,
        ),
        onEdit: (context, row) => SimpleMasterSheet.show(
          context,
          title: 'Category',
          path: '/master/party-categories/',
          fields: _categoryFields,
          editing: row,
        ),
        onDelete: (row) => (row['category_name'] ?? 'this category').toString(),
        rowOf: (row) {
          // A row that carries no flag predates it and is active, the same way
          // the form reads it.
          final active = row['is_active'] != false;
          return MasterRowSpec(
            title: (row['category_name'] ?? '—').toString(),
            trailing: active ? 'Active' : 'Inactive',
            tone: active ? ChipTone.up : ChipTone.muted,
          );
        },
      ),
    ),
    (
      icon: Icons.receipt_long_outlined,
      title: 'Document code',
      subtitle: 'Voucher numbering',
      open: () => MasterListScreen(
        title: 'Document code',
        subtitle: 'How voucher numbers are built',
        path: '/master/document-formats/',
        addLabel: 'Add format',
        onAdd: (context) => SimpleMasterSheet.show(
          context,
          title: 'Document format',
          path: '/master/document-formats/',
          fields: _documentFields,
        ),
        onEdit: (context, row) => SimpleMasterSheet.show(
          context,
          title: 'Document format',
          path: '/master/document-formats/',
          fields: _documentFields,
          editing: row,
        ),
        rowOf: (row) => MasterRowSpec(
          title: (row['document_type'] ?? '—').toString().replaceAll('_', ' '),
          subtitle: [
            if ((row['prefix'] ?? '').toString().isNotEmpty) 'Prefix ${row['prefix']}',
            'Padding ${row['number_padding_length'] ?? '-'}',
          ].join(' · '),
          trailing: 'No ${row['current_sequence'] ?? 0}',
        ),
      ),
    ),
    (
      icon: Icons.people_outline,
      title: 'Users',
      subtitle: 'Who can sign in',
      // Whether this opens depends on the account's own rights; the screen
      // reports that plainly rather than the tile pretending it cannot exist.
      open: () => MasterListScreen(
        title: 'Users',
        subtitle: 'Accounts on this organisation',
        // The desk reads these off the employee record, not the raw user
        // table - which an operator account is not allowed to list at all.
        path: employeePath,
        addLabel: 'Add user',
        onAdd: (context) => UserEditSheet.show(context),
        onEdit: (context, row) => UserEditSheet.show(context, editing: row),
        onDelete: (row) {
          final user = row['user'] is Map ? row['user'] as Map : const {};
          return (user['username'] ?? 'this account').toString();
        },
        rowOf: (row) {
          final user = row['user'] is Map ? row['user'] as Map : const {};
          final role = row['role'] is Map ? row['role'] as Map : const {};
          final name = [user['first_name'], user['last_name']]
              .where((e) => (e ?? '').toString().trim().isNotEmpty)
              .join(' ');
          final username = (user['username'] ?? '').toString();

          final roleName = (role['name'] ?? '').toString();
          final minutes = row['auto_logout_minutes'];

          return MasterRowSpec(
            title: name.isEmpty ? (username.isEmpty ? '—' : username) : name,
            subtitle: [
              if ((row['user_code'] ?? '').toString().trim().isNotEmpty)
                row['user_code'].toString(),
              if (name.isNotEmpty && username.isNotEmpty) username,
              if ((row['phone'] ?? '').toString().trim().isNotEmpty)
                row['phone'].toString(),
              if (minutes != null) 'Logs out after $minutes min',
              if (user['is_2fa_enabled'] == true) '2FA on',
            ].join(' · '),
            trailing: roleName.isEmpty ? null : roleName,
            tone: roleName.isEmpty ? null : ChipTone.open,
          );
        },
      ),
    ),
    (
      icon: Icons.admin_panel_settings_outlined,
      title: 'Roles & rights',
      subtitle: 'What each role may open',
      open: () => MasterListScreen(
        title: 'Roles',
        subtitle: 'What each role may open',
        path: rolePath,
        addLabel: 'Add role',
        onAdd: (context) => RoleEditSheet.show(context),
        onEdit: (context, row) => RoleEditSheet.show(context, editing: row),
        onDelete: (row) => (row['name'] ?? 'this role').toString(),
        // Naming a role and deciding what it opens are separate jobs, so the
        // key opens its own screen rather than crowding the rename sheet.
        trailingAction: (context, row) => (
          icon: Icons.key_outlined,
          tooltip: 'Permissions',
          onTap: () => RolePermissionsScreen.open(context, role: row),
        ),
        rowOf: (row) => MasterRowSpec(
          title: (row['name'] ?? '—').toString(),
          subtitle: (row['description'] ?? '').toString(),
        ),
      ),
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      title: 'Opening balance',
      subtitle: 'Carried forward figures',
      open: () => const OpeningBalanceScreen(),
    ),
    (
      icon: Icons.security_outlined,
      title: 'Security',
      subtitle: 'Two-factor verification',
      open: () => const SecurityScreen(),
    ),
    (
      icon: Icons.domain_outlined,
      title: 'Company',
      subtitle: 'Name and address on reports',
      open: () => const CompanyScreen(),
    ),
    (
      icon: Icons.history,
      title: 'Recall entry',
      subtitle: 'Reopen a closed match',
      open: () => const RecallScreen(),
    ),
    (
      icon: Icons.account_balance_outlined,
      title: 'Clearing JV',
      subtitle: 'Journal vouchers',
      open: () => const ClearingJvScreen(),
    ),
    (
      icon: Icons.restore_from_trash_outlined,
      title: 'Recycle bin',
      subtitle: 'Deleted entries',
      open: () => const RecycleBinScreen(),
    ),
    (
      icon: Icons.manage_history,
      title: 'Edit history',
      subtitle: 'Who changed what',
      open: () => const EditHistoryScreen(),
    ),
  ];

  /// A settled match keeps its sides; what is worth correcting from a phone
  /// is a name that was typed wrong, and whether commission and PTRN apply.
  /// The desk's match form asks for the game and the sides, and nothing else.
  /// Commission and PTRN are not set here - they live above the board, where
  /// they decide how the next entry is written.
  static const _matchFields = [
    ChoiceMasterField(
      key: 'game',
      label: 'Game',
      required: true,
      options: {
        'ONE_DAY': 'One Day',
        'TEST': 'Test',
        'SESSION': 'Session',
      },
    ),
    TextMasterField(key: 'nation_a', label: 'First side', required: true, uppercase: true),
    TextMasterField(key: 'nation_b', label: 'Second side', required: true, uppercase: true),
    TextMasterField(key: 'nation_c', label: 'Third outcome', hint: 'DRAW', uppercase: true),
  ];

  /// True while the cup is at least [count] teams big.
  static bool Function(Map<String, String?>) _upTo(int count) =>
      (choices) => (int.tryParse(choices['total_nations'] ?? '') ?? 2) >= count;

  /// How many teams the cup runs, then that many team boxes.
  ///
  /// The count is asked for rather than counted, because the server settles on
  /// it - it is what decides when the last team is standing - and the desk
  /// asks for it the same way. Boxes past the count are hidden and sent empty,
  /// so the teams can never disagree with the number above them.
  ///
  /// Commission is not set here; it lives above the board with the other
  /// switches, where it decides how the next entry is written.
  static final _cupFields = <MasterField>[
    const TextMasterField(
        key: 'cup_name', label: 'Cup name', required: true, uppercase: true),
    ChoiceMasterField(
      key: 'total_nations',
      label: 'Number of nations',
      required: true,
      options: {for (var i = 2; i <= 10; i++) '$i': '$i'},
    ),
    TextMasterField(
      key: 'nation_a',
      label: 'Team 1',
      required: true,
      uppercase: true,
      showIf: _upTo(1),
    ),
    TextMasterField(
      key: 'nation_b',
      label: 'Team 2',
      required: true,
      uppercase: true,
      showIf: _upTo(2),
    ),
    TextMasterField(
      key: 'nation_c',
      label: 'Team 3',
      required: true,
      uppercase: true,
      showIf: _upTo(3),
    ),
    TextMasterField(
      key: 'nation_d',
      label: 'Team 4',
      required: true,
      uppercase: true,
      showIf: _upTo(4),
    ),
    TextMasterField(
      key: 'nation_e',
      label: 'Team 5',
      required: true,
      uppercase: true,
      showIf: _upTo(5),
    ),
    TextMasterField(
      key: 'nation_f',
      label: 'Team 6',
      required: true,
      uppercase: true,
      showIf: _upTo(6),
    ),
    TextMasterField(
      key: 'nation_g',
      label: 'Team 7',
      required: true,
      uppercase: true,
      showIf: _upTo(7),
    ),
    TextMasterField(
      key: 'nation_h',
      label: 'Team 8',
      required: true,
      uppercase: true,
      showIf: _upTo(8),
    ),
    TextMasterField(
      key: 'nation_i',
      label: 'Team 9',
      required: true,
      uppercase: true,
      showIf: _upTo(9),
    ),
    TextMasterField(
      key: 'nation_j',
      label: 'Team 10',
      required: true,
      uppercase: true,
      showIf: _upTo(10),
    ),
  ];

  /// The dropdown hands back its value as text; the server stores a number,
  /// and its own default of two would finish a bigger cup after one result.
  static void _countCupTeams(Map<String, dynamic> payload) {
    payload['total_nations'] =
        int.tryParse('${payload['total_nations'] ?? ''}') ?? 2;
  }

  static const _categoryFields = [
    TextMasterField(
      key: 'category_name',
      label: 'Category name',
      hint: 'A',
      required: true,
      uppercase: true,
    ),
    SwitchMasterField(key: 'is_active', label: 'Active', initial: true),
  ];

  /// The voucher series the backend knows how to number.
  static const _documentFields = [
    ChoiceMasterField(
      key: 'document_type',
      label: 'Document type',
      required: true,
      options: {
        'havala': 'Havala',
        'opening_balance_journal_voucher': 'Opening balance JV',
        'clearing_jv_oneday': 'Clearing JV — One Day',
        'clearing_jv_session': 'Clearing JV — Session',
        'clearing_jv_test': 'Clearing JV — Test',
        'clearing_jv_cup': 'Clearing JV — Cup',
        'clearing_jv_inflow': 'Clearing JV — Inflow',
      },
    ),
    TextMasterField(key: 'series_name', label: 'Series name', required: true),
    TextMasterField(key: 'prefix', label: 'Prefix', hint: 'HV', required: true, uppercase: true),
    TextMasterField(key: 'suffix', label: 'Suffix', hint: 'Optional', uppercase: true),
    NumberMasterField(key: 'number_padding_length', label: 'Number padding', hint: '4'),
    SwitchMasterField(key: 'reset_sequence_monthly', label: 'Reset every month'),
    SwitchMasterField(key: 'reset_sequence_financial_yearly', label: 'Reset every financial year'),
    SwitchMasterField(key: 'is_active', label: 'Active', initial: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final session = auth is SignedIn ? auth.session : null;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
        children: [
          _AccountCard(
            name: session?.displayName ?? 'User',
            organisation: ref.watch(organisationNameProvider).value ?? '',
            isOrgAdmin: session?.isOrgAdmin ?? false,
            onSignOut: () => _confirmSignOut(context, ref),
            onChangePassword: () async {
              final changed = await ChangePasswordSheet.show(context);
              if (changed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed.')),
                );
              }
            },
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 1.55,
            children: [
              for (final item in _items)
                _MoreTile(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.subtitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => item.open()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Times shown in ${AppTime.ianaName}',
              style: context.text.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your user ID and password to get back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.book.down),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.organisation,
    required this.isOrgAdmin,
    required this.onSignOut,
    required this.onChangePassword,
  });

  final String name;
  final String organisation;
  final bool isOrgAdmin;
  final VoidCallback onSignOut;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    // The organisation is often named after the person running it, and
    // printing "KPS · KPS" says nothing twice.
    final place = organisation.trim().toLowerCase() == name.trim().toLowerCase()
        ? ''
        : organisation.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.rCard + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, Colors.black, 0.22)!],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.rCard),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (isOrgAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FULL ACCESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    if (isOrgAdmin && place.isNotEmpty) const SizedBox(width: 7),
                    if (place.isNotEmpty)
                      Flexible(
                        child: Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _CardAction(
            icon: Icons.key_outlined,
            tooltip: 'Change password',
            onTap: onChangePassword,
          ),
          const SizedBox(width: 6),
          _CardAction(
            icon: Icons.logout,
            tooltip: 'Sign out',
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

/// A button on the account card. Given a surface of its own so it reads as
/// something to press rather than an icon floating on the blue.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppTheme.rButton),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.rButton),
            onTap: onTap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rCard + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.rCard + 4),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.rCard + 4),
              border: Border.all(color: context.book.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: context.scheme.primary),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(fontSize: 9.5, height: 1.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
