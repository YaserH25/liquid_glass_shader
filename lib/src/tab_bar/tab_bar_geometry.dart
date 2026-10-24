import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../liquid_tab_bar_lens.dart';

/// Where the tabs and the lens sit in a tab bar's row of [count] tabs, with
/// tab slots counted from the physical left.
@immutable
class TabBarGeometry {
  /// A row of [count] tabs; [rtl] puts the first tab on the right.
  const TabBarGeometry({required this.count, required this.rtl});

  /// How many tabs there are.
  final int count;

  /// Whether the first tab sits on the right.
  final bool rtl;

  /// The physical slot of a tab, or the tab in a physical slot (the map is
  /// its own inverse).
  int flip(int index) => rtl ? count - 1 - index : index;

  /// The slot position under [local], a point in a [row]: 0 at the centre
  /// of the first slot, 1 at the centre of the second.
  double slotAt(Offset local, Size row) => local.dx / (row.width / count) - 0.5;

  /// The lens on slot [position] of a [row]: at rest, the slot less [gap];
  /// larger as it [lift]s, by [LiquidTabBarLens.liftedExtent] and
  /// [LiquidTabBarLens.liftedThickness] at a lift of 1; and drawn out along
  /// its path, and a little thinner, by [stretch].
  Rect lensRect(
    Size row,
    double position, {
    required double lift,
    required double stretch,
    required LiquidTabBarLens lens,
    EdgeInsets gap = EdgeInsets.zero,
  }) {
    final slot = row.width / count;
    final resting = gap.deflateRect(
      Rect.fromLTWH(position * slot, 0, slot, row.height),
    );
    final width =
        resting.width * (1 + (lens.liftedExtent - 1) * lift) * (1 + stretch);
    final height =
        resting.height *
        (1 + (lens.liftedThickness - 1) * lift) /
        (1 + stretch / 2);
    return Rect.fromCenter(
      center: resting.center,
      width: width,
      height: height,
    );
  }
}
