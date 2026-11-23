import 'package:flutter/material.dart';

/// Visual configuration of the tour overlay, highlight and tooltip card.
///
/// [SpotlightTourTheme.gold] reproduces the reference design: dark warm card,
/// golden highlight border with a soft glow and a golden primary button.
class SpotlightTourTheme {
  const SpotlightTourTheme({
    required this.scrimColor,
    required this.cardColor,
    required this.accentColor,
    required this.onAccentColor,
    required this.titleStyle,
    required this.bodyStyle,
    required this.counterStyle,
    required this.skipStyle,
    required this.previousStyle,
    required this.buttonTextStyle,
    this.cardRadius = 20,
    this.cardPadding = const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
    this.cardMargin = const EdgeInsetsDirectional.all(16),
    this.borderWidth = 2,
    this.glowSigma = 12,
    this.targetGap = 16,
    this.primaryButtonHeight = 46,
    this.scrimFadeDuration = const Duration(milliseconds: 400),
    this.cardEnterDuration = const Duration(milliseconds: 300),
    this.cardExitDuration = const Duration(milliseconds: 200),
    this.spotlightMorphDuration = const Duration(milliseconds: 380),
    this.pulseDuration = const Duration(milliseconds: 1500),
    this.pulseRepeatCount = 4,
    this.contentStagger = true,
  });

  /// Dimmed backdrop color. Its alpha controls how dark the app gets.
  final Color scrimColor;

  /// Tooltip card background.
  final Color cardColor;

  /// Gold accent: highlight border, glow, primary button, counter, skip pill.
  final Color accentColor;

  /// Text/icon color on top of [accentColor] (primary button label).
  final Color onAccentColor;

  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle counterStyle;
  final TextStyle skipStyle;
  final TextStyle previousStyle;
  final TextStyle buttonTextStyle;

  final double cardRadius;
  final EdgeInsetsDirectional cardPadding;

  /// Margin between the card and the screen edges.
  final EdgeInsetsDirectional cardMargin;

  /// Stroke width of the highlight border.
  final double borderWidth;

  /// Blur sigma of the outer glow around the highlight. Set to `0` to skip
  /// the blur entirely: it is the single most expensive paint of the tour,
  /// and the crisp border alone still reads clearly on low-end devices.
  final double glowSigma;

  /// Vertical gap between the spotlight and the tooltip card.
  final double targetGap;

  final double primaryButtonHeight;

  /// Durations of the motion seen in the reference video.
  final Duration scrimFadeDuration;
  final Duration cardEnterDuration;
  final Duration cardExitDuration;

  /// How long the spotlight takes to glide from one target to the next.
  final Duration spotlightMorphDuration;

  /// One full pulse cycle (grow + fade).
  final Duration pulseDuration;

  /// How many pulse cycles play when a step becomes active before the orb
  /// rests. A bounded pulse keeps the screen from repainting at 60 fps for
  /// the whole time the user reads a step (battery and low-end GPUs), and
  /// it stops nagging visually. `null` repeats forever (the 0.3.0
  /// behaviour), `0` disables the pulse on every step. Default: 4.
  final int? pulseRepeatCount;

  /// Whether the card's content (header, title, body, buttons) fades and
  /// slides in with a short stagger after the card itself. Purely visual;
  /// automatically disabled when the system asks for reduced motion.
  final bool contentStagger;

  /// The exact look of the reference video.
  factory SpotlightTourTheme.gold({TextStyle? base}) {
    const accent = Color(0xFFB08E3F);
    const card = Color(0xFF1C1A16);
    TextStyle merge(TextStyle style) => base != null ? base.merge(style) : style;
    return SpotlightTourTheme(
      scrimColor: Colors.black.withValues(alpha: 0.88),
      cardColor: card,
      accentColor: accent,
      onAccentColor: const Color(0xFF1C1A16),
      titleStyle: merge(const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.4,
      )),
      bodyStyle: merge(TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.55,
      )),
      counterStyle: merge(const TextStyle(
        color: accent,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      )),
      skipStyle: merge(const TextStyle(
        color: accent,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      )),
      previousStyle: merge(TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      )),
      buttonTextStyle: merge(const TextStyle(
        color: Color(0xFF1C1A16),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      )),
    );
  }

  SpotlightTourTheme copyWith({
    Color? scrimColor,
    Color? cardColor,
    Color? accentColor,
    Color? onAccentColor,
    double? glowSigma,
    int? Function()? pulseRepeatCount,
    bool? contentStagger,
  }) {
    return SpotlightTourTheme(
      scrimColor: scrimColor ?? this.scrimColor,
      cardColor: cardColor ?? this.cardColor,
      accentColor: accentColor ?? this.accentColor,
      onAccentColor: onAccentColor ?? this.onAccentColor,
      titleStyle: titleStyle,
      bodyStyle: bodyStyle,
      counterStyle: counterStyle,
      skipStyle: skipStyle,
      previousStyle: previousStyle,
      buttonTextStyle: buttonTextStyle,
      cardRadius: cardRadius,
      cardPadding: cardPadding,
      cardMargin: cardMargin,
      borderWidth: borderWidth,
      glowSigma: glowSigma ?? this.glowSigma,
      targetGap: targetGap,
      primaryButtonHeight: primaryButtonHeight,
      scrimFadeDuration: scrimFadeDuration,
      cardEnterDuration: cardEnterDuration,
      cardExitDuration: cardExitDuration,
      spotlightMorphDuration: spotlightMorphDuration,
      pulseDuration: pulseDuration,
      pulseRepeatCount:
          pulseRepeatCount != null ? pulseRepeatCount() : this.pulseRepeatCount,
      contentStagger: contentStagger ?? this.contentStagger,
    );
  }
}
