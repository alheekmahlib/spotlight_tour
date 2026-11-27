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
    this.cardMaxWidth,
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
    this.borderColor,
    this.glowColor,
    this.glowOpacity = 0.55,
    this.dividerColor,
    this.dividerThickness = 1,
    this.iconColor,
    this.iconSize = 15,
    this.buttonColor,
    this.buttonRadius,
    this.skipBorderColor,
    this.skipBorderWidth = 1,
    this.skipRadius = 20,
    this.skipPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.previousPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    this.hintColor,
    this.hintBorderWidth = 1,
    this.hintIcon = Icons.touch_app_outlined,
    this.hintStyle,
    this.cardBorderColor,
    this.cardBorderWidth = 0,
    this.cardShadows,
    this.titleGap = 14,
    this.bodyGap = 6,
    this.actionsGap = 18,
    this.indicatorColor,
    this.indicatorGlowColor,
    this.indicatorOpacity = 1,
    this.indicatorSizeFactor = 0.9,
    this.indicatorMinSize = 36,
    this.indicatorMaxSize = 110,
    this.indicatorGlowSigma = 10,
    this.morphCurve = Curves.easeInOutCubic,
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

  /// Maximum width of the tooltip card. `null` (the default) keeps the
  /// card spanning the screen width minus [cardMargin]; a value caps the
  /// card's own width (margins excluded) and centers it horizontally, so
  /// narrow screens still shrink it as before.
  final double? cardMaxWidth;

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

  /// Highlight border colour. Defaults to [accentColor].
  final Color? borderColor;

  /// Outer glow colour. Defaults to the border colour.
  final Color? glowColor;

  /// Opacity (0..1) of the outer glow.
  final double glowOpacity;

  /// Line between the skip pill and the counter. Defaults to [accentColor] at 40%.
  final Color? dividerColor;

  /// Thickness of that line.
  final double dividerThickness;

  /// Colour of the step icon. Defaults to [accentColor].
  final Color? iconColor;

  /// Size of the step icon.
  final double iconSize;

  /// Primary button background. Defaults to [accentColor].
  final Color? buttonColor;

  /// Primary button corner radius. Defaults to a full pill (half the button height).
  final double? buttonRadius;

  /// Skip pill border. Defaults to [accentColor].
  final Color? skipBorderColor;

  /// Skip pill border width.
  final double skipBorderWidth;

  /// Skip pill corner radius.
  final double skipRadius;

  /// Skip pill padding.
  final EdgeInsetsGeometry skipPadding;

  /// Padding of the Previous text button.
  final EdgeInsetsGeometry previousPadding;

  /// Border, icon and text colour of the interaction hint. Defaults to [accentColor].
  final Color? hintColor;

  /// Interaction hint border width.
  final double hintBorderWidth;

  /// Icon of the interaction hint.
  final IconData hintIcon;

  /// Interaction hint text style. Defaults to [bodyStyle] in the hint colour.
  final TextStyle? hintStyle;

  /// Optional border around the tooltip card.
  final Color? cardBorderColor;

  /// Width of the card border (0 = none).
  final double cardBorderWidth;

  /// Shadows under the tooltip card.
  final List<BoxShadow>? cardShadows;

  /// Space between the header row and the title.
  final double titleGap;

  /// Space between title and description.
  final double bodyGap;

  /// Space between description and buttons.
  final double actionsGap;

  /// Colour of the pointer (pulse orb and swipe orb). Defaults to white.
  final Color? indicatorColor;

  /// Colour of the pointer glow. Defaults to [indicatorColor].
  final Color? indicatorGlowColor;

  /// Overall opacity multiplier (0..1) of the pointer.
  final double indicatorOpacity;

  /// Pulse orb size as a fraction of the target's shorter side.
  final double indicatorSizeFactor;

  /// Smallest pulse orb size.
  final double indicatorMinSize;

  /// Largest pulse orb size.
  final double indicatorMaxSize;

  /// Blur of the pointer glow (0 = no glow).
  final double indicatorGlowSigma;

  /// Curve of the card's move between steps.
  final Curve morphCurve;

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

  /// A copy with the given fields replaced.
  SpotlightTourTheme copyWith({
    Color? scrimColor,
    Color? cardColor,
    Color? accentColor,
    Color? onAccentColor,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
    TextStyle? counterStyle,
    TextStyle? skipStyle,
    TextStyle? previousStyle,
    TextStyle? buttonTextStyle,
    double? cardRadius,
    EdgeInsetsDirectional? cardPadding,
    EdgeInsetsDirectional? cardMargin,
    double? cardMaxWidth,
    double? borderWidth,
    double? glowSigma,
    double? targetGap,
    double? primaryButtonHeight,
    Duration? scrimFadeDuration,
    Duration? cardEnterDuration,
    Duration? cardExitDuration,
    Duration? spotlightMorphDuration,
    Duration? pulseDuration,
    bool? contentStagger,
    Color? borderColor,
    Color? glowColor,
    double? glowOpacity,
    Color? dividerColor,
    double? dividerThickness,
    Color? iconColor,
    double? iconSize,
    Color? buttonColor,
    double? buttonRadius,
    Color? skipBorderColor,
    double? skipBorderWidth,
    double? skipRadius,
    EdgeInsetsGeometry? skipPadding,
    EdgeInsetsGeometry? previousPadding,
    Color? hintColor,
    double? hintBorderWidth,
    IconData? hintIcon,
    TextStyle? hintStyle,
    Color? cardBorderColor,
    double? cardBorderWidth,
    List<BoxShadow>? cardShadows,
    double? titleGap,
    double? bodyGap,
    double? actionsGap,
    Color? indicatorColor,
    Color? indicatorGlowColor,
    double? indicatorOpacity,
    double? indicatorSizeFactor,
    double? indicatorMinSize,
    double? indicatorMaxSize,
    double? indicatorGlowSigma,
    Curve? morphCurve,
    int? Function()? pulseRepeatCount,
  }) {
    return SpotlightTourTheme(
      scrimColor: scrimColor ?? this.scrimColor,
      cardColor: cardColor ?? this.cardColor,
      accentColor: accentColor ?? this.accentColor,
      onAccentColor: onAccentColor ?? this.onAccentColor,
      titleStyle: titleStyle ?? this.titleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      counterStyle: counterStyle ?? this.counterStyle,
      skipStyle: skipStyle ?? this.skipStyle,
      previousStyle: previousStyle ?? this.previousStyle,
      buttonTextStyle: buttonTextStyle ?? this.buttonTextStyle,
      cardRadius: cardRadius ?? this.cardRadius,
      cardPadding: cardPadding ?? this.cardPadding,
      cardMargin: cardMargin ?? this.cardMargin,
      cardMaxWidth: cardMaxWidth ?? this.cardMaxWidth,
      borderWidth: borderWidth ?? this.borderWidth,
      glowSigma: glowSigma ?? this.glowSigma,
      targetGap: targetGap ?? this.targetGap,
      primaryButtonHeight: primaryButtonHeight ?? this.primaryButtonHeight,
      scrimFadeDuration: scrimFadeDuration ?? this.scrimFadeDuration,
      cardEnterDuration: cardEnterDuration ?? this.cardEnterDuration,
      cardExitDuration: cardExitDuration ?? this.cardExitDuration,
      spotlightMorphDuration: spotlightMorphDuration ?? this.spotlightMorphDuration,
      pulseDuration: pulseDuration ?? this.pulseDuration,
      contentStagger: contentStagger ?? this.contentStagger,
      borderColor: borderColor ?? this.borderColor,
      glowColor: glowColor ?? this.glowColor,
      glowOpacity: glowOpacity ?? this.glowOpacity,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
      buttonColor: buttonColor ?? this.buttonColor,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      skipBorderColor: skipBorderColor ?? this.skipBorderColor,
      skipBorderWidth: skipBorderWidth ?? this.skipBorderWidth,
      skipRadius: skipRadius ?? this.skipRadius,
      skipPadding: skipPadding ?? this.skipPadding,
      previousPadding: previousPadding ?? this.previousPadding,
      hintColor: hintColor ?? this.hintColor,
      hintBorderWidth: hintBorderWidth ?? this.hintBorderWidth,
      hintIcon: hintIcon ?? this.hintIcon,
      hintStyle: hintStyle ?? this.hintStyle,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      cardShadows: cardShadows ?? this.cardShadows,
      titleGap: titleGap ?? this.titleGap,
      bodyGap: bodyGap ?? this.bodyGap,
      actionsGap: actionsGap ?? this.actionsGap,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorGlowColor: indicatorGlowColor ?? this.indicatorGlowColor,
      indicatorOpacity: indicatorOpacity ?? this.indicatorOpacity,
      indicatorSizeFactor: indicatorSizeFactor ?? this.indicatorSizeFactor,
      indicatorMinSize: indicatorMinSize ?? this.indicatorMinSize,
      indicatorMaxSize: indicatorMaxSize ?? this.indicatorMaxSize,
      indicatorGlowSigma: indicatorGlowSigma ?? this.indicatorGlowSigma,
      morphCurve: morphCurve ?? this.morphCurve,
      pulseRepeatCount:
          pulseRepeatCount != null ? pulseRepeatCount() : this.pulseRepeatCount,
    );
  }
}

