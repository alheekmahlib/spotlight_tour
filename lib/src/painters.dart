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
    this.contourPath,
    this.contourBlend = 0,
  });

  final Color scrimColor;
  final Color borderColor;

  /// The current (already animated) spotlight outline, or `null` for steps
  /// without a target. May be a single rounded rect or a stepped contour
  /// following wrapped text lines.
  final Path? targetPath;
  final double borderWidth;
  final double glowSigma;

  /// 0..1 fade of the whole scrim (tour enter/exit).
  final double scrimOpacity;

  /// When true, gestures landing inside [targetPath] pass through the
  /// backdrop to the app's widgets below (see [TourStep.interaction]),
  /// instead of being absorbed by the tour.
  final bool tapThroughTarget;

  /// The precise text-lines contour the spotlight is gliding towards, while
  /// the animated bounding shape in [targetPath] is still morphing. When set
  /// with [contourBlend] > 0, the border and glow are cross-faded between
  /// [targetPath] and this contour, so a text-outline step no longer snaps
  /// from the rounded rect to the stepped contour at the end of the glide.
  final Path? contourPath;

  /// 0..1 cross-fade from [targetPath]'s border to [contourPath]'s border.
  final double contourBlend;

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
      final blend = contourBlend.clamp(0.0, 1.0);
      final contour = contourPath;
      // Soft outer glow, then the crisp border, both fading with the scrim.
      // The glow is the most expensive paint in the tour: glowSigma 0 skips
      // it entirely (see SpotlightTourTheme.glowSigma).
      final glow = glowSigma > 0;
      final glowPaint = glow
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma))
          : null;
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;

      if (contour != null && blend > 0) {
        // Cross-fade the highlight from the morphing shape to the precise
        // contour during the last part of the glide.
        if (blend < 1) {
          glowPaint?.color =
              borderColor.withValues(alpha: 0.55 * scrimOpacity * (1 - blend));
          borderPaint.color =
              borderColor.withValues(alpha: scrimOpacity * (1 - blend));
          if (glow) canvas.drawPath(t, glowPaint!);
          canvas.drawPath(t, borderPaint);
        }
        glowPaint?.color =
            borderColor.withValues(alpha: 0.55 * scrimOpacity * blend);
        borderPaint.color = borderColor.withValues(alpha: scrimOpacity * blend);
        if (glow) canvas.drawPath(contour, glowPaint!);
        canvas.drawPath(contour, borderPaint);
      } else {
        glowPaint?.color =
            borderColor.withValues(alpha: 0.55 * scrimOpacity);
        borderPaint.color = borderColor.withValues(alpha: scrimOpacity);
        if (glow) canvas.drawPath(t, glowPaint!);
        canvas.drawPath(t, borderPaint);
      }
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
      oldDelegate.tapThroughTarget != tapThroughTarget ||
      !identical(oldDelegate.contourPath, contourPath) ||
      oldDelegate.contourBlend != contourBlend;
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
