import 'package:flutter/material.dart';
import '../theme.dart';

class SectorLoadBar extends StatelessWidget {
  final String zone;
  final int percent;
  final Color color;
  const SectorLoadBar({super.key,
    required this.zone, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(zone,
              style: Theme.of(context).textTheme.bodySmall),
            Text('$percent%',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: AppTheme.onSurface)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent / 100,
            color: color,
            backgroundColor: AppTheme.surfaceContainer,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
