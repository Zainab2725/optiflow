import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../services/api_service.dart';
import '../services/agent_state_provider.dart';
import 'profile_screen.dart';
import 'fleet_screen.dart';
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

  String _getDynamicPredictionText() {
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
              'target': const FleetScreen(),
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
        title: const Text('Supply Chain Analytics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            onPressed: _refreshData,
            tooltip: 'Synchronize Data',
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
                  _buildPredictionBanner(),
                  const SizedBox(height: 16),
                  _buildStatsSummaryGrid(latestResult),
                  const SizedBox(height: 16),
                  _buildRecommendationsSection(),
                  const SizedBox(height: 16),
                  _buildChartsGrid(),
                  const SizedBox(height: 16),
                  _buildActiveMovementsPanel(),
                  const SizedBox(height: 24),
                  _buildFooter(),
                ],
              ),
            ),
    );
  }

  Widget _buildPredictionBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B5C), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF60A5FA), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Autonomous AI Intel Feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDynamicPredictionText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgentConsoleScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'DECISION CONSOLE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummaryGrid(Map<String, dynamic>? latestResult) {
    final highestRisk = _getHighestRiskZoneData();
    final criticalStockCount = _getCriticalStockCount();
    final activeIncidentsCount = _incidentsList.length;
    
    String aiDelaySavings = 'N/A';
    String aiRiskReduction = 'N/A';
    
    if (latestResult != null) {
      final metrics = latestResult['simulation']?['impact_metrics'] as Map<String, dynamic>? ?? {};
      aiDelaySavings = metrics['delay_reduction']?.toString() ?? metrics['eta_improvement']?.toString() ?? 'N/A';
      aiRiskReduction = metrics['risk_reduction']?.toString() ?? metrics['alternative_route_safety']?.toString() ?? 'N/A';
    }

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          title: 'TELEMETRY INCIDENTS',
          value: activeIncidentsCount.toString(),
          subtitle: 'Real-time urban reports',
          icon: Icons.crisis_alert_outlined,
          color: AppTheme.criticalRed,
        ),
        _buildStatCard(
          title: 'CRITICAL SHORTS',
          value: criticalStockCount.toString(),
          subtitle: 'SKUs below safety buffer',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.warning,
        ),
        if (latestResult != null) ...[
          _buildStatCard(
            title: 'AI DELAY REDUCTION',
            value: aiDelaySavings,
            subtitle: 'Logistics time saved',
            icon: Icons.timer_outlined,
            color: AppTheme.successGreen,
          ),
          _buildStatCard(
            title: 'AI RISK REDUCTION',
            value: aiRiskReduction,
            subtitle: 'Safety optimization gain',
            icon: Icons.security_outlined,
            color: Colors.blueAccent,
          ),
        ] else ...[
          _buildStatCard(
            title: 'HIGHEST RISK SECTOR',
            value: highestRisk['zone'],
            subtitle: 'Crisis Risk Index: ${highestRisk['risk']}',
            icon: Icons.share_location_outlined,
            color: AppTheme.primary,
          ),
        ],
      ],
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
                    MaterialPageRoute(builder: (_) => const FleetScreen()),
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
