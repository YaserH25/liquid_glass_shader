import 'package:flutter/material.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

import 'colorful_backdrop.dart';

/// A colourful page under a glass card and a liquid tab bar, with a switch
/// between clear and frosted glass.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  GlassStyle _style = GlassStyle.clear;
  int _tab = 0;

  static const _icons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.photo_library_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Home', 'Search', 'Library', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'liquid_glass_shader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: GlassScope(
        style: _style,
        child: Scaffold(
          extendBody: true,
          body: ColorfulBackdrop(header: _styleCard()),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LiquidTabBar(
                tabCount: _labels.length,
                selectedIndex: _tab,
                onSelected: (index) => setState(() => _tab = index),
                shadows: const [
                  BoxShadow(
                    color: Color(0x29000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
                tabBuilder: _tabItem,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _styleCard() => GlassSurface(
    borderRadius: BorderRadius.circular(28),
    padding: const EdgeInsets.all(16),
    child: Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Liquid glass', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<GlassStyle>(
            segments: const [
              ButtonSegment(value: GlassStyle.clear, label: Text('Clear')),
              ButtonSegment(value: GlassStyle.frosted, label: Text('Frosted')),
            ],
            selected: {_style},
            onSelectionChanged: (styles) =>
                setState(() => _style = styles.single),
          ),
        ],
      ),
    ),
  );

  Widget _tabItem(BuildContext context, int index, bool active) {
    final colors = Theme.of(context).colorScheme;
    final color = active ? colors.primary : colors.onSurfaceVariant;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_icons[index], color: color),
        const SizedBox(height: 2),
        Text(
          _labels[index],
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
