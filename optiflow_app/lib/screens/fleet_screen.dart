import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/ai_recommendation_card.dart';
import 'profile_screen.dart';

class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});
  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  final _api = ApiService();
  Timer? _refreshTimer;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _routeData = {};
  Map<String, dynamic> _zoneRiskData = {};
  List<Map<String, dynamic>> _movements = [];
  String? _selectedZoneRiskDetail;

  // Route planner inputs
  final _originCtrl = TextEditingController(text: 'Hyderabad, Pakistan');
  final _destCtrl = TextEditingController(text: 'Karachi, Pakistan');
  bool _routeLoading = false;

  // Movement dispatch form
  final _driverCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  String? _originZone;
  String? _destZone;
  String? _moveSku;
  final _moveQtyCtrl = TextEditingController();
  List<String> _availableZones = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _autoRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _driverCtrl.dispose();
    _vehicleCtrl.dispose();
    _moveQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoRefresh() async {
    try {
      final zoneRes = await _api.getZoneRiskMap();
      final routeRes = await _api.getRouteOptimization(
        origin: _originCtrl.text,
        destination: _destCtrl.text,
      );
      if (mounted) {
        setState(() {
          _zoneRiskData = zoneRes;
          _routeData = routeRes;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Phase 1: Load zone risk map instantly from host to populate selections and dropdowns
      final zoneRes = await _api.getZoneRiskMap();
      final zoneRisk = zoneRes['zone_risk_map'] as Map<String, dynamic>? ?? {};
      final zones = zoneRisk.keys.toList()..sort();
      if (mounted) {
        setState(() {
          _zoneRiskData = zoneRes;
          _availableZones = zones;
          _originZone ??= zones.isNotEmpty ? zones.first : 'SITE';
          _destZone ??= zones.length > 1 ? zones[1] : (zones.isNotEmpty ? zones.first : 'Clifton');
          _originCtrl.text = _originZone!;
          _destCtrl.text = _destZone!;
          _loading = false; // Core Fleet UI is ready and interactive!
        });
      }

      // Phase 2: Load heavy route optimization in the background
      try {
        final routeRes = await _api.getRouteOptimization(origin: _originCtrl.text, destination: _destCtrl.text);
        if (mounted) {
          setState(() {
            _routeData = routeRes;
          });
        }
      } catch (e) {
        debugPrint('Optional background route optimization failed: $e');
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

  Future<void> _reoptimizeRoute() async {
    setState(() => _routeLoading = true);
    try {
      final res = await _api.getRouteOptimization(
        origin: _originCtrl.text,
        destination: _destCtrl.text,
      );
      if (mounted) setState(() { _routeData = res; _routeLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  Future<void> _dispatchMovement() async {
    if (_driverCtrl.text.trim().isEmpty || _vehicleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in driver name and vehicle ID.'),
      ));
      return;
    }
    final qty = int.tryParse(_moveQtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid quantity.'),
      ));
      return;
    }
    try {
      final res = await _api.ingestMovement(
        driverName: _driverCtrl.text.trim(),
        vehicleId: _vehicleCtrl.text.trim(),
        originZone: _originZone ?? 'Unknown',
        destinationZone: _destZone ?? 'Unknown',
        sku: _moveSku ?? 'GENERAL',
        quantity: qty,
        status: 'in_transit',
      );
      if (mounted) {
        // Add to local movements list for display
        final movement = res['movement'] as Map<String, dynamic>? ?? {};
        movement['event_type'] = 'logistics_movement';
        setState(() {
          _movements.insert(0, movement);
          _driverCtrl.clear();
          _vehicleCtrl.clear();
          _moveQtyCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Movement dispatched: ${_vehicleCtrl.text.isEmpty ? (res['movement']?['vehicle']) ?? 'Vehicle' : _vehicleCtrl.text} in transit"),
          backgroundColor: AppTheme.success,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.criticalRed));
      }
    }
  }

  void _showDispatchDialog() {
    if (_availableZones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Zones not loaded yet. Please wait.')));
      return;
    }
    _originZone ??= _availableZones.first;
    _destZone ??= _availableZones.length > 1 ? _availableZones[1] : _availableZones.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(children: [
            Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Log Movement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('DRIVER NAME'),
                const SizedBox(height: 6),
                TextField(controller: _driverCtrl, decoration: const InputDecoration(hintText: 'e.g. Kamran Siddiqui')),
                const SizedBox(height: 12),
                _label('VEHICLE ID'),
                const SizedBox(height: 6),
                TextField(controller: _vehicleCtrl, decoration: const InputDecoration(hintText: 'e.g. TRUCK-092')),
                const SizedBox(height: 12),
                _label('ORIGIN ZONE'),
                const SizedBox(height: 6),
                _zoneDropdown(
                  value: _originZone,
                  zones: _availableZones,
                  onChanged: (v) { if (v != null) setDlg(() => _originZone = v); },
                ),
                const SizedBox(height: 12),
                _label('DESTINATION ZONE'),
                const SizedBox(height: 6),
                _zoneDropdown(
                  value: _destZone,
                  zones: _availableZones,
                  onChanged: (v) { if (v != null) setDlg(() => _destZone = v); },
                ),
                const SizedBox(height: 12),
                _label('SKU (optional)'),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => _moveSku = v.trim().isEmpty ? null : v.trim(),
                  decoration: const InputDecoration(hintText: 'e.g. MED-001 or leave blank'),
                ),
                const SizedBox(height: 12),
                _label('QUANTITY (UNITS)'),
                const SizedBox(height: 6),
                TextField(controller: _moveQtyCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 500')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _dispatchMovement,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Dispatch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoneRisk = _zoneRiskData['zone_risk_map'] as Map<String, dynamic>? ?? {};
    final riskSummary = _zoneRiskData['summary'] as Map<String, dynamic>? ?? {};
    final redZonesList = riskSummary['red_zones'] as List<dynamic>? ?? [];
    final redZones = redZonesList.length;
    final alertZones = riskSummary['alert_zones'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Fleet & Route Intelligence'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadAll),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E40AF),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _showDispatchDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.route_outlined, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Log Movement',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.auto_awesome, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: AppTheme.primary,
                  child: _buildBody(zoneRisk, redZones, alertZones),
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
            Text('Backend Unreachable', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVar), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> zoneRisk, int redZones, int alertZones) {
    final opt = _routeData['recommended_route'] as Map<String, dynamic>? ?? _routeData['optimized_route'] as Map<String, dynamic>? ?? {};
    final routeAlerts = opt['alerts'] as List<dynamic>? ?? [];
    final routeSummary = _routeData['decision_summary'] ?? opt['summary'] ?? opt['recommendation'] ?? opt['route'] ?? 'Select origin and destination, then tap Optimize.';

    final int? timeMin = (opt['estimated_time_min'] as num?)?.toInt() ?? (opt['normal_time_min'] as num?)?.toInt();
    final String durationText = timeMin != null ? (timeMin < 60 ? '$timeMin mins' : '${timeMin ~/ 60}h ${timeMin % 60}m') : '--';
    final double? distance = (opt['distance_km'] as num?)?.toDouble();
    final String distanceText = distance != null ? '${distance.toStringAsFixed(1)} km' : '--';
    final int? score = (opt['score'] as num?)?.toInt();
    final String safetyScoreText = score != null ? '$score/100' : '--';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Live Zone Risk KPIs ──
        Row(children: [
          Expanded(child: _metricTile('RED ALERT ZONES', '$redZones Zones',
            redZones > 0 ? AppTheme.criticalRed : AppTheme.success)),
          const SizedBox(width: 12),
          Expanded(child: _metricTile('TOTAL ALERT ZONES', '$alertZones Active',
            alertZones > 0 ? AppTheme.warning : AppTheme.success)),
        ]),
        const SizedBox(height: 16),

        // ── Zone Risk Map from Backend ──
        if (zoneRisk.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.map_outlined, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Live Zone Risk Map', style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.outlineVar, width: 0.5),
              ),
              child: DataTable(
                columnSpacing: 24,
                headingRowColor: MaterialStateProperty.all(AppTheme.outlineVar.withOpacity(0.1)),
                columns: const [
                  DataColumn(label: Text('Zone Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Current Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Avg. Daily Incidents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Last Incident Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Operational Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
                rows: zoneRisk.entries.map((e) {
                  final zone = e.key;
                  final details = e.value as Map<String, dynamic>;
                  final riskStr = (details['risk'] ?? 'GREEN') as String;
                  final avgDaily = details['avg_daily_incidents'] ?? '0.8/day';
                  final lastTime = details['last_incident_time'] ?? '3 hrs ago';
                  final opStatus = details['operational_status'] ?? 'Active';
                  final riskPct = details['risk_percent'] ?? 15;
                  
                  final isRed = riskStr == 'RED';
                  final isYellow = riskStr == 'YELLOW';
                  
                  final Color riskColor = isRed
                      ? AppTheme.criticalRed
                      : isYellow ? AppTheme.warning : AppTheme.success;
                      
                  final String riskLabel = isRed
                      ? 'Critical ($riskPct%)'
                      : isYellow ? 'Warning ($riskPct%)' : 'Nominal';

                  final isOpWarning = opStatus.contains('%');

                  return DataRow(
                    selected: _selectedZoneRiskDetail == zone,
                    onSelectChanged: (selected) {
                      setState(() {
                        _selectedZoneRiskDetail = (selected == true) ? zone : null;
                      });
                    },
                    cells: [
                      // Zone Name
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: riskColor),
                          ),
                          const SizedBox(width: 8),
                          Text(zone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      )),
                      // Current Risk Badge
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: riskColor, width: 1),
                        ),
                        child: Text(
                          riskLabel,
                          style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )),
                      // Avg Daily
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 12, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(avgDaily, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ],
                      )),
                      // Last Incident Time
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(lastTime, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ],
                      )),
                      // Operational Status
                      DataCell(Container(
                        padding: isOpWarning ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
                        decoration: isOpWarning ? BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ) : null,
                        child: Text(
                          opStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isOpWarning ? FontWeight.bold : FontWeight.normal,
                            color: isOpWarning ? Colors.amber[900] : Colors.black87,
                          ),
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          if (_selectedZoneRiskDetail != null) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0F1E36), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0xFF0F1E36),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'INCIDENT LOG: ${_selectedZoneRiskDetail!.toUpperCase()} (${(zoneRisk[_selectedZoneRiskDetail!]?['risk'] == 'RED') ? 'Red Zone' : (zoneRisk[_selectedZoneRiskDetail!]?['risk'] == 'YELLOW') ? 'Yellow Zone' : 'Green Zone'})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _selectedZoneRiskDetail = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dynamic Safety Vectors Grid
                        Row(
                          children: [
                            Expanded(
                              child: _factorCard(
                                title: 'ROAD INCIDENTS',
                                value: '${zoneRisk[_selectedZoneRiskDetail]?['total_incidents'] ?? 0} Active',
                                subtitle: '${zoneRisk[_selectedZoneRiskDetail]?['critical_count'] ?? 0} Crit / ${zoneRisk[_selectedZoneRiskDetail]?['high_count'] ?? 0} High',
                                icon: Icons.traffic_outlined,
                                color: (zoneRisk[_selectedZoneRiskDetail]?['total_incidents'] ?? 0) > 0 ? AppTheme.criticalRed : AppTheme.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _factorCard(
                                title: 'COMPLAINTS',
                                value: '${zoneRisk[_selectedZoneRiskDetail]?['complaint_count'] ?? 0} Active',
                                subtitle: 'Shortages & Stockouts',
                                icon: Icons.storefront_outlined,
                                color: (zoneRisk[_selectedZoneRiskDetail]?['complaint_count'] ?? 0) > 0 ? AppTheme.warning : AppTheme.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _factorCard(
                                title: 'LOCAL WEATHER',
                                value: '${zoneRisk[_selectedZoneRiskDetail]?['weather_desc'] ?? 'Clear sky'}'.toUpperCase(),
                                subtitle: '${zoneRisk[_selectedZoneRiskDetail]?['weather_risk'] ?? 'LOW'} RISK',
                                icon: Icons.cloud_outlined,
                                color: (zoneRisk[_selectedZoneRiskDetail]?['weather_risk'] == 'HIGH') ? AppTheme.criticalRed : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._getMockIncidentLogsForZone(_selectedZoneRiskDetail!),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CustomPaint(
                              painter: MiniMapPainter(),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],

        // ── AI Route Optimizer ──
        Row(children: [
          const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
          const SizedBox(width: 6),
          Text('AI Route Intelligence', style: Theme.of(context).textTheme.headlineMedium),
        ]),
        const SizedBox(height: 10),

        // Route Planner card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'Route Planner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ORIGIN WAREHOUSE',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black45,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, color: Colors.black54, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _originCtrl.text.isNotEmpty && _availableZones.contains(_originCtrl.text)
                                              ? _originCtrl.text
                                              : (_availableZones.isNotEmpty ? _availableZones.first : null),
                                          isExpanded: true,
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black45, size: 16),
                                          style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600),
                                          items: _availableZones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() {
                                                _originCtrl.text = v;
                                                _originZone = v;
                                              });
                                              _reoptimizeRoute();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.swap_horiz, color: Colors.black45, size: 18),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DESTINATION WAREHOUSE',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black45,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, color: Colors.black54, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _destCtrl.text.isNotEmpty && _availableZones.contains(_destCtrl.text)
                                              ? _destCtrl.text
                                              : (_availableZones.length > 1 ? _availableZones[1] : (_availableZones.isNotEmpty ? _availableZones.first : null)),
                                          isExpanded: true,
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black45, size: 16),
                                          style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600),
                                          items: _availableZones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() {
                                                _destCtrl.text = v;
                                                _destZone = v;
                                              });
                                              _reoptimizeRoute();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton(
                        onPressed: _routeLoading ? null : _reoptimizeRoute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_routeLoading) ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ] else ...[
                              const Icon(Icons.route_outlined, color: Colors.white, size: 14),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              _routeLoading ? 'Optimizing…' : 'Optimize Route with AI',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Analysis Module card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Analysis Module',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    Icon(
                      Icons.settings_input_component_outlined, 
                      size: 14, 
                      color: Colors.blue[800]
                    ),
                  ],
                ),
              ),
              _routeLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Optimizing routes & analyzing crisis vectors...',
                              style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle, 
                            color: Color(0xFF10B981), 
                            size: 26
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Route Analysis Complete',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  routeSummary.toString().isNotEmpty && routeSummary.toString() != 'Route intelligence loading…'
                                      ? routeSummary.toString()
                                      : 'No critical adjustments required. All routes clear.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    const Text('Est. Duration', style: TextStyle(fontSize: 9, color: Colors.black54)),
                                    const SizedBox(width: 6),
                                    Text(durationText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.alt_route, size: 12, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    const Text('Est. Distance', style: TextStyle(fontSize: 9, color: Colors.black54)),
                                    const SizedBox(width: 6),
                                    Text(distanceText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 12, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    const Text('Safety Score', style: TextStyle(fontSize: 9, color: Colors.black54)),
                                    const SizedBox(width: 6),
                                    Text(
                                      safetyScoreText,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Route alerts from backend
        if (routeAlerts.isNotEmpty)
          ...routeAlerts.map((a) {
            final severity = (a['severity'] ?? '').toString().toUpperCase();
            final isHigh = severity == 'HIGH' || severity == 'CRITICAL';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: AiRecommendationCard(
                tag: 'LIVE ALERT',
                tagColor: isHigh ? AppTheme.criticalRed : AppTheme.warning,
                tagRight: severity.isEmpty ? 'INFO' : severity,
                tagRightColor: isHigh ? AppTheme.criticalRed : AppTheme.warning,
                icon: Icons.alt_route,
                title: a['title'] ?? 'Route Adjustment',
                subtitle: 'Reason: ${a['reason'] ?? 'Weather/Traffic Anomaly'}',
                buttonLabel: 'APPLY ROUTE',
                buttonFilled: isHigh,
                executed: false,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route update dispatched to fleet.')));
                },
              ),
            );
          }),

        const SizedBox(height: 20),

        // ── Recent Dispatched Movements (this session) ──
        if (_movements.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.swap_horiz, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Movements Logged This Session', style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _movements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final m = _movements[idx];
                final driver = m['driver'] ?? m['driver_name'] ?? 'Driver';
                final vehicle = m['vehicle'] ?? m['vehicle_id'] ?? 'Vehicle';
                final from = m['from'] ?? m['origin_zone'] ?? '—';
                final to = m['to'] ?? m['destination_zone'] ?? '—';
                final sku = m['sku'] ?? 'GENERAL';
                final qty = m['quantity'] ?? 0;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: AppTheme.primary, size: 20),
                  ),
                  title: Text('$vehicle · $driver',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('$from → $to  |  SKU: $sku  |  Qty: $qty units',
                    style: const TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('IN TRANSIT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.onSurfaceVar)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _factorCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 7.5,
              color: Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurfaceVar, fontSize: 9));

  Widget _zoneDropdown({
    required String? value,
    required List<String> zones,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<Widget> _getMockIncidentLogsForZone(String zone) {
    final List<Map<String, dynamic>> logs = zone.toLowerCase() == 'korangi'
        ? [
            {
              'time': '11:30 AM',
              'msg': 'Route Obstruction (Korangi Road)',
              'severity': 'CRITICAL',
            },
            {
              'time': '10:15 AM',
              'msg': 'Resource Scarcity Alert (Supply Point 4)',
              'severity': 'WARNING',
            },
            {
              'time': '09:00 AM',
              'msg': 'Transit Delay (Logistics Hub B)',
              'severity': 'INFO',
            },
            {
              'time': '09:00 AM',
              'msg': 'Transit Delay (Logistics Hub L)',
              'severity': 'INFO',
            },
          ]
        : [
            {
              'time': '10:00 AM',
              'msg': 'Routine Telemetry Active ($zone Zone)',
              'severity': 'INFO',
            },
            {
              'time': '08:30 AM',
              'msg': 'Minor Traffic Delay near $zone Depot',
              'severity': 'INFO',
            },
          ];

    return [
      ...logs.map((l) {
        final String severity = l['severity'];
        final IconData icon = severity == 'CRITICAL'
            ? Icons.warning
            : severity == 'WARNING' ? Icons.warning_amber_rounded : Icons.access_time;
        final Color iconColor = severity == 'CRITICAL'
            ? AppTheme.criticalRed
            : severity == 'WARNING' ? AppTheme.warning : Colors.black45;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 8),
                Text(
                  l['time']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
                ),
                const SizedBox(width: 4),
                const Text('|', style: TextStyle(color: Colors.black26, fontSize: 10)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l['msg']!,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        height: 28,
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Colors.black26),
          ),
          child: const Text('View More Logs', style: TextStyle(fontSize: 10, color: Colors.black87)),
        ),
      ),
    ];
  }
}

class MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final streetPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
      
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.4), streetPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.5, size.height), streetPaint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.6), streetPaint);

    final waterPaint = Paint()..color = const Color(0xFFE0F2FE);
    final waterPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.7, 0, size.height * 0.6)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    const textStyle = TextStyle(
      color: Colors.black54,
      fontSize: 8,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
    final textPainter = TextPainter(
      text: const TextSpan(text: 'KORANGI', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width * 0.35, size.height * 0.75));

    _drawPin(canvas, Offset(size.width * 0.4, size.height * 0.3), Colors.red);
    _drawPin(canvas, Offset(size.width * 0.7, size.height * 0.5), Colors.red);
    _drawPin(canvas, Offset(size.width * 0.5, size.height * 0.6), Colors.red);
    _drawPin(canvas, Offset(size.width * 0.2, size.height * 0.4), Colors.orange);
  }

  void _drawPin(Canvas canvas, Offset pos, Color color) {
    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 6, pinPaint);
    
    final innerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(pos - const Offset(0, 3), pos + const Offset(0, 1), innerPaint);
    canvas.drawCircle(pos + const Offset(0, 3), 0.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MiniMapPreview extends StatelessWidget {
  const MiniMapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -5,
              child: Container(
                width: 30,
                height: 25,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Positioned(
              left: -5,
              bottom: -5,
              child: Container(
                width: 25,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Center(
              child: CustomPaint(
                size: const Size(36, 16),
                painter: RouteLinePainter(),
              ),
            ),
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.circle, size: 3, color: Colors.blue),
            ),
            const Positioned(
              right: 6,
              top: 4,
              child: Icon(Icons.circle, size: 3, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final path = Path()
      ..moveTo(4, size.height - 4)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.3, size.width - 6, 4);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

