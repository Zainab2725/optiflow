import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';

class IncidentTile extends StatelessWidget {
  final Incident incident;
  final bool compact;
  final bool selected;

  const IncidentTile({super.key,
    required this.incident,
    this.compact = false,
    this.selected = false});

  Color get _sevColor {
    switch (incident.severity) {
      case 'CRITICAL': return AppTheme.criticalRed;
      case 'HIGH': return AppTheme.warning;
      default: return AppTheme.onSurfaceVar;
    }
  }

  IconData get _sevIcon {
    switch (incident.severity) {
      case 'CRITICAL': return Icons.local_fire_department_outlined;
      case 'HIGH': return Icons.warning_amber_outlined;
      default: return Icons.info_outline;
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(incident.timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary.withOpacity(0.03) : AppTheme.surface,
        border: Border(
          left: BorderSide(color: _sevColor, width: 3),
          top: BorderSide(
              color: selected ? AppTheme.primary : AppTheme.outlineVar,
              width: selected ? 1 : 0.5),
          right: BorderSide(
              color: selected ? AppTheme.primary : AppTheme.outlineVar,
              width: selected ? 1 : 0.5),
          bottom: BorderSide(
              color: selected ? AppTheme.primary : AppTheme.outlineVar,
              width: selected ? 1 : 0.5),
        ),
        borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(8)),
      ),
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _sevColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_sevIcon, color: _sevColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        incident.title.length > 28
                            ? '${incident.title.substring(0, 28)}...'
                            : incident.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Text(_timeAgo(),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppTheme.criticalRed)),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(incident.description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppTheme.onSurfaceVar),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ] else
                  Text(incident.zone,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppTheme.onSurfaceVar)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  _tag(context, incident.severity, _sevColor),
                  if (incident.sku != 'GENERAL')
                    _tag(context, incident.sku, AppTheme.primary),
                  if (!compact && incident.unitsActive > 0)
                    _tag(context,
                        '${incident.unitsActive} Units Active',
                        AppTheme.onSurfaceVar),
                  if (!compact)
                    _riskBadge(context),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext ctx, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label,
        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: color)),
    );
  }

  Widget _riskBadge(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('RISK: ${incident.riskScore}',
        style: Theme.of(ctx).textTheme.labelSmall
            ?.copyWith(color: AppTheme.primary,
                fontWeight: FontWeight.bold)),
    );
  }
}
