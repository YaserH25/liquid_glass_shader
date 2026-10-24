import 'dart:ui';

import 'package:flutter/painting.dart';

/// The part of [bar], a tab bar's box on screen, that a separating fold or
/// hinge in [features] leaves for its glass, so no tab sits on the crease:
/// the side before the fold along [axis] when [toward] is negative, the
/// side after it when positive, and the larger side when it is 0 (the start
/// side, by [rtl], when they are even). Null when no separating fold crosses
/// the bar.
///
/// A hinge always separates; a fold only while the device is half open,
/// like a book or a laptop. A feature that runs along the bar rather than
/// across it is the app's to lay out around.
Rect? clearOfFolds(
  Rect bar,
  Iterable<DisplayFeature> features, {
  required Axis axis,
  required double toward,
  required bool rtl,
}) {
  final horizontal = axis == Axis.horizontal;
  for (final feature in features) {
    final separates =
        feature.type == DisplayFeatureType.hinge ||
        (feature.type == DisplayFeatureType.fold &&
            feature.state == DisplayFeatureState.postureHalfOpened);
    if (!separates) continue;
    final crease = feature.bounds;
    final across = horizontal
        ? crease.top <= bar.top && crease.bottom >= bar.bottom
        : crease.left <= bar.left && crease.right >= bar.right;
    final within = horizontal
        ? crease.left < bar.right && crease.right > bar.left
        : crease.top < bar.bottom && crease.bottom > bar.top;
    if (!across || !within) continue;

    final before = horizontal
        ? Rect.fromLTRB(bar.left, bar.top, crease.left, bar.bottom)
        : Rect.fromLTRB(bar.left, bar.top, bar.right, crease.top);
    final after = horizontal
        ? Rect.fromLTRB(crease.right, bar.top, bar.right, bar.bottom)
        : Rect.fromLTRB(bar.left, crease.bottom, bar.right, bar.bottom);
    if (toward < 0) return before;
    if (toward > 0) return after;
    double length(Rect side) => horizontal ? side.width : side.height;
    if (length(before) != length(after)) {
      return length(before) > length(after) ? before : after;
    }
    return horizontal && rtl ? after : before;
  }
  return null;
}
