import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../data/models/match.dart';
import '../../data/models/party.dart';
import 'general_report_screen.dart';
import 'report_form.dart';

/// The matches closed inside a period, so the desk can pick which to print.
final _matchesInRangeProvider = FutureProvider.autoDispose
    .family<List<GameMatch>, ({DateTime from, DateTime to})>((ref, range) async {
  final body = await ref.watch(apiClientProvider).get(
    '/master/matches/filter_matches_by_date/',
    query: {
      'from_date': AppTime.apiDate(range.from),
      'to_date': AppTime.apiDate(range.to),
    },
  );
  return asList(body).map((row) => GameMatch.fromJson(row)).toList();
});

/// One or more matches, printed.
///
/// The desk's MATCH REPORT. Unlike the others it is not about a period so much
/// as about particular matches - the dates only narrow the list you then tick
/// through, which is why the match list is the biggest thing on the screen.
class MatchReportScreen extends ConsumerStatefulWidget {
  const MatchReportScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<MatchReportScreen> createState() => _MatchReportScreenState();
}

class _MatchReportScreenState extends ConsumerState<MatchReportScreen> {
  DateTime _from = AppTime.today;
  DateTime _to = AppTime.today;
  String _display = 'Name';
  String _orderBy = 'Default';
  final _picked = <int>{};
  List<Party> _members = const [];

  void _clear() => setState(() {
        _from = AppTime.today;
        _to = AppTime.today;
        _display = 'Name';
        _orderBy = 'Default';
        _picked.clear();
        _members = const [];
      });

  Future<void> _run() => ReportRunner.run(
        context,
        ref,
        path: '/master/matches/download_match_report/',
        name: 'Match report',
        query: {
          'from_date': AppTime.apiDate(_from),
          'to_date': AppTime.apiDate(_to),
          'match_ids': _picked.join(','),
          'display_format': _display,
          'order_by': _orderBy,
          'party_ids': _members.map((p) => p.id).join(','),
        },
      );

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(_matchesInRangeProvider((from: _from, to: _to)));

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
              onChanged: (d) => setState(() {
                _from = d;
                _picked.clear();
              }),
            ),
            ReportDate(
              label: 'To date',
              value: _to,
              onChanged: (d) => setState(() {
                _to = d;
                _picked.clear();
              }),
            ),
            ReportChoice(
              label: 'Code/name',
              value: _display,
              options: displayFormats,
              onChanged: (v) => setState(() => _display = v),
            ),
            ReportChoice(
              label: 'Order by',
              value: _orderBy,
              options: orderings,
              onChanged: (v) => setState(() => _orderBy = v),
            ),
          ],
        ),
        ReportSection(
          title: 'MATCHES',
          children: [
            switch (matches) {
              AsyncError() => Text(
                  'Could not load the matches in that period.',
                  style: context.text.bodySmall,
                ),
              AsyncData(:final value) when value.isEmpty => Text(
                  'No matches in that period.',
                  style: context.text.bodySmall,
                ),
              AsyncData(:final value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          _picked.isEmpty
                              ? '${value.length} matches - all of them'
                              : '${_picked.length} of ${value.length} picked',
                          style: context.text.bodySmall,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            if (_picked.length == value.length) {
                              _picked.clear();
                            } else {
                              _picked
                                ..clear()
                                ..addAll(value.map((m) => m.id));
                            }
                          }),
                          child: Text(
                            _picked.length == value.length ? 'Clear all' : 'Select all',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    for (final match in value)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _picked.contains(match.id),
                        onChanged: (on) => setState(() {
                          on == true ? _picked.add(match.id) : _picked.remove(match.id);
                        }),
                        title: Text(
                          match.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${match.game.label} · ${AppTime.date(match.closeDate ?? match.createdAt)}',
                          style: context.text.bodySmall?.copyWith(fontSize: 10.5),
                        ),
                      ),
                  ],
                ),
              _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            },
          ],
        ),
        ReportSection(
          title: 'MEMBERS',
          children: [
            ReportMembers(
              chosen: _members,
              onChanged: (list) => setState(() => _members = list),
            ),
          ],
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Match report')),
      body: body,
    );
  }
}
