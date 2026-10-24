import 'package:flutter/widgets.dart';

import '../liquid_tab_builder.dart';

/// The tabs of a tab bar side by side, each in an equal slot.
class TabRow extends StatelessWidget {
  /// The bar's own tabs: [active] drawn as current, and each tab a button
  /// for screen readers that calls [onSemanticsTap].
  const TabRow({
    super.key,
    required this.count,
    required this.tabBuilder,
    required this.selected,
    required int this.active,
    required ValueChanged<int> this.onSemanticsTap,
  });

  /// Every tab drawn as current and hidden from screen readers: the copy
  /// magnified inside the lifted lens.
  const TabRow.magnified({
    super.key,
    required this.count,
    required this.tabBuilder,
  }) : selected = -1,
       active = null,
       onSemanticsTap = null;

  /// How many tabs there are.
  final int count;

  /// Draws each tab.
  final LiquidTabBuilder tabBuilder;

  /// The current tab, for screen readers.
  final int selected;

  /// The tab drawn as current; null draws them all as current.
  final int? active;

  /// A screen reader tapped a tab; null leaves the tabs out of semantics.
  final ValueChanged<int>? onSemanticsTap;

  @override
  Widget build(BuildContext context) {
    final onTap = onSemanticsTap;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: onTap == null
                ? tabBuilder(context, i, true)
                : Semantics(
                    key: ValueKey('liquid_tab_$i'),
                    container: true,
                    button: true,
                    selected: i == selected,
                    onTap: () => onTap(i),
                    child: tabBuilder(context, i, i == active),
                  ),
          ),
      ],
    );
  }
}
