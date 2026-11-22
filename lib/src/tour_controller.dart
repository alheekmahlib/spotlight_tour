import 'package:flutter/widgets.dart';

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
  SpotlightTourController({List<TourStep>? steps}) : _steps = steps ?? const [];

  List<TourStep> _steps;
  int _index = 0;
  TourStatus _status = TourStatus.idle;

  /// Steps of the current (or next) run.
  List<TourStep> get steps => _steps;

  /// Index of the active step while [status] is [TourStatus.running].
  int get index => _index;

  /// Whether the tour overlay is on screen.
  TourStatus get status => _status;

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
    if (steps != null) _steps = steps;
    if (_steps.isEmpty) return;
    _index = initialIndex.clamp(0, _steps.length - 1);
    _status = TourStatus.running;
    notifyListeners();
    onStepChanged?.call(_index);
  }

  /// Advances to the next step, or finishes on the last one.
  void next() {
    if (_status != TourStatus.running) return;
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
    if (_status != TourStatus.running || _index == 0) return;
    _index--;
    notifyListeners();
    onStepChanged?.call(_index);
  }

  /// Skips the tour.
  void skip() {
    if (_status != TourStatus.running) return;
    _status = TourStatus.closing;
    notifyListeners();
    onSkip?.call();
  }

  /// Completes the tour (called from the last step's primary button, but may
  /// also be called programmatically).
  void finish() {
    if (_status != TourStatus.running) return;
    _status = TourStatus.closing;
    notifyListeners();
    onFinish?.call();
  }

  /// Internal: the overlay calls this once its exit animation completed.
  void markClosed() {
    if (_status != TourStatus.closing) return;
    _status = TourStatus.idle;
    notifyListeners();
  }
}
