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
      final glowPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.55 * scrimOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);
      canvas.drawPath(t, glowPaint);

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
      oldDelegate.scrimOpacity != scrimOpacity;
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
