import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// Paints the dimmed backdrop with a see-through cutout, a glowing golden
/// border around the target, and nothing else. The card is a normal widget.
class SpotlightPainter extends CustomPainter {
  const SpotlightPainter({
    required this.scrimColor,
    required this.borderColor,
    required this.targetPath,
    required this.borderWidth,
    required this.glowSigma,
    required this.scrimOpacity,
    this.tapThroughTarget = false,
  });

  final Color scrimColor;
  final Color borderColor;

  /// The current (already animated) spotlight outline, or `null` for steps
  /// without a target. May be a single rounded rect or a stepped contour
  /// following wrapped text lines. While the spotlight glides between steps
  /// this path is animated line by line, so the border and the cutout below
  /// always describe the same shape (see `_animatedPath`).
  final Path? targetPath;
  final double borderWidth;
  final double glowSigma;

  /// 0..1 fade of the whole scrim (tour enter/exit).
  final double scrimOpacity;

  /// When true, gestures landing inside [targetPath] pass through the
  /// backdrop to the app's widgets below (see [TourStep.interaction]),
  /// instead of being absorbed by the tour.
  final bool tapThroughTarget;

  @override
  bool? hitTest(Offset position) {
    final t = targetPath;
    if (tapThroughTarget && t != null && t.contains(position)) return false;
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (scrimOpacity <= 0) return;
    final scrimPaint = Paint()
      ..color = scrimColor.withValues(alpha: scrimColor.a * scrimOpacity);
    final scrimPath = Path()..addRect(Offset.zero & size);
    final t = targetPath;
    if (t != null) {
      scrimPath.addPath(t, Offset.zero);
      scrimPath.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(scrimPath, scrimPaint);

    if (t != null) {
      // Soft outer glow, then the crisp border, both fading with the scrim.
      // The glow is the most expensive paint in the tour: glowSigma 0 skips
      // it entirely (see SpotlightTourTheme.glowSigma).
      if (glowSigma > 0) {
        final glowPaint = Paint()
          ..color = borderColor.withValues(alpha: 0.55 * scrimOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);
        canvas.drawPath(t, glowPaint);
      }

      final borderPaint = Paint()
        ..color = borderColor.withValues(alpha: scrimOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(t, borderPaint);
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) =>
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.borderColor != borderColor ||
      !identical(oldDelegate.targetPath, targetPath) ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.glowSigma != glowSigma ||
      oldDelegate.scrimOpacity != scrimOpacity ||
      oldDelegate.tapThroughTarget != tapThroughTarget;
}

/// Traces one continuous stepped outline around a stack of per-line
/// rounded rects (top to bottom, vertically touching or overlapping).
///
/// A boolean union of fully-rounded line rects pinches at the join
/// between lines of different widths: each line's own corner radius cuts
/// into the neck, and when the vertical overlap is smaller than the
/// corner diameter the outline visibly thins or breaks at the step (the
/// "disconnected frame between two lines" report). This walks the left
/// and right edge profiles instead, so the result is a single closed
/// contour by construction: rounded corners only at the four outermost
/// corners, sharp steps where a line's edge moves in or out, and no
/// pinch at any width difference or overlap.
Path steppedContourPath(List<RRect> lines) {
  assert(lines.isNotEmpty);
  if (lines.length == 1) return Path()..addRRect(lines.first);

  double cornerRadius(RRect r) =>
      math.min(r.tlRadius.x, math.min(r.width, r.height) / 2);
  final firstR = cornerRadius(lines.first);
  final lastR = cornerRadius(lines.last);
  // Steps smaller than this are antialiasing noise, not real width
  // changes; skipping them avoids zero-length jag segments.
  const eps = 0.5;

  final path = Path()
    ..moveTo(lines.first.left + firstR, lines.first.top);
  // Top edge, top-right corner, then the right profile downwards.
  path.lineTo(lines.first.right - firstR, lines.first.top);
  if (firstR > 0) {
    path.arcToPoint(Offset(lines.first.right, lines.first.top + firstR),
        radius: Radius.circular(firstR));
  }
  for (var i = 0; i < lines.length - 1; i++) {
    final cur = lines[i];
    final next = lines[i + 1];
    if (next.right > cur.right + eps) {
      // The next line reaches further right: step at its top, the
      // highest y where it owns the edge.
      path
        ..lineTo(cur.right, next.top)
        ..lineTo(next.right, next.top);
    } else if (next.right < cur.right - eps) {
      // The next line ends earlier: step at this line's bottom, the
      // lowest y where this line owns the edge.
      path
        ..lineTo(cur.right, cur.bottom)
        ..lineTo(next.right, cur.bottom);
    }
  }
  path.lineTo(lines.last.right, lines.last.bottom - lastR);
  if (lastR > 0) {
    path.arcToPoint(Offset(lines.last.right - lastR, lines.last.bottom),
        radius: Radius.circular(lastR));
  }
  // Bottom edge and bottom-left corner.
  path.lineTo(lines.last.left + lastR, lines.last.bottom);
  if (lastR > 0) {
    path.arcToPoint(Offset(lines.last.left, lines.last.bottom - lastR),
        radius: Radius.circular(lastR));
  }
  // Left profile, upwards (mirror of the right profile).
  for (var i = lines.length - 1; i > 0; i--) {
    final cur = lines[i];
    final above = lines[i - 1];
    if (above.left < cur.left - eps) {
      // The line above reaches further left: step at its bottom.
      path
        ..lineTo(cur.left, above.bottom)
        ..lineTo(above.left, above.bottom);
    } else if (above.left > cur.left + eps) {
      // The line above ends earlier: step at this line's top.
      path
        ..lineTo(cur.left, cur.top)
        ..lineTo(above.left, cur.top);
    }
  }
  path.lineTo(lines.first.left, lines.first.top + firstR);
  if (firstR > 0) {
    path.arcToPoint(Offset(lines.first.left + firstR, lines.first.top),
        radius: Radius.circular(firstR));
  }
  path.close();
  return path;
}

/// The white "tap" orb that grows and fades on top of the highlighted target.
class PulsePainter extends CustomPainter {
  const PulsePainter({required this.progress});

  /// 0..1, repeating.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide / 2;
    // Two overlapping waves, half a cycle apart, like the reference video.
    for (final phase in const [0.0, 0.5]) {
      final t = (progress + phase) % 1.0;
      final radius = baseRadius * (0.45 + 0.85 * t);
      final opacity = (1.0 - t) * 0.9;
      if (opacity <= 0) continue;
      final glowPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, radius, glowPaint);
      final corePaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.85);
      canvas.drawCircle(center, radius * 0.55, corePaint);
    }
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A white orb that glides horizontally across the highlighted target with a
/// short fading trail, demonstrating a swipe gesture ("drag the page like
/// this"). Painted above the cutout but below the card, always inside an
/// `IgnorePointer`: the real swipe still passes through to the app.
class SwipePainter extends CustomPainter {
  const SwipePainter({required this.progress, required this.leftToRight})
      : syncFraction = null,
        syncOpacity = null;

  /// Driven directly by a running `PageSwipeDemo` (see
  /// `TourStep.swipeDemo`): [fraction] is the orb's head position across
  /// the target (0 = left edge, 1 = right edge), [opacity] its fade, and
  /// [leftToRight] the CURRENT leg's travel direction — the demonstrated
  /// direction on the outward turn, the opposite on the way back.
  const SwipePainter.synced({
    required double fraction,
    required this.leftToRight,
    required double opacity,
  })  : progress = 0,
        syncFraction = fraction,
        syncOpacity = opacity;

  /// 0..1, repeating.
  final double progress;

  /// True to glide from the left edge to the right edge, false for the
  /// opposite direction. In synced mode this is the current leg's
  /// direction, which flips between the outward turn and the return.
  final bool leftToRight;

  /// Direct head position (0..1 across the target) in synced mode, else
  /// `null` and the position comes from [progress].
  final double? syncFraction;

  /// Direct opacity (0..1) in synced mode, else `null` and the opacity
  /// comes from [progress].
  final double? syncOpacity;

  /// Where the travel happens inside one cycle: the orb fades in, crosses,
  /// then fades out, so the repeating cycle reads as separate swipes.
  static const double _fadeInEnd = 0.18;
  static const double _travelEnd = 0.82;

  /// Horizontal position of the orb's head at [progress], as a 0..1 fraction
  /// of the paint area's width (0 = left edge, 1 = right edge). Static and
  /// pure so tests can assert the motion direction without rendering.
  static double headFraction(double progress, {required bool leftToRight}) {
    final p = progress.clamp(0.0, 1.0);
    final t = ((p - _fadeInEnd) / (_travelEnd - _fadeInEnd)).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(t);
    return leftToRight ? eased : 1.0 - eased;
  }

  /// Opacity of the head at [progress]: fades in at the start of the cycle
  /// and out at the end.
  static double headOpacity(double progress) {
    final p = progress.clamp(0.0, 1.0);
    final fadeIn = (p / _fadeInEnd).clamp(0.0, 1.0);
    final fadeOut = ((1.0 - p) / (1.0 - _travelEnd)).clamp(0.0, 1.0);
    return fadeIn < fadeOut ? fadeIn : fadeOut;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.height;
    final headRadius = band * 0.30;
    final margin = headRadius + band * 0.12;
    final x0 = margin;
    final x1 = size.width - margin;
    if (x1 <= x0) return;
    final centerY = size.height / 2;
    final fraction =
        syncFraction ?? headFraction(progress, leftToRight: leftToRight);
    final headX = lerpDouble(x0, x1, fraction)!;
    final opacity = syncOpacity ?? headOpacity(progress);
    if (opacity <= 0) return;

    // Short trail behind the head, against the direction of travel.
    final dir = leftToRight ? -1.0 : 1.0;
    for (var k = 3; k >= 1; k--) {
      final trailOpacity = opacity * (0.34 - 0.09 * k);
      if (trailOpacity <= 0) continue;
      final paint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: trailOpacity);
      canvas.drawCircle(
          Offset(headX + dir * k * headRadius * 1.15, centerY),
          headRadius * (1.0 - 0.16 * k),
          paint);
    }

    // The head: soft glow plus a bright core, like the pulse orb.
    final glowPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(headX, centerY), headRadius * 1.6, glowPaint);
    final corePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.9);
    canvas.drawCircle(Offset(headX, centerY), headRadius, corePaint);
  }

  @override
  bool shouldRepaint(SwipePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.leftToRight != leftToRight ||
      oldDelegate.syncFraction != syncFraction ||
      oldDelegate.syncOpacity != syncOpacity;
}
