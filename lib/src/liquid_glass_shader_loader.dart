import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The refraction shader behind liquid glass. It needs Impeller; elsewhere
/// (Skia, web, widget tests) [program] stays null and glass falls back to a
/// frosted blur.
class LiquidGlassShader {
  LiquidGlassShader._();

  /// Where the shader is bundled. Assets of a package are keyed under
  /// `packages/<name>/`.
  static const String assetKey =
      'packages/liquid_glass_shader/shaders/liquid_glass.frag';

  /// The loaded shader program; null until it loads, and for good where the
  /// engine cannot run shader filters.
  static ValueListenable<ui.FragmentProgram?> get program => _program;
  static final _program = ValueNotifier<ui.FragmentProgram?>(null);
  static Future<void>? _loading;

  static Future<void> _load() async {
    try {
      _program.value = await ui.FragmentProgram.fromAsset(assetKey);
    } catch (error) {
      log('Liquid glass shader unavailable: $error', name: 'glass');
    }
  }

  /// Whether the shader has loaded.
  static bool get isReady => _program.value != null;

  /// Loads the shader once; safe to call repeatedly.
  static void ensureLoaded() {
    if (_loading != null || !ui.ImageFilter.isShaderFilterSupported) return;
    _loading = _load();
  }
}
