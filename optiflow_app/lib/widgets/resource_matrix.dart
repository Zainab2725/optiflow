import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/firestore_service.dart';

class ResourceMatrix extends StatefulWidget {
  final Incident incident;
  const ResourceMatrix({super.key, required this.incident});
  @override
  State<ResourceMatrix> createState() => _ResourceMatrixState();
}

class _ResourceMatrixState extends State<ResourceMatrix> {
  bool _dispatched = false;
  final _fs = FirestoreService();

  final _assets = [
    {'type': 'Fire Engine', 'icon': Icons.local_fire_department_outlined,
      'id': 'KHI-FD-102', 'prox': '0.4 km', 'color': 0xFFDC2626},
    {'type': 'Water Tender', 'icon': Icons.water_outlined,
      'id': 'KHI-WT-058', 'prox': '1.2 km', 'color': 0xFF0052D4},
    {'type': 'ALS Ambulance', 'icon': Icons.local_hospital_outlined,
      'id': 'KHI-EMS-22', 'prox': '0.8 km', 'color': 0xFFDC2626},
    {'type': 'Patrol Unit', 'icon': Icons.shield_outlined,
      'id': 'KHI-PD-771', 'prox': '2.5 km', 'color': 0xFF515F74},
    {'type': 'Aerial Ladder', 'icon': Icons.height_outlined,
      'id': 'KHI-FD-Ladder4', 'prox': '4.1 km', 'color': 0xFFDC2626},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.grid_view_outlined,
                      size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text('Resource Allocation Matrix',
                      style: Theme.of(context).textTheme.headlineSmall),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'ACTIVE INCIDENT: ${widget.incident.title.toUpperCase()}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppTheme.onSurfaceVar),
                  ),
                ]),
                ElevatedButton.icon(
                  onPressed: _dispatched ? null : () async {
                    setState(() => _dispatched = true);
                    await _fs.updateIncidentStatus(
                        widget.incident.id, 'dispatched');
                  },
                  icon: Icon(_dispatched
                      ? Icons.check : Icons.add_circle_outline,
                    size: 14),
                  label: Text(_dispatched
                      ? 'DISPATCHED' : 'DISPATCH\nREINFORCEMENTS',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dispatched
                        ? AppTheme.success : AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table header
          Container(
            color: AppTheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(child: Text('ASSET TYPE',
                style: Theme.of(context).textTheme.labelSmall)),
              Expanded(child: Text('IDENTIFIER',
                style: Theme.of(context).textTheme.labelSmall)),
              const SizedBox(width: 70, child: Text('PROXIMITY',
                style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVar))),
            ]),
          ),
          ..._assets.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: AppTheme.outlineVar, width: 0.5))),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Icon(a['icon'] as IconData,
                    size: 16,
                    color: Color(a['color'] as int)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(a['type'] as String,
                    style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
              Expanded(
                child: Text(a['id'] as String,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: AppTheme.primary)),
              ),
              SizedBox(width: 70, child: Text(a['prox'] as String,
                style: Theme.of(context).textTheme.bodySmall)),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TOTAL DEPLOYED',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppTheme.onSurfaceVar)),
                  Text('12 Units',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: AppTheme.primary)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AVG RESPONSE TIME',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppTheme.onSurfaceVar)),
                  Text('8.4 mins',
                    style: Theme.of(context).textTheme.headlineMedium),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              Text('PERSONNEL COUNT',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppTheme.onSurfaceVar)),
              const SizedBox(width: 8),
              Text('42 active',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}
