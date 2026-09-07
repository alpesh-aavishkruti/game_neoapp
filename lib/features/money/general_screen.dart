import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/money.dart';
import '../../data/models/general_view.dart';
import '../../data/models/party.dart';
import '../../shared/widgets/async_view.dart';
import '../matches/match_providers.dart';
import 'ledger_screen.dart';

final generalViewProvider = FutureProvider<GeneralView>((ref) async {
  final body = await ref.watch(apiClientProvider).get('/master/parties/view_general/');
  return GeneralView.fromJson(asMap(body));
});

/// Where the whole book stands.
///
/// Every other screen answers for one match or one party. This one answers for
/// all of them at once: who the house owes, who owes the house, and what is
/// left over. The two totals are shown side by side rather than netted into a
/// single figure, because the difference is the thing worth looking at.
class GeneralScreen extends ConsumerWidget {
  const GeneralScreen({super.key, this.embedded = false});

  final bool embedded;

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing the report…')),
    );
    try {
      await ref.read(reportSharingProvider).sharePdf(
            path: '/master/parties/download_general_report/',
            name: 'General report',
          );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final general = ref.watch(generalViewProvider);

    final body = RefreshIndicator(
      onRefresh: () => ref.refresh(generalViewProvider.future),
      child: AsyncView(
        value: general,
        onRetry: () => ref.invalidate(generalViewProvider),
        isEmpty: (data) => data.isEmpty,
        emptyTitle: 'Nothing outstanding',
        emptyMessage: 'Balances appear here once matches are settled.',
        builder: (data) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Summary(view: data),
            _Section(
              title: 'HOUSE OWES',
              lines: data.give,
              total: data.totalGive,
              isCredit: true,
            ),
            _Section(
              title: 'OWED TO HOUSE',
              lines: data.take,
              total: data.totalTake,
              isCredit: false,
            ),
          ],
        ),
      ),
    );

    if (embedded) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _share(context, ref),
              icon: const Icon(Icons.ios_share, size: 17),
              label: const Text('Share as PDF'),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('General'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share as PDF',
            onPressed: () => _share(context, ref),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.view});

  final GeneralView view;

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final difference = view.difference;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Container(
        decoration: BoxDecoration(
          color: book.line,
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          border: Border.all(color: book.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _Figure(label: 'HOUSE OWES', value: view.totalGive, tone: book.down),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: _Figure(label: 'OWED TO HOUSE', value: view.totalTake, tone: book.up),
                ),
              ],
            ),
            const SizedBox(height: 1),
            _Figure(
              label: 'DIFFERENCE',
              value: difference,
              tone: book.forAmount(difference),
              signed: true,
              wide: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.tone,
    this.signed = false,
    this.wide = false,
  });

  final String label;
  final double value;
  final Color tone;
  final bool signed;
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
        width: wide ? double.infinity : null,
        color: context.scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.text.labelSmall),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                signed ? Money.position(value, decimals: 0) : Money.format(value, decimals: 0),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: wide ? 17 : 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.lines,
    required this.total,
    required this.isCredit,
  });

  final String title;
  final List<GeneralLine> lines;
  final double total;
  final bool isCredit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = context.book;
    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Expanded(child: Text(title, style: context.text.labelSmall)),
              Text(
                Money.format(total, decimals: 0),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCredit ? book.down : book.up,
                ),
              ),
            ],
          ),
        ),
        for (final line in lines)
          _GeneralRow(line: line, isCredit: isCredit),
      ],
    );
  }
}

class _GeneralRow extends ConsumerWidget {
  const _GeneralRow({required this.line, required this.isCredit});

  final GeneralLine line;
  final bool isCredit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = context.book;

    return InkWell(
      // A figure here is a question - "why does this party owe that?" - and
      // the statement is the answer, so it is one tap away.
      onTap: () async {
        final parties = await ref.read(partiesProvider.future);
        if (!context.mounted) return;
        final party = parties.firstWhere(
          (p) => p.id == line.partyId,
          orElse: () => Party(id: line.partyId, code: line.code, name: line.name),
        );
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LedgerScreen(party: party)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          border: Border(bottom: BorderSide(color: book.line)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                line.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              Money.format(line.amount, decimals: 0),
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCredit ? book.down : book.up,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
