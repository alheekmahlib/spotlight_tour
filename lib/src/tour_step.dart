import 'package:flutter/widgets.dart';

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

  /// Whether the pulse animation plays on this step.
  final bool showPulse;
}
