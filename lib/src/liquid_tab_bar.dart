import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_look.dart';
import 'glass_quality.dart';
import 'glass_scope.dart';
import 'glass_style.dart';
import 'glass_surface.dart';
import 'liquid_glass_shader_loader.dart';
import 'liquid_tab_bar_lens.dart';
import 'liquid_tab_bar_metrics.dart';
import 'liquid_tab_bar_motion.dart';
import 'liquid_tab_builder.dart';
import 'tab_bar/lens_motion.dart';
import 'tab_bar/lifted_lens.dart';
import 'tab_bar/minimized_pill.dart';
import 'tab_bar/resting_lens_row.dart';
import 'tab_bar/springs.dart';
import 'tab_bar/tab_bar_geometry.dart';
import 'tab_bar/tab_row.dart';

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
/// The bar takes the whole width it is given and [metrics.thickness] of
/// height. Its glass hugs the tabs, at [LiquidTabBarMetrics.tabExtent] each,
/// placed by [alignment], unless there is not room, when it fills the width;
/// touches beside the glass reach the page under the bar.
///
/// Reduced motion keeps the lens flat and moves it from tab to tab at once.
///
/// Tabs are passive content: the bar handles touch and screen readers, so a
/// tab must not add an `InkWell`, a `GestureDetector` or button semantics of
/// its own (a tap would select twice). Each tab is a button for screen
/// readers, with its selected state, labelled by the text [tabBuilder]
/// draws. Tab wrappers are keyed `ValueKey('liquid_tab_$index')`, the
/// resting lens `Key('liquid_tab_bar_lens')` and the lifted lens
/// `Key('liquid_tab_bar_lifted_lens')`, for tests.
class LiquidTabBar extends StatefulWidget {
  /// A bar of [tabCount] tabs with [selectedIndex] current.
  const LiquidTabBar({
    super.key,
    required this.tabCount,
    required this.tabBuilder,
    required this.selectedIndex,
    required this.onSelected,
    this.metrics = LiquidTabBarMetrics.stacked,
    this.motion,
    this.lens = LiquidTabBarLens.standard,
    this.alignment = Alignment.center,
    this.style,
    this.look,
    this.rim = true,
    this.edge = true,
    this.strength = 1,
    this.shadows,
    this.onTick = selectionClick,
    this.shareBackdrop = false,
    this.minimized = false,
    this.minimizedAlignment = AlignmentDirectional.bottomStart,
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

  /// The bar's sizes: [LiquidTabBarMetrics.stacked] by default.
  final LiquidTabBarMetrics metrics;

  /// How the lens moves: [LiquidTabBarMotion.standard] by default.
  final LiquidTabBarMotion? motion;

  /// How the lens looks: its tint and shadows, and its size and optics once
  /// lifted.
  final LiquidTabBarLens lens;

  /// Where the glass sits when it hugs its tabs: centred by default, as on
  /// iOS.
  final AlignmentGeometry alignment;

  /// Forces the bar's glass clear or frosted; none follows the
  /// [GlassScope]. See [GlassSurface.style].
  final GlassStyle? style;

  /// A look of the bar's own; overrides [style]. See [GlassSurface.look].
  final GlassLook? look;

  /// Draws the light-catching rim of the bar's glass.
  final bool rim;

  /// Draws the outer hairline that separates the bar from light pages.
  final bool edge;

  /// How much glass the bar has, 0 to 1; see [GlassSurface.strength].
  final double strength;

  /// Shadows outside the bar's glass.
  final List<BoxShadow>? shadows;

  /// Called each time the lens moves onto another tab, with that tab: as a
  /// finger drags it, or as a screen reader selects. Plays the selection
  /// click by default ([selectionClick]); null stays silent. Pass your own
  /// for a different haptic, a sound, or both.
  final ValueChanged<int>? onTick;

  /// The selection click of the platform: the default [onTick].
  static void selectionClick(int tab) => HapticFeedback.selectionClick();

  /// Shares the copy of the screen behind the bar with other glass that
  /// shares; see [GlassSurface.shareBackdrop]. The lifted lens never shares,
  /// because it refracts the bar's own tabs.
  final bool shareBackdrop;

  /// Shrinks the bar into a pill that shows only the current tab
  /// ([minimizedBuilder]), as the iOS 26 tab bar does while a page scrolls
  /// down. The bar keeps its size, so the page does not move; touches beside
  /// the pill reach the page under the bar. A screen reader always gets the
  /// full bar.
  final bool minimized;

  /// Where the pill sits: at the bottom of the start edge by default, as on
  /// iOS.
  final AlignmentGeometry minimizedAlignment;

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
  late final LensMotion _lens = LensMotion(vsync: this);

  /// 0 as the full bar, 1 shrunk into the minimized pill (springs past
  /// both a little).
  late final AnimationController _minimize = AnimationController.unbounded(
    vsync: this,
  );
  double? _minimizeTarget;

  /// The lens moving, lifting or drawing out; only the lens rebuilds.
  late final Listenable _lensMoves = Listenable.merge([
    _lens.position,
    _lens.lift,
    _lens.stretch,
  ]);

  /// The whole bar swelling a little while a finger is on it.
  late final Animation<double> _pressedScale = _lens.lift.drive(
    Animatable.fromCallback(
      (lift) => 1 + (_motion.pressedScale - 1) * math.max(lift, 0.0),
    ),
  );

  /// The tabs fading out as the bar shrinks into its pill, and the pill's
  /// tab fading in.
  late final Animation<double> _rowOpacity = _minimize.drive(
    Animatable.fromCallback((minimize) => 1 - minimize.clamp(0.0, 1.0)),
  );
  late final Animation<double> _pillOpacity = _minimize.drive(
    Animatable.fromCallback((minimize) => minimize.clamp(0.0, 1.0)),
  );

  final GlobalKey _rowKey = GlobalKey();

  /// The pointer being tracked, and the tab currently under it.
  int? _pointer;
  int? _hovered;
  bool? _wasRtl;

  int get _count => widget.tabCount;
  LiquidTabBarMetrics get _metrics => widget.metrics;
  LiquidTabBarMotion get _motion =>
      widget.motion ?? LiquidTabBarMotion.standard;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// Minimized only when asked, and never for a screen reader.
  bool get _showsMinimized =>
      widget.minimized && !MediaQuery.accessibleNavigationOf(context);

  TabBarGeometry get _geometry => TabBarGeometry(
    count: _count,
    rtl: Directionality.of(context) == TextDirection.rtl,
  );

  @override
  void initState() {
    super.initState();
    _lens.config = _motion;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lens.reduceMotion = _reduceMotion;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    if (_wasRtl != isRtl) {
      _wasRtl = isRtl;
      _lens.jumpTo(_geometry.flip(widget.selectedIndex).toDouble());
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
      springTo(
        _minimize,
        _motion.minimize,
        target,
        reduceMotion: _reduceMotion,
      );
    }
  }

  @override
  void didUpdateWidget(LiquidTabBar old) {
    super.didUpdateWidget(old);
    _lens.config = _motion;
    if (old.tabCount != widget.tabCount) {
      // Slots are counted from the physical left, so in RTL the same tab
      // sits in a different slot once the count changes.
      _lens.jumpTo(_geometry.flip(widget.selectedIndex).toDouble());
    } else if (_pointer == null && old.selectedIndex != widget.selectedIndex) {
      _settleOn(widget.selectedIndex);
    }
    if (old.minimized != widget.minimized) _followMinimized();
  }

  @override
  void dispose() {
    _lens.dispose();
    _minimize.dispose();
    super.dispose();
  }

  void _settleOn(int index) => _lens.settleOn(_geometry.flip(index).toDouble());

  void _tick(int tab) => widget.onTick?.call(tab);

  /// Follows the finger at [globalPosition]: moves the lens and updates the
  /// tab under it.
  void _track(Offset globalPosition, {bool jump = false}) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final geometry = _geometry;
    final raw = geometry.slotAt(box.globalToLocal(globalPosition), box.size);
    final nearest = raw.round().clamp(0, _count - 1);

    final tab = geometry.flip(nearest);
    if (tab != (_hovered ?? widget.selectedIndex)) _tick(tab);
    // Rebuilds every tab, so only when the tab under the finger changes.
    if (tab != _hovered) setState(() => _hovered = tab);

    _lens.follow(
      raw,
      nearest: nearest,
      last: (_count - 1).toDouble(),
      jump: jump,
    );
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _lens.setLifted(true);
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
    setState(() {
      _pointer = null;
      _hovered = null;
    });
    _lens.release();
  }

  /// A screen reader tapped tab [index].
  void _selectFromSemantics(int index) {
    if (index != widget.selectedIndex) _tick(index);
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    // Built once per state change, never per animation frame: the lens, the
    // swell and the shrink each animate on their own, over the same glass
    // and tab widgets. Each row of tabs sits behind its own repaint boundary
    // so the moving lens does not repaint the labels.
    final tabs = RepaintBoundary(
      child: TabRow(
        count: _count,
        tabBuilder: widget.tabBuilder,
        selected: widget.selectedIndex,
        active: _hovered ?? widget.selectedIndex,
        onSemanticsTap: _selectFromSemantics,
      ),
    );
    final lensTabs = RepaintBoundary(
      child: TabRow.magnified(count: _count, tabBuilder: widget.tabBuilder),
    );
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
        child: ValueListenableBuilder(
          // The tier, and so how the lifted lens draws, depends on the shader.
          valueListenable: LiquidGlassShader.program,
          builder: (context, _, _) => _bar(tabs, lensTabs, pill),
        ),
      ),
    );
  }

  Widget _bar(Widget tabs, Widget lensTabs, Widget? pill) {
    // At the refraction tier the lifted lens refracts the real tabs beneath
    // it; otherwise it shows a magnified copy over a cut-out.
    final refracts = GlassScope.qualityOf(context) == GlassQuality.refraction;
    final metrics = _metrics;
    final direction = Directionality.of(context);
    final barAlignment = widget.alignment.resolve(direction);
    final pillAlignment = widget.minimizedAlignment.resolve(direction);
    final pillSize = metrics.minimizedSize ?? metrics.thickness;

    // The bar keeps its whole box, so the page under it never moves; only
    // the glass in it hugs the tabs or shrinks into the pill, and the box
    // around the glass takes no touches.
    return LayoutBuilder(
      builder: (context, constraints) {
        final hug = _count * metrics.tabExtent + 2 * metrics.inset;
        final length = math.min(constraints.maxWidth, hug);
        assert(
          length.isFinite,
          'A LiquidTabBar that fills (an infinite tabExtent) needs a '
          'bounded width.',
        );
        final box =
            Offset.zero &
            Size(
              constraints.hasBoundedWidth ? constraints.maxWidth : length,
              metrics.thickness,
            );
        final bar = barAlignment.inscribe(Size(length, metrics.thickness), box);
        final shrunk = pillAlignment.inscribe(Size.square(pillSize), box);
        final glass = _glass(
          tabs,
          lensTabs,
          pill,
          row: Size(
            length - 2 * metrics.inset,
            metrics.thickness - 2 * metrics.inset,
          ),
          refracts: refracts,
          pillAlignment: pillAlignment,
          pillSize: pillSize,
        );
        return SizedBox.fromSize(
          size: box.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _minimize,
                child: glass,
                builder: (context, glass) => Positioned.fromRect(
                  rect: Rect.lerp(
                    bar,
                    shrunk,
                    _minimize.value.clamp(0.0, 1.0),
                  )!,
                  child: glass!,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The lens in a [row], where it is this frame.
  Rect _lensIn(Size row) => _geometry.lensRect(
    row,
    _lens.position.value,
    lift: _lens.lift.value,
    stretch: _reduceMotion ? 0.0 : _lens.stretch.value,
    lens: widget.lens,
    gap: _metrics.lensGap,
  );

  Widget _glass(
    Widget tabs,
    Widget lensTabs,
    Widget? pill, {
    required Size row,
    required bool refracts,
    required Alignment pillAlignment,
    required double pillSize,
  }) {
    final minimized = _minimizeTarget == 1;
    final inset = _metrics.inset;
    return ScaleTransition(
      scale: _pressedScale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassSurface(
            borderRadius: _metrics.borderRadius,
            style: widget.style,
            look: widget.look,
            rim: widget.rim,
            edge: widget.edge,
            strength: widget.strength,
            shareBackdrop: widget.shareBackdrop,
            shadows: widget.shadows,
            padding: EdgeInsets.all(inset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  ignoring: minimized,
                  child: ExcludeSemantics(
                    excluding: minimized,
                    child: FadeTransition(
                      opacity: _rowOpacity,
                      // The row keeps its full length while the glass
                      // shrinks over it towards the pill, so the tabs never
                      // squeeze.
                      child: OverflowBox(
                        alignment: Alignment(pillAlignment.x, 0),
                        minWidth: row.width,
                        maxWidth: row.width,
                        minHeight: row.height,
                        maxHeight: row.height,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: _onDown,
                          onPointerMove: _onMove,
                          onPointerUp: _onUp,
                          onPointerCancel: _onCancel,
                          child: AnimatedBuilder(
                            animation: _lensMoves,
                            builder: (context, _) => RestingLensRow(
                              key: _rowKey,
                              lens: _lensIn(row),
                              lift: _lens.lift.value,
                              refracts: refracts,
                              optics: widget.lens,
                              tabs: tabs,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (pill != null)
                  MinimizedPill(
                    opacity: _pillOpacity,
                    minimized: minimized,
                    alignment: pillAlignment,
                    size: pillSize - 2 * inset,
                    onTap: widget.onExpand,
                    child: pill,
                  ),
              ],
            ),
          ),
          // The lifted lens stands over the bar, so it is drawn outside the
          // glass clip. Same inset as the glass content, so coordinates match.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final row = Size(
                        constraints.maxWidth,
                        _metrics.thickness - 2 * inset,
                      );
                      return AnimatedBuilder(
                        animation: _lensMoves,
                        builder: (context, _) {
                          final lift = _lens.lift.value;
                          if (lift <= 0) return const SizedBox.shrink();
                          return LiftedLens(
                            lens: _lensIn(row),
                            row: row,
                            lift: lift,
                            refracts: refracts,
                            optics: widget.lens,
                            tabs: lensTabs,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
