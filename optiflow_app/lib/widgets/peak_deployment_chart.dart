import 'package:flutter/material.dart';
import '../theme.dart';

class PeakDeploymentChart extends StatelessWidget {
  const PeakDeploymentChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [45, 55, 80, 60, 90, 70, 55, 40];
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...data.asMap().entries.map((e) {
          final isMax = e.value == maxVal.toInt();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: (e.value / maxVal) * 100,
                decoration: BoxDecoration(
                  color: isMax
                      ? AppTheme.primary
                      : AppTheme.primary.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
