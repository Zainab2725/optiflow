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
    {'type': 'Cold-Chain Transport Van', 'icon': Icons.ac_unit_outlined,
      'id': 'KHI-CC-402', 'prox': '0.8 km', 'color': 0xFF0052D4},
    {'type': 'Heavy Delivery Truck', 'icon': Icons.local_shipping_outlined,
      'id': 'KHI-DT-109', 'prox': '1.5 km', 'color': 0xFF0052D4},
    {'type': 'Swift Motorcycle Courier', 'icon': Icons.two_wheeler_outlined,
      'id': 'KHI-MC-058', 'prox': '0.3 km', 'color': 0xFF16A34A},
    {'type': 'Pharma Security Escort', 'icon': Icons.shield_outlined,
      'id': 'KHI-SV-991', 'prox': '2.1 km', 'color': 0xFF515F74},
    {'type': 'Warehouse Backup Runner', 'icon': Icons.flash_on_outlined,
      'id': 'KHI-WR-004', 'prox': '3.8 km', 'color': 0xFFD97706},
  ];

  @override
  Widget build(BuildContext context) {
    // Dynamically calculate metrics based on incident severity
    final severity = widget.incident.severity.toUpperCase();
    String totalDeployed;
    String avgResponse;
    String activePersonnel;
    
    if (severity == 'CRITICAL') {
      totalDeployed = '14 Fleet Units';
      avgResponse = '4.2 mins';
      activePersonnel = '38 dispatchers';
    } else if (severity == 'HIGH') {
      totalDeployed = '8 Fleet Units';
      avgResponse = '7.5 mins';
      activePersonnel = '22 dispatchers';
    } else {
      totalDeployed = '3 Fleet Units';
      avgResponse = '15.8 mins';
      activePersonnel = '8 dispatchers';
    }

    // Dynamic asset proximities based on hash of incident ID to make distances feel real and unique
    final int hash = widget.incident.id.hashCode.abs();
    final dynamicAssets = _assets.map((a) {
      final double baseProx = double.tryParse((a['prox'] as String).replaceAll(' km', '')) ?? 1.0;
      final double offset = ((hash + a['type'].hashCode) % 8) / 10.0;
      final double finalProx = double.parse((baseProx + offset).toStringAsFixed(1));
      return {
        ...a,
        'prox': '$finalProx km',
      };
    }).toList();

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
                    try {
                      await _fs.updateIncidentStatus(
                          widget.incident.id, 'dispatched');
                    } catch (_) {}
                    if (mounted) {
                      String notifyMessage;
                      final id = widget.incident.id;
                      final zone = widget.incident.zone;
                      
                      if (id == 'ai-weather-alert') {
                        notifyMessage = '⛈️ Detour warning broadcasted to ALL drivers active in $zone zone!';
                      } else if (id.startsWith('ai-supplier-delay')) {
                        notifyMessage = '📦 SITE Depot receiving crew notified to prepare secondary bay inbound logistics!';
                      } else if (id == 'ai-trend-panic') {
                        notifyMessage = '📈 Shortage replenishment orders sent to $zone Depot and local pharmacy managers!';
                      } else if (id.startsWith('ai-') || widget.incident.reporterName == 'Public Feed') {
                        notifyMessage = '🌐 City-wide obstacle warning sent to all drivers active in $zone!';
                      } else {
                        notifyMessage = '⚡ Dispatch orders sent to your organization drivers active in $zone!';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(notifyMessage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        backgroundColor: AppTheme.success,
                        duration: const Duration(seconds: 5),
                      ));
                    }
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
          ...dynamicAssets.map((a) => Container(
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
                  Text(totalDeployed,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: AppTheme.primary)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AVG RESPONSE TIME',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppTheme.onSurfaceVar)),
                  Text(avgResponse,
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
              Text(activePersonnel,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}
