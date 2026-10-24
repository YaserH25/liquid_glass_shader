import 'package:flutter/material.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

import 'playground_page.dart';
import 'playground_settings.dart';

/// The playground: a colourful page under a liquid tab bar, with controls
/// for its layout, size, glass, direction, theme and motion.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  PlaygroundSettings _settings = const PlaygroundSettings();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'liquid_glass_shader',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: _settings.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: GlassScope(
          style: _settings.glass,
          child: Scaffold(
            body: PlaygroundPage(
              settings: _settings,
              onChanged: (settings) => setState(() => _settings = settings),
            ),
          ),
        ),
      ),
    );
  }
}
