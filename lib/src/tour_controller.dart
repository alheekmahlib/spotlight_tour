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

/// Drives a [SpotlightTour].
///
/// Create one controller per screen (a [State] field is fine) and pass it to
/// the [SpotlightTour] widget, then call [start] when the tour should begin
/// (first launch, a "replay the tour" button, ...).
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
  final String? tourId;

  /// Where completion of [tourId] is recorded. Defaults to an in-memory
  /// store; see [TourCompletionStore] for wiring it to the app's storage.
  final TourCompletionStore completionStore;

  /// Whether skipping the tour also marks [tourId] completed, so a skipped
  /// first-launch tour does not auto-start again. Default: true.
  final bool markCompletedOnSkip;

  List<TourStep> _steps;
  int _index = 0;
  TourStatus _status = TourStatus.idle;

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
  void start({List<TourStep>? steps, int initialIndex = 0}) {
    if (_busy) return;
    if (steps != null) _steps = steps;
    if (_steps.isEmpty) return;
    _index = initialIndex.clamp(0, _steps.length - 1);
    _status = TourStatus.running;
    _finishedByConfirm = false;
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
  Future<bool> startOnce({List<TourStep>? steps, int initialIndex = 0}) async {
    final id = tourId;
    if (id != null) {
      try {
        if (await completionStore.isCompleted(id)) return false;
      } catch (_) {
        // A failing store must not block the tour: run it anyway.
      }
    }
    if (_status != TourStatus.idle) return false;
    start(steps: steps, initialIndex: initialIndex);
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

  /// Records [tourId] in [completionStore]; failures are ignored so a
  /// broken store can never wedge the tour.
  void _recordCompletion() {
    final id = tourId;
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
