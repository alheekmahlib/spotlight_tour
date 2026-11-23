import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tour_completion.dart';
import 'tour_step.dart';

/// Lifecycle of a tour run.
enum TourStatus {
  /// No tour is showing.
  idle,

  /// The overlay is visible and a step is active.
  running,

  /// The tour finished all steps (or was skipped) and is animating out.
  closing,
}

/// Drives a [SpotlightTour] (per screen) or a [SpotlightTourHost] (whole
/// app).
///
/// Per screen: create one controller (a [State] field is fine), pass it to
/// the [SpotlightTour] widget wrapping that screen, then call [start] when
/// the tour should begin (first launch, a "replay the tour" button, ...).
///
/// Centrally: keep ONE controller in your app's service locator (a GetX
/// service, a Provider, a top-level final), mount ONE [SpotlightTourHost]
/// in `MaterialApp.builder`/`GetMaterialApp.builder`, and call
/// [start] from anywhere in the app with that section's steps:
/// `tourService.tour.start(steps: audioSteps)`. See [SpotlightTourHost]
/// for the rules that keep this safe.
class SpotlightTourController extends ChangeNotifier {
  SpotlightTourController({
    List<TourStep>? steps,
    this.tourId,
    TourCompletionStore? completionStore,
    this.markCompletedOnSkip = true,
  })  : _steps = steps ?? const [],
        completionStore = completionStore ?? InMemoryTourCompletionStore();

  /// Stable identifier of this tour, used with [completionStore] by
  /// [startOnce]. Give every section of the app its own id (`'mushaf'`,
  /// `'audio'`, `'adhkar'`, ...) so each section's tour auto-starts once,
  /// independently of the others. `null` disables completion tracking.
  ///
  /// With a central controller (see [SpotlightTourHost]) pass the section's
  /// id per run instead: `startOnce(tourId: 'settings', steps: ...)`.
  final String? tourId;

  /// The id completion is recorded under for the current (or next) run:
  /// the `tourId` argument of [start]/[startOnce], falling back to
  /// [tourId]. Lets ONE central controller track each section's tour
  /// independently.
  String? _activeTourId;

  /// Where completion of [tourId] is recorded. Defaults to an in-memory
  /// store; see [TourCompletionStore] for wiring it to the app's storage.
  final TourCompletionStore completionStore;

  /// Whether skipping the tour also marks [tourId] completed, so a skipped
  /// first-launch tour does not auto-start again. Default: true.
  final bool markCompletedOnSkip;

  List<TourStep> _steps;
  int _index = 0;
  TourStatus _status = TourStatus.idle;

  /// Incremented by every [start]: lets a mounted host tell a *restart*
  /// (a new tour was launched while one was visible) apart from an ordinary
  /// step change, so calling [start] again from anywhere replaces the
  /// running tour instead of being swallowed.
  int _runGeneration = 0;

  /// Internal: how many times [start] has launched a run. Not part of the
  /// public API.
  int get runGeneration => _runGeneration;

  /// When [start] replaces a RUNNING tour, the step that was on screen.
  /// The overlay tears that step down (its [TourStep.onExit]) before
  /// entering the first new step, even though [steps] already holds the new
  /// list. Null on a fresh start from idle.
  TourStep? _replacedStep;

  /// Internal: see [_replacedStep]. Not part of the public API.
  TourStep? get replacedStepForRestart => _replacedStep;

  /// Internal: the overlay consumes [_replacedStep] once it has captured it.
  void clearReplacedStep() => _replacedStep = null;

  /// While true, a step action ([TourStep.onNext]/[TourStep.onEnter]) or the
  /// step transition animation is still running. [next], [previous] and
  /// [start] are ignored in this state, so rapid taps and reentrant calls
  /// from app handlers cannot corrupt the transition; [skip] stays usable.
  bool _busy = false;

  /// Whether the current [TourStatus.closing] came from the user confirming
  /// the last step (so its [TourStep.onNext] still runs) rather than a skip.
  bool _finishedByConfirm = false;

  /// Steps of the current (or next) run.
  List<TourStep> get steps => _steps;

  /// Index of the active step while [status] is [TourStatus.running].
  int get index => _index;

  /// Whether the tour overlay is on screen.
  TourStatus get status => _status;

  /// Whether a step action or transition is in flight (the card shows the
  /// primary button disabled with a spinner).
  bool get isBusy => _busy;

  /// True while closing after the last step's Done button (not a skip).
  bool get finishedByConfirm => _finishedByConfirm;

  /// The active step, or `null` when idle.
  TourStep? get currentStep =>
      _status == TourStatus.running && _steps.isNotEmpty ? _steps[_index] : null;

