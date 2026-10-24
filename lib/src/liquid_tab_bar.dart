import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'glass_backdrop.dart';
import 'glass_lens.dart';
import 'glass_quality.dart';
import 'glass_scope.dart';
import 'glass_surface.dart';
import 'liquid_glass_shader_loader.dart';
import 'liquid_tab_bar_style.dart';

/// Builds tab [index] of a [LiquidTabBar]. [active] is true for the tab to
/// draw as current: the selected one, the one under a held lens, and every
/// tab in the magnified copy inside the lifted lens.
typedef LiquidTabBuilder = Widget Function(
  BuildContext context,
  int index,
  bool active,
);

/// A row of tabs in liquid glass, behaving like the iOS 26 tab bar:
///
/// * A finger down anywhere on the bar lifts the selected-tab lens and
///   brings it under the finger. Lifted, the lens is clear glass, larger
///   than the tab, and magnifies the tabs under it; the bar swells a little.
/// * Dragging moves the lens with the finger (it resists past the first and
///   last tab) and highlights the tab under it, with a selection tick for
///   each tab it crosses. [onSelected] is not called yet.
/// * Letting go selects the tab under the lens; the lens settles on it and
///   drops back into the bar.
/// * A change of [selectedIndex] from elsewhere slides the lens, stretched
///   along its path in proportion to its speed.
///
/// Reduced motion keeps the lens flat and moves it from tab to tab at once.
///
/// Tabs are passive content: the bar handles touch and screen readers, so a
/// tab must not add an `InkWell`, a `GestureDetector` or button semantics of
/// its own (a tap would select twice). Each tab is a button for screen
/// readers, with its selected state, labelled by the text [tabBuilder] draws. Tab wrappers are keyed
/// `ValueKey('liquid_tab_$index')`, the resting lens
/// `Key('liquid_tab_bar_lens')` and the lifted lens
/// `Key('liquid_tab_bar_lifted_lens')`, for tests.
class LiquidTabBar extends StatefulWidget {
  /// A bar of [tabCount] tabs with [selectedIndex] current.
  const LiquidTabBar({
    super.key,
    required this.tabCount,
    required this.tabBuilder,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
    this.inset = 4,
    this.shadows,
    this.style,
    this.haptics = true,
    this.shareBackdrop = false,
    this.minimized = false,
    this.onExpand,
    this.minimizedBuilder,
  }) : assert(tabCount > 0),
       assert(selectedIndex >= 0 && selectedIndex < tabCount);

  /// How many tabs there are.
  final int tabCount;

  /// Draws each tab.
  final LiquidTabBuilder tabBuilder;

  /// The current tab.
  final int selectedIndex;

  /// Called with the chosen tab on release, or on a screen-reader tap.
  final ValueChanged<int> onSelected;

  /// Height of the row of tabs, inside the glass.
  final double height;

  /// Inset of the tabs from the edge of the glass, on every side.
  final double inset;

  /// Shadows outside the bar's glass.
  final List<BoxShadow>? shadows;

  /// Lens motion and optics; [LiquidTabBarStyle.standard] by default.
  final LiquidTabBarStyle? style;

  /// A selection tick for each tab the lens crosses.
  final bool haptics;

  /// Shares the copy of the screen behind the bar with other glass that
  /// shares; see [GlassSurface.shareBackdrop]. The lifted lens never shares,
  /// because it refracts the bar's own tabs.
  final bool shareBackdrop;

  /// Shrinks the bar into a pill at its start edge that shows only the
  /// current tab ([minimizedBuilder]), as the iOS 26 tab bar does while a
  /// page scrolls down. The bar keeps its size, so the page does not move;
  /// touches beside the pill reach the page under the bar. A screen reader
  /// always gets the full bar.
  final bool minimized;

  /// Called when the minimized pill is tapped; expand the bar here.
  final VoidCallback? onExpand;

