import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/field_label.dart';
import 'master_providers.dart';
import '../../shared/widgets/app_dropdown.dart';

const employeePath = '/employee/';

final _rolesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  // Every page - the role list is paged ten at a time by default.
  (ref) => ref.watch(apiClientProvider).getAll('/role/'),
);

/// Adding a person who can sign in, or correcting one.
///
/// This writes a login, not just a record: the name and password here are what
/// someone types at the sign-in screen. So the password is asked for once when
/// the account is made, and afterwards only when it is being changed - leaving
/// it blank keeps whatever they already use.
class UserEditSheet extends ConsumerStatefulWidget {
  const UserEditSheet({super.key, this.editing});

  /// The employee row as the list sends it. Null when adding.
  final Map<String, dynamic>? editing;

  static Future<bool?> show(BuildContext context,
          {Map<String, dynamic>? editing}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => UserEditSheet(editing: editing),
      );

  @override
  ConsumerState<UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends ConsumerState<UserEditSheet> {
  final _userName = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _shortName = TextEditingController();
  final _phone = TextEditingController();
  final _autoLogout = TextEditingController(text: '15');

  int? _roleId;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final row = widget.editing;
    if (row == null) return;

    final user = row['user'] is Map ? row['user'] as Map : const {};
    final role = row['role'] is Map ? row['role'] : null;

    _userName.text = (user['username'] ?? '').toString();
    _code.text = (row['user_code'] ?? '').toString();
    _shortName.text = (row['user_short_name'] ?? '').toString();
    _phone.text = (row['phone'] ?? '').toString();
    _autoLogout.text = (row['auto_logout_minutes'] ?? '').toString();
    _roleId = role is Map
        ? int.tryParse('${role['id']}')
        : int.tryParse('${row['role']}');
  }

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    _code.dispose();
    _shortName.dispose();
    _phone.dispose();
    _autoLogout.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    final userName = _userName.text.trim();
    final password = _password.text;

    final problem = switch (null) {
      _ when userName.isEmpty => 'Enter the user name they will sign in with',
      _ when !_isEditing && password.isEmpty => 'Set a password for the account',
      _ when _roleId == null => 'Choose what this account may do',
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'user_name': userName,
        'user_code': _code.text.trim(),
        'user_short_name': _shortName.text.trim(),
        'phone': _phone.text.trim(),
        'auto_logout_minutes': int.tryParse(_autoLogout.text.trim()) ?? 15,
        'role': _roleId,
        // On an edit a blank box means "leave the password alone", so it is
        // left out rather than sent empty - which would clear it.
        if (password.isNotEmpty) 'password': password,
      };

      final api = ref.read(apiClientProvider);
      if (_isEditing) {
        await api.patch('$employeePath${widget.editing!['id']}/', data: payload);
      } else {
        await api.post(employeePath, data: payload);
      }

      ref.invalidate(masterRowsProvider(employeePath));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.fieldErrors?['user_name'] ?? e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the account. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(_rolesProvider);
    final book = context.book;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: book.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(_isEditing ? 'Edit user' : 'New user',
                  style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                _isEditing
                    ? 'They sign in with this name'
                    : 'Creates a sign-in for this organisation',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 16),

              LabelledField(
                label: 'User name',
                child: TextField(
                  controller: _userName,
                  autofocus: !_isEditing,
                  autocorrect: false,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 14),
              LabelledField(
                label: _isEditing ? 'New password' : 'Password',
                child: TextField(
                  controller: _password,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: _isEditing ? 'Leave blank to keep the current one' : '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Code',
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: LabelledField(
                      label: 'Short name',
                      child: TextField(
                        controller: _shortName,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: LabelledField(
                      label: 'Phone',
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    flex: 2,
                    child: LabelledField(
                      label: 'Auto logout',
                      child: TextField(
                        controller: _autoLogout,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '15',
                          suffixText: 'min',
                        ),
                        style: const TextStyle(
                            fontFamily: 'Roboto Mono', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              LabelledField(
                label: 'Role',
                child: AppDropdown<int>(
                  initialValue: _roleId,
                  isExpanded: true,
                  hint: Text(roles.isLoading ? 'Loading…' : 'Choose a role'),
                  items: [
                    for (final role in roles.value ?? const [])
                      DropdownMenuItem(
                        value: int.tryParse('${role['id']}'),
                        child: Text(
                          (role['name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _roleId = v),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: context.text.bodyMedium?.copyWith(color: book.down)),
              ],

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Add user'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
