import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import '../masters/master_providers.dart';
import 'opening_balance_sheet.dart';

const openingBalancePath = '/soda/opening-balances/';

/// Opening balances — what each party was carrying before the book started.
///
/// Start-of-year work, so the list is usually empty for most of the year. That
/// is worth saying on the screen rather than leaving someone wondering whether
/// it failed to load.
class OpeningBalanceScreen extends ConsumerWidget {
  const OpeningBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(masterRowsProvider(openingBalancePath));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Opening balance'),
            Text(
              'Carried forward before the book started',
              style: context.text.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await OpeningBalanceSheet.show(context);
          if (saved == true) ref.invalidate(masterRowsProvider(openingBalancePath));
        },
        icon: const Icon(Icons.add),
        label: const Text('New voucher'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(masterRowsProvider(openingBalancePath).future),
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(masterRowsProvider(openingBalancePath)),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'No opening balances yet',
          emptyMessage: 'These are entered once, when a new book opens.',
          builder: (list) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) => _VoucherRow(row: list[i]),
          ),
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    final debit = Money.toDouble(row['dr_total']);
    final credit = Money.toDouble(row['cr_total']);
    final balanced = (debit - credit).abs() < 0.005;
    final date = AppTime.toLocal(row['voucher_date']);
    final lines = row['details'] is List ? (row['details'] as List).length : 0;

    return Container(
      decoration: BoxDecoration(
        color: balanced ? context.scheme.surface : book.warnSoft,
        border: Border(bottom: BorderSide(color: book.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (row['voucher_no'] ?? '—').toString(),
                  style: const TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (balanced)
                const StatusChip('Balanced', tone: ChipTone.up)
              else
                StatusChip(
                  'Off by ${Money.format((debit - credit).abs())}',
                  tone: ChipTone.live,
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (date != null) AppTime.date(date),
              if (lines > 0) '$lines ${lines == 1 ? 'party' : 'parties'}',
            ].join(' · '),
            style: context.text.bodySmall?.copyWith(fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Figure(label: 'DR TOTAL', value: debit)),
              Expanded(child: _Figure(label: 'CR TOTAL', value: credit)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: context.text.labelSmall),
          Text(
            Money.format(value),
            style: const TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
