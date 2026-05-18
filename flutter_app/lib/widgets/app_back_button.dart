import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button that always does something useful.
///
/// `BackButton()` calls `Navigator.maybePop`, which fails silently when the
/// shell route has no inner stack (very common with `context.go(...)` since
/// it replaces the route instead of pushing). This widget falls back to
/// `context.go('/')` so tapping the chevron always leaves the page.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallbackPath = '/'});

  final String fallbackPath;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackPath);
        }
      },
    );
  }
}
