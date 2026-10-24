import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_quality.dart';
import 'glass_scope.dart';
import 'glass_surface.dart';
import 'liquid_glass_shader_loader.dart';
import 'liquid_tab_bar_style.dart';
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
  late final LensMotion _lens = LensMotion(vsync: this);

  /// 0 as the full bar, 1 shrunk into the minimized pill (springs past
  /// both a little).
  late final AnimationController _minimize = AnimationController.unbounded(
    vsync: this,
  );
  double? _minimizeTarget;

  final GlobalKey _rowKey = GlobalKey();

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

  TabBarGeometry get _geometry => TabBarGeometry(
    count: _count,
    rtl: Directionality.of(context) == TextDirection.rtl,
  );

  @override
  void initState() {
    super.initState();
    _lens.style = _style;
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
      springTo(_minimize, _style.minimize, target, reduceMotion: _reduceMotion);
    }
  }

  @override
  void didUpdateWidget(LiquidTabBar old) {
    super.didUpdateWidget(old);
    _lens.style = _style;
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

  void _tick() {
    if (widget.haptics) HapticFeedback.selectionClick();
  }

  /// Follows the finger at [globalPosition]: moves the lens and updates the
  /// tab under it.
  void _track(Offset globalPosition, {bool jump = false}) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final geometry = _geometry;
    final raw = geometry.slotAt(box.globalToLocal(globalPosition), box.size);
    final nearest = raw.round().clamp(0, _count - 1);

    final tab = geometry.flip(nearest);
    if (tab != (_hovered ?? widget.selectedIndex)) _tick();
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
    if (index != widget.selectedIndex) _tick();
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    // Built once per state change, not per animation frame: the lens moves
    // over the same tab widgets, and each sits behind its own repaint
    // boundary so the moving lens does not repaint the labels.
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
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _lens.position,
            _lens.lift,
            _lens.stretch,
            _minimize,
            LiquidGlassShader.program,
          ]),
          builder: (context, _) => _bar(tabs, lensTabs, pill),
        ),
      ),
    );
  }

  Widget _bar(Widget tabs, Widget lensTabs, Widget? pill) {
    final lift = _lens.lift.value;
    // At the refraction tier the lifted lens refracts the real tabs beneath
    // it; otherwise it shows a magnified copy over a cut-out.
    final refracts = GlassScope.qualityOf(context) == GlassQuality.refraction;
    final stretch = _reduceMotion ? 0.0 : _lens.stretch.value;
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
    required bool refracts,
    required double stretch,
    required double minimize,
    required bool minimized,
  }) {
    final row = Size(rowWidth, widget.height);
    Rect lensIn(Size row) => _geometry.lensRect(
      row,
      _lens.position.value,
      lift: lift,
      stretch: stretch,
      liftedWidth: _style.liftedWidth,
      liftedHeight: _style.liftedHeight,
    );
    return Transform.scale(
      scale: 1 + (_style.pressedScale - 1) * math.max(lift, 0.0),
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
                            child: RestingLensRow(
                              key: _rowKey,
                              lens: lensIn(row),
                              lift: lift,
                              refracts: refracts,
                              tabs: tabs,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (pill != null && (minimized || minimize > 0))
                  MinimizedPill(
                    minimize: minimize,
                    minimized: minimized,
                    size: _style.minimizedSize - 2 * widget.inset,
                    onTap: widget.onExpand,
                    child: pill,
                  ),
              ],
            ),
          ),
          // The lifted lens stands over the bar, so it is drawn outside the
          // glass clip. Same inset as the glass content, so coordinates match.
          if (lift > 0)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(widget.inset),
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final row = Size(constraints.maxWidth, widget.height);
                        return LiftedLens(
                          lens: lensIn(row),
                          row: row,
                          lift: lift,
                          refracts: refracts,
                          style: _style,
                          tabs: lensTabs,
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
