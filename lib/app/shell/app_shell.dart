import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'responsive_scaffold.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const AppShell({
    super.key,
    required this.child,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    // Determine current path
    final location = state.uri.path;

    return ResponsiveScaffold(
      currentRoute: location,
      child: child,
    );
  }
}
