import 'dart:async';

import 'package:flutter/widgets.dart';

/// Direction of the swipe a [PageSwipeDemo] demonstrates.
enum TourSwipeDirection {
  /// The content slides from left to right — the gesture that turns to the
  /// next page in an RTL reader (e.g. a mushaf), or back to the previous
  /// page in an LTR one.
  leftToRight,

  /// The content slides from right to left.
  rightToLeft,
}

/// Demonstrates a page swipe on a [PageController] *without committing a
/// page change*: the page slides partway in the demonstrated direction,
/// pauses, then returns to the exact offset it started from.
///
/// This is the automatic alternative to a "try it yourself" swipe step
/// (`TourStep.requireInteraction`): instead of asking the user to swipe,
/// the tour shows the gesture itself on the real `PageView`, and the page
/// the user was reading never changes:
///
/// - The slide covers [fraction] of the viewport — always less than half a
///   page, so the page index (and any `onPageChanged` wiring in the app)
///   never flips, whatever page the user is on. The starting page is not
///   assumed to be zero; the exact starting offset is restored.
/// - [cancel] restores the starting offset immediately: wire it to the
///   step's `onExit` (or the controller's skip/dispose paths) so a skipped
///   or interrupted tour never leaves the page half-turned.
/// - At the scroll edge where the demonstrated direction has no room (e.g.
///   demonstrating a left-to-right swipe while on the last page of an RTL
///   reader), [demonstrate] is a safe no-op: it never shows the OPPOSITE
///   gesture in place of the requested one. The step's indicator
///   ([TourIndicator.swipeLeftToRight]) still shows the direction.
///
/// ```dart
/// final _swipeDemo = PageSwipeDemo(
///   pageController: _pageController,
///   vsync: this, // State with TickerProviderStateMixin
/// );
///
/// TourStep(
///   targetKey: _pageViewKey,
///   indicator: TourIndicator.swipeLeftToRight,
///   onEnter: () => unawaited(_swipeDemo.demonstrate(TourSwipeDirection.leftToRight)),
///   onExit: _swipeDemo.cancel,
///   // ...
/// );
/// ```
///
/// Honours the system's reduced-motion setting by *not being run*: check
/// `MediaQuery.of(context).disableAnimations` in `onEnter` and skip
/// [demonstrate], the same rule the tour applies to its own indicator.
class PageSwipeDemo {
  PageSwipeDemo({
    required this.pageController,
    required TickerProvider vsync,
    this.fraction = 0.42,
    this.moveDuration = const Duration(milliseconds: 600),
    this.holdDuration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOutCubic,
  })  : assert(fraction > 0 && fraction < 0.5,
            'The slide must stay under half a page so the page index never changes.'),
        _ctrl = AnimationController(vsync: vsync);

  /// The controller of the `PageView` to demonstrate on.
  final PageController pageController;

  /// How far the page slides, as a fraction of the viewport width. Must be
  /// under 0.5 so the settled page can never change. Default 0.42.
  final double fraction;

  /// Duration of the outward slide; the return slide takes the same time.
  final Duration moveDuration;

  /// Pause at the farthest point before returning.
  final Duration holdDuration;

  /// Curve of both slides.
  final Curve curve;

  final AnimationController _ctrl;

  /// Starting pixels of the in-flight demonstration, or `null` when idle.
  double? _startPixels;
  double _delta = 0;

  /// Whether a demonstration is currently running.
  bool get isRunning => _startPixels != null;

  static double _signFor(AxisDirection axis, TourSwipeDirection direction) {
    // Scroll offset semantics follow the axis direction: with
    // AxisDirection.right (LTR horizontal) a growing offset moves content
    // left; with AxisDirection.left (RTL horizontal) it moves content
    // right. A left-to-right swipe moves the *content* rightward.
    final contentRight = direction == TourSwipeDirection.leftToRight;
    switch (axis) {
      case AxisDirection.right:
        return contentRight ? -1 : 1;
      case AxisDirection.left:
        return contentRight ? 1 : -1;
      case AxisDirection.down:
        return contentRight ? -1 : 1;
      case AxisDirection.up:
        return contentRight ? 1 : -1;
    }
  }

  /// Slides the page partway toward [direction], holds, and returns to the
  /// exact offset the demonstration started from. No-op while another
  /// demonstration is running or when the `PageView` is not attached.
  ///
  /// Completes when the page is back at its starting offset; a [cancel]
  /// mid-flight completes it early, after restoring the offset.
  Future<void> demonstrate(TourSwipeDirection direction) async {
    if (_startPixels != null || !pageController.hasClients) return;
    final position = pageController.position;
    final start = position.pixels;
    final viewport = position.viewportDimension;
    final sign = _signFor(position.axisDirection, direction);
    final amount = viewport * fraction;

    // Stay strictly inside the scroll range. If the demonstrated
    // direction has no room at this edge (last page of an RTL reader,
    // first page of an LTR one), do nothing rather than silently showing
    // the opposite gesture — the caller asked for THIS direction.
    final target = start + sign * amount;
    final delta =
        target.clamp(position.minScrollExtent, position.maxScrollExtent) -
            start;
    if (delta.abs() < amount * 0.25) return; // No room this way: no-op.

    _startPixels = start;
    _delta = delta;
    final move = moveDuration.inMicroseconds;
    final hold = holdDuration.inMicroseconds;
    final total = 2 * move + hold;
    _ctrl.duration = Duration(microseconds: total);

    double factorAt(double t) {
      final us = (t * total).round();
      if (us <= 0) return 0;
      if (us < move) return curve.transform(us / move);
      if (us < move + hold) return 1.0;
      final back = ((us - move - hold) / move).clamp(0.0, 1.0);
      return 1.0 - curve.transform(back);
    }

    void apply() {
      // The page can be disposed mid-demo (app popped the route); the
      // cancel path restores via jumpTo, so only drive while attached.
      if (pageController.hasClients) {
        pageController.jumpTo(start + _delta * factorAt(_ctrl.value));
      }
    }

    _ctrl.addListener(apply);
    try {
      await _ctrl.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The provider was disposed mid-demo; nothing left to animate.
    } finally {
      _ctrl.removeListener(apply);
      // Only restore when this run is still the live one: cancel() already
      // jumped back and cleared the state, and a stale completion must not
      // fight a newer demonstration.
      if (_startPixels == start) {
        if (pageController.hasClients) pageController.jumpTo(start);
        _startPixels = null;
      }
    }
  }

  /// Immediately restores the offset captured when the in-flight
  /// [demonstrate] started. Safe to call when idle, from skip/finish
  /// handlers and from `dispose`.
  void cancel() {
    final start = _startPixels;
    if (start == null) return;
    _startPixels = null; // First: the completing run must not re-restore.
    _ctrl.stop();
    if (pageController.hasClients) pageController.jumpTo(start);
  }

  /// Releases the animation controller. Call from the owning State's
  /// `dispose`.
  void dispose() {
    cancel();
    _ctrl.dispose();
  }
}
