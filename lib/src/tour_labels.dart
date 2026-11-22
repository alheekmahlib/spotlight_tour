/// Text labels used by the tour UI. All labels are overridable; the defaults
/// match the reference Arabic tour.
class TourLabels {
  const TourLabels({
    this.skip = 'تخطي الجولة',
    this.previous = 'السابق',
    this.next = 'التالي',
    this.done = 'تم',
    this.start = 'ابدأ الجولة',
    this.counter = _defaultCounter,
  });

  /// Pill button that skips the whole tour.
  final String skip;

  /// Text button that goes back one step.
  final String previous;

  /// Primary button that advances one step.
  final String next;

  /// Primary button on the last step.
  final String done;

  /// Primary button on a target-less first step (intro).
  final String start;

  /// Builds the counter text, e.g. "5 من 25".
  final String Function(int current, int total) counter;

  static String _defaultCounter(int current, int total) => '$current من $total';
}
