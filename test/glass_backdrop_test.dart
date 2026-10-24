import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

Iterable<BackdropFilterLayer> _backdrops(WidgetTester tester) =>
    tester.layers.whereType<BackdropFilterLayer>();

void main() {
  test('loads the shader from the package', () {
    expect(
      LiquidGlassShader.assetKey,
      'packages/liquid_glass_shader/shaders/liquid_glass.frag',
    );
  });

  // Widget tests run without Impeller, so the refraction shader never loads
  // and the glass takes its fallback.
  test('the shader is unavailable without Impeller', () {
    expect(ui.ImageFilter.isShaderFilterSupported, isFalse);
    LiquidGlassShader.ensureLoaded();
    expect(LiquidGlassShader.isReady, isFalse);
  });

  testWidgets('without the shader the glass draws its frosted fallback', (
    tester,
  ) async {
    final fallback = ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 200,
          height: 60,
          child: GlassBackdrop(
            fallback: fallback,
            band: 16,
            bend: 10,
            dispersion: 0.1,
            specular: 0.3,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(_backdrops(tester).single.filter, fallback);
  });

  testWidgets('with no fallback it leaves the backdrop alone', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(
          width: 200,
          height: 60,
          child: GlassBackdrop(
            band: 16,
            bend: 10,
            dispersion: 0.1,
            specular: 0.3,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(_backdrops(tester), isEmpty);
  });
}
