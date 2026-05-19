import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'fleet_screen.dart';
import 'agent_console_screen.dart';

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

  // Live data
  Map<String, dynamic> _zoneRiskMap = {};
  List<dynamic> _stockList = [];
  Map<String, List<double>> _zoneHourlyCounts = {};
  List<dynamic> _activeMovements = [];

  // Deployed action states for Control Panel
  bool _emergencyResponseDeployed = false;
  bool _supplyChainAlertReviewed = false;

  int _parseHour(String timeStr) {
    if (timeStr.isEmpty) return -1;
    try {
      return DateTime.parse(timeStr).toLocal().hour;
    } catch (_) {
      return -1;
    }
  }

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
      final incidentData = await _api.getContradictions();
      final List<dynamic> incidents = incidentData['contradictions'] ?? [];

      Map<String, List<double>> zoneHourlyCounts = {};
      for (var incident in incidents) {
        final zone = incident['location_zone'] ?? incident['zone'] ?? 'Unknown';
        final timeStr = incident['timestamp'] ?? incident['detected_at'] ?? '';
        final hour = _parseHour(timeStr);
        zoneHourlyCounts.putIfAbsent(zone, () => List.filled(24, 0.0));
        if (hour >= 0) zoneHourlyCounts[zone]![hour] += 1.0;
      }

      List<dynamic> activeMovements = [];
      try {
        final movementsList = await _api.getMovements();
        activeMovements = movementsList
            .where((m) => m['status'] == 'in_transit' || m['status'] == 'dispatched')
            .toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _zoneRiskMap = riskData['zone_risk_map'] ?? {};
          _stockList = stockData['records'] ?? [];
          _zoneHourlyCounts = zoneHourlyCounts;
          _activeMovements = activeMovements;
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
      return "Scanning urban crisis vectors across Karachi command network. Monitoring supply chain corridors, weather conditions, and field incident reports in real-time.";
    }

    String highestZone = "Saddar";
    double highestScore = 0.0;
    _zoneRiskMap.forEach((zone, data) {
      double score = (data['risk_pct'] ?? 0.0).toDouble();
      if (score > highestScore) {
        highestScore = score;
        highestZone = zone;
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

  List<Map<String, dynamic>> _getTopCriticalZones() {
    if (_zoneRiskMap.isEmpty) {
      return [
        {'zone': 'Saddar', 'risk': 'LOW (0.1)', 'trend': 'Stable', 'isCritical': false, 'color': Colors.green},
        {'zone': 'Clifton', 'risk': 'LOW (0.1)', 'trend': 'Stable', 'isCritical': false, 'color': Colors.green},
        {'zone': 'Korangi', 'risk': 'LOW (0.1)', 'trend': 'Stable', 'isCritical': false, 'color': Colors.green},
      ];
    }

    final sorted = _zoneRiskMap.entries.toList()
      ..sort((a, b) => (b.value['risk_pct'] ?? 0).compareTo(a.value['risk_pct'] ?? 0));

    return sorted.take(3).map((e) {
      final name = e.key;
      final data = e.value;
      final pct = (data['risk_pct'] ?? 0.0) / 100.0;
      final isCritical = data['risk'] == 'RED';
      final isWarning = data['risk'] == 'YELLOW';
      Color c = Colors.green;
      if (isCritical) c = AppTheme.criticalRed;
      else if (isWarning) c = AppTheme.warning;
      return {
        'zone': name,
        'risk': '${data['risk']} (${pct.toStringAsFixed(2)})',
        'trend': data['status'] ?? 'Stable',
        'isCritical': isCritical || isWarning,
        'color': c,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getArealRiskDistributionList() {
    if (_zoneRiskMap.isEmpty) {
      return [
        {'name': 'Saddar', 'level': 'Low', 'val': 0.15, 'color': Colors.green},
        {'name': 'Korangi', 'level': 'Low', 'val': 0.15, 'color': Colors.green},
        {'name': 'Malir', 'level': 'Low', 'val': 0.15, 'color': Colors.green},
        {'name': 'Clifton', 'level': 'Low', 'val': 0.15, 'color': Colors.green},
        {'name': 'Gulshan', 'level': 'Low', 'val': 0.15, 'color': Colors.green},
        {'name': 'SITE', 'level': 'Low', 'val': 0.15, 'color': Colors.green},
      ];
    }

    final sorted = _zoneRiskMap.entries.toList()
      ..sort((a, b) => (b.value['risk_pct'] ?? 0).compareTo(a.value['risk_pct'] ?? 0));

    return sorted.take(6).map((e) {
      final name = e.key;
      final data = e.value;
      final pct = (data['risk_pct'] ?? 0.0) / 100.0;
      Color c = Colors.green;
      String lvl = "Low";
      if (data['risk'] == 'RED') { c = AppTheme.criticalRed; lvl = "Critical"; }
      else if (data['risk'] == 'YELLOW') { c = AppTheme.warning; lvl = "Medium"; }
      return {'name': name, 'level': lvl, 'val': pct, 'color': c};
    }).toList();
  }

  List<String> _getDeploymentZones() {
    if (_zoneRiskMap.isEmpty) return ["Saddar", "Korangi"];
    final sorted = _zoneRiskMap.entries.toList()
      ..sort((a, b) => (b.value['risk_pct'] ?? 0).compareTo(a.value['risk_pct'] ?? 0));
    final list = sorted.map((e) => e.key).toList();
    if (list.length >= 2) return [list[0], list[1]];
    if (list.length == 1) return [list[0], "SITE"];
    return ["Saddar", "Korangi"];
  }

  // Summary stats for control panel fallback when no active movements
  Map<String, dynamic> _getRiskSummaryStats() {
    int redCount = 0;
    int yellowCount = 0;
    int criticalStock = 0;
    _zoneRiskMap.forEach((zone, data) {
      if (data['risk'] == 'RED') redCount++;
      else if (data['risk'] == 'YELLOW') yellowCount++;
    });
    for (var s in _stockList) {
      if ((s['status'] ?? '') == 'CRITICAL') criticalStock++;
    }
    return {
      'red_zones': redCount,
      'yellow_zones': yellowCount,
      'critical_stock': criticalStock,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Analytics & Crisis Intelligence'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _refreshData),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 950;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPredictionBanner(),
                      const SizedBox(height: 16),
                      _buildCriticalZoneMonitoring(isWide),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: _buildArealRiskDistribution()),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: _buildAggregateZoneTrends()),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: _buildControlPanel()),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildArealRiskDistribution(),
                            const SizedBox(height: 16),
                            _buildAggregateZoneTrends(),
                            const SizedBox(height: 16),
                            _buildControlPanel(),
                          ],
                        ),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                );
              },
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
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF60A5FA), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Engine Prediction',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text(
                  _getDynamicPredictionText(),
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.3),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text(
              'LAUNCH AGENT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalZoneMonitoring(bool isWide) {
    final topZones = _getTopCriticalZones();
    final cards = topZones.map((data) {
      final isCritical = data['isCritical'] as bool;
      final Color c = data['color'] as Color;
      return Container(
        margin: EdgeInsets.symmetric(horizontal: isWide ? 4.0 : 0.0, vertical: isWide ? 0.0 : 6.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCritical
              ? (c == AppTheme.criticalRed ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB))
              : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCritical
                ? (c == AppTheme.criticalRed ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A))
                : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCritical
                    ? (c == AppTheme.criticalRed ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7))
                    : const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCritical
                    ? (c == AppTheme.criticalRed ? Icons.warning_amber_rounded : Icons.crisis_alert_outlined)
                    : Icons.check,
                color: c,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zone: ${data['zone']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text('Current Risk: ${data['risk']}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                  Text('Trend: ${data['trend']}',
                      style: TextStyle(fontSize: 10, color: isCritical ? Colors.black54 : const Color(0xFF166534))),
                ],
              ),
            ),
            Icon(isCritical ? Icons.trending_up : Icons.check_circle_outline, color: c, size: 20),
          ],
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CRITICAL ZONE MONITORING',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        isWide
            ? Row(
                children: cards.isEmpty
                    ? const [Expanded(child: Center(child: Text('No active critical zones.')))]
                    : cards.map((card) => Expanded(child: card)).expand((card) => [card, const SizedBox(width: 12)]).toList()..removeLast(),
              )
            : Column(children: cards),
      ],
    );
  }

  Widget _buildArealRiskDistribution() {
    final list = _getArealRiskDistributionList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AREAL RISK DISTRIBUTION',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: list.map((z) {
                    final color = z['color'] as Color;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Expanded(flex: 3,
                              child: Text(z['name'] as String,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87))),
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: z['val'] as double,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(flex: 2,
                              child: Text(z['level'] as String,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              // GIS Map
              Expanded(
                flex: 3,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: KarachiStylizedMapPainter(_zoneRiskMap)),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: ElevatedButton(
                          // Navigate to Fleet screen which has the real zone risk table
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FleetScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('View Full Risk Map', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAggregateZoneTrends() {
    List<double> getRecent(String zone) {
      if (_zoneHourlyCounts.containsKey(zone)) {
        final hourly = _zoneHourlyCounts[zone]!;
        final nowHour = DateTime.now().hour;
        List<double> recent = [];
        for (int i = 5; i >= 0; i--) {
          int h = (nowHour - i) % 24;
          if (h < 0) h += 24;
          recent.add(hourly[h] == 0 ? 5.0 : hourly[h] * 20.0);
        }
        return recent;
      }
      return [5.0, 5.0, 5.0, 5.0, 5.0, 5.0];
    }

    final saddarVals = getRecent('Saddar');
    final siteVals = getRecent('SITE');
    final malirVals = getRecent('Malir');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('AGGREGATE ZONE TRENDS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5, color: Color(0xFF64748B))),
                  SizedBox(height: 2),
                  Text('24 hour incident flow', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const Icon(Icons.more_vert, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: MultiLineChartPainter(_zoneRiskMap, _zoneHourlyCounts),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00:00', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('06:00', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('12:00', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('18:00', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('00:00', style: TextStyle(fontSize: 9, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSparklineMetric(
                  'Incident Volume (Saddar)',
                  saddarVals,
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSparklineMetric(
                  'Stock Alerts (SITE)',
                  siteVals,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSparklineMetric(
                  'Crisis Index (Malir)',
                  malirVals,
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSparklineMetric(String title, List<double> values, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: CustomPaint(size: const Size(double.infinity, 30), painter: SparklinePainter(values, color)),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('00:00', style: TextStyle(fontSize: 7, color: Colors.black38)),
            Text('12:00', style: TextStyle(fontSize: 7, color: Colors.black38)),
            Text('18:00', style: TextStyle(fontSize: 7, color: Colors.black38)),
          ],
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    final deploymentZones = _getDeploymentZones();
    final z1 = deploymentZones[0];
    final z2 = deploymentZones[1];
    final stats = _getRiskSummaryStats();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTROL PANEL',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5, color: Color(0xFF64748B))),
          const SizedBox(height: 12),

          // Risk summary stats (always visible)
          Row(
            children: [
              Expanded(child: _miniStatCard('RED ZONES', '${stats['red_zones']}', AppTheme.criticalRed)),
              const SizedBox(width: 6),
              Expanded(child: _miniStatCard('YELLOW', '${stats['yellow_zones']}', AppTheme.warning)),
              const SizedBox(width: 6),
              Expanded(child: _miniStatCard('CRIT STOCK', '${stats['critical_stock']}', const Color(0xFF7C3AED))),
            ],
          ),
          const SizedBox(height: 16),

          // Emergency Response Deployment
          const Text('Emergency Response',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
          const SizedBox(height: 8),

          // Deploy to z1
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              onPressed: () {
                setState(() => _emergencyResponseDeployed = !_emergencyResponseDeployed);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_emergencyResponseDeployed
                      ? '✅ Emergency response deployed to $z1'
                      : '↩ Response to $z1 recalled'),
                  backgroundColor: _emergencyResponseDeployed ? AppTheme.success : Colors.grey,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _emergencyResponseDeployed ? const Color(0xFF10B981) : const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                _emergencyResponseDeployed ? '✓ Deployed → $z1' : 'Deploy Response → $z1',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Alert review for z2
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              onPressed: () {
                setState(() => _supplyChainAlertReviewed = !_supplyChainAlertReviewed);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_supplyChainAlertReviewed
                      ? '✅ Supply chain alert reviewed for $z2'
                      : '↩ Alert for $z2 marked unreviewed'),
                  backgroundColor: _supplyChainAlertReviewed ? AppTheme.success : Colors.grey,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _supplyChainAlertReviewed
                    ? const Color(0xFF10B981)
                    : const Color(0xFFB45309),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                _supplyChainAlertReviewed ? '✓ Alert Reviewed: $z2' : 'Review Alert: $z2',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Active dispatches
          const Text('Active Dispatches',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
          const SizedBox(height: 8),

          if (_activeMovements.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.local_shipping_outlined, size: 14, color: Colors.black38),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No active units in transit. Use Fleet screen to dispatch.',
                      style: TextStyle(color: Colors.black45, fontSize: 9, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._activeMovements.take(3).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${m['vehicle'] ?? 'Unit'} → ${m['to'] ?? 'Destination'}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('IN TRANSIT',
                          style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
              ),
            )).toList(),
        ],
      ),
    );
  }

  Widget _miniStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 7, color: Colors.black54, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Last Updated: $_lastUpdatedText',
          style: const TextStyle(fontSize: 10, color: Colors.black45, fontStyle: FontStyle.italic),
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
            const Text('Live Data Feed Active',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
          ],
        ),
      ],
    );
  }
}

// ─── Custom Painters (unchanged — they work correctly) ───

class KarachiStylizedMapPainter extends CustomPainter {
  final Map<String, dynamic> riskMap;
  KarachiStylizedMapPainter(this.riskMap);

  Color _getFillColorForZone(String zone, Color defaultColor) {
    if (riskMap.containsKey(zone)) {
      final r = riskMap[zone]['risk'];
      if (r == 'RED') return const Color(0xFFFEE2E2);
      if (r == 'YELLOW') return const Color(0xFFFEF3C7);
      return const Color(0xFFDCFCE7);
    }
    return defaultColor;
  }

  Color _getBorderColorForZone(String zone, Color defaultColor) {
    if (riskMap.containsKey(zone)) {
      final r = riskMap[zone]['risk'];
      if (r == 'RED') return AppTheme.criticalRed.withOpacity(0.4);
      if (r == 'YELLOW') return AppTheme.warning.withOpacity(0.4);
      return Colors.green.withOpacity(0.4);
    }
    return defaultColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = _getFillColorForZone('Clifton', const Color(0xFFDCFCE7));
    var path1 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.7)
      ..lineTo(size.width * 0.35, size.height * 0.8)
      ..lineTo(size.width * 0.25, size.height * 0.95)
      ..lineTo(size.width * 0.05, size.height * 0.85)
      ..close();
    canvas.drawPath(path1, paint);
    paint.color = _getBorderColorForZone('Clifton', Colors.green.withOpacity(0.3));
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.8;
    canvas.drawPath(path1, paint);

    paint.style = PaintingStyle.fill;
    paint.color = _getFillColorForZone('Saddar', const Color(0xFFDCFCE7));
    var path2 = Path()
      ..moveTo(size.width * 0.35, size.height * 0.5)
      ..lineTo(size.width * 0.55, size.height * 0.6)
      ..lineTo(size.width * 0.45, size.height * 0.85)
      ..lineTo(size.width * 0.3, size.height * 0.75)
      ..close();
    canvas.drawPath(path2, paint);
    paint.color = _getBorderColorForZone('Saddar', Colors.green.withOpacity(0.3));
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path2, paint);

    paint.style = PaintingStyle.fill;
    paint.color = _getFillColorForZone('SITE', const Color(0xFFDCFCE7));
    var path3 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.3)
      ..lineTo(size.width * 0.3, size.height * 0.4)
      ..lineTo(size.width * 0.2, size.height * 0.65)
      ..lineTo(size.width * 0.05, size.height * 0.55)
      ..close();
    canvas.drawPath(path3, paint);
    paint.color = _getBorderColorForZone('SITE', Colors.green.withOpacity(0.3));
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path3, paint);

    paint.style = PaintingStyle.fill;
    paint.color = _getFillColorForZone('Gulshan', const Color(0xFFFEF3C7));
    var path4 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.25)
      ..lineTo(size.width * 0.65, size.height * 0.35)
      ..lineTo(size.width * 0.55, size.height * 0.55)
      ..lineTo(size.width * 0.35, size.height * 0.45)
      ..close();
    canvas.drawPath(path4, paint);
    paint.color = _getBorderColorForZone('Gulshan', Colors.orange.withOpacity(0.3));
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path4, paint);

    paint.style = PaintingStyle.fill;
    paint.color = _getFillColorForZone('Malir', const Color(0xFFFEE2E2));
    var path5 = Path()
      ..moveTo(size.width * 0.65, size.height * 0.45)
      ..lineTo(size.width * 0.95, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height * 0.8)
      ..lineTo(size.width * 0.55, size.height * 0.7)
      ..close();
    canvas.drawPath(path5, paint);
    paint.color = _getBorderColorForZone('Malir', AppTheme.criticalRed.withOpacity(0.3));
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MultiLineChartPainter extends CustomPainter {
  final Map<String, dynamic> riskMap;
  final Map<String, List<double>> hourlyCounts;
  MultiLineChartPainter(this.riskMap, this.hourlyCounts);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gridPaint = Paint()..color = const Color(0xFFF1F5F9)..strokeWidth = 1.0;
    for (int i = 0; i <= 4; i++) {
      final y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    List<double> get24h(String zone, double baseCurveVal) {
      if (!hourlyCounts.containsKey(zone)) return List.generate(24, (i) => baseCurveVal);
      final hourly = hourlyCounts[zone]!;
      final nowHour = DateTime.now().hour;
      List<double> vals = [];
      for (int i = 23; i >= 0; i--) {
        int hr = (nowHour - i) % 24;
        if (hr < 0) hr += 24;
        double normalized = baseCurveVal - (hourly[hr] * 0.15);
        vals.add(normalized.clamp(0.1, 0.9));
      }
      return vals;
    }

    _drawLine(canvas, w, h, get24h('Clifton', 0.8), Colors.green.shade600);
    _drawLine(canvas, w, h, get24h('SITE', 0.6), const Color(0xFF2563EB));
    _drawLine(canvas, w, h, get24h('Saddar', 0.5), const Color(0xFFF97316));
    _drawLine(canvas, w, h, get24h('Malir', 0.3), AppTheme.criticalRed);
  }

  void _drawLine(Canvas canvas, double w, double h, List<double> relativeY, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = w / (relativeY.length - 1);
    path.moveTo(0, h * relativeY[0]);
    for (int i = 1; i < relativeY.length; i++) {
      final double prevX = stepX * (i - 1);
      final double prevY = h * relativeY[i - 1];
      final double currX = stepX * i;
      final double currY = h * relativeY[i];
      path.cubicTo(prevX + stepX * 0.5, prevY, currX - stepX * 0.5, currY, currX, currY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final diff = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = w / (values.length - 1);
    double normalizeY(double val) => h - ((val - minVal) / diff * (h * 0.8) + (h * 0.1));

    path.moveTo(0, normalizeY(values[0]));
    for (int i = 1; i < values.length; i++) {
      final double prevX = stepX * (i - 1);
      final double prevY = normalizeY(values[i - 1]);
      final double currX = stepX * i;
      final double currY = normalizeY(values[i]);
      path.cubicTo(prevX + stepX * 0.5, prevY, currX - stepX * 0.5, currY, currX, currY);
    }
    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
