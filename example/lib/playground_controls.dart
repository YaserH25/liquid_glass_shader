import 'package:flutter/material.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

import 'playground_layout.dart';
import 'playground_settings.dart';

/// A frosted glass card of controls that change the playground's tab bar.
class PlaygroundControls extends StatelessWidget {
  /// Controls showing [settings], reporting changes to [onChanged].
  const PlaygroundControls({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  /// What the controls show.
  final PlaygroundSettings settings;

  /// Called with the settings after a change.
  final ValueChanged<PlaygroundSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return GlassSurface(
      // Text sits right on this glass, so it is always frosted.
      style: GlassStyle.frosted,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Liquid tab bar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final layout in PlaygroundLayout.values)
                  ChoiceChip(
                    label: Text(layout.label),
                    selected: s.layout == layout,
                    onSelected: (_) => onChanged(s.copyWith(layout: layout)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _row(
              context,
              'Width',
              _segments<bool>(
                {false: 'Hug', true: 'Fill'},
                s.fill,
                (fill) => s.copyWith(fill: fill),
              ),
            ),
            _row(
              context,
              'Tabs',
              _segments<int>(
                {3: '3', 4: '4', 5: '5'},
                s.tabCount,
                (count) => s.copyWith(tabCount: count),
              ),
            ),
            _row(
              context,
              'Glass',
              _segments<GlassStyle>(
                {GlassStyle.clear: 'Clear', GlassStyle.frosted: 'Frosted'},
                s.glass,
                (glass) => s.copyWith(glass: glass),
              ),
            ),
            _row(
              context,
              'Direction',
              _segments<bool>(
                {false: 'LTR', true: 'RTL'},
                s.rtl,
                (rtl) => s.copyWith(rtl: rtl),
              ),
            ),
            _row(
              context,
              'Theme',
              _segments<ThemeMode>(
                {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                s.themeMode,
                (mode) => s.copyWith(themeMode: mode),
              ),
            ),
            _switch('Labels', s.labels, (on) => s.copyWith(labels: on)),
            _switch(
              'Minimize on scroll',
              s.minimizeOnScroll,
              (on) => s.copyWith(minimizeOnScroll: on),
            ),
            _switch('Tick', s.tick, (on) => s.copyWith(tick: on)),
            _switch(
              'Tinted lens',
              s.tintedLens,
              (on) => s.copyWith(tintedLens: on),
            ),
          ],
        ),
      ),
    );
  }

  /// [label] and [control] on one line, or the control below the label
  /// when the card is too narrow for both.
  Widget _row(BuildContext context, String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        control,
      ],
    ),
  );

  Widget _segments<T>(
    Map<T, String> options,
    T selected,
    PlaygroundSettings Function(T value) change,
  ) => SegmentedButton<T>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: [
      for (final MapEntry(:key, :value) in options.entries)
        ButtonSegment(value: key, label: Text(value)),
    ],
    selected: {selected},
    onSelectionChanged: (values) => onChanged(change(values.single)),
  );

  Widget _switch(
    String label,
    bool value,
    PlaygroundSettings Function(bool on) change,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    value: value,
    onChanged: (on) => onChanged(change(on)),
  );
}
