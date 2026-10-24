import 'package:flutter/widgets.dart';

/// Builds tab [index] of a `LiquidTabBar`. [active] is true for the tab to
/// draw as current: the selected one, the one under a held lens, and every
/// tab in the magnified copy inside the lifted lens.
typedef LiquidTabBuilder = Widget Function(
  BuildContext context,
  int index,
  bool active,
);