/// Per-step visual overrides, layered on top of the tour's
/// [SpotlightTourTheme].
///
/// Set [TourStep.style] to restyle one step without touching the others:
/// every field left `null` falls back to the tour's theme, so a step can
/// change only its accent colour, only its card background, or only one
/// text style. A step without a style uses the theme unchanged, so
/// existing tours are unaffected.
///
/// Text styles MERGE over the theme's (`TextStyle.merge`): passing
/// `TextStyle(color: Colors.red)` to [titleStyle] keeps the theme's font
/// family, size and weight and changes only the colour. Colours and
/// layout values REPLACE the theme's when set.
///
/// ```dart
/// TourStep(
///   targetKey: audioButtonKey,
///   title: 'المشغل',
///   description: '...',
///   style: TourStepStyle(
///     accentColor: Colors.teal,
///     titleStyle: TextStyle(color: Colors.tealAccent),
///   ),
/// )
/// ```
class TourStepStyle {
  const TourStepStyle({
    this.scrimColor,
    this.cardColor,
    this.accentColor,
    this.onAccentColor,
    this.titleStyle,
    this.bodyStyle,
    this.counterStyle,
    this.skipStyle,
    this.previousStyle,
    this.buttonTextStyle,
    this.cardRadius,
    this.cardPadding,
    this.cardMargin,
    this.cardMaxWidth,
    this.borderWidth,
    this.glowSigma,
    this.targetGap,
    this.primaryButtonHeight,
    this.borderColor,
    this.glowColor,
    this.glowOpacity,
    this.dividerColor,
    this.dividerThickness,
    this.iconColor,
    this.iconSize,
    this.buttonColor,
    this.buttonRadius,
    this.skipBorderColor,
    this.skipBorderWidth,
    this.skipRadius,
    this.skipPadding,
    this.previousPadding,
    this.hintColor,
    this.hintBorderWidth,
    this.hintIcon,
    this.hintStyle,
    this.cardBorderColor,
    this.cardBorderWidth,
    this.cardShadows,
    this.titleGap,
    this.bodyGap,
    this.actionsGap,
    this.indicatorColor,
    this.indicatorGlowColor,
    this.indicatorOpacity,
    this.indicatorSizeFactor,
    this.indicatorMinSize,
    this.indicatorMaxSize,
    this.indicatorGlowSigma,
    this.morphCurve,
  });

