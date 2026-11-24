import 'dart:async';

import 'package:flutter/widgets.dart';

import 'page_swipe_demo.dart';
import 'tour_theme.dart';

/// Shape of the spotlight cutout around a target widget.
enum TourTargetShape {
  /// Rounded rectangle (see [TourStep.borderRadius]).
  roundedRect,

  /// Circle fitted to the larger side of the target.
  circle,

  /// Follows the rendered lines of a text range inside the target widget,
  /// like a text selection: the contour wraps each line separately, so a
  /// selection that starts or ends mid-line leaves the rest of that line
  /// outside the highlight. Requires the target to be a [Text] or
  /// [RichText] widget; see [TourStep.textRange].
  textLines,
}

/// Which real gestures pass through the dimmed backdrop to the target widget
/// underneath, instead of being absorbed by the tour.
///
/// Used together with [TourStep.requireInteraction] to build steps that wait
/// for the user to actually perform the gesture in the app (long-press the
/// verse, swipe the page, ...) before the tour continues. The app's own
/// handler then calls `SpotlightTourController.next()`.
enum TourTargetInteraction {
  /// Default: the backdrop absorbs all touches.
  none,

  /// Taps inside the spotlight cutout reach the target widget.
  tap,

  /// Long-presses (and taps) inside the cutout reach the target widget.
  longPress,

  /// Horizontal/vertical drags (and taps) inside the cutout reach the
  /// target widget, e.g. to let the user really swipe a `PageView`.
  swipe,
}

/// What the small animated indicator on top of the highlighted target
/// demonstrates. The indicator never blocks gestures: on interactive steps
/// (see [TourStep.interaction]) the real gesture still passes through to the
/// app underneath.
enum TourIndicator {
  /// A white pulsing orb suggesting a tap (default).
  pulse,

  /// A white orb gliding from the target's left edge to its right edge with
  /// a short fading trail, demonstrating a left-to-right swipe — e.g.
  /// turning to the next page of a mushaf.
  swipeLeftToRight,

  /// Same demonstration, gliding from right to left.
  swipeRightToLeft,
}

/// A single step of the tour.
///
/// A step with a `null` [targetKey] is a "free" step: no spotlight is shown
/// and the tooltip card is centered on screen (used for the intro and the
/// closing step in the reference design).
class TourStep {
  const TourStep({
    this.targetKey,
    required this.title,
    required this.description,
    this.icon,
    this.shape = TourTargetShape.roundedRect,
    this.targetPadding = const EdgeInsets.all(8),
    this.borderRadius,
    this.textRange,
    this.pulseAlignment = Alignment.center,
    this.showPulse = true,
    this.indicator = TourIndicator.pulse,
    this.swipeDemo,
    this.autoRunSwipeDemo = true,
    this.onEnter,
    this.onNext,
    this.onExit,
    this.interaction = TourTargetInteraction.none,
    this.requireInteraction = false,
    this.interactionHint,
    this.targetTimeout,
    this.style,
    this.nextLabel,
    this.previousLabel,
    this.skipLabel,
  });

  /// Key of the widget to highlight. `null` means a centered card with no
  /// spotlight (intro / closing step).
  final GlobalKey? targetKey;

  /// Bold title inside the tooltip card.
  final String title;

  /// Body text inside the tooltip card.
  final String description;

  /// Optional small icon shown next to the "x of y" counter, as in the
  /// reference tour where each step carries its own glyph.
  final IconData? icon;

  /// Shape of the spotlight cutout.
  final TourTargetShape shape;

  /// Extra padding around the target bounds before drawing the spotlight.
  /// For [TourTargetShape.textLines] the padding is applied per line.
  final EdgeInsets targetPadding;

  /// Corner radius for [TourTargetShape.roundedRect] and
  /// [TourTargetShape.textLines]. Defaults to 16.
  final double? borderRadius;

  /// Character range inside the target's text that the contour should wrap,
  /// used only with [TourTargetShape.textLines]. Offsets are code-unit
  /// offsets into the plain string of the target [Text]/[RichText], exactly
  /// like a [TextSelection]. `null` highlights the whole string.
  ///
  /// Only text covered by the range is cut out of the dimmed backdrop:
  /// verses or paragraphs outside the range stay dimmed even when they share
  /// a line with the highlighted text.
  final TextRange? textRange;

  /// Where the white pulse orb sits inside the spotlight.
  final Alignment pulseAlignment;

  /// Whether the indicator animation plays on this step.
  final bool showPulse;

  /// What the indicator on this step demonstrates. Defaults to
  /// [TourIndicator.pulse]; use [TourIndicator.swipeLeftToRight] or
  /// [TourIndicator.swipeRightToLeft] on steps that teach a page swipe.
  /// Honours [showPulse], `SpotlightTourTheme.pulseRepeatCount` and the
  /// system's reduced-motion setting exactly like the pulse.
  final TourIndicator indicator;

