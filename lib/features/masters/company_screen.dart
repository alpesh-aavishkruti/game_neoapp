import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/field_label.dart';
import 'master_providers.dart';

final organisationSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(masterRepositoryProvider).organisationSettings();
});

/// The company the book belongs to.
///
/// Editable here because the name and address are what land on every printed
/// report - the one part of this record anyone actually needs to correct from
/// a phone. The trading settings behind it stay at the desk.
class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;
  String? _error;
  bool _loaded = false;

  static const _fields = [
    (key: 'name', label: 'Organisation name'),
    (key: 'company_name', label: 'Company name'),
    (key: 'address_line1', label: 'Address line 1'),
    (key: 'address_line2', label: 'Address line 2'),
    (key: 'city', label: 'City'),
    (key: 'state', label: 'State'),
    (key: 'pin', label: 'PIN'),
    (key: 'country', label: 'Country'),
    (key: 'phone', label: 'Phone'),
    (key: 'email', label: 'Email'),
  ];

  void _hydrate(Map<String, dynamic> settings) {
    if (_loaded) return;
    _loaded = true;
    for (final field in _fields) {
      _controllers[field.key] =
          TextEditingController(text: (settings[field.key] ?? '').toString().trim());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    if ((_controllers['name']?.text.trim() ?? '').isEmpty) {
      setState(() => _error = 'Enter the organisation name');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).patch('/organization-settings', data: {
        for (final field in _fields) field.key: _controllers[field.key]!.text.trim(),
      });
      // The account card reads the company name, so it has to be told.
      ref.invalidate(organisationNameProvider);
      ref.invalidate(organisationSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Company details saved.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(organisationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Company')),
      body: AsyncView(
        value: settings,
        onRetry: () => ref.invalidate(organisationSettingsProvider),
        builder: (data) {
          _hydrate(data);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              for (final field in _fields) ...[
                LabelledField(
                  label: field.label,
                  child: TextField(controller: _controllers[field.key]),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.book.down)),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save details'),
              ),
            ],
          );
        },
      ),
    );
  }
}