  /// Backdrop colour for this step only.
  final Color? scrimColor;

  /// Tooltip card background for this step only.
  final Color? cardColor;

  /// Highlight border, glow, primary button, counter and skip pill for
  /// this step only.
  final Color? accentColor;

  /// Text/icon colour on top of [accentColor] (primary button label) for
  /// this step only.
  final Color? onAccentColor;

  /// Merged over the theme's style of the same name (see [TextStyle.merge]).
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;
  final TextStyle? counterStyle;
  final TextStyle? skipStyle;
  final TextStyle? previousStyle;
  final TextStyle? buttonTextStyle;

  final double? cardRadius;
  final EdgeInsetsDirectional? cardPadding;
  final EdgeInsetsDirectional? cardMargin;

  /// Maximum width of this step's card. Falls back to the theme's
  /// [SpotlightTourTheme.cardMaxWidth] when null.
  final double? cardMaxWidth;

  /// Stroke width of this step's highlight border.
  final double? borderWidth;

  /// Blur sigma of this step's outer glow. `0` paints the crisp border
  /// without the blur.
  final double? glowSigma;

  /// Vertical gap between this step's spotlight and the tooltip card.
  final double? targetGap;

  final double? primaryButtonHeight;

  // Fields below mirror the same-named [SpotlightTourTheme] fields; see
  // their docs. Each falls back to the tour's theme when null.