  /// The [PageSwipeDemo] performing this step's page turn. When set (and
  /// [indicator] is a swipe direction), the tour runs the demonstration
  /// itself shortly after the step appears: the demo waits
  /// `PageSwipeDemo.settleDuration` with the page still — so the user first
  /// sees the step's card and spotlight — then turns the page in the
  /// direction of [indicator], and the indicator mirrors the real page:
  /// parked at the starting edge during the pause, gliding with the turn,
  /// then back with the return leg. The tour cancels a still-running
  /// demonstration whenever the step is left (Next, Previous, skip or
  /// finish), so the page is never left half-turned. No `onEnter`/`onExit`
  /// wiring is needed; see [autoRunSwipeDemo] to drive it manually.
  ///
  /// If the demo cannot run (reduced motion, or a scroll edge with no full
  /// page of room in the demonstrated direction) the indicator falls back
  /// to the looping [indicator] animation.
  final PageSwipeDemo? swipeDemo;

  /// Whether the tour itself runs [swipeDemo] when this step becomes
  /// active (default) and cancels it when the step is left. The direction
  /// comes from [indicator]; with [TourIndicator.pulse] no direction is
  /// known and nothing is auto-run. Set to false to call
  /// `PageSwipeDemo.demonstrate` yourself at a custom moment — the tour
  /// still cancels a running demonstration when the step is left, exactly
  /// like the documented `onExit: demo.cancel` wiring did.
  final bool autoRunSwipeDemo;

  /// Runs when this step becomes active, *before* its target is resolved.
  ///
  /// Use it to prepare the UI this step points at: open the same sheet your
  /// app opens, turn a page, expand a section. Return a [Future] to make the
  /// tour wait for it; the target is then resolved with [targetTimeout]
  /// retries, so widgets created by the action (e.g. the content of a modal
  /// bottom sheet) are found once they are laid out.
  ///
  /// Runs on forward and backward entry, so keep it idempotent.
  ///
  /// This is also what restores the step's UI when the user comes BACK to
  /// the step with the Previous button: pair it with [onExit] (open the
  /// sheet here, close it there) and returning to the step re-establishes
  /// exactly what it needs. Consecutive steps that point into the same UI
  /// (two steps inside one bottom sheet) should each open it here — an
  /// idempotent opener makes the second call a no-op — and only the last
  /// of them closes it in [onExit].
  final FutureOr<void> Function()? onEnter;

  /// Runs when the user confirms this step (the Next/Start/Done button) and
  /// is awaited before the tour moves on.
  ///
  /// This is the "the tour does things" hook: wire it to the same function
  /// your app uses for the real gesture (open the verse-options sheet, play
  /// the audio, close the panel). Because it is awaited, UI it creates
  /// exists before the next step resolves its target, and UI it destroys
  /// (e.g. popping a sheet) is gone before the next spotlight is measured.
  ///
  /// Only runs on forward moves (including the final Done confirmation), not
  /// when going back or when the tour is skipped.
  final FutureOr<void> Function()? onNext;

  /// Runs when the tour leaves this step — Next, Previous, skip or the
  /// final Done — and is awaited before the transition continues.
  ///
  /// Pair it with [onEnter] for UI a step needs while it is active:
  /// [onEnter] establishes it (on forward and backward entry), [onExit]
  /// tears it down. This is also the right place to cancel a still-running
  /// demonstration started in [onEnter] (see `PageSwipeDemo.cancel`), so a
  /// skipped or interrupted tour never leaves the app mid-animation.
  final FutureOr<void> Function()? onExit;

  /// Which gestures pass through the dimmed backdrop to the target widget
  /// underneath. See [TourTargetInteraction]. Default: [TourTargetInteraction.none]
  /// (the backdrop absorbs everything).
  final TourTargetInteraction interaction;

  /// When true, the primary button is replaced by [interactionHint] and the
  /// step only advances when the app itself calls
  /// `SpotlightTourController.next()` — typically from the real gesture
  /// handler that [interaction] lets through. Use this for "try it yourself"
  /// steps: the user actually swipes the page or long-presses the verse, the
  /// app reacts for real, and the tour continues.
  final bool requireInteraction;

  /// Text shown in place of the primary button while [requireInteraction]
  /// is true, e.g. "اسحب الصفحة للمتابعة". Defaults to
  /// [TourLabels.interactionHint].
  final String? interactionHint;

  /// Visual overrides for this step only, layered on the tour's theme:
  /// this step can have its own accent colour, card background, text
  /// styles, ... while every field left `null` in the style keeps the
  /// theme's value. See [TourStepStyle].
  final TourStepStyle? style;

  /// Replaces the primary button text on this step only (the tour's
  /// `TourLabels` apply when null).
  final String? nextLabel;

  /// Replaces the Previous button text on this step only.
  final String? previousLabel;

  /// Replaces the skip pill text on this step only.
  final String? skipLabel;

  /// How long to wait for [targetKey]'s widget to appear and be laid out
  /// before giving up and showing the card without a spotlight. Matters for
  /// targets created by [onEnter]/[onNext] (a sheet sliding in, a page
  /// turning). Defaults to 1200 ms.
  final Duration? targetTimeout;
}
