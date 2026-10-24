import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../liquid_tab_bar_lens.dart';

/// Where the tabs and the lens sit in a tab bar's row of [count] tabs along
/// [axis], with tab slots counted from the physical left, or the top.
@immutable
class TabBarGeometry {
  /// A row of [count] tabs along [axis]; [rtl] puts the first tab of a
  /// horizontal row on the right.
  const TabBarGeometry({
    required this.count,
    required this.axis,
    required this.rtl,
  });

  /// How many tabs there are.
  final int count;

  /// The direction the tabs follow each other in.
  final Axis axis;

  /// Whether the first tab of a horizontal row sits on the right. A vertical
  /// row always runs from the top.
  final bool rtl;

  bool get _horizontal => axis == Axis.horizontal;

  /// The physical slot of a tab, or the tab in a physical slot (the map is
  /// its own inverse).
  int flip(int index) => _horizontal && rtl ? count - 1 - index : index;

  /// The slot position under [local], a point in a [row]: 0 at the centre
  /// of the first slot, 1 at the centre of the second.
  double slotAt(Offset local, Size row) => _horizontal
      ? local.dx / (row.width / count) - 0.5
      : local.dy / (row.height / count) - 0.5;

  /// The lens on slot [position] of a [row]: at rest, the slot less [gap];
  /// larger as it [lift]s, by [LiquidTabBarLens.liftedExtent] along the row
  /// and [LiquidTabBarLens.liftedThickness] across it at a lift of 1; and
  /// drawn out along the row, and a little thinner, by [stretch].
  Rect lensRect(
    Size row,
    double position, {
    required double lift,
    required double stretch,
    required LiquidTabBarLens lens,
    EdgeInsets gap = EdgeInsets.zero,
  }) {
    final Rect slot;
    if (_horizontal) {
      final length = row.width / count;
      slot = Rect.fromLTWH(position * length, 0, length, row.height);
    } else {
      final length = row.height / count;
      slot = Rect.fromLTWH(0, position * length, row.width, length);
    }
    final resting = gap.deflateRect(slot);
    final along =
        (_horizontal ? resting.width : resting.height) *
        (1 + (lens.liftedExtent - 1) * lift) *
        (1 + stretch);
    final across =
        (_horizontal ? resting.height : resting.width) *
        (1 + (lens.liftedThickness - 1) * lift) /
        (1 + stretch / 2);
    return Rect.fromCenter(
      center: resting.center,
      width: _horizontal ? along : across,
      height: _horizontal ? across : along,
    );
  }
}
