import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/party.dart';
import '../matches/match_providers.dart';

/// The pieces every report builder is made of.
///
/// All six reports on the desk are the same screen with different boxes: pick
/// a period, pick who and how it is ordered, then print. Building them out of
/// one set of parts keeps them behaving identically, which matters more here
/// than on most screens - an operator sets these up once and then runs them
/// from memory.

/// Runs a report and hands the PDF to the share sheet.
///
/// The desk has two buttons, SCREEN and VIEW AND PRINT. A phone has one: there
/// is nowhere to put a preview window, and the share sheet already offers
/// print, WhatsApp and save. The PDF is the same document the desk prints.
class ReportRunner {
  const ReportRunner._();

  static Future<void> run(
    BuildContext context,
    WidgetRef ref, {
    required String path,
    required String name,
    required Map<String, dynamic> query,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Preparing $name…')));
    try {
      await ref.read(reportSharingProvider).sharePdf(
            path: path,
            name: name,
            // Empty values are dropped rather than sent blank: the desk's
            // report views treat a missing filter and an empty one alike, and
            // sending both invites the two to drift apart.
            query: {
              for (final entry in query.entries)
                if ('${entry.value}'.trim().isNotEmpty) entry.key: entry.value,
            },
          );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not build the $name.')),
      );
    }
  }
}

/// The shell a report builder is drawn in: scrolling body, then the actions.
class ReportForm extends StatelessWidget {
  const ReportForm({
    super.key,
    required this.children,
    required this.onRun,
    required this.onClear,
    this.runLabel = 'View and print',
    this.busy = false,
  });

  final List<Widget> children;
  final VoidCallback onRun;
  final VoidCallback onClear;
  final String runLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              children: children,
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: context.scheme.surface,
                border: Border(top: BorderSide(color: context.book.line)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  // Given a width: the theme asks every outlined button to
                  // fill its line, which inside a Row means infinity.
                  SizedBox(
                    width: 104,
                    child: OutlinedButton(
                      onPressed: onClear,
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onRun,
                      icon: busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print_outlined, size: 18),
                      label: Text(runLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

/// A titled group of fields, drawn the way the desk boxes them.
class ReportSection extends StatelessWidget {
  const ReportSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          border: Border.all(color: context.book.line),
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.text.labelSmall),
            const SizedBox(height: 9),
            ...children,
          ],
        ),
      );
}

/// A labelled date, tapped to change.
class ReportDate extends StatelessWidget {
  const ReportDate({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: context.text.labelSmall),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.rField),
              onTap: () async {
                final start = value ?? AppTime.today;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: start,
                  firstDate: DateTime(start.year - 3),
                  lastDate: DateTime(start.year + 2),
                );
                if (picked != null) onChanged(picked);
              },
              child: Container(
                height: AppTheme.minTouch,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.rField),
                  border: Border.all(color: book.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppTime.date(value),
                        style: const TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today_outlined, size: 15, color: book.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled choice from a fixed list.
class ReportChoice extends StatelessWidget {
  const ReportChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;

  /// Value to what the operator reads. Order is kept.
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: context.text.labelSmall),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final entry in options.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Set on the item, not the field: a style on the field
                        // replaces the theme's colour and the selected value
                        // comes out unpainted.
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
                onChanged: (v) => onChanged(v ?? value),
              ),
            ),
          ],
        ),
      );
}

/// Who the report covers.
///
/// Empty means everyone, which is how the desk runs it most days. Clients are
/// added one at a time, or a whole agent's book at once - the second is the
/// reason this is not just a multi-select.
class ReportMembers extends ConsumerStatefulWidget {
  const ReportMembers({super.key, required this.chosen, required this.onChanged});

  final List<Party> chosen;
  final ValueChanged<List<Party>> onChanged;

  @override
  ConsumerState<ReportMembers> createState() => _ReportMembersState();
}

class _ReportMembersState extends ConsumerState<ReportMembers> {
  Future<void> _pick({required bool byRef}) async {
    final parties = await ref.read(partiesProvider.future);
    if (!mounted) return;

    final chosen = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PartySheet(
        parties: parties,
        title: byRef ? 'Whose book?' : 'Add a client',
      ),
    );
    if (chosen == null) return;

    // By ref member: everyone that agent introduced, not the agent.
    final adding = byRef
        ? parties.where((p) => p.refMemberId == chosen.id).toList()
        : [chosen];

    final next = [...widget.chosen];
    for (final party in adding) {
      if (!next.any((p) => p.id == party.id)) next.add(party);
    }

    if (byRef && adding.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No clients are under ${chosen.code}')),
      );
      return;
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(byRef: false),
                  icon: const Icon(Icons.person_add_alt, size: 17),
                  label: const Text('Add client'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(byRef: true),
                  icon: const Icon(Icons.groups_outlined, size: 17),
                  label: const Text('Add by ref'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (widget.chosen.isEmpty)
            Text(
              'Nobody added - the report covers every client.',
              style: context.text.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final party in widget.chosen)
                  InputChip(
                    label: Text(party.code, style: const TextStyle(fontSize: 11.5)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => widget.onChanged(
                      widget.chosen.where((p) => p.id != party.id).toList(),
                    ),
                  ),
                if (widget.chosen.length > 1)
                  ActionChip(
                    label: const Text('Clear all', style: TextStyle(fontSize: 11.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onChanged(const []),
                  ),
              ],
            ),
        ],
      );
}

class _PartySheet extends StatefulWidget {
  const _PartySheet({required this.parties, required this.title});

  final List<Party> parties;
  final String title;

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(widget.title, style: context.text.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                dense: true,
                title: Text(shown[i].display),
                onTap: () => Navigator.of(context).pop(shown[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
