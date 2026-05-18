import 'package:flutter/material.dart';
import '../theme.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color barColor;

  const KpiCard({super.key,
    required this.label, required this.value,
    required this.icon, required this.color,
    required this.barColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppTheme.onSurfaceVar)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(value,
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(color: color)),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
