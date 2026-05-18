import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';

class FleetUnitTile extends StatelessWidget {
  final FleetUnit unit;
  const FleetUnitTile({super.key, required this.unit});

  Color get _statusColor {
    switch (unit.status) {
      case 'DELAYED': return AppTheme.criticalRed;
      case 'LOADING': return AppTheme.onSurfaceVar;
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(
            color: AppTheme.outlineVar, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(unit.vehicleId,
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: _statusColor.withOpacity(0.3)),
                ),
                child: Text(unit.status,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: _statusColor)),
              ),
            ]),
            const SizedBox(height: 2),
            Text('Destination: ${unit.destination}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppTheme.onSurfaceVar)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              unit.fuelEff > 0
                  ? '${unit.fuelEff.toStringAsFixed(1)} km/L' : '---',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: unit.status == 'DELAYED'
                    ? AppTheme.criticalRed : AppTheme.primary),
            ),
            const SizedBox(height: 2),
            Row(children: [
              Icon(
                unit.delayMinutes > 0
                    ? Icons.warning_amber_outlined : Icons.timer_outlined,
                size: 12,
                color: unit.delayMinutes > 0
                    ? AppTheme.criticalRed : AppTheme.onSurfaceVar,
              ),
              const SizedBox(width: 4),
              Text(
                unit.status == 'LOADING'
                    ? 'Est. ${unit.etaMinutes ~/ 60}h'
                    : unit.delayMinutes > 0
                        ? '+${unit.delayMinutes} min'
                        : '${unit.etaMinutes} min',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: unit.delayMinutes > 0
                      ? AppTheme.criticalRed : AppTheme.onSurfaceVar),
              ),
            ]),
          ]),
        ],
      ),
    );
  }
}
