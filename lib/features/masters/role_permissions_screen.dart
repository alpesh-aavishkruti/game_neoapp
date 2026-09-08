import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import 'role_edit_sheet.dart';

/// One switchable right on one feature: read, write or delete.
///
/// A right is several permission rows on the server - writing means both add
/// and change - so it carries the whole set and is granted or taken as one.
class _Right {
  _Right({required this.name, required this.ids, required this.active});

  final String name;
  final List<int> ids;
  bool active;
}

class _Feature {
  _Feature({required this.title, required this.rights});

  final String title;
  final List<_Right> rights;
}

class _Group {
  _Group({required this.title, required this.features});

  final String title;
  final List<_Feature> features;
}

final _permissionsProvider =
    FutureProvider.autoDispose.family<List<_Group>, int>((ref, roleId) async {
  final body =
      await ref.watch(apiClientProvider).get('$rolePath$roleId/get_role_permissions/');

  return asList(body).whereType<Map>().map((group) {
    final features = (group['perm'] is List ? group['perm'] as List : const [])
        .whereType<Map>()
        .map((feature) {
      final rights =
          (feature['perms'] is List ? feature['perms'] as List : const [])
              .whereType<Map>()
              .map((right) => _Right(
                    name: (right['display_name'] ?? right['name'] ?? '')
                        .toString(),
                    ids: (right['perms'] is List ? right['perms'] as List : const [])
                        .map((e) => int.tryParse('$e'))
                        .whereType<int>()
                        .toList(),
                    active: right['active'] == true,
                  ))
              .toList();
      return _Feature(
        title: (feature['title'] ?? '').toString(),
        rights: rights,
      );
    }).toList();

    return _Group(title: (group['title'] ?? '').toString(), features: features);
  }).toList();
});

/// What one role may open.
///
/// The server sends every right with a flag, and saving sends back the whole
/// set that should be on - so this holds the switches until Save rather than
/// writing each tap. Half-applied rights are worse than none: someone would be
/// left able to write what they cannot read.
class RolePermissionsScreen extends ConsumerStatefulWidget {
  const RolePermissionsScreen({super.key, required this.role});

  final Map<String, dynamic> role;

  static Future<void> open(BuildContext context,
          {required Map<String, dynamic> role}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RolePermissionsScreen(role: role)),
      );

  @override
  ConsumerState<RolePermissionsScreen> createState() =>
      _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends ConsumerState<RolePermissionsScreen> {
  bool _saving = false;

  int get _roleId => int.tryParse('${widget.role['id']}') ?? 0;

  Future<void> _save(List<_Group> groups) async {
    if (_saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final ids = <int>[
        for (final group in groups)
          for (final feature in group.features)
            for (final right in feature.rights)
              if (right.active) ...right.ids,
      ];

      await ref
          .read(apiClientProvider)
          .patch('$rolePath$_roleId/', data: {'permissions': ids});

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.role['name']} updated')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(_permissionsProvider(_roleId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((widget.role['name'] ?? 'Role').toString()),
            Text(
              'What this role may open',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: AsyncView(
        value: permissions,
        onRetry: () => ref.invalidate(_permissionsProvider(_roleId)),
        isEmpty: (groups) => groups.isEmpty,
        emptyTitle: 'Nothing to set here',
        builder: (groups) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: groups.length,
                itemBuilder: (context, i) => _GroupBlock(
                  group: groups[i],
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(groups),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save permissions'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.group, required this.onChanged});

  final _Group group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 6),
          child: Text(group.title.toUpperCase(), style: context.text.labelSmall),
        ),
        for (final feature in group.features)
          Container(
            decoration: BoxDecoration(
              color: context.scheme.surface,
              border: Border(bottom: BorderSide(color: book.line)),
            ),
            padding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    feature.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final right in feature.rights)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _RightChip(right: right, onChanged: onChanged),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RightChip extends StatelessWidget {
  const _RightChip({required this.right, required this.onChanged});

  final _Right right;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final on = right.active;

    // The first letter is enough once the three sit side by side, and it is
    // what keeps a row of features readable on a phone.
    final label = right.name.isEmpty ? '?' : right.name[0].toUpperCase();

    return Semantics(
      label: right.name,
      toggled: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rField),
        onTap: () {
          right.active = !right.active;
          onChanged();
        },
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? context.scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.rField),
            border: Border.all(color: on ? context.scheme.primary : book.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : book.muted,
            ),
          ),
        ),
      ),
    );
  }
}