  /// Highlight border colour. Defaults to [accentColor].
  final Color? borderColor;

  /// Outer glow colour. Defaults to the border colour.
  final Color? glowColor;

  /// Opacity (0..1) of the outer glow.
  final double? glowOpacity;

  /// Line between the skip pill and the counter. Defaults to [accentColor] at 40%.
  final Color? dividerColor;

  /// Thickness of that line.
  final double? dividerThickness;

  /// Colour of the step icon. Defaults to [accentColor].
  final Color? iconColor;

  /// Size of the step icon.
  final double? iconSize;

  /// Primary button background. Defaults to [accentColor].
  final Color? buttonColor;

  /// Primary button corner radius. Defaults to a full pill (half the button height).
  final double? buttonRadius;

  /// Skip pill border. Defaults to [accentColor].
  final Color? skipBorderColor;

  /// Skip pill border width.
  final double? skipBorderWidth;

  /// Skip pill corner radius.
  final double? skipRadius;

  /// Skip pill padding.
  final EdgeInsetsGeometry? skipPadding;

  /// Padding of the Previous text button.
  final EdgeInsetsGeometry? previousPadding;

  /// Border, icon and text colour of the interaction hint. Defaults to [accentColor].
  final Color? hintColor;

  /// Interaction hint border width.
  final double? hintBorderWidth;

  /// Icon of the interaction hint.
  final IconData? hintIcon;

  /// Interaction hint text style. Defaults to [bodyStyle] in the hint colour.
  final TextStyle? hintStyle;

  /// Optional border around the tooltip card.
  final Color? cardBorderColor;

  /// Width of the card border (0 = none).
  final double? cardBorderWidth;

  /// Shadows under the tooltip card.
  final List<BoxShadow>? cardShadows;

  /// Space between the header row and the title.
  final double? titleGap;

  /// Space between title and description.
  final double? bodyGap;

  /// Space between description and buttons.
  final double? actionsGap;

  /// Colour of the pointer (pulse orb and swipe orb). Defaults to white.
  final Color? indicatorColor;

  /// Colour of the pointer glow. Defaults to [indicatorColor].
  final Color? indicatorGlowColor;

  /// Overall opacity multiplier (0..1) of the pointer.
  final double? indicatorOpacity;

  /// Pulse orb size as a fraction of the target's shorter side.
  final double? indicatorSizeFactor;

  /// Smallest pulse orb size.
  final double? indicatorMinSize;

  /// Largest pulse orb size.
  final double? indicatorMaxSize;

  /// Blur of the pointer glow (0 = no glow).
  final double? indicatorGlowSigma;

  /// Curve of the card's move between steps.
  final Curve? morphCurve;

