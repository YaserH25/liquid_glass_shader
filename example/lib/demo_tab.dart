import 'package:flutter/material.dart';

import 'demo_tab_look.dart';

/// One tab of the playground's bar, in the app's colours: the primary
/// colour when [active].
class DemoTab extends StatelessWidget {
  /// The tab with [icon] and [label], laid out as [look].
  const DemoTab({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.look,
  });

  /// The tab's icon.
  final IconData icon;

  /// The tab's name.
  final String label;

  /// Whether to draw it as current.
  final bool active;

  /// How icon and label sit.
  final DemoTabLook look;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = active ? colors.primary : colors.onSurfaceVariant;
    return switch (look) {
      DemoTabLook.stacked => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: text.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
      // The bar scales a tab down when it is too long for its slot, so the
      // label is never cut short.
      DemoTabLook.inline => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: text.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
      DemoTabLook.icon => Icon(icon, color: color, semanticLabel: label),
    };
  }
}
