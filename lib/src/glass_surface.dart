import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'glass_backdrop.dart';
import 'glass_look.dart';
import 'glass_quality.dart';
import 'glass_rim_painter.dart';
import 'glass_scope.dart';
import 'glass_style.dart';
import 'liquid_glass_shader_loader.dart';

/// Liquid glass behind [child], in the style of iOS 26, drawn by Flutter so
/// Android shows the same thing. Use it for chrome that floats over content
/// (bars, sheets, floating controls), never for content itself.
///
/// What it draws depends on the quality tier ([GlassScope.qualityOf]):
/// refracting glass with the shader, a frosted blur without it, or an
/// opaque surface under high contrast or when the device is struggling.
/// Its look follows the scope's style unless [style] forces one. A sheen
/// brightens the top half and a rim catches the light along the edge.
class GlassSurface extends StatefulWidget {
  /// Glass behind [child].
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.style,
    this.look,
    this.shadows,
    this.padding = EdgeInsets.zero,
    this.edge = true,
    this.rim = true,
    this.strength = 1,
    this.shareBackdrop = false,
  });

  /// What sits on the glass.
  final Widget child;

  /// The glass's corners; none makes a pill.
  final BorderRadiusGeometry? borderRadius;

  /// Forces a style where readability needs it; none follows the scope.
  final GlassStyle? style;

  /// A custom look; overrides [style].
  final GlassLook? look;

  /// Shadows outside the glass; they are never drawn under it.
  final List<BoxShadow>? shadows;

  /// Space between the glass's edge and [child].
  final EdgeInsetsGeometry padding;

  /// Draws the outer hairline that separates the glass from light pages.
  final bool edge;

  /// Draws the light-catching rim; off for edge-to-edge bars.
  final bool rim;

  /// How much glass there is, 0 to 1: frost, refraction, tint, sheen and rim
  /// all scale with it, so glass can fade in (a large title collapsing). At
  /// 0 nothing is drawn behind [child].
  final double strength;

  /// Shares the engine's copy of the screen behind with other glass that
  /// shares, under the same [GlassScope], so the screen is copied once for
  /// all of them each frame.
  ///
  /// Shared glass sees the screen as it was at the first shared glass
  /// painted, so only share glass that nothing else is painted under in
  /// between, and that sits farther from other shared glass than its frost
  /// blurs (about three times the frost): a title bar at the top and a tab
  /// bar at the bottom, not a pinned bar just above the tab bar, sheets or
  /// glass over glass. Inside a page
  /// it shares only while the page is the current one and nothing opens or
  /// closes over it; a page sliding in or out would be missing behind later
  /// shared glass.
  final bool shareBackdrop;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();

  static Color _fade(Color color, double k) =>
      color.withValues(alpha: color.a * k);

  /// A blur of [sigma] with colour [saturation]: the glass without the
  /// shader.
  static ImageFilter _frostFilter(double sigma, {double saturation = 1.8}) =>
      ImageFilter.compose(
        outer: _saturation(saturation),
        inner: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );

  /// A colour matrix that scales saturation by [amount] (1 = unchanged).
  static ColorFilter _saturation(double amount) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final inv = 1 - amount;
    return ColorFilter.matrix([
      r * inv + amount, g * inv, b * inv, 0, 0, //
      r * inv, g * inv + amount, b * inv, 0, 0, //
      r * inv, g * inv, b * inv + amount, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }
}

class _GlassSurfaceState extends State<GlassSurface> {
  final List<Animation<double>> _routeAnimations = [];

  /// Whether this glass shares the scope's backdrop now, and since when its
  /// page has been settled (in frame time).
  bool _shared = false;
  Duration? _settledSince;
  bool _waiting = false;

