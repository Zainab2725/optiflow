import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/incident_tile.dart';
import '../widgets/sector_load_bar.dart';
import '../models.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _dashData = {};
  Map<String, dynamic> _ingestData = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Phase 1: Load core logistics and dashboard statistics instantly from the host
      final dash = await _api.getDashboardData();
      if (mounted) {
        setState(() {
          _dashData = dash;
          _loading = false;
        });
      }

      // Phase 2: Load optional heavy AI telemetry & currency rates in the background
      try {
        final ingest = await _api.getIngest();
        if (mounted) {
          setState(() {
            _ingestData = ingest;
          });
        }
      } catch (ingestError) {
        debugPrint('Optional background ingest telemetry failed (graceful fallback): $ingestError');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: Text(
          ApiService.currentUser?['org_name'] ?? 'Command Center',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: AppTheme.primary,
                  child: _buildBody(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppTheme.criticalRed, size: 48),
            const SizedBox(height: 16),
            Text('Could not connect to backend.', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVar), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final overview = _dashData['overview'] as Map<String, dynamic>? ?? {};
    final zoneRisk = Map<String, dynamic>.from(_dashData['zone_risk_map'] ?? {});
    final contradictions = List<dynamic>.from(_dashData['contradictions'] ?? []);
    final recentIncidents = List<dynamic>.from(_dashData['recent_incidents'] ?? []);

    final totalStockRecords = overview['total_stock_records'] ?? 0;
    final criticalStockCount = overview['critical_stock_count'] ?? 0;
    final activeIncidents = overview['active_incidents'] ?? 0;
    final redZones = List<dynamic>.from(overview['red_zones'] ?? []);
    final contradictionsFound = overview['contradictions_found'] ?? 0;
    final complaintSpike = overview['complaint_spike'] == true;

    // Ingest telemetry
    final pkrRate = (_ingestData['currency']?['data']?['usd_to_pkr'] ?? 0.0).toDouble();
    final weather = _ingestData['weather']?['data']?['condition'] ?? '--';
    final sourcesHealthy = _ingestData['meta']?['sources_healthy'] ?? 0;

    // Derived health score
    final systemHealth = (100.0 - (contradictionsFound * 5.0) - (activeIncidents * 2.0)).clamp(0.0, 100.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Complaint Spike Alert Banner ──
        if (complaintSpike) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.criticalRedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.criticalRed.withOpacity(0.5)),
            ),
            child: Row(children: [
              const Icon(Icons.campaign_outlined, color: AppTheme.criticalRed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'COMPLAINT SPIKE DETECTED — Unusual surge in field reports. Activate response protocol.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.criticalRed, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Header ──
        Row(
          children: [
            const Icon(Icons.bar_chart, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Critical Indicators', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),

        // ── KPI Grid (all live data) ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            KpiCard(
              label: 'SYSTEM STATUS',
              value: '${systemHealth.toStringAsFixed(1)}%',
              icon: Icons.monitor_heart_outlined,
              color: systemHealth > 80 ? AppTheme.success : AppTheme.criticalRed,
              barColor: systemHealth > 80 ? AppTheme.success : AppTheme.criticalRed,
            ),
            KpiCard(
              label: 'TOTAL ITEMS',
              value: '$totalStockRecords Items',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.primary,
              barColor: AppTheme.primary,
            ),
            KpiCard(
              label: 'LOW STOCK ITEMS',
              value: '$criticalStockCount Items',
              icon: Icons.gpp_maybe_outlined,
              color: criticalStockCount > 0 ? AppTheme.criticalRed : AppTheme.success,
              barColor: criticalStockCount > 0 ? AppTheme.criticalRed : AppTheme.success,
            ),
            KpiCard(
              label: 'ACTIVE REPORTS',
              value: '$activeIncidents',
              icon: Icons.notifications_outlined,
              color: activeIncidents > 5 ? AppTheme.criticalRed : AppTheme.warning,
              barColor: activeIncidents > 5 ? AppTheme.criticalRed : AppTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Red Zones Summary ──
        if (redZones.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.criticalRedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.criticalRed.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: AppTheme.criticalRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HIGH RISK AREAS: ${redZones.join(', ')}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.criticalRed, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Live Zone Risk Map ──
        if (zoneRisk.isNotEmpty) ...[
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
                  const Icon(Icons.map_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text('Active Incidents by Area', style: Theme.of(context).textTheme.headlineSmall),
                ]),
                const SizedBox(height: 16),
                ...zoneRisk.entries.map((e) {
                  final riskStr = e.value['risk'] ?? 'GREEN';
                  final color = riskStr == 'RED'
                      ? AppTheme.criticalRed
                      : (riskStr == 'YELLOW' ? AppTheme.warning : AppTheme.success);
                  final active = e.value['active_incidents'] ?? 0;
                  final pct = riskStr == 'RED' ? 90 : (riskStr == 'YELLOW' ? 55 : 20);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectorLoadBar(
                      zone: '${e.key.toUpperCase()} — $active Incident(s)',
                      percent: pct,
                      color: color,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── AI Contradictions Panel ──
        if (contradictions.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.criticalRedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.criticalRed.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.criticalRed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'ALERT: $contradictionsFound STOCK MISMATCHES DETECTED',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.criticalRed, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 12),
                ...contradictions.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '[${c['sku'] ?? 'N/A'}] @ ${c['depot'] ?? c['location'] ?? 'Unknown'} (${c['zone'] ?? '—'}): ${c['explanation'] ?? c['anomaly'] ?? 'Stock report discrepancy found'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.criticalRed, fontWeight: FontWeight.w600),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Recent Incidents from Backend ──
        if (recentIncidents.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.rss_feed, color: AppTheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Text('RECENT INCIDENTS',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primary)),
                      ]),
                      Text('LIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.success)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...recentIncidents.map((raw) {
                  final inc = Incident.fromMap(raw as Map<String, dynamic>);
                  return IncidentTile(incident: inc, compact: true);
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Data Source Status Bar (all live from /ingest) ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sourcesHealthy > 5 ? AppTheme.successBg : AppTheme.criticalRedBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: (sourcesHealthy > 5 ? AppTheme.success : AppTheme.criticalRed).withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(
              sourcesHealthy > 5 ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 14,
              color: sourcesHealthy > 5 ? AppTheme.success : AppTheme.criticalRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$sourcesHealthy/8 DATA SOURCES LIVE'
                '${pkrRate > 0 ? '   •   USD/PKR: ${pkrRate.toStringAsFixed(1)}' : ''}'
                '${weather != '--' ? '   •   WEATHER: $weather' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: sourcesHealthy > 5 ? AppTheme.success : AppTheme.criticalRed),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
