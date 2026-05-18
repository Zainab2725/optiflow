import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../models.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/incident_tile.dart';
import '../widgets/sector_load_bar.dart';
import '../widgets/peak_deployment_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _fs = FirestoreService();
  final _api = ApiService();
  double _pkrRate = 278.5;
  String _weatherStatus = 'CLEAR';
  int _sourcesHealthy = 6;
  bool _loadingIngest = false;

  @override
  void initState() {
    super.initState();
    _loadIngest();
  }

  Future<void> _loadIngest() async {
    setState(() => _loadingIngest = true);
    final data = await _api.getIngest();
    setState(() {
      _pkrRate = (data['currency']?['data']?['usd_to_pkr'] ?? 278.5).toDouble();
      _weatherStatus = data['weather']?['data']?['condition'] ?? 'Clear';
      _sourcesHealthy = data['meta']?['sources_healthy'] ?? 6;
      _loadingIngest = false;
    });
  }

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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _fs.dashboardStream(),
        builder: (ctx, snap) {
          final kpi = snap.data ?? {};
          final total = kpi['total'] ?? 0;
          final critical = kpi['critical'] ?? 0;
          final health = (kpi['system_health'] ?? 99.8).toDouble();
          return RefreshIndicator(
            onRefresh: _loadIngest,
            color: AppTheme.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Critical Indicators header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.bar_chart, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text('Critical Indicators',
                        style: Theme.of(context).textTheme.headlineSmall),
                    ]),
                    Text('LAST UPDATE: ${TimeOfDay.now().format(context)}',
                      style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 12),
                // ── KPI Grid ──
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    KpiCard(
                      label: 'SYSTEM HEALTH',
                      value: '${health.toStringAsFixed(1)}%',
                      icon: Icons.monitor_heart_outlined,
                      color: health > 95 ? AppTheme.success : AppTheme.warning,
                      barColor: health > 95 ? AppTheme.success : AppTheme.warning,
                    ),
                    KpiCard(
                      label: 'ACTIVE UNITS',
                      value: '${482 - critical * 2}',
                      icon: Icons.local_shipping_outlined,
                      color: AppTheme.primary,
                      barColor: AppTheme.primary,
                    ),
                    KpiCard(
                      label: 'RESPONSE TIME',
                      value: '8.4m',
                      icon: Icons.timer_outlined,
                      color: AppTheme.primary,
                      barColor: AppTheme.primary,
                    ),
                    KpiCard(
                      label: 'ALERT VOLUME',
                      value: '${total}/h',
                      icon: Icons.notifications_outlined,
                      color: total > 10 ? AppTheme.criticalRed : AppTheme.warning,
                      barColor: total > 10 ? AppTheme.criticalRed : AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Live Tactical Intelligence ──
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.rss_feed,
                                color: AppTheme.primary, size: 14),
                              const SizedBox(width: 6),
                              Text('LIVE TACTICAL INTELLIGENCE',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppTheme.primary)),
                            ]),
                            Text('EXPORT LOGS',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppTheme.primary)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      StreamBuilder<List<Incident>>(
                        stream: _fs.incidentsStream(),
                        builder: (_, incSnap) {
                          final incidents = incSnap.data ?? [];
                          if (incidents.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Column(
                            children: [
                              ...incidents.take(4).map((inc) =>
                                IncidentTile(incident: inc, compact: true)),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('LOAD MORE DATA',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: AppTheme.primary)),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Sector Load ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.account_tree_outlined,
                          size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text('Sector Load',
                          style: Theme.of(context).textTheme.headlineSmall),
                      ]),
                      const SizedBox(height: 16),
                      const SectorLoadBar(zone: 'ZONE NORTH', percent: 78,
                          color: AppTheme.primary),
                      const SizedBox(height: 10),
                      const SectorLoadBar(zone: 'ZONE SOUTH', percent: 42,
                          color: AppTheme.primary),
                      const SizedBox(height: 10),
                      const SectorLoadBar(zone: 'ZONE EAST', percent: 89,
                          color: AppTheme.criticalRed),
                      const SizedBox(height: 10),
                      const SectorLoadBar(zone: 'ZONE WEST', percent: 55,
                          color: AppTheme.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Peak Deployment Chart ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Peak Deployment',
                        style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      const SizedBox(height: 120,
                          child: PeakDeploymentChart()),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Direct Actions ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Direct Actions',
                        style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _actionButton(
                          context, Icons.add_alert_outlined, 'NEW ALERT')),
                        const SizedBox(width: 12),
                        Expanded(child: _actionButton(
                          context, Icons.sync_outlined, 'SYNC UNITS')),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Data sources status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.cloud_done_outlined,
                      size: 14, color: AppTheme.success),
                    const SizedBox(width: 8),
                    Text('$_sourcesHealthy/8 DATA SOURCES LIVE   '
                        'USD/PKR: ${_pkrRate.toStringAsFixed(1)}   '
                        'WEATHER: $_weatherStatus',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppTheme.success)),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton(BuildContext ctx, IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label,
        style: Theme.of(ctx).textTheme.labelLarge),
    );
  }
}
