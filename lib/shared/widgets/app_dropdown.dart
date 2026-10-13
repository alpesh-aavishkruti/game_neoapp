import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The one dropdown every form uses.
///
/// Material's default menu opened as a flat grey slab the width of the
/// screen; this keeps it a rounded, raised card in the surface colour, with
/// the same text size as the fields around it, so every picker in the app
/// looks and behaves alike.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.hint,
    this.style,
    this.isExpanded = true,
  });

  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final InputDecoration decoration;
  final Widget? hint;
  final TextStyle? style;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) => ButtonTheme(
    // Opens the menu the width of the box it came from, rather than
    // spilling past it to the screen edge.
    alignedDropdown: true,
    child: DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      decoration: decoration,
      hint: hint,
      isExpanded: isExpanded,
      style:
          style ??
          TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: context.scheme.onSurface),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.book.muted),
      dropdownColor: context.scheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      menuMaxHeight: 380,
    ),
  );
}
