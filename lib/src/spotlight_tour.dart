import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import 'painters.dart';
import 'page_swipe_demo.dart';
import 'tooltip_card.dart';
import 'tour_controller.dart';
import 'tour_labels.dart';
import 'tour_step.dart';
import 'tour_theme.dart';

/// The resolved on-screen outline of a step's target.
class _SpotTarget {
  const _SpotTarget({required this.bounds, this.path, required this.lines});

  /// Bounding shape of the target: used for the morph animation, the
  /// indicator and the card placement.
  final RRect bounds;

  /// Precise cutout outline, or `null` to cut out [bounds]. Set for
  /// [TourTargetShape.textLines] steps: one continuous stepped contour
  /// around the per-line rects (see [steppedContourPath]).
  final Path? path;

  /// The outline as a list of rounded rects, top to bottom: one entry per
  /// rendered text line for [TourTargetShape.textLines] steps, a single
  /// entry ([bounds]) for rect/circle targets. The morph animates these
  /// line by line, so a text contour keeps its stepped, text-hugging shape
  /// through the whole glide instead of travelling as a plain rectangle.
  final List<RRect> lines;
}

/// Wraps a screen and shows the guided tour above it when its
/// [SpotlightTourController] is started.
///
/// ```dart
/// final controller = SpotlightTourController(steps: mySteps);
///
/// SpotlightTour(
///   controller: controller,
///   child: MyScreen(),
/// );
///
/// controller.start(); // e.g. on first launch or from a button
/// ```
class SpotlightTour extends StatefulWidget {
  const SpotlightTour({
    super.key,
    required this.controller,
    this.theme,
    this.labels = const TourLabels(),
    this.barrierDismissible = false,
    required this.child,
  });

  final SpotlightTourController controller;

  /// Defaults to [SpotlightTourTheme.gold].
  final SpotlightTourTheme? theme;

  /// Overridable strings; defaults are the Arabic labels of the reference tour.
  final TourLabels labels;

  /// Whether tapping the dimmed backdrop skips the tour. The reference tour
  /// only reacts to its own buttons, so the default is `false`.
  final bool barrierDismissible;

  final Widget child;

