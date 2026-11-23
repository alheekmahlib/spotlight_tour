import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Where the step's swipe indicator should be while a [PageSwipeDemo] runs.
///
/// The tour overlay reads one of these per animation tick (see
/// [PageSwipeDemo.indicator]) and paints the gliding orb to match the real
/// page: same eased position, same direction — which flips between the
/// outward turn and the return.
class PageSwipeDemoIndicator {
  const PageSwipeDemoIndicator({
    required this.fraction,
    required this.leftToRight,
    required this.opacity,
  });

  /// Horizontal position of the orb's head as a 0..1 fraction of the
  /// target's width (0 = left edge, 1 = right edge), mirroring how far the
  /// page itself has slid.
  final double fraction;

  /// Travel direction of the CURRENT leg: the requested direction on the
  /// outward turn, the opposite on the return.
  final bool leftToRight;

  /// 0..1 fade of the orb: fades in at the start of the turn and out at the
  /// end of the return.
  final double opacity;
}

/// Demonstrates a page swipe on a [PageController] by actually turning the
/// page — one full page in the demonstrated direction, a short hold, then a
/// full turn back to the exact offset the user was reading.
///
/// This is the automatic alternative to a "try it yourself" swipe step
/// (`TourStep.requireInteraction`): instead of asking the user to swipe,
/// the tour performs the gesture on the real `PageView`, at a pace the user
/// can follow, and ends exactly where they were:
///
/// - The turn covers a WHOLE page: the page visibly flips over and back,
///   like a real swipe. The starting page is not assumed to be zero; the
///   exact starting offset is restored afterwards.
/// - Because the turn crosses the page boundary, a `PageView` fires its
///   `onPageChanged` callback — once on the outward turn and once on the
///   return. If your app reacts to `onPageChanged` (loading data, updating
///   state), ignore those transient calls while the demo runs:
///
///   ```dart
///   onPageChanged: (i) {
///     if (_swipeDemo.isRunning) return; // tour demonstration, not the user
///     // ...normal handling...
///   },
///   ```
///
/// - Before the page moves at all, [demonstrate] waits [settleDuration]
///   with the page still and the indicator parked at the starting edge,
///   so the user first sees the step itself (its card and spotlight) and
///   only then watches the page turn. Set it to [Duration.zero] for the
///   old immediate behaviour.
/// - [cancel] restores the starting offset immediately. You do not need to
///   wire this yourself: when the step sets `TourStep.swipeDemo`, the tour
///   runs [demonstrate] automatically once the step has appeared (in the
///   direction of the step's `TourIndicator`), and cancels it whenever the
///   step is left — Next, Previous, skip or finish. Manual wiring through
///   `onEnter`/`onExit` keeps working: [demonstrate] is a no-op while a
///   run is in flight and [cancel] is safe to call when idle.
/// - At the scroll edge where the demonstrated direction has no full page
///   of room (e.g. demonstrating a left-to-right swipe while on the last
///   page of an RTL reader), [demonstrate] is a safe no-op: it never shows
///   the OPPOSITE gesture in place of the requested one. The step's
///   indicator ([TourIndicator.swipeLeftToRight]) still shows the
///   direction.
/// - While it runs, [indicator] publishes where the step's swipe indicator
///   should be; pass the demo to `TourStep.swipeDemo` and the orb on the
///   spotlight glides WITH the page, rightward on the outward turn and
///   leftward on the way back, instead of looping on its own.
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
///   swipeDemo: _swipeDemo, // the tour runs and cancels the demo itself
///   // ...
/// );
/// ```
///
/// Honours the system's reduced-motion setting by *not being run*: the
/// tour's automatic run skips it under `MediaQuery.disableAnimations`, the
/// same rule the tour applies to its own indicator. If you call
/// [demonstrate] yourself instead (see `TourStep.autoRunSwipeDemo`), make
/// the same check first.
class PageSwipeDemo {
  PageSwipeDemo({
    required this.pageController,
    required TickerProvider vsync,
    this.settleDuration = const Duration(milliseconds: 1000),
    this.turnDuration = const Duration(milliseconds: 850),
    this.holdDuration = const Duration(milliseconds: 450),
    this.curve = Curves.easeInOutCubic,
  }) : _ctrl = AnimationController(vsync: vsync);

  /// The controller of the `PageView` to demonstrate on.
  final PageController pageController;

  /// Pause with the page still before the turn starts. The step that
  /// triggered the demonstration has just appeared — its card is sliding
  /// in and its spotlight gliding over — so the turn waits for the user to
  /// actually see it instead of firing the instant the step arrives.
  /// During the wait the indicator is parked at the starting edge, fading
  /// in. Default 1000 ms; [Duration.zero] restores the immediate start.
  final Duration settleDuration;