  bool get isFirstStep => _index == 0;
  bool get isLastStep => _index == _steps.length - 1;

  /// Called when the last step is confirmed (the "done" button).
  VoidCallback? onFinish;

  /// Called when the user skips the tour.
  VoidCallback? onSkip;

  /// Called whenever the visible step changes.
  void Function(int index)? onStepChanged;

  /// Replaces the step list. Safe to call before [start].
  set steps(List<TourStep> value) {
    _steps = value;
    if (_status == TourStatus.running) {
      _index = _index.clamp(0, _steps.length - 1);
      notifyListeners();
    }
  }

  /// Starts the tour from the first step. Optionally replaces the steps.
  ///
  /// Calling this while a tour is already running restarts with the new
  /// steps: the running step's [TourStep.onExit] teardown still runs (its
  /// forward [TourStep.onNext] action does not), so UI it opened is never
  /// left behind. While a step transition or the brief exit animation is in
  /// flight ([isBusy], or [status] is [TourStatus.closing]) the call is
  /// ignored, exactly like [next] and [previous]; wait for
  /// [TourStatus.idle] or call again a moment later.
  void start(
      {List<TourStep>? steps, int initialIndex = 0, String? tourId}) {
    if (_busy || _status == TourStatus.closing) return;
    _replacedStep =
        _status == TourStatus.running && _steps.isNotEmpty ? _steps[_index] : null;
    if (steps != null) _steps = steps;
    if (_steps.isEmpty) {
      _replacedStep = null;
      return;
    }
    _activeTourId = tourId ?? this.tourId;
    _index = initialIndex.clamp(0, _steps.length - 1);
    _status = TourStatus.running;
    _finishedByConfirm = false;
    _runGeneration++;
    notifyListeners();
    onStepChanged?.call(_index);
  }

  /// Starts the tour only if [tourId] is not yet marked completed in
  /// [completionStore]. Returns whether the tour actually started.
  ///
  /// This is the first-launch pattern: call it from a post-frame callback
  /// on screens whose tour should auto-run exactly once. A "replay the
  /// tour" button should call [start] directly instead.
  ///
  /// Requires [tourId]; without one it behaves like [start] and returns
  /// true, because there is nothing to track.
  Future<bool> startOnce(
      {List<TourStep>? steps, int initialIndex = 0, String? tourId}) async {
    final id = tourId ?? this.tourId;
    if (id != null) {
      try {
        if (await completionStore.isCompleted(id)) return false;
      } catch (_) {
        // A failing store must not block the tour: run it anyway.
      }
    }
    if (_status != TourStatus.idle) return false;
    start(steps: steps, initialIndex: initialIndex, tourId: id);
    return _status == TourStatus.running;
  }

  /// Advances to the next step, or finishes on the last one.
  ///
  /// Also called programmatically by the app's own gesture handlers on
  /// [TourStep.requireInteraction] steps: when the user really performs the
  /// gesture, the app's handler calls `next()` and the tour continues.
  void next() {
    if (_status != TourStatus.running || _busy) return;
    if (isLastStep) {
      finish();
      return;
    }
    _index++;
    notifyListeners();
    onStepChanged?.call(_index);
  }

  /// Goes back one step. Does nothing on the first step.
  void previous() {
    if (_status != TourStatus.running || _busy || _index == 0) return;
    _index--;
    notifyListeners();
    onStepChanged?.call(_index);
  }

  /// Skips the tour. Always works, even while a step action is running.
  void skip() {
    if (_status != TourStatus.running) return;
    _finishedByConfirm = false;
    _status = TourStatus.closing;
    if (markCompletedOnSkip) _recordCompletion();
    notifyListeners();
    onSkip?.call();
  }

  /// Completes the tour (called from the last step's primary button, but may
  /// also be called programmatically).
  void finish() {
    if (_status != TourStatus.running) return;
    _finishedByConfirm = true;
    _status = TourStatus.closing;
    _recordCompletion();
    notifyListeners();
    onFinish?.call();
  }

  /// Records the run's id in [completionStore]; failures are ignored so a
  /// broken store can never wedge the tour.
  void _recordCompletion() {
    final id = _activeTourId ?? tourId;
    if (id == null) return;
    unawaited(Future(() => completionStore.markCompleted(id))
        .catchError((_) {}));
  }

  /// Internal: the overlay calls this once its exit animation completed.
  void markClosed() {
    if (_status != TourStatus.closing) return;
    _status = TourStatus.idle;
    _busy = false;
    notifyListeners();
  }

  /// Internal: the overlay toggles [isBusy] around step actions and
  /// transitions. Not part of the public API.
  void setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
