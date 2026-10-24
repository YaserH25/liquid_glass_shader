import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'active_glass.dart';
import 'liquid_glass_shader_loader.dart';

/// Fills its box with what lies behind it, seen through liquid glass shaped
/// as a rounded rectangle filling the box ([radius]; a pill by default):
/// refracted toward the rim, split into colours there, lit along the top
/// edge, and lightly frosted. Wrap it in a clip of the same shape.
///
/// The shader only samples inside the glass, and saturation happens in it
/// rather than in a separate colour pass, so its cost stays with the glass's
/// own area on every GPU. The frost is the engine's blur, which downsamples
/// wide radii.
///
/// Without the shader, or with [refract] off (a lower quality tier), it
/// draws [fallback] instead (a frosted blur).
class GlassBackdrop extends SingleChildRenderObjectWidget {
  /// Glass with the given optics over whatever lies behind it.
  const GlassBackdrop({
    super.key,
    this.frost = 0,
    this.saturation = 1,
    this.fallback,
    required this.band,
    required this.bend,
    required this.dispersion,
    required this.specular,
    this.magnify = 1,
    this.radius = double.infinity,
    this.refract = true,
    this.backdropKey,
    super.child,
  });

  /// Shares the copy of what lies behind with other glass using the same
  /// key, so the engine copies the screen once for all of them. Glass that
  /// shares sees the screen as it was at the first sharing glass painted:
  /// only share between glass with nothing painted in between under them.
  final BackdropKey? backdropKey;

  /// Corner radius of the glass in logical pixels (capped at a pill).
  final double radius;

  /// Off draws [fallback] even when the shader is available.
  final bool refract;

  /// Blur sigma of the frost behind the glass (0 keeps it sharp).
  final double frost;

  /// Colour saturation of what shows through (1 = unchanged).
  final double saturation;

  /// Drawn instead when the shader is unavailable; none leaves the backdrop
  /// as it is.
  final ui.ImageFilter? fallback;

  /// How far in from the rim the glass curves, in logical pixels.
  final double band;

  /// How far the glass displaces the backdrop at the rim, in logical pixels.
  final double bend;

  /// Colour split at the rim, as a fraction of [bend].
  final double dispersion;

  /// Strength of the light caught along the rim (0 to 1).
  final double specular;

  /// Magnification of everything behind the glass.
  final double magnify;

  @override
  RenderGlassBackdrop createRenderObject(BuildContext context) =>
      RenderGlassBackdrop(
        frost: frost,
        saturation: saturation,
        fallback: fallback,
        band: band,
        bend: bend,
        dispersion: dispersion,
        specular: specular,
        magnify: magnify,
        radius: radius,
        refract: refract,
        backdropKey: backdropKey,
        devicePixelRatio: View.of(context).devicePixelRatio,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassBackdrop renderObject,
  ) {
    renderObject
      ..frost = frost
      ..saturation = saturation
      ..fallback = fallback
      ..band = band
      ..bend = bend
      ..dispersion = dispersion
      ..specular = specular
      ..magnify = magnify
      ..radius = radius
      ..refract = refract
      ..backdropKey = backdropKey
      ..devicePixelRatio = View.of(context).devicePixelRatio;
  }
}

/// The render object of [GlassBackdrop]: pushes a backdrop filter layer with
/// the refraction shader, or the fallback filter.
class RenderGlassBackdrop extends RenderProxyBox {
  /// Creates the render object; [GlassBackdrop] documents each value.
  RenderGlassBackdrop({
    required this._frost,
    required this._saturation,
    required this._fallback,
    required this._band,
    required this._bend,
    required this._dispersion,
    required this._specular,
    required this._magnify,
    required this._radius,
    required this._refract,
    required this._backdropKey,
    required this._devicePixelRatio,
  });

  BackdropKey? _backdropKey;
  set backdropKey(BackdropKey? value) =>
      _set(_backdropKey != value, () => _backdropKey = value);

  double _radius;
  set radius(double value) => _set(_radius != value, () => _radius = value);

  bool _refract;
  set refract(bool value) => _set(_refract != value, () => _refract = value);

  double _frost;
  set frost(double value) => _set(_frost != value, () => _frost = value);

  double _saturation;
  set saturation(double value) =>
      _set(_saturation != value, () => _saturation = value);