  /// Duration of each full-page turn, out and back. Default 850 ms — slow
  /// enough that the flip reads as a real page turn, not a flicker.
  final Duration turnDuration;

  /// Pause on the turned-to page before returning. Default 450 ms.
  final Duration holdDuration;

  /// Curve of both turns.
  final Curve curve;

  final AnimationController _ctrl;
  final ValueNotifier<PageSwipeDemoIndicator?> _indicator =
      ValueNotifier(null);

  /// Starting pixels of the in-flight demonstration, or `null` when idle.
  double? _startPixels;
  double _delta = 0;

  /// Whether a demonstration is currently running. Apps with an
  /// `onPageChanged` handler should ignore page changes while this is true
  /// (see the class docs).
  bool get isRunning => _startPixels != null;

  /// Indicator state mirroring the running demonstration, `null` while
  /// idle. The tour overlay listens to this when the step sets
  /// `TourStep.swipeDemo`.
  ValueListenable<PageSwipeDemoIndicator?> get indicator => _indicator;

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

  /// Waits [settleDuration] with the page still, then turns the page fully
  /// toward [direction], holds, and turns back to the exact offset the
  /// demonstration started from. No-op while another demonstration is
  /// running, when the `PageView` is not attached, or when the scroll edge
  /// leaves no full page of room in [direction].
  ///
  /// Completes when the page is back at its starting offset; a [cancel]
  /// mid-flight completes it early, after restoring the offset.
  Future<void> demonstrate(TourSwipeDirection direction) async {
    if (_startPixels != null || !pageController.hasClients) return;
    final position = pageController.position;
    final start = position.pixels;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final sign = _signFor(position.axisDirection, direction);

    // A full turn needs a full page of room. If the demonstrated direction
    // has none at this edge (last page of an RTL reader, first page of an
    // LTR one), do nothing rather than silently showing the opposite
    // gesture — the caller asked for THIS direction.
    final delta = (start + sign * viewport)
            .clamp(position.minScrollExtent, position.maxScrollExtent) -
        start;
    if (delta.abs() < viewport * 0.98) return; // No full page this way.

    _startPixels = start;
    _delta = delta;
    final settle = settleDuration.inMicroseconds;
    final turn = turnDuration.inMicroseconds;
    final hold = holdDuration.inMicroseconds;
    final total = settle + 2 * turn + hold;
    _ctrl.duration = Duration(microseconds: total);
    final requestedLtr = direction == TourSwipeDirection.leftToRight;

    double factorAt(int us) {
      if (us <= settle) return 0;
      if (us < settle + turn) return curve.transform((us - settle) / turn);
      if (us < settle + turn + hold) return 1.0;
      final back = ((us - settle - turn - hold) / turn).clamp(0.0, 1.0);
      return 1.0 - curve.transform(back);
    }

    double lastPixels = double.nan;
    void apply() {
      final us = (_ctrl.value * total).round();
      final f = factorAt(us);
      // The page can be disposed mid-demo (app popped the route); the
      // cancel path restores via jumpTo, so only drive while attached.
      if (pageController.hasClients) {
        final px = start + _delta * f;
        // Skip no-op jumps: an unneeded jumpTo restarts the scroll
        // position's idle ballistic every frame of the hold.
        if (px != lastPixels) {
          lastPixels = px;
          pageController.jumpTo(px);
        }
      }
      // The indicator follows the page itself: parked at the starting
      // edge while the settle elapses (fading in), then the same eased
      // fraction as the page, with the travel direction flipping on the
      // return leg.
      final onReturnLeg = us >= settle + turn + hold;
      _indicator.value = PageSwipeDemoIndicator(
        fraction: requestedLtr ? f : 1.0 - f,
        leftToRight: onReturnLeg ? !requestedLtr : requestedLtr,
        opacity: us < settle && settle > 0
            ? (us / (settle * 0.6)).clamp(0.0, 1.0)
            : ((total - us) / (turn * 0.18)).clamp(0.0, 1.0),
      );
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
        _indicator.value = null;
      }
    }
  }

  /// Immediately restores the offset captured when the in-flight
  /// [demonstrate] started — even if the page has already committed to the
  /// turned-to page. Safe to call when idle, from skip/finish handlers and
  /// from `dispose`.
  void cancel() {
    final start = _startPixels;
    if (start == null) return;
    _startPixels = null; // First: the completing run must not re-restore.
    _indicator.value = null;
    _ctrl.stop();
    if (pageController.hasClients) pageController.jumpTo(start);
  }

  /// Releases the animation controller. Call from the owning State's
  /// `dispose`.
  void dispose() {
    cancel();
    _indicator.dispose();
    _ctrl.dispose();
  }
}
