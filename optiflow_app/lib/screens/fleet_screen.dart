import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/firestore_service.dart';
import '../widgets/fleet_unit_tile.dart';
import '../widgets/ai_recommendation_card.dart';

class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});
  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  final _fs = FirestoreService();
  int _executedIdx = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Karachi Command'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<List<FleetUnit>>(
        stream: _fs.fleetStream(),
        builder: (ctx, snap) {
          final fleet = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── KPIs ──
              Row(children: [
                Expanded(child: _metricTile(context, 'FUEL EFFICIENCY', '94.2%')),
                const SizedBox(width: 12),
                Expanded(child: _metricTile(context, 'ON-TIME ARRIVAL', '88.5%')),
              ]),
              const SizedBox(height: 16),
              // ── Active Fleet ──
              Text('ACTIVE FLEET',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppTheme.onSurfaceVar)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                ),
                child: Column(
                  children: fleet.isEmpty
                      ? [const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()))]
                      : fleet.map((u) => FleetUnitTile(unit: u)).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // ── Fleet Operational Status table ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fleet Operational Status',
                    style: Theme.of(context).textTheme.headlineMedium),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.filter_list, size: 14),
                      label: const Text('Filter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Export'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              _fleetTable(context, fleet),
              const SizedBox(height: 20),
              // ── AI Dispatch Recommendations ──
              Row(children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text('AI Dispatch Recommendations',
                  style: Theme.of(context).textTheme.headlineMedium),
              ]),
              const SizedBox(height: 12),
              AiRecommendationCard(
                tag: 'OPTIMIZATION #412',
                tagColor: AppTheme.primary,
                tagRight: '-28m Delay',
                tagRightColor: AppTheme.success,
                icon: Icons.route_outlined,
                title: 'Reroute TRUCK-092 via Lyari Expressway to bypass M-9 accident.',
                subtitle: '↗ Estimated Fuel Savings: 4.2%',
                buttonLabel: 'EXECUTE RE-DISPATCH',
                buttonFilled: true,
                executed: _executedIdx == 0,
                onPressed: () => setState(() => _executedIdx = 0),
              ),
              const SizedBox(height: 12),
              AiRecommendationCard(
                tag: 'FUEL SAVE #109',
                tagColor: AppTheme.success,
                tagRight: 'Efficiency Gain',
                tagRightColor: AppTheme.onSurfaceVar,
                icon: Icons.speed_outlined,
                title: 'Reduce speed cap for FT-492 by 10km/h on N-5 highway segment.',
                subtitle: '⊕ +3 min to ETA (Negligible)',
                buttonLabel: 'APPLY SPEED PROFILE',
                buttonFilled: false,
                executed: _executedIdx == 1,
                onPressed: () => setState(() => _executedIdx = 1),
              ),
              const SizedBox(height: 12),
              AiRecommendationCard(
                tag: 'SCHEDULE #055',
                tagColor: AppTheme.onSurfaceVar,
                tagRight: 'Queue Opt',
                tagRightColor: AppTheme.onSurfaceVar,
                icon: Icons.schedule_outlined,
                title: 'Delay departure of FT-211 by 20 min to avoid peak gate congestion at Site.',
                subtitle: '',
                buttonLabel: 'DISMISS',
                buttonFilled: false,
                executed: _executedIdx == 2,
                onPressed: () => setState(() => _executedIdx = 2),
              ),
              const SizedBox(height: 20),
              // ── Fleet Health ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FLEET HEALTH',
                    style: Theme.of(context).textTheme.labelLarge),
                  Text('Stable',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: AppTheme.success)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: 0.88,
                color: AppTheme.primary,
                backgroundColor: AppTheme.surfaceContainer,
                minHeight: 4,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricTile(BuildContext ctx, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: Theme.of(ctx).textTheme.labelSmall
              ?.copyWith(color: AppTheme.onSurfaceVar)),
        const SizedBox(height: 4),
        Text(value,
          style: Theme.of(ctx).textTheme.headlineLarge
              ?.copyWith(color: AppTheme.primary)),
      ]),
    );
  }

  Widget _fleetTable(BuildContext ctx, List<FleetUnit> fleet) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(children: [
            Expanded(child: Text('VEHICLE ID',
              style: Theme.of(ctx).textTheme.labelSmall)),
            Expanded(child: Text('CARGO TYPE',
              style: Theme.of(ctx).textTheme.labelSmall)),
            Expanded(child: Text('DESTINATION',
              style: Theme.of(ctx).textTheme.labelSmall)),
          ]),
        ),
        ...(fleet.isEmpty ? [
          {'vehicle_id': 'FT-492', 'cargo': 'Consumer Goods', 'dest': 'Port Qasim'},
          {'vehicle_id': 'TRUCK-092', 'cargo': 'Industrial Raw', 'dest': 'Korangi'},
          {'vehicle_id': 'FT-211', 'cargo': 'Textile Export', 'dest': 'Site Area'},
          {'vehicle_id': 'FT-305', 'cargo': 'Pharma Supplies', 'dest': 'Defense Ph 6'},
          {'vehicle_id': 'TRUCK-118', 'cargo': 'Heavy Machinery', 'dest': 'Hub Chawki'},
        ].map((r) => _tableRow(ctx, r['vehicle_id']!,
            r['cargo']!, r['dest']!))
        : fleet.map((u) => _tableRow(ctx,
            u.vehicleId, u.cargoType, u.destination))),
      ]),
    );
  }

  Widget _tableRow(BuildContext ctx, String vid, String cargo, String dest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.outlineVar, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(child: Text(vid,
          style: Theme.of(ctx).textTheme.labelMedium
              ?.copyWith(color: AppTheme.primary))),
        Expanded(child: Text(cargo,
          style: Theme.of(ctx).textTheme.bodySmall)),
        Expanded(child: Text(dest,
          style: Theme.of(ctx).textTheme.bodySmall)),
      ]),
    );
  }
}
