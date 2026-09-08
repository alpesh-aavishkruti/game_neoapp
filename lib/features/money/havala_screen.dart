import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/app_time.dart';
import '../../core/util/money.dart';
import '../../data/models/havala.dart';
import '../../data/repositories/havala_repository.dart';
import '../../core/network/api_exception.dart';
import '../../shared/widgets/async_view.dart';
import 'auto_havala_sheet.dart';
import 'havala_entry_sheet.dart';

final havalaRepositoryProvider = Provider<HavalaRepository>(
  (ref) => HavalaRepository(ref.watch(apiClientProvider)),
);

final havalaListProvider = FutureProvider<List<Havala>>((ref) async {
  return ref.watch(havalaRepositoryProvider).list();
});

/// Havala - money moving between two parties.
class HavalaScreen extends ConsumerWidget {
  const HavalaScreen({super.key, this.embedded = false});

  /// Inside the Reports tabs the section is already named above.
  final bool embedded;

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing the report…')),
    );
    try {
      await ref.read(reportSharingProvider).sharePdf(
            path: '/soda/havala/download_havala_report/',
            name: 'Havala report',
          );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(havalaListProvider);

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Havala'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  tooltip: 'Auto havala',
                  onPressed: () async {
                    final saved = await AutoHavalaSheet.show(context);
                    if (saved == true) ref.invalidate(havalaListProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Share as PDF',
                  onPressed: () => _share(context, ref),
                ),
              ],
            ),
      persistentFooterAlignment: AlignmentDirectional.centerStart,
      persistentFooterButtons: embedded
          ? [
              TextButton.icon(
                onPressed: () async {
                  final saved = await AutoHavalaSheet.show(context);
                  if (saved == true) ref.invalidate(havalaListProvider);
                },
                icon: const Icon(Icons.auto_fix_high_outlined, size: 17),
                label: const Text('Auto havala'),
              ),
              TextButton.icon(
                onPressed: () => _share(context, ref),
                icon: const Icon(Icons.ios_share, size: 17),
                label: const Text('Share as PDF'),
              ),
            ]
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await HavalaEntrySheet.show(context);
          if (saved == true) ref.invalidate(havalaListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New havala'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(havalaListProvider.future),
        child: AsyncView(
          value: entries,
          onRetry: () => ref.invalidate(havalaListProvider),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'No havala entries yet',
          emptyMessage: 'Transfers between parties will appear here.',
          builder: (list) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) => _HavalaRow(entry: list[i]),
          ),
        ),
      ),
    );
  }
}

class _HavalaRow extends StatelessWidget {
  const _HavalaRow({required this.entry});

  final Havala entry;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
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
                  entry.voucherNo.isEmpty ? 'HAVALA' : entry.voucherNo,
                  style: const TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Money.format(entry.amount),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Payer above, receiver below, with an arrow between - the same
          // shape as the form, so a transfer can never be read backwards.
          _Leg(label: 'FROM', code: entry.fromCode, name: entry.fromName),
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
            child: Icon(Icons.south, size: 14, color: book.muted),
          ),
          _Leg(label: 'TO', code: entry.toCode, name: entry.toName),
          if (entry.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.description, style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: 5),
          Text(
            [
              if (entry.date != null) AppTime.date(entry.date),
              if (entry.createdBy.isNotEmpty) entry.createdBy.toUpperCase(),
            ].join(' · '),
            style: context.text.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.label, required this.code, required this.name});

  final String label;
  final String code;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: context.text.labelSmall)),
          Expanded(
            child: Text(
              name.isEmpty ? code : '$code — $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
