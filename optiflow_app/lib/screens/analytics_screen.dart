import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../services/api_service.dart';
import '../providers/agent_state_provider.dart';
import 'profile_screen.dart';
import 'dispatch_screen.dart';
import 'agent_console_screen.dart';
import 'stock_screen.dart';
import 'incidents_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late AnimationController _pulseController;

  bool _loading = true;
  String _lastUpdatedText = "Just now";

  // Dynamic live datasets
  Map<String, dynamic> _zoneRiskMap = {};
  List<dynamic> _stockList = [];
  List<dynamic> _activeMovements = [];
  List<dynamic> _incidentsList = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadLiveDashboardData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveDashboardData() async {
    if (!mounted) return;
    setState(() { _loading = true; });
    try {
      final riskData = await _api.getZoneRiskMap();
      final stockData = await _api.getStock();
      
      List<dynamic> activeMovements = [];
      try {
        final movementsList = await _api.getMovements();
        if (movementsList is List) {
          activeMovements = movementsList
              .where((m) => m is Map)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .where((m) => m['status'] == 'in_transit' || m['status'] == 'dispatched')
              .toList();
        }
      } catch (_) {}

      List<dynamic> incidentsList = [];
      try {
        final incidentsResult = await _api.getIncidents();
        if (incidentsResult is Map && incidentsResult['karachi_incidents'] is List) {
          incidentsList = (incidentsResult['karachi_incidents'] as List)
              .where((i) => i is Map)
              .map((i) => Map<String, dynamic>.from(i as Map))
              .toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _zoneRiskMap = (riskData is Map && riskData['zone_risk_map'] is Map)
              ? Map<String, dynamic>.from(riskData['zone_risk_map'] as Map)
              : {};
          _stockList = (stockData is Map && stockData['records'] is List)
              ? (stockData['records'] as List)
                  .where((e) => e is Map)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList()
              : [];
          _activeMovements = activeMovements;
          _incidentsList = incidentsList;
          _loading = false;
          _lastUpdatedText = "Just now";
        });
      }
    } catch (e) {
      debugPrint("Error loading live analytics metrics: $e");
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _refreshData() async {
    await _loadLiveDashboardData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Live intelligence metrics synchronized with command center."),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  String _getDynamicPredictionText(Map<String, dynamic>? latestResult) {
    final decision = latestResult?['decision'] as Map<String, dynamic>? ?? {};
    final String insight = decision['primary_insight']?.toString() ?? decision['summary']?.toString() ?? '';
    if (insight.isNotEmpty) {
      return insight;
    }

    if (_zoneRiskMap.isEmpty) {
      return "Scanning urban crisis vectors across Karachi command network. Monitoring supply chain corridors and field incident reports in real-time.";
    }

    String highestZone = "Saddar";
    double highestScore = 0.0;
    _zoneRiskMap.forEach((zone, data) {
      if (data is Map) {
        double score = (data['risk_percent'] ?? data['risk_pct'] ?? 0.0).toDouble();
        if (score > highestScore) {
          highestScore = score;
          highestZone = zone;
        }
      }
    });

    if (highestScore >= 70.0) {
      return "CRITICAL ALERT: High crisis conditions detected in $highestZone corridor. Active supply chain anomalies and field incident spikes detected. Immediate emergency response deployment recommended.";
    } else if (highestScore >= 35.0) {
      return "TACTICAL WARNING: Moderate risk signals detected in the $highestZone sector. Cross-referencing ledger data against ground reports. System recommends tactical resource reallocation.";
    } else {
      return "NOMINAL STATUS: Karachi urban crisis network is operating within acceptable parameters. All monitored corridors reporting stable conditions.";
    }
  }

  // Generate 100% data-driven recommendations dynamically
  List<Map<String, dynamic>> _generateRecommendations() {
    List<Map<String, dynamic>> recommendations = [];

    // 1. Stock Replenishments
    for (var stock in _stockList) {
      if (stock is! Map) continue;
      final int qty = ((stock['quantity'] ?? 0) as num).toInt();
      final int threshold = ((stock['min_threshold'] ?? 500) as num).toInt();
      final String sku = (stock['sku'] ?? '') as String;
      final String itemName = (stock['item_name'] ?? '') as String;
      final String zone = (stock['zone'] ?? 'Unknown') as String;

      if (qty < threshold) {
        recommendations.add({
          'type': 'stock',
          'severity': 'high',
          'title': 'Safety Threshold Breached: $sku',
          'description': 'Stock level of $itemName in $zone depot ($qty units) has fallen below safety buffer of $threshold units. Trigger emergency stock replenishment.',
          'action': 'Restock Item',
          'target': const StockScreen(),
        });
      }
    }

    // 2. Critical/High Incident Response
    for (var incident in _incidentsList) {
      if (incident is! Map) continue;
      final String msg = incident['message'] ?? '';
      final String severity = (incident['severity'] ?? 'medium').toString().toUpperCase();
      final String zone = incident['location_zone'] ?? incident['zone'] ?? 'Unknown';
      final String reporter = incident['reporter_name'] ?? 'System';

      if (severity == 'CRITICAL' || severity == 'HIGH') {
        recommendations.add({
          'type': 'incident',
          'severity': severity == 'CRITICAL' ? 'critical' : 'high',
          'title': 'Active Incident in $zone Sector',
          'description': '[$severity] $msg (Reported by $reporter). Dispatch and logistics routes through $zone corridor should be routed with dynamic buffers.',
          'action': 'Manage incident',
          'target': const IncidentsScreen(),
        });
      }
    }

    // 3. High Risk Zone Diverts
    if (_zoneRiskMap.isNotEmpty) {
      _zoneRiskMap.forEach((zone, data) {
        if (data is Map) {
          final double score = (data['risk_percent'] ?? data['risk_pct'] ?? 0.0).toDouble();
          if (score >= 65.0) {
            recommendations.add({
              'type': 'risk',
              'severity': 'high',
              'title': 'High Risk Corridor Divert: $zone',
              'description': '$zone zone is exhibiting elevated crisis risk indicators (${score.toStringAsFixed(0)}%). Consider pausing dispatches and establishing supply hub reroutes.',
              'action': 'Optimize Routes',
              'target': const DispatchScreen(),
            });
          }
        }
      });
    }

    // 4. Default nominal state if empty
    if (recommendations.isEmpty) {
      recommendations.add({
        'type': 'nominal',
        'severity': 'nominal',
        'title': 'Karachi Operations Nominal',
        'description': 'No safety threshold breaches, critical incidents, or high-risk corridors detected. Continue standard monitoring and standard fleet schedules.',
        'action': 'Review stock',
        'target': const StockScreen(),
      });
    }

    return recommendations;
  }

  // Summary Metrics computed on the fly
  int _getCriticalStockCount() {
    int count = 0;
    for (var s in _stockList) {
      if (s is Map) {
        final int qty = ((s['quantity'] ?? 0) as num).toInt();
        final int threshold = ((s['min_threshold'] ?? 500) as num).toInt();
        if (qty < threshold) count++;
      }
    }
    return count;
  }

  Map<String, dynamic> _getHighestRiskZoneData() {
    if (_zoneRiskMap.isEmpty) return {'zone': 'None', 'risk': '0%'};
    String highestZone = "Saddar";
    double highestScore = 0.0;
    _zoneRiskMap.forEach((zone, data) {
      if (data is Map) {
        double score = (data['risk_percent'] ?? data['risk_pct'] ?? 0.0).toDouble();
        if (score > highestScore) {
          highestScore = score;
          highestZone = zone;
        }
      }
    });
    return {'zone': highestZone, 'risk': '${highestScore.toStringAsFixed(0)}%'};
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Operations Insights'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            onPressed: _refreshData,
            tooltip: 'Refresh insights',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildScreenHeader(),
                  const SizedBox(height: 16),
                  _buildStatusSummary(latestResult),
                  const SizedBox(height: 16),
                  _buildAiImpactSection(latestResult),
                  const SizedBox(height: 16),
                  _buildComparisonSection(latestResult),
                  const SizedBox(height: 16),
                  _buildDecisionExplanation(latestResult),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Operations Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Live AI operational improvements and emergency response analytics',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(Map<String, dynamic>? latestResult) {
    final String emergencyLevel = _getEmergencyLevel(latestResult);
    final String aiAction = _getActiveAiAction(latestResult);
    final String routeStatus = _getCurrentRouteStatus(latestResult);

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: MediaQuery.of(context).size.width > 600 ? 3 : 5,
      children: [
        _buildStatusCard(
          title: 'Emergency Level',
          value: emergencyLevel,
          icon: Icons.priority_high_outlined,
          color: AppTheme.criticalRed,
        ),
        _buildStatusCard(
          title: 'Active AI Action',
          value: aiAction,
          icon: Icons.auto_fix_high_outlined,
          color: AppTheme.primary,
        ),
        _buildStatusCard(
          title: 'Route Status',
          value: routeStatus,
          icon: Icons.alt_route_outlined,
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _formatImpactMetric(dynamic metric) {
    if (metric == null) return 'No update';
    final text = metric.toString();
    if (double.tryParse(text) != null && !text.contains('%')) {
      return '$text%';
    }
    return text;
  }

  Widget _buildAiImpactSection(Map<String, dynamic>? latestResult) {
    final metrics = latestResult?['simulation']?['impact_metrics'] as Map<String, dynamic>? ?? {};
    final String delayImproved = _formatImpactMetric(metrics['delay_reduction'] ?? metrics['eta_improvement']);
    final String riskImproved = _formatImpactMetric(metrics['risk_reduction'] ?? metrics['alternative_route_safety'] ?? metrics['route_safety']);
    final String deliveryProtected = _formatImpactMetric(metrics['emergency_protected'] ?? metrics['critical_shipments_saved'] ?? metrics['protected_deliveries']);
    final String stockProtected = _formatImpactMetric(metrics['stockout_prevented'] ?? metrics['inventory_saved'] ?? metrics['stock_protected']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.show_chart_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Impact',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: [
              _buildImpactCard('Delivery Delay Reduced', delayImproved, AppTheme.success),
              _buildImpactCard('Route Safety Improved', riskImproved, const Color(0xFF2563EB)),
              _buildImpactCard('Emergency Deliveries Protected', deliveryProtected, AppTheme.warning),
              _buildImpactCard('Stock Issues Prevented', stockProtected, AppTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard(String title, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(Map<String, dynamic>? latestResult) {
    final before = latestResult?['simulation']?['before_state'] as Map<String, dynamic>? ?? {};
    final after = latestResult?['simulation']?['after_state'] as Map<String, dynamic>? ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 640;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildComparisonCard('BEFORE AI', before, const Color(0xFFEF4444))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildComparisonCard('AFTER AI', after, const Color(0xFF10B981))),
                ],
              )
            : Column(
                children: [
                  _buildComparisonCard('BEFORE AI', before, const Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  _buildComparisonCard('AFTER AI', after, const Color(0xFF10B981)),
                ],
              );
      },
    );
  }

  Widget _buildComparisonCard(String title, Map<String, dynamic> state, Color accent) {
    final String route = state['route']?.toString() ?? 'Unknown route';
    final String status = state['status']?.toString() ?? state['delivery_status']?.toString() ?? 'Pending';
    final String stock = state['stock_status']?.toString() ?? state['stock_level']?.toString() ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 14),
          _buildComparisonItem('Route', route, accent),
          const SizedBox(height: 10),
          _buildComparisonItem('Delivery Status', status, accent),
          const SizedBox(height: 10),
          _buildComparisonItem('Stock Status', stock, accent),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionExplanation(Map<String, dynamic>? latestResult) {
    final decision = latestResult?['decision'] as Map<String, dynamic>? ?? {};
    final String insight = decision['primary_insight']?.toString() ?? decision['summary']?.toString() ?? 'AI has selected the best route using current conditions.';
    final List<String> steps = _extractReasoningSteps(decision);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Decision',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight,
            style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 14),
          if (steps.isNotEmpty) ...[
            const Text(
              'Why this update was made',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            ...steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ))
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No additional explanation available yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          ],
        ],
      ),
    );
  }

  List<String> _extractReasoningSteps(Map<String, dynamic> decision) {
    final rawSteps = decision['reasoning_steps'] ?? decision['reasoning'] ?? decision['step_summary'] ?? decision['explanation'];
    if (rawSteps is List) {
      return rawSteps.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    if (rawSteps is String) {
      final cleaned = rawSteps.trim();
      if (cleaned.contains('\n')) {
        return cleaned.split('\n').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
      }
      if (cleaned.contains('. ')) {
        return cleaned.split('. ').map((item) => item.trim()).where((item) => item.isNotEmpty).map((item) => item.endsWith('.') ? item : '$item.').toList();
      }
      return cleaned.isEmpty ? [] : [cleaned];
    }
    return [];
  }

  String _getEmergencyLevel(Map<String, dynamic>? latestResult) {
    final decision = latestResult?['decision'] as Map<String, dynamic>? ?? {};
    final metrics = latestResult?['simulation']?['impact_metrics'] as Map<String, dynamic>? ?? {};

    final String rawLevel = decision['emergency_level']?.toString() ?? decision['risk_level']?.toString() ?? metrics['emergency_level']?.toString() ?? metrics['risk_level']?.toString() ?? decision['severity']?.toString() ?? '';
    if (rawLevel.isEmpty) {
      return 'Normal';
    }
    final lower = rawLevel.toLowerCase();
    if (lower.contains('critical')) return 'CRITICAL';
    if (lower.contains('high')) return 'HIGH';
    if (lower.contains('warning') || lower.contains('alert')) return 'ATTENTION';
    return rawLevel.toUpperCase();
  }

  String _getActiveAiAction(Map<String, dynamic>? latestResult) {
    final decision = latestResult?['decision'] as Map<String, dynamic>? ?? {};
    final action = decision['selected_action'] as Map<String, dynamic>? ?? {};
    final String rawAction = action['name']?.toString() ?? action['label']?.toString() ?? action['type']?.toString() ?? decision['action']?.toString() ?? '';
    if (rawAction.isEmpty) {
      return 'Awaiting AI review';
    }
    return rawAction.replaceAll('_', ' ').toUpperCase();
  }

  String _getCurrentRouteStatus(Map<String, dynamic>? latestResult) {
    final after = latestResult?['simulation']?['after_state'] as Map<String, dynamic>? ?? {};
    final String status = after['status']?.toString() ?? after['delivery_status']?.toString() ?? 'Pending';
    if (status.isEmpty) return 'Pending';
    return status.replaceAll('_', ' ').toUpperCase();
  }


  Widget _buildSmallMetricCard(String label, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStateSnapshot(String title, Map<String, dynamic> state, Color accentColor) {
    final String route = state['route']?.toString() ?? 'N/A';
    final String status = state['status']?.toString() ?? 'N/A';
    final String load = state['load']?.toString() ?? state['stock_level']?.toString() ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 10),
          ),
          const SizedBox(height: 10),
          Text('Route: $route', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Text('Status: $status', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Text('Load: $load', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    final list = _generateRecommendations();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assistant_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'DATA-DRIVEN RECOVERY PLAN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF334155),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final rec = list[index];
              Color borderCol = Colors.green.shade200;
              Color bgCol = Colors.green.shade50;
              IconData icon = Icons.check_circle_outline;
              Color themeCol = Colors.green.shade600;

              if (rec['type'] == 'stock') {
                borderCol = Colors.amber.shade200;
                bgCol = Colors.amber.shade50;
                icon = Icons.inventory_2_outlined;
                themeCol = Colors.amber.shade700;
              } else if (rec['type'] == 'incident') {
                borderCol = Colors.red.shade200;
                bgCol = Colors.red.shade50;
                icon = Icons.warning_amber_rounded;
                themeCol = Colors.red.shade700;
              } else if (rec['type'] == 'risk') {
                borderCol = Colors.blue.shade200;
                bgCol = Colors.blue.shade50;
                icon = Icons.share_location_outlined;
                themeCol = Colors.blue.shade700;
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderCol, width: 0.8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: themeCol, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: themeCol,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec['description'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => rec['target']),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeCol,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text(
                        rec['action'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartsGrid() {
    final bool isWide = MediaQuery.of(context).size.width > 950;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildZoneRiskChartCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildStockShortfallChartCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildIncidentDistributionChartCard()),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildZoneRiskChartCard(),
          const SizedBox(height: 16),
          _buildStockShortfallChartCard(),
          const SizedBox(height: 16),
          _buildIncidentDistributionChartCard(),
        ],
      );
    }
  }

  Widget _buildZoneRiskChartCard() {
    // Prepare Top 5 active risk zones
    final sortedZones = _zoneRiskMap.entries.where((e) => e.value is Map).toList()
      ..sort((a, b) {
        final double scoreA = ((a.value as Map)['risk_percent'] ?? (a.value as Map)['risk_pct'] ?? 0).toDouble();
        final double scoreB = ((b.value as Map)['risk_percent'] ?? (b.value as Map)['risk_pct'] ?? 0).toDouble();
        return scoreB.compareTo(scoreA);
      });
    final zonesToShow = sortedZones.take(5).toList();

    return Container(
      height: 310,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ZONE CRISIS INDEX (%)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Highest dynamic operational threats',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: zonesToShow.isEmpty
                ? const Center(child: Text('No zone data loaded.', style: TextStyle(fontSize: 12)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => const Color(0xFF0F172A),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final zoneName = zonesToShow[groupIndex].key;
                            return BarTooltipItem(
                              '$zoneName: ${rod.toY.toStringAsFixed(0)}%',
                              const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final int idx = value.toInt();
                              if (idx >= 0 && idx < zonesToShow.length) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 6,
                                  child: Text(
                                    zonesToShow[idx].key,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: zonesToShow.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final valMap = entry.value.value as Map;
                        final double score = (valMap['risk_percent'] ?? valMap['risk_pct'] ?? 0.0).toDouble();
                        Color barCol = AppTheme.success;
                        if (score >= 70.0) {
                          barCol = AppTheme.criticalRed;
                        } else if (score >= 30.0) {
                          barCol = AppTheme.warning;
                        }

                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: score,
                              color: barCol,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 100,
                                color: const Color(0xFFF1F5F9),
                              ),
                            )
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockShortfallChartCard() {
    // Filter stock entries to show top 5 in greatest need of attention
    final stockToShow = _stockList.where((s) => s is Map).map((s) => s as Map).toList()
      ..sort((a, b) {
        final double qtyA = (a['quantity'] ?? 0).toDouble();
        final double limitA = (a['min_threshold'] ?? 500).toDouble();
        final double ratioA = qtyA / (limitA == 0 ? 1 : limitA);

        final double qtyB = (b['quantity'] ?? 0).toDouble();
        final double limitB = (b['min_threshold'] ?? 500).toDouble();
        final double ratioB = qtyB / (limitB == 0 ? 1 : limitB);

        return ratioA.compareTo(ratioB); // Lowest ratios (critical shorts) first
      });

    final topStock = stockToShow.take(5).toList();
    double maxVal = 1000;
    for (var s in topStock) {
      final double val = (s['quantity'] ?? 0).toDouble();
      if (val > maxVal) maxVal = val;
    }

    return Container(
      height: 310,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEPOT STOCK VS MIN LIMIT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Red rods flag items below dynamic safety threshold',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: topStock.isEmpty
                ? const Center(child: Text('No stock data loaded.', style: TextStyle(fontSize: 12)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxVal * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => const Color(0xFF0F172A),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final item = topStock[groupIndex];
                            final int minLimit = item['min_threshold'] ?? 500;
                            return BarTooltipItem(
                              '${item['item_name']}\nQty: ${rod.toY.toInt()} / Limit: $minLimit',
                              const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final int idx = value.toInt();
                              if (idx >= 0 && idx < topStock.length) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 6,
                                  child: Text(
                                    topStock[idx]['sku'] ?? '',
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: topStock.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final double qty = (item['quantity'] ?? 0.0).toDouble();
                        final double limit = (item['min_threshold'] ?? 500.0).toDouble();
                        final bool critical = qty < limit;

                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: qty,
                              color: critical ? AppTheme.criticalRed : AppTheme.primary,
                              width: 14,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentDistributionChartCard() {
    // Calculate incident severities count dynamically
    int critical = 0;
    int high = 0;
    int medium = 0;
    int minor = 0;

    for (var incident in _incidentsList) {
      if (incident is Map) {
        final String sev = (incident['severity'] ?? 'medium').toString().toLowerCase();
        if (sev == 'critical') {
          critical++;
        } else if (sev == 'high') {
          high++;
        } else if (sev == 'minor' || sev == 'low' || sev == 'green') {
          minor++;
        } else {
          medium++;
        }
      }
    }

    final double total = (critical + high + medium + minor).toDouble();

    return Container(
      height: 310,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CRISIS SEVERITY DISTRIBUTION',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Analysis of real-time urban telemetry reports',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: total == 0
                ? const Center(child: Text('No incidents registered.', style: TextStyle(fontSize: 12)))
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 28,
                            sections: [
                              if (critical > 0)
                                PieChartSectionData(
                                  value: critical.toDouble(),
                                  color: AppTheme.criticalRed,
                                  radius: 38,
                                  showTitle: false,
                                ),
                              if (high > 0)
                                PieChartSectionData(
                                  value: high.toDouble(),
                                  color: AppTheme.warning,
                                  radius: 38,
                                  showTitle: false,
                                ),
                              if (medium > 0)
                                PieChartSectionData(
                                  value: medium.toDouble(),
                                  color: const Color(0xFF2563EB),
                                  radius: 38,
                                  showTitle: false,
                                ),
                              if (minor > 0)
                                PieChartSectionData(
                                  value: minor.toDouble(),
                                  color: AppTheme.success,
                                  radius: 38,
                                  showTitle: false,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem('Critical ($critical)', AppTheme.criticalRed),
                            const SizedBox(height: 8),
                            _buildLegendItem('High ($high)', AppTheme.warning),
                            const SizedBox(height: 8),
                            _buildLegendItem('Medium ($medium)', const Color(0xFF2563EB)),
                            const SizedBox(height: 8),
                            _buildLegendItem('Minor ($minor)', AppTheme.success),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveMovementsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_shipping_outlined, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ACTIVE DISPATCHES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF334155),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DispatchScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF475569),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('MANAGE FLEET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_activeMovements.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                  SizedBox(width: 8),
                  Text(
                    'All logistics systems at standby. No units currently in transit.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(3, _activeMovements.length),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final m = _activeMovements[index];
                if (m is! Map) return const SizedBox();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${m['driver_name'] ?? m['driver'] ?? 'Unit'} driving vehicle ${m['vehicle_id'] ?? m['vehicle'] ?? 'ID'} (${m['sku'] ?? 'GENERAL'})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${m['origin_zone'] ?? m['from'] ?? 'Central'} ➔ ${m['destination_zone'] ?? m['to'] ?? 'Destination'}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Command Engine Synchronized: $_lastUpdatedText',
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseController.value,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            const Text(
              'Dynamic Telemetry Active',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
            ),
          ],
        ),
      ],
    );
  }
}
