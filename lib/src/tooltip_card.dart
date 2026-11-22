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
  });

  final TourStep step;
  final int index;
  final int total;
  final SpotlightTourTheme theme;
  final TourLabels labels;
  final SpotlightTourController controller;

  bool get _isIntro => step.targetKey == null && index == 0;

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
          Row(
            children: [
              _SkipPill(theme: theme, label: labels.skip, onTap: controller.skip),
              if (!_isIntro) ...[
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                    color: theme.accentColor.withValues(alpha: 0.4),
                  ),
                ),
                if (step.icon != null) ...[
                  Icon(step.icon, size: 15, color: theme.accentColor),
                  const SizedBox(width: 5),
                ],
                Text(labels.counter(index + 1, total), style: theme.counterStyle),
              ] else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(step.title, style: theme.titleStyle, textAlign: TextAlign.start),
          const SizedBox(height: 6),
          Text(step.description, style: theme.bodyStyle, textAlign: TextAlign.start),
          const SizedBox(height: 18),
          Row(
            children: [
              if (index > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: InkWell(
                    onTap: controller.previous,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(labels.previous, style: theme.previousStyle),
                    ),
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: theme.primaryButtonHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: theme.onAccentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(theme.primaryButtonHeight / 2),
                      ),
                    ),
                    onPressed: controller.next,
                    child: Text(primaryLabel, style: theme.buttonTextStyle),
                  ),
                ),
              ),
            ],
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
