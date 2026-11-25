import 'package:flutter/widgets.dart';

import 'spotlight_tour.dart';
import 'tour_controller.dart';
import 'tour_labels.dart';
import 'tour_theme.dart';

/// Mounts ONE app-wide tour surface, so a single [SpotlightTourController]
/// can be started from anywhere in the app — any route, any section — with
/// that section's steps.
///
/// Put it in `MaterialApp.builder` / `GetMaterialApp.builder`, above the
/// Navigator:
///
/// ```dart
/// // One controller for the whole app, kept in your service locator
/// // (a GetX service, a Provider, a top-level final — your choice).
/// final appTour = SpotlightTourController();
///
/// GetMaterialApp(
///   builder: (context, child) =>
///       SpotlightTourHost(controller: appTour, child: child!),
///   home: const HomePage(),
/// );
///
/// // From ANY screen, bloc or service:
/// appTour.start(steps: mushafSteps);   // this section's steps
/// appTour.start(steps: audioSteps);    // another section's steps
/// ```
///
/// How it works and what keeps it safe:
///
/// * The host places the tour in its own [Overlay] ABOVE the Navigator, so
///   the scrim and card cover every route — full-screen pages pushed with
///   `Get.to`/`Navigator.push`, dialogs and modal sheets alike — instead of
///   only the screen that happened to wrap itself.
/// * A step's target is located by its [TourStep.targetKey] anywhere under
///   that overlay, so steps can point at widgets on the CURRENT route
///   whatever it is. A target that is not mounted when its step runs (a
///   page you have not navigated to yet, an off-screen list item) gets the
///   usual fallback: the card shows without a spotlight after
///   [TourStep.targetTimeout]. To highlight something on another page,
///   navigate there in the step's [TourStep.onEnter] (awaited) and the
///   target is found as the page settles.
/// * Each [GlobalKey] may be attached to exactly one mounted widget — the
///   same rule as always; keys are how the tour finds its targets.
/// * A plain key ([ValueKey]) is looked up in the tree instead, so it may
///   tag a widget that is mounted more than once (a sheet package's offstage
///   measuring copy, a per-page widget kept alive next to the page shown);
///   of several copies the one on top is highlighted.
/// * Starting a new tour while one is visible replaces it cleanly: the
///   running step's [TourStep.onExit] teardown runs (its forward
///   [TourStep.onNext] action does not), so a sheet or demo the old step
///   opened is never left behind. While a step transition is animating
///   ([SpotlightTourController.isBusy]) `start` is ignored, like Next.
/// * When no tour is running the host costs nothing: no extra animation
///   tickers and no tour overlay entry.
///
/// Exactly ONE [SpotlightTourHost] may be mounted per controller (a debug
/// assert catches duplicates). Per-screen tours with [SpotlightTour] keep
/// working unchanged alongside it, on their own controllers.
class SpotlightTourHost extends StatefulWidget {
  const SpotlightTourHost({
    super.key,
    required this.controller,
    this.theme,
    this.labels = const TourLabels(),
    this.barrierDismissible = false,
    required this.child,
  });

  /// The single app-wide controller. Keep it alive for as long as the host
  /// is mounted (an app-lifetime service is ideal) and dispose it yourself
  /// when the app is torn down, if ever.
  final SpotlightTourController controller;

  /// Defaults to [SpotlightTourTheme.gold].
  final SpotlightTourTheme? theme;

  /// Overridable strings; defaults are the Arabic labels of the reference tour.
  final TourLabels labels;

  /// Whether tapping the dimmed backdrop skips the tour. Default: `false`.
  final bool barrierDismissible;

  /// The app's Navigator subtree (the `child` given to
  /// `MaterialApp.builder`).
  final Widget child;

  @override
  State<SpotlightTourHost> createState() => _SpotlightTourHostState();
}

class _SpotlightTourHostState extends State<SpotlightTourHost> {
  /// Controllers with a live host, for the one-host-per-controller assert.
  static final Set<SpotlightTourController> _mounted =
      <SpotlightTourController>{};

  /// The Navigator subtree lives inside this entry of the host's own
  /// [Overlay]. The tour's scrim entry is inserted after it, so the tour
  /// always paints above every route, dialog and sheet inside the app —
  /// and targets anywhere below can still be measured against this
  /// overlay's full-screen render box.
  late final OverlayEntry _childEntry =
      OverlayEntry(builder: _buildChild);

  @override
  void initState() {
    super.initState();
    assert(
      _mounted.add(widget.controller),
      'SpotlightTourHost: another host is already mounted for this '
      'SpotlightTourController. Mount exactly one SpotlightTourHost per '
      'controller; two hosts would show the same tour twice.',
    );
  }

  @override
  void didUpdateWidget(SpotlightTourHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(() {
      if (oldWidget.controller != widget.controller) {
        _mounted.remove(oldWidget.controller);
        _mounted.add(widget.controller);
      }
      return true;
    }());
    _childEntry.markNeedsBuild();
  }

  @override
  void dispose() {
    assert(_mounted.remove(widget.controller) || true);
    super.dispose();
  }

  Widget _buildChild(BuildContext context) {
    return SpotlightTour(
      controller: widget.controller,
      theme: widget.theme,
      labels: widget.labels,
      barrierDismissible: widget.barrierDismissible,
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_childEntry]);
  }
}
