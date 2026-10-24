import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader_example/colorful_backdrop.dart';

/// Frame times while a page scrolls under the tab bar, while a finger
/// scrubs the bar, and while the lens slides between tabs. Run it in profile
/// mode on a device:
///
/// ```bash
/// flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/tab_bar_perf_test.dart
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Frames come from the engine as in an app, not from the test's pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  // binding.watchPerformance without its garbage collection count, which
  // needs the VM service, and a phone connected over Wi-Fi cannot reach it.
  Future<void> watch(String key, Future<void> Function() action) async {
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    // The engine reports frame timings in batches, up to a second late.
    await wait(2000);
    binding.addTimingsCallback(collect);
    await action();
    await wait(2000);
    binding.removeTimingsCallback(collect);
    (binding.reportData ??= {})[key] = FrameTimingSummarizer(timings).summary;
  }

  testWidgets('tab bar frame times', (tester) async {
    final tab = ValueNotifier(0);
    await tester.pumpWidget(_Scene(tab: tab));
    await wait(1500);

    await watch('scroll', () async {
      for (var i = 0; i < 3; i++) {
        await tester.fling(find.byType(ListView), const Offset(0, -500), 1500);
        await wait(900);
        await tester.fling(find.byType(ListView), const Offset(0, 500), 1500);
        await wait(900);
      }
    });

    final bar = tester.getRect(find.byType(LiquidTabBar));
    final slot = bar.width / 4;
    await watch('scrub', () async {
      for (var i = 0; i < 3; i++) {
        final start = Offset(bar.left + slot / 2, bar.center.dy);
        await tester.timedDragFrom(
          start,
          Offset(slot * 3, 0),
          const Duration(milliseconds: 700),
          frequency: 120,
        );
        await wait(600);
      }
    });

    await watch('slide', () async {
      for (final index in [3, 0, 2, 1, 3, 0]) {
        tab.value = index;
        await wait(500);
      }
    });
  });
}

/// A colourful page under a four-tab bar, as an app would have it.
class _Scene extends StatelessWidget {
  const _Scene({required this.tab});

  final ValueNotifier<int> tab;

  static const _icons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.photo_library_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      extendBody: true,
      body: const ColorfulBackdrop(header: SizedBox.shrink()),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ValueListenableBuilder(
            valueListenable: tab,
            builder: (context, selected, _) => LiquidTabBar(
              tabCount: _icons.length,
              selectedIndex: selected,
              onSelected: (index) => tab.value = index,
              height: 64,
              tabBuilder: (context, index, active) => Icon(
                _icons[index],
                color: active ? Colors.indigo : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
