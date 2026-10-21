import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

/// One place that decides how loading, empty and failure look.
///
/// Screens hand it an [AsyncValue] and a builder; they never write their own
/// spinner or error text, so a failure reads the same wherever it happens.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  /// Lets a screen say what "empty" means for its own data.
  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Pullable(
          child: _Failure(
            message: error is ApiException
                ? error.message
                : 'Something went wrong. Please try again.',
            onRetry: onRetry,
          ),
        ),
        data: (data) {
          if (isEmpty?.call(data) == true) {
            return _Pullable(child: _Empty(title: emptyTitle, message: emptyMessage));
          }
          return builder(data);
        },
      );
}

/// Lets an empty or failed screen be pulled down to refresh.
///
/// A pull to refresh only fires on something that scrolls, and the empty and
/// failure messages did not - so on an empty Matches tab the operator pulled
/// and pulled and nothing was read, and a match made on the desk only showed
/// up once something else happened to reload the list. In a fixed height the
/// message now sits in a scroll view the full height of the screen; anywhere
/// else (inside a list, say) it is left as it was.
class _Pullable extends StatelessWidget {
  const _Pullable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) return child;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          );
        },
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 34, color: context.book.muted),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A quiet mark so an empty list reads as "nothing yet" at a
              // glance rather than as a screen that failed to draw.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.book.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inbox_outlined, size: 26, color: context.scheme.primary),
              ),
              const SizedBox(height: 14),
              Text(title, style: context.text.titleMedium),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );
}