  @override
  State<SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<SpotlightTour>
    with TickerProviderStateMixin {
  late final AnimationController _scrimCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _morphCtrl;
  late final AnimationController _pulseCtrl;

  OverlayEntry? _entry;

  /// Step whose content is currently inside the card (lags the controller's
  /// index while the exit/enter animation runs).
  int _displayedIndex = 0;

  /// Cached result of the system's reduced-motion setting
  /// (`MediaQuery.disableAnimations`), refreshed when the tour starts and on
  /// every step transition. When true: no pulse, instant spotlight moves and
  /// a short fade instead of the card's slide.
  bool _reduceMotion = false;

  /// True when the pulse should not be painted: the step disables it,
  /// reduced motion is on, the theme sets `pulseRepeatCount: 0`, or a
  /// bounded pulse has finished its cycles on this step.
  bool _pulsesDone = true;

  /// Set when the card's content changed and its size must be re-measured
  /// after the next layout. Keeps a post-frame measurement callback from
  /// being registered on every animation frame (the 0.3.0 behaviour, which
  /// ran one callback per pulse tick for as long as the tour was visible).
  bool _cardSizeDirty = true;

  /// True while a step action / transition pipeline is running.
  bool _transitioning = false;

  /// True once the exit animation has started (skip/finish).
  bool _closing = false;

  /// The run generation this state is showing (see
  /// [SpotlightTourController.runGeneration]). A start() while the tour is
  /// visible bumps the generation without changing the index, which is how
  /// a restart from anywhere replaces the running tour cleanly.
  int _shownGeneration = 0;

  /// Current animated spotlight bounds (null = no cutout on this step).
  _SpotTarget? _target;
  RRect? _morphFrom;
  RRect? _morphTo;
  List<RRect>? _morphFromLines;
  List<RRect>? _morphToLines;

  /// Target-settling tracker: after a step activates, its target can still
  /// be moving (the page slide that advanced the tour is still settling, a
  /// sheet still animating in). The tracker re-resolves the outline every
  /// frame until it stays put for a few frames, so the highlight never
  /// freezes mid-gesture, offset from the real widget.
  int _settleStableFrames = 0;
  DateTime? _settleDeadline;
  int _settleGeneration = 0;

  /// The demo whose [PageSwipeDemo.indicator] this state currently listens
  /// to (see [_watchSwipeDemo]).
  PageSwipeDemo? _demoListened;

  /// Measured card size, used to place the card without overflowing.
  Size _cardSize = const Size(320, 220);
  final GlobalKey _cardKey = GlobalKey();

  /// Captured when the tour starts: the overlay sits above the app's
  /// [Directionality] (the Navigator's), so the card must re-apply it.
  TextDirection _textDirection = TextDirection.ltr;

  SpotlightTourTheme get _theme => widget.theme ?? SpotlightTourTheme.gold();

  /// The theme in effect for the displayed step: the tour's [theme] with
  /// the step's own [TourStep.style] applied on top ([TourStepStyle]).
  /// Durations and motion settings always come from the tour's theme.
  SpotlightTourTheme get _stepTheme {
    final steps = widget.controller.steps;
    if (steps.isEmpty || _displayedIndex >= steps.length) return _theme;
    return steps[_displayedIndex].style?.applyTo(_theme) ?? _theme;
  }

  @override
  void initState() {
    super.initState();
    _scrimCtrl = AnimationController(vsync: this);
    _cardCtrl = AnimationController(vsync: this, value: 0);
    _morphCtrl = AnimationController(vsync: this);
    _pulseCtrl = AnimationController(vsync: this);
    _pulseCtrl.addStatusListener(_onPulseStatus);
    widget.controller.addListener(_onController);
    // The controller may already be running: a central host is mounted once
    // for the app's lifetime, and a service can start a tour before the
    // first frame (or while the host was temporarily unmounted). Pick the
    // tour up as soon as we have a frame.
    if (widget.controller.status == TourStatus.running) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _entry == null &&
            widget.controller.status == TourStatus.running) {
          _show();
        }
      });
    }
  }

  @override
  void dispose() {
    _demoListened?.indicator.removeListener(_onDemoIndicator);
    widget.controller.removeListener(_onController);
    _entry?.remove();
    _scrimCtrl.dispose();
    _cardCtrl.dispose();
    _morphCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onController() {
    final c = widget.controller;
    switch (c.status) {
      case TourStatus.running:
        if (_entry == null) {
          _show();
        } else if (c.runGeneration != _shownGeneration && !_transitioning) {
          // start() was called again while a tour was visible: replace it
          // with the new run. Like a backward move, the leaving step's
          // onNext action does NOT run, but its onExit teardown does.
          unawaited(_goToStep(c.index, forward: false));
        } else if (c.index != _displayedIndex && !_transitioning) {
          // Backward moves (and restarts from a higher index) must not run
          // the leaving step's onNext action.
          unawaited(_goToStep(c.index, forward: c.index > _displayedIndex));
        }
      case TourStatus.closing:
        if (_entry != null && !_closing) unawaited(_closeFlow());
      case TourStatus.idle:
        break;
    }
  }

  void _show() {
    _closing = false;
    _textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _displayedIndex = widget.controller.index;
    _shownGeneration = widget.controller.runGeneration;
    _cardSizeDirty = true;
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);

    _scrimCtrl.duration = _scrimFade;
    _cardCtrl.duration = _cardEnter;
    _pulseCtrl.duration = _theme.pulseDuration;
    _scrimCtrl.forward(from: 0);
    _cardCtrl.forward(from: 0);

    // Resolve the first target after running the step's onEnter hook, the
    // same pipeline used between steps (minus the exit animation).
    unawaited(_goToStep(_displayedIndex, forward: true, initial: true));
  }

  // Durations honour the reduced-motion setting: a short fade replaces the
  // scrim/card motion and the spotlight jumps instead of gliding.
  Duration get _scrimFade => _reduceMotion
      ? const Duration(milliseconds: 120)
      : _theme.scrimFadeDuration;
  Duration get _cardEnter => _reduceMotion
      ? const Duration(milliseconds: 120)
      : _theme.cardEnterDuration;
  Duration get _cardExit => _reduceMotion
      ? const Duration(milliseconds: 100)
      : _theme.cardExitDuration;
  Duration get _morphDuration =>
      _reduceMotion ? Duration.zero : _theme.spotlightMorphDuration;

  /// Listens to the step's [PageSwipeDemo] while the step is active: when
  /// a synced demonstration ends, the looping indicator must NOT resume —
  /// the orb would teleport from the page's final position back into a
  /// loop cycle. The orb rests for the rest of the step instead. When the
  /// demo never ran (scroll edge, reduced motion) it publishes nothing and
  /// the loop keeps playing as the documented fallback.
  void _watchSwipeDemo(TourStep step) {
    final demo = step.swipeDemo;
    if (identical(demo, _demoListened)) return;
    _demoListened?.indicator.removeListener(_onDemoIndicator);
    _demoListened = demo;
    demo?.indicator.addListener(_onDemoIndicator);
  }

  void _onDemoIndicator() {
    final demo = _demoListened;
    if (demo == null) return;
    if (demo.indicator.value == null && !demo.isRunning && !_pulsesDone) {
      _pulsesDone = true;
      _pulseCtrl.stop();
      _entry?.markNeedsBuild();
    }
  }

  /// Runs the step's [PageSwipeDemo] when the step declares one (see
  /// [TourStep.autoRunSwipeDemo]): the tour owns the demonstration's
  /// timing, so the page starts turning only after the step's card and
  /// spotlight have appeared (the demo itself additionally waits
  /// [PageSwipeDemo.settleDuration] before the page moves). A step that
  /// still wires `onEnter` to [PageSwipeDemo.demonstrate] is unaffected:
  /// the demo is already running and this call is a no-op.
  void _autoRunSwipeDemo(TourStep step) {
    final demo = step.swipeDemo;
    if (demo == null || !step.autoRunSwipeDemo || _reduceMotion) return;
    final direction = switch (step.indicator) {
      TourIndicator.swipeLeftToRight => TourSwipeDirection.leftToRight,
      TourIndicator.swipeRightToLeft => TourSwipeDirection.rightToLeft,
      TourIndicator.pulse => null,
    };
    if (direction == null || demo.isRunning) return;
    unawaited(demo.demonstrate(direction));
  }

  /// (Re)starts the pulse for a step that just became active.
  ///
  /// The pulse is bounded by [SpotlightTourTheme.pulseRepeatCount]: after
  /// that many cycles the orb rests, so the overlay stops scheduling frames
  /// while the user reads. `null` repeats forever, `0` turns the pulse off.
  void _startPulse(TourStep step) {
    _pulseCtrl.stop();
    final count = _theme.pulseRepeatCount;
    if (!step.showPulse || _reduceMotion || count == 0) {
      if (!_pulsesDone) {
        _pulsesDone = true;
        _entry?.markNeedsBuild();
      }
      return;
    }
    _pulsesDone = false;
    _pulseCtrl.duration = _theme.pulseDuration;
    if (count == null) {
      _pulseCtrl.repeat();
    } else {
      _pulseCtrl.repeat(count: count);
    }
    _entry?.markNeedsBuild();
  }

  void _onPulseStatus(AnimationStatus status) {
    // A bounded pulse parks the controller at value 1.0, which would paint
    // a frozen bright orb: hide it instead.
    if (status == AnimationStatus.completed && !_pulsesDone) {
      _pulsesDone = true;
      _entry?.markNeedsBuild();
    }
  }

  /// Runs the last step's [TourStep.onNext] when the tour ended via its Done
  /// button (not via skip), then animates out.
  Future<void> _closeFlow() async {
    _closing = true;
    final c = widget.controller;
    if (_displayedIndex < c.steps.length) {
      final step = c.steps[_displayedIndex];
      // A page-turn demonstration still running on the closing step is
      // cancelled first, so the page is back where the user left it before
      // any teardown measures or moves it.
      step.swipeDemo?.cancel();
      if (c.finishedByConfirm) {
        try {
          await step.onNext?.call();
        } catch (_) {
          // A failing cleanup action must not trap the tour on screen.
        }
        if (!mounted || c.status != TourStatus.closing) return;
      }
      // The active step's teardown runs on BOTH endings — Done and skip —
      // so UI the step opened (a sheet, a running demo) is never left
      // behind when the tour goes away.
      try {
        await step.onExit?.call();
      } catch (_) {
        // Same policy as above.
      }
      if (!mounted || c.status != TourStatus.closing) return;
      _raiseEntry();
    }
    await _dismiss();
  }

  Future<void> _dismiss() async {
    _pulseCtrl.stop();
    _pulsesDone = true;
    _cardCtrl.duration = _cardExit;
    _scrimCtrl.reverseDuration = _scrimFade;
    try {
      await Future.wait(
          [_cardCtrl.reverse().orCancel, _scrimCtrl.reverse().orCancel]);
    } on TickerCanceled {
      // Disposed mid-animation.
    }
    if (!mounted) return;
    _entry?.remove();
    _entry = null;
    _closing = false;
    widget.controller.markClosed();
  }

  /// The full step-to-step pipeline:
  ///
  /// 1. capture the current target's bounds (before any action changes it)
  /// 2. forward moves: run the leaving step's [TourStep.onNext] and wait for
  ///    it — this is what makes the tour *do* things (open the app's sheet,
  ///    turn the page, ...)
  /// 3. both directions: run the leaving step's [TourStep.onExit], then the
  ///    card slides out; the entering step's [TourStep.onEnter] runs and is
  ///    awaited, so UI it prepares exists before measurement
  /// 4. the overlay re-raises itself above any route (sheet/dialog) those
  ///    actions pushed, then the new target is resolved, retrying every
  ///    frame until [TourStep.targetTimeout] for targets that appear late
  /// 5. spotlight glides over while the new card slides in.
  ///
  /// While this runs, the controller is busy: Next/Previous/Start calls are
  /// ignored, so double taps and reentrant calls from app handlers cannot
  /// interleave transitions.
  Future<void> _goToStep(int index,
      {required bool forward, bool initial = false}) async {
    final c = widget.controller;
    if (_transitioning) return;
    _transitioning = true;
    _shownGeneration = c.runGeneration;
    c.setBusy(true);
    // Read before any await: the setting can change between frames, and the
    // context is unsafe to use across the async gaps below.
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    try {
      // On a restart (start() while running) the controller's step list is
      // already the NEW tour's; the step actually on screen is the captured
      // replaced one. It is the one whose target and teardown belong to
      // this transition.
      final leaving = c.replacedStepForRestart ?? c.steps[_displayedIndex];
      c.clearReplacedStep();
      final fromTarget = _resolveTarget(leaving);

      bool aborted() =>
          !mounted ||
          c.status != TourStatus.running ||
          c.index != index;

      if (!initial) {
        if (forward) {
          try {
            await leaving.onNext?.call();
          } catch (_) {
            // A failing action must not wedge the tour: continue without it.
          }
          if (aborted()) return;
        }
        // The leaving step's teardown runs in BOTH directions (and on a
        // restart): a step must let go of its own UI before the next one
        // prepares its own. A page-turn demonstration is cancelled first,
        // restoring the page before the app's own teardown runs.
        leaving.swipeDemo?.cancel();
        try {
          await leaving.onExit?.call();
        } catch (_) {
          // Same policy as onNext above.
        }
        if (aborted()) return;
        _raiseEntry();

        _cardCtrl.duration = _cardExit;
        try {
          await _cardCtrl.reverse().orCancel;
        } on TickerCanceled {
          return;
        }
        if (aborted()) return;
      }

      _displayedIndex = index;
      _cardSizeDirty = true;
      final toStep = c.steps[index];
      try {
        await toStep.onEnter?.call();
      } catch (_) {
        // Same policy as onNext above.
      }
      if (aborted()) return;
      _raiseEntry();

      // The step's page-turn demonstration starts here — after the step's
      // own entrance began, never before — and is cancelled when the step
      // is left. The demo's settle delay keeps the page still until the
      // card and spotlight are on screen.
      _autoRunSwipeDemo(toStep);
      _watchSwipeDemo(toStep);

      final toTarget = await _resolveTargetWithWait(toStep);
      if (aborted()) return;

      _target = toTarget;
      // The target can still be moving (the page slide or sheet animation
      // that advanced the tour is still settling): keep the outline glued
      // to the real widget instead of freezing it mid-gesture.
      _trackTargetUntilSettled(toStep);
      if (!initial) {
        // The morph animates the outline between steps line by line (see
        // _animatedPath): a text-lines contour keeps its stepped,
        // text-hugging shape through the whole glide instead of travelling
        // as a plain rectangle and snapping at the end.
        _morphFrom = fromTarget?.bounds;
        _morphTo = toTarget?.bounds;
        _morphFromLines = fromTarget?.lines;
        _morphToLines = toTarget?.lines;
        _morphCtrl.duration = _morphDuration;
        _entry?.markNeedsBuild();
        unawaited(_morphCtrl.forward(from: 0).then((_) {
          _morphFrom = null;
          _morphTo = null;
          _morphFromLines = null;
          _morphToLines = null;
          if (mounted) _entry?.markNeedsBuild();
        }));
        _cardCtrl.duration = _cardEnter;
        unawaited(_cardCtrl.forward(from: 0));
      } else {
        _entry?.markNeedsBuild();
      }
      _startPulse(toStep);
    } finally {
      _transitioning = false;
      if (mounted && c.status == TourStatus.running) {
        c.setBusy(false);
      }
    }
  }

  /// Re-inserts the overlay entry on top of the [Overlay]'s stack.
  ///
  /// Routes pushed by step actions (a modal bottom sheet with the verse
  /// options, a dialog, ...) land *above* entries inserted earlier, which
  /// would hide the tour. Removing and re-inserting puts the tour back on
  /// top so its scrim and card cover the sheet and the sheet's widgets can
  /// be highlighted by key, exactly like widgets on the page below.
  void _raiseEntry() {
    final entry = _entry;
    if (entry == null || !mounted) return;
    entry.remove();
    Overlay.of(context).insert(entry);
  }

  /// Like [_resolveTarget], but for steps whose target may not exist yet
  /// (created by an awaited action, a sheet still sliding in, a page still
  /// turning): retries every frame until the target has laid-out bounds or
  /// [TourStep.targetTimeout] elapses.
  Future<_SpotTarget?> _resolveTargetWithWait(TourStep step) async {
    var target = _resolveTarget(step);
    if (target != null || step.targetKey == null) return target;
    final timeout = step.targetTimeout ?? const Duration(milliseconds: 1200);
    final deadline = DateTime.now().add(timeout);
    while (target == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 32));
      if (!mounted) return null;
      target = _resolveTarget(step);
    }
    return target;
  }

  /// Resolves the current outline of a step's target in overlay coordinates.
  _SpotTarget? _resolveTarget(TourStep? step) {
    final key = step?.targetKey;
    if (step == null || key == null) return null;
    final targetContext = key.currentContext;
    if (targetContext == null) return null;
    final box = targetContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || overlayBox == null) return null;

    final bounds = Offset.zero & overlayBox.size;
    final radius = Radius.circular(step.borderRadius ?? 16);

    if (step.shape == TourTargetShape.textLines && box is RenderParagraph) {
      final target = _resolveTextTarget(step, box, overlayBox, bounds, radius);
      if (target != null) return target;
      // Fall through to the plain widget bounds when the range resolves to
      // nothing (e.g. empty selection).
    }

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    var rect = topLeft & box.size;
    rect = step.targetPadding.inflateRect(rect);
    rect = rect.intersect(bounds);
    if (rect.isEmpty) return null;

    if (step.shape == TourTargetShape.circle) {
      final side = rect.longestSide;
      final square =
          Rect.fromCenter(center: rect.center, width: side, height: side);
      final r = RRect.fromRectAndRadius(square, Radius.circular(side / 2));
      return _SpotTarget(bounds: r, lines: [r]);
    }
    final r = RRect.fromRectAndRadius(rect, radius);
    return _SpotTarget(bounds: r, lines: [r]);
  }

  /// Builds the stepped contour around [TourStep.textRange] (or the whole
  /// string) inside a [RenderParagraph], one rounded rect per rendered line.
  ///
  /// Boxes come from [RenderParagraph.getBoxesForSelection], so they are
  /// physical rectangles: for RTL text a shorter line is already anchored to
  /// the right edge, exactly like a text selection.
  _SpotTarget? _resolveTextTarget(TourStep step, RenderParagraph paragraph,
      RenderBox overlayBox, Rect overlayBounds, Radius radius) {
    final plainText = paragraph.text.toPlainText();
    if (plainText.isEmpty) return null;
    final range = step.textRange ?? TextRange(start: 0, end: plainText.length);
    final start = range.start.clamp(0, plainText.length);
    final end = range.end.clamp(0, plainText.length);
    if (end <= start) return null;

    final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end));
    if (boxes.isEmpty) return null;

    // Convert to overlay coordinates and merge glyph-run boxes that share a
    // line into one rect per line.
    final lineRects = <Rect>[];
    final sorted = [...boxes]..sort((a, b) {
        final dy = a.top.compareTo(b.top);
        return dy != 0 ? dy : a.left.compareTo(b.left);
      });
    for (final box in sorted) {
      final topLeft = paragraph.localToGlobal(Offset(box.left, box.top),
          ancestor: overlayBox);
      final rect = Rect.fromLTWH(
          topLeft.dx, topLeft.dy, box.right - box.left, box.bottom - box.top);
      if (lineRects.isNotEmpty) {
        final last = lineRects.last;
        final overlap =
            math.min(rect.bottom, last.bottom) - math.max(rect.top, last.top);
        // Same visual line: glyph-run boxes on one line can have different
        // vertical extents (mixed font sizes, Arabic diacritics, embedded
        // numbers), but they overlap by most of the shorter box. Boxes on
        // different lines never overlap that much. A fixed top tolerance
        // would split such a line into two stacked strips, which the
        // outline then traces as a spurious rectangular bump.
        if (overlap > 0.5 * math.min(rect.height, last.height)) {
          lineRects[lineRects.length - 1] = last.expandToInclude(rect);
          continue;
        }
      }
      lineRects.add(rect);
    }

    // Make consecutive lines vertically contiguous (selection boxes are
    // tight to the glyphs, so line leading would otherwise split the
    // outline into separate shapes), then pad each line and clip to the
    // overlay.
    final padded = <Rect>[];
    for (var i = 0; i < lineRects.length; i++) {
      var r = lineRects[i];
      if (i > 0 && r.top > padded.last.bottom) {
        final mid = (r.top + padded.last.bottom) / 2;
        padded[padded.length - 1] =
            Rect.fromLTRB(padded.last.left, padded.last.top,
                padded.last.right, mid);
        r = Rect.fromLTRB(r.left, mid, r.right, r.bottom);
      }
      padded.add(r);
    }
    Rect? bounding;
    final lineRRects = <RRect>[];
    for (final r in padded) {
      final inflated =
          step.targetPadding.inflateRect(r).intersect(overlayBounds);
      if (inflated.isEmpty) continue;
      bounding = bounding == null ? inflated : bounding.expandToInclude(inflated);
      lineRRects.add(RRect.fromRectAndRadius(inflated, radius));
    }
    if (bounding == null || lineRRects.isEmpty) return null;
    return _SpotTarget(
        bounds: RRect.fromRectAndRadius(bounding, radius),
        path: steppedContourPath(lineRRects),
        lines: lineRRects);
  }

  /// Starts (or restarts) the post-activation settling tracker for [step].
  ///
  /// Steps often become active while their target is still moving: the tour
  /// advances from `onPageChanged` while the `PageView` slide is still
  /// settling, or a sheet opened by [TourStep.onEnter] is still animating.
  /// Resolving once at activation freezes the highlight at a mid-gesture
  /// position (the 0.4.0 "offset verse frame" bug), so the tracker
  /// re-resolves every frame until the outline stays put for a few frames.
  void _trackTargetUntilSettled(TourStep step) {
    if (step.targetKey == null) return;
    final generation = ++_settleGeneration;
    _settleStableFrames = 0;
    _settleDeadline = DateTime.now().add(const Duration(seconds: 2));
    void tick() {
      if (!mounted || _entry == null) return;
      if (generation != _settleGeneration) return;
      final c = widget.controller;
      if (c.status != TourStatus.running || c.index != _displayedIndex) {
        return;
      }
      final deadline = _settleDeadline;
      if (deadline == null || DateTime.now().isAfter(deadline)) return;
      final fresh = _resolveTarget(step);
      if (fresh != null && !_sameOutline(fresh, _target)) {
        _target = fresh;
        _settleStableFrames = 0;
        // A morph still in flight chases the moving target.
        if (_morphTo != null) {
          _morphTo = fresh.bounds;
          _morphToLines = fresh.lines;
        }
        _entry?.markNeedsBuild();
      } else if (fresh != null) {
        _settleStableFrames++;
        if (_settleStableFrames >= 4) return; // settled
      }
      // fresh == null: the target is (transiently) unmounted; keep waiting.
      WidgetsBinding.instance.addPostFrameCallback((_) => tick());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  static bool _sameOutline(_SpotTarget a, _SpotTarget? b) {
    if (b == null) return false;
    if (!_sameRRect(a.bounds, b.bounds)) return false;
    if (a.lines.length != b.lines.length) return false;
    for (var i = 0; i < a.lines.length; i++) {
      if (!_sameRRect(a.lines[i], b.lines[i])) return false;
    }
    return true;
  }

  static bool _sameRRect(RRect a, RRect b) {
    const e = 0.5;
    return (a.left - b.left).abs() <= e &&
        (a.top - b.top).abs() <= e &&
        (a.right - b.right).abs() <= e &&
        (a.bottom - b.bottom).abs() <= e;
  }

  Offset _pulseCenter(RRect rect, Alignment alignment) {
    final r = rect.outerRect;
    return Offset(
      r.left + (alignment.x + 1) / 2 * r.width,
      r.top + (alignment.y + 1) / 2 * r.height,
    );
  }

  RRect? get _animatedRect {
    final from = _morphFrom;
    final to = _morphTo;
    if (from == null && to == null) return _target?.bounds;
    final t = Curves.easeInOutCubic.transform(_morphCtrl.value);
    if (from == null || to == null) {
      // Appearing / disappearing spotlight: no lerp, just show the target.
      return _morphCtrl.value < 0.5 ? from : to ?? from;
    }
    return RRect.lerp(from, to, t);
  }

  /// The outline actually cut out of the scrim and stroked by the border:
  /// one shape at every moment, so the border always hugs the bright area.
  ///
  /// While a morph is in flight the two steps' line rects are lerped one by
  /// one (extra lines split out of / merge into the nearest existing line),
  /// so a text-lines contour keeps its stepped, text-hugging shape through
  /// the whole glide. Outside a morph the step's precise contour is used.
  Path? get _animatedPath {
    final from = _morphFromLines;
    final to = _morphToLines;
    if (from == null && to == null) {
      final precise = _target?.path;
      if (precise != null) return precise;
      final b = _target?.bounds;
      return b == null ? null : (Path()..addRRect(b));
    }
    if (from == null || to == null) {
      // Appearing / disappearing spotlight: no lerp, just show the target.
      final rect = _animatedRect;
      return rect == null ? null : (Path()..addRRect(rect));
    }
    final t = Curves.easeInOutCubic.transform(_morphCtrl.value);
    final count = math.max(from.length, to.length);
    final lines = <RRect>[];
    for (var i = 0; i < count; i++) {
      final f = from[math.min(i, from.length - 1)];
      final d = to[math.min(i, to.length - 1)];
      final r = RRect.lerp(f, d, t);
      if (r != null) lines.add(r);
    }
    if (lines.isEmpty) return null;
    return steppedContourPath(lines);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final theme = _stepTheme;
    final c = widget.controller;
    final step = c.steps[_displayedIndex];
    final media = MediaQuery.of(overlayContext);

    // The overlay rebuilds on the scrim, card and morph controllers only.
    // The pulse has its own AnimatedBuilder below, inside a RepaintBoundary:
    // in 0.3.0 every pulse tick rebuilt and repainted the full-screen scrim
    // (including the blur glow) for as long as the tour was visible.
    return AnimatedBuilder(
      animation: Listenable.merge([_scrimCtrl, _cardCtrl, _morphCtrl]),
      builder: (context, _) {
        final rect = _animatedRect;
        final path = _animatedPath;
        if (_cardSizeDirty) {
          _cardSizeDirty = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final size = _cardKey.currentContext?.size;
            if (size != null && size != _cardSize && mounted) {
              _cardSize = size;
              _cardSizeDirty = true;
              _entry?.markNeedsBuild();
            }
          });
        }
        final card = KeyedSubtree(
          key: _cardKey,
          child: Padding(
            padding: theme.cardMargin,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: _reduceMotion ? Offset.zero : const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: _cardCtrl, curve: Curves.easeOutCubic)),
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _cardCtrl, curve: Curves.easeOut),
                child: TourTooltipCard(
                  step: step,
                  index: _displayedIndex,
                  total: c.steps.length,
                  theme: theme,
                  labels: widget.labels,
                  controller: c,
                  entrance: _cardCtrl,
                  stagger: theme.contentStagger && !_reduceMotion,
                ),
              ),
            ),
          ),
        );

        return Material(
          type: MaterialType.transparency,
          child: Directionality(
            textDirection: _textDirection,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  // Backdrop + highlight border + glow.
                  Positioned.fill(
                    child: GestureDetector(
                      // deferredToChild + the painter's hitTest: gestures
                      // inside the spotlight pass through to the app below
                      // on interactive steps, everything else is absorbed.
                      behavior: HitTestBehavior.deferToChild,
                      onTap: widget.barrierDismissible ? c.skip : null,
                      child: CustomPaint(
                        painter: SpotlightPainter(
                          scrimColor: theme.scrimColor,
                          borderColor: theme.borderColor ?? theme.accentColor,
                          glowColor: theme.glowColor,
                          glowOpacity: theme.glowOpacity,
                          targetPath: path,
                          borderWidth: theme.borderWidth,
                          glowSigma: theme.glowSigma,
                          scrimOpacity: _scrimCtrl.value,
                          tapThroughTarget: !_transitioning &&
                              step.interaction != TourTargetInteraction.none,
                        ),
                      ),
                    ),
                  ),
                  // Indicator on the target: the pulsing tap orb, or a
                  // swipe-demonstrating orb gliding across the target
                  // (TourStep.indicator). Isolated in its own
                  // RepaintBoundary + AnimatedBuilder: while it runs, only
                  // this small layer repaints, not the full-screen scrim.
                  // Always IgnorePointer: the real gesture passes through
                  // to the app on interactive steps.
                  if (rect != null && (!_pulsesDone || step.swipeDemo != null))
                    Builder(builder: (context) {
                      final side = (rect.outerRect.shortestSide *
                              theme.indicatorSizeFactor)
                          .clamp(theme.indicatorMinSize,
                              theme.indicatorMaxSize);
                      final ic = theme.indicatorColor ?? const Color(0xFFFFFFFF);
                      final ig = theme.indicatorGlowColor;
                      final io = theme.indicatorOpacity;
                      final isg = theme.indicatorGlowSigma;
                      final center = _pulseCenter(rect, step.pulseAlignment);
                      final swipe = step.indicator != TourIndicator.pulse;
                      final demo = step.swipeDemo;
                      // While a PageSwipeDemo wired to this step runs, the
                      // orb mirrors the real page: it glides with the turn
                      // and its direction flips with the return leg. Idle
                      // demo (or none): the usual looping indicator.
                      final Widget orb = swipe && demo != null
                          ? AnimatedBuilder(
                              animation: demo.indicator,
                              builder: (context, _) {
                                final sync = demo.indicator.value;
                                if (sync != null) {
                                  return CustomPaint(
                                    painter: SwipePainter.synced(
                                      color: ic,
                                      glowColor: ig,
                                      colorOpacity: io,
                                      glowSigma: isg,
                                      fraction: sync.fraction,
                                      leftToRight: sync.leftToRight,
                                      opacity: sync.opacity,
                                    ),
                                  );
                                }
                                if (_pulsesDone) {
                                  return const SizedBox.shrink();
                                }
                                return AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (context, _) => CustomPaint(
                                    painter: SwipePainter(
                                      color: ic,
                                      glowColor: ig,
                                      colorOpacity: io,
                                      glowSigma: isg,
                                      progress: _pulseCtrl.value,
                                      leftToRight: step.indicator ==
                                          TourIndicator.swipeLeftToRight,
                                    ),
                                  ),
                                );
                              },
                            )
                          : AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (context, _) => CustomPaint(
                                painter: swipe
                                    ? SwipePainter(
                                        color: ic,
                                        glowColor: ig,
                                        colorOpacity: io,
                                        glowSigma: isg,
                                        progress: _pulseCtrl.value,
                                        leftToRight: step.indicator ==
                                            TourIndicator.swipeLeftToRight,
                                      )
                                    : PulsePainter(
                                        color: ic,
                                        glowColor: ig,
                                        opacity: io,
                                        glowSigma: isg,
                                        progress: _pulseCtrl.value),
                              ),
                            );
                      return Positioned(
                        left: swipe
                            ? rect.outerRect.left
                            : center.dx - side / 2,
                        top: center.dy - side / 2,
                        width: swipe ? rect.outerRect.width : side,
                        height: side,
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: orb,
                          ),
                        ),
                      );
                    }),
                  // Tooltip card.
                  _positionedCard(rect, media, card),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _positionedCard(RRect? rect, MediaQueryData media, Widget card) {
    final theme = _stepTheme;
    final size = media.size;
    final top0 = media.padding.top + 8;
    final bottomLimit = size.height - media.padding.bottom - 8;
    final cardH = _cardSize.height;

    double top;
    if (rect == null) {
      top = (size.height - cardH) / 2;
    } else {
      final centerY = rect.outerRect.center.dy;
      if (centerY < size.height * 0.45) {
        top = rect.outerRect.bottom + theme.targetGap;
      } else if (centerY > size.height * 0.6) {
        top = rect.outerRect.top - theme.targetGap - cardH;
      } else {
        top = bottomLimit - cardH;
      }
    }
    top = top.clamp(top0, (bottomLimit - cardH).clamp(top0, bottomLimit));

    return AnimatedPositioned(
      duration: _theme.spotlightMorphDuration,
      curve: theme.morphCurve,
      left: 0,
      right: 0,
      top: top,
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
