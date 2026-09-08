import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/party.dart';
import '../../features/masters/party_edit_sheet.dart';

/// Picking a party by code or name.
///
/// Used anywhere money names a party. It searches on the device against the
/// list already loaded, so it answers as fast as the operator types.
class PartyField extends StatelessWidget {
  const PartyField({
    super.key,
    required this.parties,
    required this.selected,
    required this.onChanged,
    this.hint = 'Tap to choose',
  });

  final List<Party> parties;
  final Party? selected;
  final ValueChanged<Party> onChanged;
  final String hint;

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PartyPickerSheet(parties: parties),
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final party = selected;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.rField),
      onTap: () => _pick(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppTheme.minTouch),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.rField),
          border: Border.all(color: book.line),
        ),
        child: Row(
          children: [
            if (party != null) ...[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: book.brandSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  party.initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                party?.display ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: party == null ? FontWeight.w400 : FontWeight.w600,
                  color: party == null ? book.muted : context.scheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 20, color: book.muted),
          ],
        ),
      ),
    );
  }
}

/// The searchable list behind [PartyField].
class PartyPickerSheet extends StatefulWidget {
  const PartyPickerSheet({super.key, required this.parties});

  final List<Party> parties;

  @override
  State<PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<PartyPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.text.trim().toUpperCase();
    final shown = term.isEmpty
        ? widget.parties
        : widget.parties
            .where((p) => p.code.contains(term) || p.name.toUpperCase().contains(term))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _search,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search code or name',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          if (shown.isEmpty)
            // A code that matches nothing is usually a party that has not been
            // added yet. Sending the operator away to the master and back
            // loses whatever they were in the middle of, so it is added from
            // here and comes straight back as the choice.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  Text('Nothing matches that', style: context.text.bodyMedium),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final created = await PartyEditSheet.show(
                        context,
                        initialCode: term,
                      );
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(created);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(term.isEmpty ? 'Add a party' : 'Add $term'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: shown.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  title: Text(shown[i].display),
                  subtitle: shown[i].categoryName == null
                      ? null
                      : Text(shown[i].subtitle, style: context.text.bodySmall),
                  onTap: () => Navigator.of(context).pop(shown[i]),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