  /// Draws tab [index] inside the minimized pill; without it the tab from
  /// [tabBuilder] is scaled down to fit.
  final Widget Function(BuildContext context, int index)? minimizedBuilder;

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar>
    with TickerProviderStateMixin {
  /// Centre of the lens, in tab slots counted from the physical left.
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 at rest, 1 lifted under a finger (springs past both a little).
  late final AnimationController _lift = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 as the full bar, 1 shrunk into the minimized pill (springs past
  /// both a little).
  late final AnimationController _minimize = AnimationController.unbounded(
    vsync: this,
  );
  double? _minimizeTarget;

  final GlobalKey _rowKey = GlobalKey();

  /// Closes the gap between the lens and the finger after touch-down, by
  /// frame time.
  ///
  /// A spring restarted on every move never advances on a real touchscreen:
  /// moves arrive before every frame, so each frame is the first tick of a
  /// new spring and the lens freezes until the finger pauses. Instead the
  /// lens sits at the finger plus [_gap], and only the gap animates, so the
  /// lens moves with the finger from the first frame while the jump closes.
  late final Ticker _catchUp = createTicker(_onCatchUpTick);
  Duration _lastTick = Duration.zero;

  /// The jelly: how drawn out the lens is along its path (0 = round,
  /// negative while it wobbles back), driven each frame by how fast the lens
  /// actually moves, so it stretches with a swipe or a slide and rounds out
  /// with a wobble when it stops.
  late final Ticker _jelly = createTicker(_onJellyTick);
  final ValueNotifier<double> _stretch = ValueNotifier(0);
  double _stretchVelocity = 0;
  double _speed = 0;
  double _lastX = 0;
  Duration _jellyLast = Duration.zero;

  /// Where the finger is, in slots (with the rubber band past the ends), and
  /// how far the lens still is from it.
  double _finger = 0;
  double _gap = 0;

  /// The pointer being tracked, and the tab currently under it.
  int? _pointer;
  int? _hovered;
  bool? _wasRtl;

  int get _count => widget.tabCount;
  LiquidTabBarStyle get _style => widget.style ?? LiquidTabBarStyle.standard;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// Minimized only when asked, and never for a screen reader.
  bool get _showsMinimized =>
      widget.minimized && !MediaQuery.accessibleNavigationOf(context);

  /// Physical slot of a tab, or tab of a physical slot (the map is its own
  /// inverse).
  int _flip(int index) => Directionality.of(context) == TextDirection.rtl
      ? _count - 1 - index
      : index;

  @override
  void initState() {
    super.initState();
    _x.addListener(_wakeJelly);
  }

  void _wakeJelly() {
    if (_jelly.isActive || _reduceMotion) return;
    _jellyLast = Duration.zero;
    _lastX = _x.value;
    _jelly.start();
  }

  void _onJellyTick(Duration elapsed) {
    final seconds = (elapsed - _jellyLast).inMicroseconds / 1e6;
    _jellyLast = elapsed;
    if (seconds <= 0) return;

    final measured = (_x.value - _lastX) / seconds;
    _lastX = _x.value;
    _speed +=
        (measured - _speed) * (1 - math.exp(-seconds * _style.speedSmoothing));
    final target = math.min(
      _speed.abs() * _style.stretchPerSpeed,
      _style.maxStretch,
    );

    // The loose spring, in small fixed steps so it stays stable at any frame
    // rate.
    final spring = _style.jelly;
    var stretch = _stretch.value;
    var velocity = _stretchVelocity;
    for (var left = seconds; left > 0; left -= _jellyStep) {
      final step = math.min(left, _jellyStep);
      final force =
          spring.stiffness * (target - stretch) - spring.damping * velocity;
      velocity += force / spring.mass * step;
      stretch += velocity * step;
    }
    _stretchVelocity = velocity;

    final still =
        _speed.abs() < 0.01 && stretch.abs() < 0.001 && velocity.abs() < 0.01;
    // A resting finger stops it too: the next move sets _x, which wakes it.
    if (still && !_x.isAnimating) {
      _speed = 0;
      _stretchVelocity = 0;
      _stretch.value = 0;
      _jelly.stop();
    } else {
      _stretch.value = stretch;
    }
  }

  static const double _jellyStep = 1 / 240;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    if (_wasRtl != isRtl) {
      _wasRtl = isRtl;
      _x.value = _flip(widget.selectedIndex).toDouble();
    }
    _followMinimized();
  }

  /// Springs towards the minimized pill or the full bar, as asked; the
  /// first build starts there.
  void _followMinimized() {
    final target = _showsMinimized ? 1.0 : 0.0;
    if (target == _minimizeTarget) return;
    final first = _minimizeTarget == null;
    _minimizeTarget = target;
    if (target == 1 && _pointer != null) {
      _release();
      _settleOn(widget.selectedIndex);
    }
    if (first) {
      _minimize.value = target;
    } else {
      _springTo(_minimize, _style.minimize, target);
    }
  }

  @override
  void didUpdateWidget(LiquidTabBar old) {
    super.didUpdateWidget(old);
    if (old.tabCount != widget.tabCount) {
      // Slots are counted from the physical left, so in RTL the same tab
      // sits in a different slot once the count changes.
      _x.stop();
      _x.value = _flip(widget.selectedIndex).toDouble();
    } else if (_pointer == null && old.selectedIndex != widget.selectedIndex) {
      _settleOn(widget.selectedIndex);
    }
    if (old.minimized != widget.minimized) _followMinimized();
  }

  @override
  void dispose() {
    _x.removeListener(_wakeJelly);
    _jelly.dispose();
    _stretch.dispose();
    _catchUp.dispose();
    _x.dispose();
    _lift.dispose();
    _minimize.dispose();
    super.dispose();
  }

  void _springTo(
    AnimationController controller,
    SpringDescription spring,
    double target,
  ) {
    if (_reduceMotion) {
      controller.value = target;
      return;
    }
    controller
        .animateWith(
          SpringSimulation(
            spring,
            controller.value,
            target,
            controller.velocity,
          ),
        )
        // Land exactly on the target; the spring stops within a tolerance.
        .then((_) => controller.value = target);
  }

  void _settleOn(int index) =>
      _springTo(_x, _style.settle, _flip(index).toDouble());

  void _setLifted(bool lifted) {
    if (_reduceMotion) {
      _lift.value = 0;
      return;
    }
    _springTo(_lift, lifted ? _style.lift : _style.drop, lifted ? 1 : 0);
  }

  void _tick() {
    if (widget.haptics) HapticFeedback.selectionClick();
  }

  /// Follows the finger at [globalPosition]: moves the lens and updates the
  /// tab under it.
  void _track(Offset globalPosition, {bool jump = false}) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final slot = box.size.width / _count;
    final last = (_count - 1).toDouble();
    final raw = box.globalToLocal(globalPosition).dx / slot - 0.5;
    final nearest = raw.round().clamp(0, _count - 1);

    final tab = _flip(nearest);
    if (tab != (_hovered ?? widget.selectedIndex)) _tick();
    // Rebuilds every tab, so only when the tab under the finger changes.
    if (tab != _hovered) setState(() => _hovered = tab);

    _finger = _rubberBand(raw, last);
    if (_reduceMotion) {
      _x.value = nearest.toDouble();
    } else {
      if (jump) {
        // Glide under the finger from wherever the lens is.
        _x.stop();
        _gap = _x.value - _finger;
        _lastTick = Duration.zero;
        if (!_catchUp.isActive) _catchUp.start();
      }
      // Follow the finger in this frame, plus whatever gap is left.
      _x.value = _finger + _gap;
    }
  }

