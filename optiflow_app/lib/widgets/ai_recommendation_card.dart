import 'package:flutter/material.dart';
import '../theme.dart';

class AiRecommendationCard extends StatelessWidget {
  final String tag;
  final Color tagColor;
  final String tagRight;
  final Color tagRightColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool buttonFilled;
  final bool executed;
  final VoidCallback onPressed;

  const AiRecommendationCard({super.key,
    required this.tag, required this.tagColor,
    required this.tagRight, required this.tagRightColor,
    required this.icon, required this.title,
    required this.subtitle, required this.buttonLabel,
    required this.buttonFilled, required this.executed,
    required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tag,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: tagColor)),
              Text(tagRight,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: tagRightColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                style: Theme.of(context).textTheme.bodyMedium),
            ),
          ]),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppTheme.onSurfaceVar)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: executed
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.successBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 14, color: AppTheme.success),
                          const SizedBox(width: 6),
                          Text('EXECUTED',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppTheme.success)),
                        ],
                      ),
                    ),
                  )
                : buttonFilled
                    ? ElevatedButton(
                        onPressed: onPressed,
                        child: Text(buttonLabel,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: Colors.white)),
                      )
                    : OutlinedButton(
                        onPressed: onPressed,
                        child: Text(buttonLabel,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppTheme.primary)),
                      ),
          ),
        ],
      ),
    );
  }
}
