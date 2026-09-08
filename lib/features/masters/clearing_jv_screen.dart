import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_chip.dart';
import 'master_providers.dart';

/// Clearing journal vouchers.
///
/// Debit against credit on the same line, with a chip that says at a glance
/// whether they agree. An unbalanced voucher names its gap here rather than
/// waiting to be found at month end.
class ClearingJvScreen extends StatefulWidget {
  const ClearingJvScreen({super.key});

  @override
  State<ClearingJvScreen> createState() => _ClearingJvScreenState();
}

class _ClearingJvScreenState extends State<ClearingJvScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clearing JV'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              tabs: const [Tab(text: 'CLEARING'), Tab(text: 'INFLOW CLEARING')],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _VoucherList(path: '/soda/clearing-jv/'),
          _VoucherList(path: '/soda/inflow-clearing-jv/'),
        ],
      ),
    );
  }
}

class _VoucherList extends ConsumerWidget {
  const _VoucherList({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(masterRowsProvider(path));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(masterRowsProvider(path).future),
      child: AsyncView(
        value: rows,
        onRetry: () => ref.invalidate(masterRowsProvider(path)),
        isEmpty: (list) => list.isEmpty,
        emptyTitle: 'No vouchers yet',
        builder: (list) => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, i) => _VoucherRow(row: list[i]),
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

    final debit = Money.toDouble(row['dr_total'] ?? row['dr_amount']);
    final credit = Money.toDouble(row['cr_total'] ?? row['cr_amount']);
    final gap = debit - credit;
    final balanced = gap.abs() < 0.005;

    final date = AppTime.toLocal(row['voucher_date']);
    final daybook = (row['daybook_name'] ?? row['daybook_code'] ?? '').toString().trim();
    final createdBy = (row['created_by_name'] ?? '').toString().trim();

    return Container(
      decoration: BoxDecoration(
        // An unbalanced voucher is the one worth finding, so it carries the
        // warning ground rather than just a different word.
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
                StatusChip('Off by ${Money.format(gap.abs())}', tone: ChipTone.live),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (daybook.isNotEmpty) daybook,
              if (date != null) AppTime.date(date),
              if (createdBy.isNotEmpty) createdBy.toUpperCase(),
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
