import 'dart:async';

/// Remembers which tours the user has already seen, so a "first launch"
/// tour does not nag on every start, and so each section of a large app can
/// run its own tour exactly once.
///
/// The package ships [InMemoryTourCompletionStore] only: persistence is the
/// app's choice, and the store interface is deliberately tiny so it maps
/// onto whatever the app already uses. With `get_storage`, for example:
///
/// ```dart
/// class GetStorageTourCompletionStore implements TourCompletionStore {
///   GetStorageTourCompletionStore(this._box);
///   final GetStorage _box;
///   static const _key = 'completed_tours';
///
///   List<String> get _done =>
///       (_box.read<List>(_key) ?? const []).cast<String>();
///
///   @override
///   Future<bool> isCompleted(String tourId) async =>
///       _done.contains(tourId);
///
///   @override
///   Future<void> markCompleted(String tourId) async {
///     if (_done.contains(tourId)) return;
///     await _box.write(_key, [..._done, tourId]);
///   }
///
///   @override
///   Future<void> reset(String tourId) async =>
///       _box.write(_key, _done.where((id) => id != tourId).toList());
/// }
/// ```
///
/// Wire it once and share it between screens:
///
/// ```dart
/// final tourStore = GetStorageTourCompletionStore(GetStorage());
///
/// final mushafTour = SpotlightTourController(
///   tourId: 'mushaf',
///   completionStore: tourStore,
/// );
/// await mushafTour.startOnce(); // shows only the first time
/// ```
abstract class TourCompletionStore {
  /// Whether the tour with [tourId] has already run to completion (or was
  /// skipped, when the controller marks skips as completed).
  Future<bool> isCompleted(String tourId);

  /// Records that the tour with [tourId] no longer needs to auto-start.
  Future<void> markCompleted(String tourId);

  /// Forgets [tourId], e.g. from a "replay the tour" settings entry that
  /// also resets the flag. The default does nothing.
  Future<void> reset(String tourId) async {}
}

/// Default [TourCompletionStore]: a process-lifetime set. Tours marked
/// completed are remembered until the app restarts. Useful for tests and as
/// a fallback; apps that want persistence across restarts should implement
/// [TourCompletionStore] over their existing storage (see the class docs).
class InMemoryTourCompletionStore implements TourCompletionStore {
  final Set<String> _completed = <String>{};

  @override
  Future<bool> isCompleted(String tourId) async =>
      _completed.contains(tourId);

  @override
  Future<void> markCompleted(String tourId) async {
    _completed.add(tourId);
  }

  @override
  Future<void> reset(String tourId) async {
    _completed.remove(tourId);
  }
}
