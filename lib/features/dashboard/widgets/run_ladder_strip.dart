import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/util/money.dart';
import '../../../data/models/run_ladder.dart';

/// The session ladder, and the four figures it settles on.
///
/// The run the book stands to lose most on is outlined, and the strip opens
/// scrolled to it - that is the figure being watched, and hunting for it in a
/// long row is exactly the work a phone should save.
class RunLadderStrip extends StatefulWidget {
  const RunLadderStrip({super.key, required this.ladder, required this.totals});

  final RunLadder ladder;
  final SessionTotals totals;

  @override
  State<RunLadderStrip> createState() => _RunLadderStripState();
}

class _RunLadderStripState extends State<RunLadderStrip> {
  final _controller = ScrollController();

  static const _rungWidth = 62.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToWorst());
  }

  void _scrollToWorst() {
    final worst = widget.ladder.worst;
    if (worst == null || !_controller.hasClients) return;
    final index = widget.ladder.rungs.indexOf(worst);
    if (index < 0) return;

    // Put it a little left of centre rather than hard against the edge.
    final target = (index * _rungWidth) - 80;
    _controller.jumpTo(target.clamp(0, _controller.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = context.book;
    final worst = widget.ladder.worst;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.ladder.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RUN LADDER', style: context.text.labelSmall),
                Text('SWIPE →', style: context.text.labelSmall),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: widget.ladder.rungs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final rung = widget.ladder.rungs[i];
                return _Rung(rung: rung, isWorst: rung == worst);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
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
                    Expanded(child: _Total(label: 'K TOTAL', value: widget.totals.kTotal, tone: book.down)),
                    const SizedBox(width: 1),
                    Expanded(child: _Total(label: 'L TOTAL', value: widget.totals.lTotal, tone: book.up)),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: _Total(
                        label: 'OUR K,L',
                        value: widget.totals.ourKl,
                        tone: book.forAmount(widget.totals.ourKl),
                        signed: true,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      child: _Total(
                        label: 'COMMISSION',
                        value: widget.totals.commission,
                        tone: book.warn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({required this.rung, required this.isWorst});

  final RunRung rung;
  final bool isWorst;

  @override
  Widget build(BuildContext context) {
    final book = context.book;

    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isWorst ? book.downSoft : context.scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rField),
        border: Border.all(color: isWorst ? book.down : book.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${rung.run}',
            style: const TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            Money.position(rung.profitLoss),
            style: TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: book.forAmount(rung.profitLoss),
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.tone,
    this.signed = false,
  });

  final String label;
  final double value;
  final Color tone;
  final bool signed;

  @override
  Widget build(BuildContext context) => Container(
        color: context.scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.text.labelSmall),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                signed
                    ? Money.position(value)
                    : Money.format(value),
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
      );
}