  /// How long a page must stay settled before its glass shares. A sheet or
  /// dialog closing over the page gives the page no animation to watch, and
  /// for the length of its exit it is still painted between this glass and
  /// later shared glass. Exits are shorter than this.
  static const Duration _settleDelay = Duration(milliseconds: 500);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchRoute();
    _update();
  }

  @override
  void didUpdateWidget(GlassSurface old) {
    super.didUpdateWidget(old);
    if (old.shareBackdrop != widget.shareBackdrop) {
      _watchRoute();
      _update();
    }
  }

  @override
  void dispose() {
    _watch(const []);
    super.dispose();
  }

  void _watchRoute() {
    final route = widget.shareBackdrop ? ModalRoute.of(context) : null;
    _watch([?route?.animation, ?route?.secondaryAnimation]);
  }

  void _watch(List<Animation<double>> animations) {
    for (final animation in _routeAnimations) {
      animation.removeStatusListener(_onRouteMoved);
    }
    _routeAnimations
      ..clear()
      ..addAll(animations);
    for (final animation in _routeAnimations) {
      animation.addStatusListener(_onRouteMoved);
    }
  }

  void _onRouteMoved(AnimationStatus _) => setState(_update);

  /// Whether this glass's page is the current one with nothing opening or
  /// closing over it.
  bool get _settled {
    if (!widget.shareBackdrop) return false;
    final route = ModalRoute.of(context);
    return route == null ||
        (route.isCurrent &&
            (route.animation?.isCompleted ?? true) &&
            (route.secondaryAnimation?.isDismissed ?? true));
  }

  /// Stops sharing at once when the page stops being settled, and starts
  /// sharing once it has been settled for [_settleDelay]. Callers rebuild.
  void _update() {
    if (!_settled) {
      _shared = false;
      _settledSince = null;
      return;
    }
    if (_shared || _waiting) return;
    _waiting = true;
    // Post-frame callbacks do not cause frames: an idle page waits for free.
    SchedulerBinding.instance.addPostFrameCallback(_checkSettled);
  }

  void _checkSettled(Duration _) {
    _waiting = false;
    if (!mounted || _shared || !_settled) return;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final since = _settledSince ??= now;
    if (now - since >= _settleDelay) {
      setState(() => _shared = true);
    } else {
      _waiting = true;
      SchedulerBinding.instance.addPostFrameCallback(_checkSettled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      // The tier depends on whether the shader has loaded.
      valueListenable: LiquidGlassShader.program,
      builder: (context, _, _) => _surface(context),
    );
  }

  Widget _surface(BuildContext context) {
    final quality = GlassScope.qualityOf(context);
    final theme = GlassScope.themeOf(context);
    final look =
        widget.look ?? theme.look(widget.style ?? GlassScope.styleOf(context));
    final k = widget.strength.clamp(0.0, 1.0);
    final radius = (widget.borderRadius ?? BorderRadius.circular(999)).resolve(
      Directionality.of(context),
    );

    final content = CustomPaint(
      foregroundPainter: widget.rim || widget.edge
          ? GlassRimPainter(
              borderRadius: radius,
              rim: widget.rim
                  ? GlassSurface._fade(theme.rim, k)
                  : const Color(0x00000000),
              edge: widget.edge ? GlassSurface._fade(theme.edge, k) : null,
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GlassSurface._fade(
            quality == GlassQuality.solid ? theme.solid : look.tint,
            k,
          ),
        ),
        child: DecoratedBox(
          // The sheen: light falling on the top half of the glass.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                theme.rim.withValues(alpha: look.sheen * k),
                theme.rim.withValues(alpha: 0),
              ],
            ),
          ),
          // Ink from buttons and list tiles paints on this, above the tint.
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );

    final glass = ClipRRect(
      borderRadius: radius,
      child: quality == GlassQuality.solid || k == 0
          ? content
          : GlassBackdrop(
              frost: look.frost * k,
              saturation: 1 + (look.saturation - 1) * k,
              fallback: GlassSurface._frostFilter(
                look.fallbackFrost * k,
                saturation: look.saturation,
              ),
              band: look.band,
              bend: look.bend * k,
              dispersion: look.dispersion,
              specular: look.specular * k,
              // One radius for the refraction: the smallest corner, so
              // square corners (a sheet's bottom) stay glass; the clip
              // rounds the rest.
              radius: [
                radius.topLeft.x,
                radius.topRight.x,
                radius.bottomLeft.x,
                radius.bottomRight.x,
              ].reduce(math.min),
              refract: quality == GlassQuality.refraction,
              backdropKey: _shared
                  ? BackdropGroup.of(context)?.backdropKey
                  : null,
              child: content,
            ),
    );

    final shadows = widget.shadows;
    if (shadows == null || shadows.isEmpty) return glass;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The shadow falls only outside the glass. Seen through the glass
        // it would darken it, and glass sharing a backdrop copy taken before
        // its own shadow was painted would look lighter than glass that
        // does not.
        Positioned.fill(
          child: ClipPath(
            clipper: _OutsideGlass(radius, shadows),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: shadows,
              ),
            ),
          ),
        ),
        glass,
      ],
    );
  }
}

/// Clips to everything around the glass, reaching far enough out to keep
/// the whole shadow.
class _OutsideGlass extends CustomClipper<Path> {
  _OutsideGlass(this.borderRadius, this.shadows);

  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  @override
  Path getClip(Size size) {
    final box = Offset.zero & size;
    final reach = shadows
        .map((s) => s.blurRadius * 2 + s.spreadRadius + s.offset.distance)
        .reduce(math.max);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(box.inflate(reach))
      ..addRRect(borderRadius.toRRect(box).scaleRadii());
  }

  @override
  bool shouldReclip(_OutsideGlass old) =>
      old.borderRadius != borderRadius || old.shadows != shadows;
}
