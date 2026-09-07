import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The small uppercase label that sits above every input on these boards.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text.toUpperCase(), style: context.text.labelSmall),
      );
}

/// Label above, field below - the shape used by every form in the app.
class LabelledField extends StatelessWidget {
  const LabelledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FieldLabel(label), child],
      );
}
