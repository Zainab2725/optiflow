import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/agent_state_provider.dart';
import '../widgets/kpi_card.dart';
import '../widgets/incident_tile.dart';
import '../widgets/sector_load_bar.dart';
import '../models.dart';
import 'profile_screen.dart';
import 'agent_console_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  bool _loadingCore = true;
  String? _coreError;
  Map<String, dynamic> _dashData = {};

  @override
  void initState() {
    super.initState();
    _loadCoreStats();
  }

  Future<void> _loadCoreStats() async {
    setState(() {
      _loadingCore = true;
      _coreError = null;
    });
    try {
      final dash = await _api.getDashboardData();
      if (mounted) {
        setState(() {
          _dashData = dash;
          _loadingCore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _coreError = e.toString();
          _loadingCore = false;
        });
      }
    }
  }

  Future<void> _triggerRefresh(BuildContext context) async {
    // Refresh both core dashboard and global AI agent state
    await Future.wait([
      _loadCoreStats(),
      Provider.of<AgentStateProvider>(context, listen: false).runWorkflow(quiet: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;
    final isLoadingAgent = state.isLoading;

    final insights = latestResult?['insights'] as Map<String, dynamic>? ?? {};
    final decision = latestResult?['decision'] as Map<String, dynamic>? ?? {};
    final simulation = latestResult?['simulation'] as Map<String, dynamic>? ?? {};
    final action = latestResult?['action'] as Map<String, dynamic>? ?? {};

    final isCritical = decision['risk_level'] == 'CRITICAL';
    final actionType = action['type']?.toString() ?? decision['selected_action']?['type']?.toString();

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: Row(
          children: [
            Text(ApiService.currentUser?['org_name'] ?? 'Command Center'),
            const SizedBox(width: 8),
            if (state.autoRefreshEnabled)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => _triggerRefresh(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: _loadingCore && latestResult == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _coreError != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: () => _triggerRefresh(context),
                  color: AppTheme.primary,
                  child: _buildBody(state, latestResult, insights, decision, simulation, action, isCritical, actionType),
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
            Text(_coreError ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVar), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCoreStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AgentStateProvider state,
    Map<String, dynamic>? latestResult,
    Map<String, dynamic> insights,
    Map<String, dynamic> decision,
    Map<String, dynamic> simulation,
    Map<String, dynamic> action,
    bool isCritical,
    String? actionType,
  ) {
    // 1. Extract raw dashboard statistics
    final overview = _dashData['overview'] as Map<String, dynamic>? ?? {};
    final zoneRisk = Map<String, dynamic>.from(_dashData['zone_risk_map'] ?? {});
    final contradictions = List<dynamic>.from(_dashData['contradictions'] ?? []);
    final recentIncidents = List<dynamic>.from(_dashData['recent_incidents'] ?? []);

    int totalStockRecords = overview['total_stock_records'] ?? 0;
    int criticalStockCount = overview['critical_stock_count'] ?? 0;
    int activeIncidentsCount = overview['active_incidents'] ?? 0;
    List<dynamic> redZones = List<dynamic>.from(overview['red_zones'] ?? []);
    int contradictionsFound = overview['contradictions_found'] ?? 0;

    // Override statistics dynamically if we have a live AI workflow response
    if (latestResult != null) {
      final signals = insights['signals'] as List<dynamic>? ?? [];
      if (signals.isNotEmpty) {
        activeIncidentsCount = signals.length;
        redZones = signals.where((s) => s.toString().toLowerCase().contains('flood') || s.toString().toLowerCase().contains('block')).toList();
      }
      
      // If decision contains low stock alerts
      final reason = decision['primary_insight']?.toString().toLowerCase() ?? '';
      if (reason.contains('stock') || reason.contains('insulin')) {
        criticalStockCount = (criticalStockCount == 0) ? 1 : criticalStockCount;
      }
    }

    // Health score calculations
    final systemHealth = (100.0 - (contradictionsFound * 5.0) - (activeIncidentsCount * 2.0)).clamp(0.0, 100.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Critical Pulsing Alert Header ──
        if (isCritical) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F1D1D), Color(0xFFBA1A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gpp_bad, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CRITICAL CRISIS THREAT ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        decision['primary_insight'] ?? 'Awaiting live agent intelligence...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Autonomous AI Decision Agent Banner ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AgentConsoleScreen()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.psychology, color: Color(0xFF38BDF8), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚡ LAUNCH AI DECISION CONSOLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.isLoading
                                ? 'Agent pipeline executing in background...'
                                : 'Run Multi-Agent Content-to-Action pipeline live.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF38BDF8),
                        ),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Indicators Section ──
        Row(
          children: [
            const Icon(Icons.bar_chart, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Critical Indicators', style: Theme.of(context).textTheme.headlineSmall),
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
              label: 'LOW STOCK SKU',
              value: '$criticalStockCount Items',
              icon: Icons.gpp_maybe_outlined,
              color: criticalStockCount > 0 ? AppTheme.criticalRed : AppTheme.success,
              barColor: criticalStockCount > 0 ? AppTheme.criticalRed : AppTheme.success,
            ),
            KpiCard(
              label: 'ACTIVE SIGNALS',
              value: '$activeIncidentsCount',
              icon: Icons.notifications_outlined,
              color: activeIncidentsCount > 3 ? AppTheme.criticalRed : AppTheme.warning,
              barColor: activeIncidentsCount > 3 ? AppTheme.criticalRed : AppTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Active Emergency Dispatches ──
        if (action.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'ACTIVE EMERGENCY ACTION',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.greenAccent, width: 0.5),
                      ),
                      child: Text(
                        actionType ?? 'ROUTE_CHANGE',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (action['parameters']?['item_name'] != null)
                  _buildActionDetailRow('DISPATCHED ITEM', action['parameters']!['item_name'].toString()),
                if (action['parameters']?['quantity_ordered'] != null)
                  _buildActionDetailRow('ORDER QUANTITY', '${action['parameters']!['quantity_ordered']} Units'),
                if (action['parameters']?['blocked_road'] != null)
                  _buildActionDetailRow('ROAD BLOCKED', action['parameters']!['blocked_road'].toString()),
                if (action['parameters']?['alternative_route'] != null)
                  _buildActionDetailRow('AI ALTERNATIVE BYPASS', action['parameters']!['alternative_route'].toString()),
                if (action['parameters']?['target_warehouse'] != null)
                  _buildActionDetailRow('TARGET DEPOT', action['parameters']!['target_warehouse'].toString()),
                Builder(
                  builder: (context) {
                    final delayStr = simulation['impact_metrics']?['eta_improvement']?.toString() ?? simulation['impact_metrics']?['delay_reduction']?.toString() ?? 'N/A';
                    if (delayStr == 'N/A' || delayStr == '0' || delayStr == '0%' || delayStr.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI DECISION DELAY SAVED:',
                            style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            delayStr,
                            style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── High Risk Areas (Red Zones) ──
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
                    'HIGH RISK RED-ZONES DETECTED: ${redZones.map((z) => z.toString().toUpperCase().replaceAll('_', ' ')).join(', ')}',
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

        // ── Recent Incidents ──
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
                  final Map<String, dynamic> parsed = Map<String, dynamic>.from(raw as Map);
                  final inc = Incident.fromMap(parsed);
                  return IncidentTile(incident: inc, compact: true);
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Banner removed per user request
      ],
    );
  }

  Widget _buildActionDetailRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Text(
            '$title:  ',
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