  /// The theme the tour uses while this step is on screen: [base] with
  /// every non-null field of this style applied. Text styles merge, other
  /// fields replace.
  SpotlightTourTheme applyTo(SpotlightTourTheme base) {
    TextStyle merge(TextStyle style, TextStyle? override) =>
        override == null ? style : style.merge(override);
    return SpotlightTourTheme(
      scrimColor: scrimColor ?? base.scrimColor,
      cardColor: cardColor ?? base.cardColor,
      accentColor: accentColor ?? base.accentColor,
      onAccentColor: onAccentColor ?? base.onAccentColor,
      titleStyle: merge(base.titleStyle, titleStyle),
      bodyStyle: merge(base.bodyStyle, bodyStyle),
      counterStyle: merge(base.counterStyle, counterStyle),
      skipStyle: merge(base.skipStyle, skipStyle),
      previousStyle: merge(base.previousStyle, previousStyle),
      buttonTextStyle: merge(base.buttonTextStyle, buttonTextStyle),
      cardRadius: cardRadius ?? base.cardRadius,
      cardPadding: cardPadding ?? base.cardPadding,
      cardMargin: cardMargin ?? base.cardMargin,
      cardMaxWidth: cardMaxWidth ?? base.cardMaxWidth,
      borderWidth: borderWidth ?? base.borderWidth,
      glowSigma: glowSigma ?? base.glowSigma,
      targetGap: targetGap ?? base.targetGap,
      primaryButtonHeight: primaryButtonHeight ?? base.primaryButtonHeight,
      borderColor: borderColor ?? base.borderColor,
      glowColor: glowColor ?? base.glowColor,
      glowOpacity: glowOpacity ?? base.glowOpacity,
      dividerColor: dividerColor ?? base.dividerColor,
      dividerThickness: dividerThickness ?? base.dividerThickness,
      iconColor: iconColor ?? base.iconColor,
      iconSize: iconSize ?? base.iconSize,
      buttonColor: buttonColor ?? base.buttonColor,
      buttonRadius: buttonRadius ?? base.buttonRadius,
      skipBorderColor: skipBorderColor ?? base.skipBorderColor,
      skipBorderWidth: skipBorderWidth ?? base.skipBorderWidth,
      skipRadius: skipRadius ?? base.skipRadius,
      skipPadding: skipPadding ?? base.skipPadding,
      previousPadding: previousPadding ?? base.previousPadding,
      hintColor: hintColor ?? base.hintColor,
      hintBorderWidth: hintBorderWidth ?? base.hintBorderWidth,
      hintIcon: hintIcon ?? base.hintIcon,
      hintStyle: hintStyle ?? base.hintStyle,
      cardBorderColor: cardBorderColor ?? base.cardBorderColor,
      cardBorderWidth: cardBorderWidth ?? base.cardBorderWidth,
      cardShadows: cardShadows ?? base.cardShadows,
      titleGap: titleGap ?? base.titleGap,
      bodyGap: bodyGap ?? base.bodyGap,
      actionsGap: actionsGap ?? base.actionsGap,
      indicatorColor: indicatorColor ?? base.indicatorColor,
      indicatorGlowColor: indicatorGlowColor ?? base.indicatorGlowColor,
      indicatorOpacity: indicatorOpacity ?? base.indicatorOpacity,
      indicatorSizeFactor: indicatorSizeFactor ?? base.indicatorSizeFactor,
      indicatorMinSize: indicatorMinSize ?? base.indicatorMinSize,
      indicatorMaxSize: indicatorMaxSize ?? base.indicatorMaxSize,
      indicatorGlowSigma: indicatorGlowSigma ?? base.indicatorGlowSigma,
      morphCurve: morphCurve ?? base.morphCurve,
      scrimFadeDuration: base.scrimFadeDuration,
      cardEnterDuration: base.cardEnterDuration,
      cardExitDuration: base.cardExitDuration,
      spotlightMorphDuration: base.spotlightMorphDuration,
      pulseDuration: base.pulseDuration,
      pulseRepeatCount: base.pulseRepeatCount,
      contentStagger: base.contentStagger,
    );
  }
}