  void _onCatchUpTick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // Exponential decay: frame-rate independent, never overshoots.
    _gap *= math.exp(-seconds * _style.catchUp);
    if (_gap.abs() < 0.005) {
      _gap = 0;
      _catchUp.stop();
    }
    _x.value = _finger + _gap;
  }

  /// [raw] slot position, resisting more and more past the first and last
  /// slot so the lens never travels more than [LiquidTabBarStyle.rubberBand]
  /// beyond them.
  double _rubberBand(double raw, double last) {
    final over = raw < 0 ? -raw : raw - last;
    if (over <= 0) return raw;
    final reach = _style.rubberBand;
    final pulled = reach * (1 - 1 / (over / reach + 1));
    return raw < 0 ? -pulled : last + pulled;
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _setLifted(true);
    _track(event.position, jump: true);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer == _pointer) _track(event.position);
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final tab = _hovered ?? widget.selectedIndex;
    _release();
    _settleOn(tab);
    widget.onSelected(tab);
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _release();
    _settleOn(widget.selectedIndex);
  }

  void _release() {
    _catchUp.stop();
    _gap = 0;
    setState(() {
      _pointer = null;
      _hovered = null;
    });
    _setLifted(false);
  }

  /// A screen reader tapped tab [index].
  void _selectFromSemantics(int index) {
    if (index != widget.selectedIndex) _tick();
    widget.onSelected(index);
  }

  /// The tabs, drawn as in the bar ([forLens] draws every tab as current,
  /// for the magnified view inside the lifted lens).
  Widget _tabs({bool forLens = false}) => Row(
    children: [
      for (var i = 0; i < _count; i++)
        Expanded(
          child: forLens
              ? widget.tabBuilder(context, i, true)
              : Semantics(
                  key: ValueKey('liquid_tab_$i'),
                  container: true,
                  button: true,
                  selected: i == widget.selectedIndex,
                  onTap: () => _selectFromSemantics(i),
                  child: widget.tabBuilder(
                    context,
                    i,
                    i == (_hovered ?? widget.selectedIndex),
                  ),
                ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // Built once per state change, not per animation frame: the lens moves
    // over the same tab widgets, and each sits behind its own repaint
    // boundary so the moving lens does not repaint the labels.
    final tabs = RepaintBoundary(child: _tabs());
    final lensTabs = RepaintBoundary(child: _tabs(forLens: true));
    // Only while the pill shows or is shrinking away.
    final pill = _minimizeTarget == 1 || _minimize.value > 0
        ? widget.minimizedBuilder?.call(context, widget.selectedIndex) ??
              FittedBox(
                fit: BoxFit.scaleDown,
                child: widget.tabBuilder(context, widget.selectedIndex, true),
              )
        : null;
    // Its own layer, so a scrolling page does not repaint the bar.
    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _x,
            _lift,
            _stretch,
            _minimize,
            LiquidGlassShader.program,
          ]),
          builder: (context, _) => _bar(tabs, lensTabs, pill),
        ),
      ),
    );
  }

  Widget _bar(Widget tabs, Widget lensTabs, Widget? pill) {
    final lift = _lift.value;
    final lifted = lift > 0;
    final pressedLift = math.max(lift, 0.0);
    // At the refraction tier the lifted lens refracts the real tabs beneath
    // it; otherwise it shows a magnified copy over a cut-out.
    final refracts = GlassScope.qualityOf(context) == GlassQuality.refraction;
    final stretch = _reduceMotion ? 0.0 : _stretch.value;
    final minimize = _minimize.value.clamp(0.0, 1.0);
    final minimized = _minimizeTarget == 1;
    final fullHeight = widget.height + 2 * widget.inset;

    // The bar keeps its full box, so the page under it never moves; only the
    // glass shrinks towards the start edge, and the box around the pill
    // takes no touches.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final pillSize = _style.minimizedSize;
        return SizedBox(
          width: fullWidth,
          height: fullHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                start: 0,
                bottom: 0,
                width: lerpDouble(fullWidth, pillSize, minimize),
                height: lerpDouble(fullHeight, pillSize, minimize),
                child: _glass(
                  tabs,
                  lensTabs,
                  pill,
                  rowWidth: fullWidth - 2 * widget.inset,
                  lift: lift,
                  lifted: lifted,
                  pressedLift: pressedLift,
                  refracts: refracts,
                  stretch: stretch,
                  minimize: minimize,
                  minimized: minimized,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glass(
    Widget tabs,
    Widget lensTabs,
    Widget? pill, {
    required double rowWidth,
    required double lift,
    required bool lifted,
    required double pressedLift,
    required bool refracts,
    required double stretch,
    required double minimize,
    required bool minimized,
  }) {
    return Transform.scale(
      scale: 1 + (_style.pressedScale - 1) * pressedLift,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassSurface(
            shareBackdrop: widget.shareBackdrop,
            shadows: widget.shadows,
            padding: EdgeInsets.all(widget.inset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (minimize < 1)
                  IgnorePointer(
                    ignoring: minimized,
                    child: ExcludeSemantics(
                      excluding: minimized,
                      child: Opacity(
                        opacity: 1 - minimize,
                        // The row keeps its full width while the glass
                        // shrinks over it, so the tabs never squeeze.
                        child: OverflowBox(
                          alignment: AlignmentDirectional.centerStart,
                          minWidth: rowWidth,
                          maxWidth: rowWidth,
                          minHeight: widget.height,
                          maxHeight: widget.height,
                          child: _row(tabs, lift, lifted, refracts, stretch),
                        ),
                      ),
                    ),
                  ),
                if (pill != null && minimized)
                  Semantics(
                    button: true,
                    onTap: widget.onExpand,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onExpand,
                      child: _pillContent(pill, minimize),
                    ),
                  )
                else if (pill != null && minimize > 0)
                  _pillContent(pill, minimize),
              ],
            ),
          ),
          // The lifted lens stands over the bar, so it is drawn outside the
          // glass clip. Same inset as the glass content, so coordinates match.
          if (lifted)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(widget.inset),
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, constraints) => _liftedLens(
                        Size(constraints.maxWidth, widget.height),
                        lift,
                        stretch,
                        refracts: refracts,
                        lensTabs: lensTabs,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// [pill] fading with [minimize] where the pill sits, at the start edge,
  /// so it never drifts across the tabs while the bar grows.
  Widget _pillContent(Widget pill, double minimize) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: SizedBox.square(
      dimension: _style.minimizedSize - 2 * widget.inset,
      child: Center(
        child: Opacity(opacity: minimize, child: pill),
      ),
    ),
  );

  /// The row of tabs with the resting lens, taking the bar's touches.
  Widget _row(
    Widget tabs,
    double lift,
    bool lifted,
    bool refracts,
    double stretch,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, widget.height);
      final lens = _lensRect(size, lift, stretch);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: Stack(
          key: _rowKey,
          children: [
            // At rest the lens sits behind the tabs. With the shader it fades
            // out as the clear lens lifts over them, and back in as it drops,
            // so the two never swap in one frame.
            if (!lifted || refracts)
              Positioned.fromRect(
                rect: lens,
                child: Opacity(
                  opacity: 1 - lift.clamp(0.0, 1.0),
                  child: const GlassLens(key: Key('liquid_tab_bar_lens')),
                ),
              ),
            // Lifted without the shader, it covers them; cut its area out so
            // they only show magnified, inside it.
            ClipPath(
              clipper: lifted && !refracts ? _OutsideLens(lens) : null,
              child: tabs,
            ),
          ],
        ),
      );
    },
  );

  /// The lens in row coordinates: one slot at rest, larger as it lifts,
  /// drawn out along its path (and a little thinner) as it moves.
  Rect _lensRect(Size row, double lift, double stretch) {
    final slot = row.width / _count;
    final width = slot * (1 + (_style.liftedWidth - 1) * lift) * (1 + stretch);
    final height =
        row.height * (1 + (_style.liftedHeight - 1) * lift) / (1 + stretch / 2);
    return Rect.fromCenter(
      center: Offset((_x.value + 0.5) * slot, row.height / 2),
      width: width,
      height: height,
    );
  }

  Widget _liftedLens(
    Size row,
    double lift,
    double stretch, {
    required bool refracts,
    required Widget lensTabs,
  }) {
    final lens = _lensRect(row, lift, stretch);
    final magnification = 1 + (_style.magnification - 1) * lift;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          key: const Key('liquid_tab_bar_lifted_lens'),
          rect: lens,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (refracts)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: GlassBackdrop(
                    band: _style.lensBand,
                    bend: _style.lensBend * lift,
                    dispersion: _style.lensDispersion,
                    specular: _style.lensSpecular * lift,
                    magnify: magnification,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (refracts)
                // Clear glass whose rim and shadow fade with the lift; the
                // resting lens behind the tabs supplies the tint.
                Opacity(
                  opacity: lift.clamp(0.0, 1.0),
                  child: const GlassLens(lift: 1),
                )
              else ...[
                GlassLens(lift: lift),
                _magnifiedTabs(row, lens, magnification, lensTabs),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The tabs under [lens], magnified about its centre and aligned with the
  /// bar's own row.
  Widget _magnifiedTabs(
    Size row,
    Rect lens,
    double magnification,
    Widget lensTabs,
  ) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -lens.left,
          top: -lens.top,
          width: row.width,
          height: row.height,
          child: Transform.scale(
            scale: magnification,
            alignment: Alignment.topLeft,
            origin: lens.center,
            child: lensTabs,
          ),
        ),
      ],
    ),
  );
}

/// Clips to everything except [lens].
class _OutsideLens extends CustomClipper<Path> {
  _OutsideLens(this.lens);

  final Rect lens;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(
      RRect.fromRectAndRadius(lens, Radius.circular(lens.shortestSide / 2)),
    );

  @override
  bool shouldReclip(_OutsideLens old) => old.lens != lens;
}