  ui.ImageFilter? _fallback;
  set fallback(ui.ImageFilter? value) =>
      _set(_fallback != value, () => _fallback = value);

  double _band;
  set band(double value) => _set(_band != value, () => _band = value);

  double _bend;
  set bend(double value) => _set(_bend != value, () => _bend = value);

  double _dispersion;
  set dispersion(double value) =>
      _set(_dispersion != value, () => _dispersion = value);

  double _specular;
  set specular(double value) =>
      _set(_specular != value, () => _specular = value);

  double _magnify;
  set magnify(double value) => _set(_magnify != value, () => _magnify = value);

  double _devicePixelRatio;
  set devicePixelRatio(double value) =>
      _set(_devicePixelRatio != value, () => _devicePixelRatio = value);

  void _set(bool changed, VoidCallback apply) {
    if (!changed) return;
    apply();
    markNeedsPaint();
  }

  /// Two shaders used in turn. A filter made from the same shader compares
  /// equal, so the layer would keep the last frame's uniforms; alternating
  /// also never rewrites a shader the previous frame may still be drawing.
  final List<ui.FragmentShader> _shaders = [];
  int _turn = 0;

  @override
  bool get alwaysNeedsCompositing => true;

  /// Where the glass was on screen when its shader was last set up.
  ///
  /// The shader places the glass by its on-screen rect, but an ancestor can
  /// move it without repainting it (a page transition slides the tab bar),
  /// which would leave the refraction where the glass used to be. So after
  /// every frame the glass checks where it is now and repaints if it moved.
  /// Post-frame callbacks do not cause frames, so an idle screen costs
  /// nothing.
  Rect? _paintedRect;
  bool _watching = false;

  Rect _onScreenRect() =>
      MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);

  void _watchPosition() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      final painted = _paintedRect;
      if (!attached || painted == null || !hasSize) return;
      final now = _onScreenRect();
      if ((now.topLeft - painted.topLeft).distance > 0.5 ||
          (now.bottomRight - painted.bottomRight).distance > 0.5) {
        markNeedsPaint();
      }
      _watchPosition();
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    activeGlassSurfaces++;
    LiquidGlassShader.ensureLoaded();
    LiquidGlassShader.program.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    LiquidGlassShader.program.removeListener(markNeedsPaint);
    activeGlassSurfaces--;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final filter = _filter();
    if (filter == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    // The shaders are left to the garbage collector when this goes away:
    // the last frame may still be drawing with them.
    final backdrop = layer as BackdropFilterLayer? ?? BackdropFilterLayer();
    layer = backdrop
      ..filter = filter
      ..backdropKey = _backdropKey;
    context.pushLayer(backdrop, super.paint, offset);
  }

  ui.ImageFilter? _filter() {
    final program = LiquidGlassShader.program.value;
    if (program == null || !_refract) {
      _paintedRect = null;
      return _fallback;
    }
    if (_shaders.isEmpty) {
      _shaders.addAll([program.fragmentShader(), program.fragmentShader()]);
    }
    final shader = _shaders[_turn];
    _turn = 1 - _turn;

    // The backdrop texture covers the whole view in physical pixels, so the
    // glass is placed by where this box is on screen right now (after any
    // scaling or transforms above it).
    final ratio = _devicePixelRatio;
    final rect = _onScreenRect();
    _paintedRect = rect;
    _watchPosition();
    var i = 2; // 0 and 1 are the texture size, set by the engine.
    void put(double value) => shader.setFloat(i++, value);
    put(rect.left * ratio);
    put(rect.top * ratio);
    put(rect.right * ratio);
    put(rect.bottom * ratio);
    final scale = rect.height / (size.height == 0 ? 1 : size.height);
    put(math.min(_radius * scale, rect.shortestSide / 2) * ratio);
    put(_band * scale * ratio);
    put(_bend * scale * ratio);
    put(_dispersion);
    put(_magnify);
    put(_specular);
    put(_saturation);

    final refraction = ui.ImageFilter.shader(shader);
    if (_frost <= 0) return refraction;
    return ui.ImageFilter.compose(
      outer: refraction,
      inner: ui.ImageFilter.blur(sigmaX: _frost, sigmaY: _frost),
    );
  }
}
