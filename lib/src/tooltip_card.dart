import 'package:flutter/material.dart';

import 'tour_controller.dart';
import 'tour_labels.dart';
import 'tour_step.dart';
import 'tour_theme.dart';

/// The dark tooltip card: skip pill + counter row, title, body and the
/// previous/next buttons, matching the reference tour's layout (RTL aware).
class TourTooltipCard extends StatelessWidget {
  const TourTooltipCard({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.theme,
    required this.labels,
    required this.controller,
    this.entrance,
    this.stagger = false,
  });

  final TourStep step;
  final int index;
  final int total;
  final SpotlightTourTheme theme;
  final TourLabels labels;
  final SpotlightTourController controller;

  /// The card's entrance animation (0..1). When [stagger] is true, the
  /// header, title, body and buttons fade and slide in one after another
  /// over the second half of the entrance instead of appearing at once.
  final Animation<double>? entrance;

  /// Whether to stagger the content's entrance. Off for reduced motion and
  /// when [SpotlightTourTheme.contentStagger] is false.
  final bool stagger;

  bool get _isIntro => step.targetKey == null && index == 0;

  /// Wraps [child] in a fade + gentle upward slide over [start]..[end] of
  /// the entrance animation. Without stagger (or after it) the child is
  /// returned as is, so the settled card has zero animation overhead.
  Widget _staggered(Widget child, double start, double end) {
    final animation = entrance;
    if (!stagger || animation == null) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    final primaryLabel = _isIntro
        ? labels.start
        : isLast
            ? labels.done
            : labels.next;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(theme.cardRadius),
      ),
      padding: theme.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _staggered(
            Row(
              children: [
                _SkipPill(
                    theme: theme, label: labels.skip, onTap: controller.skip),
                if (!_isIntro) ...[
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 12),
                      color: theme.accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                  if (step.icon != null) ...[
                    Icon(step.icon, size: 15, color: theme.accentColor),
                    const SizedBox(width: 5),
                  ],
                  Text(labels.counter(index + 1, total),
                      style: theme.counterStyle),
                ] else
                  const Spacer(),
              ],
            ),
            0.0,
            0.55,
          ),
          const SizedBox(height: 14),
          _staggered(
            Text(step.title,
                style: theme.titleStyle, textAlign: TextAlign.start),
            0.15,
            0.7,
          ),
          const SizedBox(height: 6),
          _staggered(
            Text(step.description,
                style: theme.bodyStyle, textAlign: TextAlign.start),
            0.3,
            0.85,
          ),
          const SizedBox(height: 18),
          // Rebuilds on controller notifications so the busy state (a step
          // action running, or the transition animation) disables the
          // buttons while the tour moves.
          _staggered(
            ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final busy = controller.isBusy;
              return Row(
                children: [
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: InkWell(
                        onTap: busy ? null : controller.previous,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          child: Text(labels.previous,
                              style: theme.previousStyle),
                        ),
                      ),
                    ),
                  Expanded(
                    child: step.requireInteraction
                        ? _InteractionHint(
                            theme: theme,
                            text:
                                step.interactionHint ?? labels.interactionHint,
                          )
                        : SizedBox(
                            height: theme.primaryButtonHeight,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.accentColor,
                                foregroundColor: theme.onAccentColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      theme.primaryButtonHeight / 2),
                                ),
                              ),
                              onPressed: busy ? null : controller.next,
                              child: busy
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.onAccentColor,
                                      ),
                                    )
                                  : Text(primaryLabel,
                                      style: theme.buttonTextStyle),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
            0.45,
            1.0,
          ),
        ],
      ),
    );
  }
}

/// The centered hint that replaces the primary button on
/// `TourStep.requireInteraction` steps: the user must perform the real
/// gesture in the app to continue.
class _InteractionHint extends StatelessWidget {
  const _InteractionHint({required this.theme, required this.text});

  final SpotlightTourTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: theme.primaryButtonHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
            color: theme.accentColor.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(theme.primaryButtonHeight / 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: theme.accentColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.bodyStyle.copyWith(color: theme.accentColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipPill extends StatelessWidget {
  const _SkipPill({required this.theme, required this.label, required this.onTap});

  final SpotlightTourTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.accentColor, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: theme.skipStyle),
      ),
    );
  }
}
