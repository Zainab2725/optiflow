import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/agent_state_provider.dart';
import '../widgets/ai_recommendation_card.dart';
import 'profile_screen.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});
  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final _api = ApiService();
  Timer? _refreshTimer;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _routeData = {};
  Map<String, dynamic> _zoneRiskData = {};
  List<Map<String, dynamic>> _movements = [];
  String? _selectedZoneRiskDetail;

  // Route planner inputs
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  bool _routeLoading = false;

  // Movement dispatch form
  final _driverCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  String? _originZone;
  String? _destZone;
  String? _moveSku;
  final _moveQtyCtrl = TextEditingController();
  List<String> _availableZones = [];

  // Zone incidents from backend
  List<dynamic> _zoneIncidents = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Only refresh zone risk on timer — NOT route optimization (that calls Gemini)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _autoRefreshZones());
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

  Future<void> _autoRefreshZones() async {
    try {
      final zoneRes = await _api.getZoneRiskMap();
      if (mounted) {
        setState(() {
          _zoneRiskData = zoneRes;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Phase 1: Load zone risk map instantly
      final zoneRes = await _api.getZoneRiskMap();
      final zoneRisk = zoneRes['zone_risk_map'] != null
          ? Map<String, dynamic>.from(zoneRes['zone_risk_map'] as Map)
          : <String, dynamic>{};
      final zones = zoneRisk.keys.toList()..sort();
      if (mounted) {
        setState(() {
          _zoneRiskData = zoneRes;
          _availableZones = zones;
          _originZone ??= zones.isNotEmpty ? zones.first : 'SITE';
          _destZone ??= zones.length > 1 ? zones[1] : (zones.isNotEmpty ? zones.first : 'Clifton');
          _originCtrl.text = _originZone!;
          _destCtrl.text = _destZone!;
          _loading = false;
        });
      }

      // Phase 2: Load route optimization in background
      try {
        final routeRes = await _api.getRouteOptimization(
          origin: _originCtrl.text,
          destination: _destCtrl.text,
        );
        if (mounted) {
          setState(() { _routeData = routeRes; });
        }
      } catch (e) {
        debugPrint('Optional background route optimization failed: $e');
      }

      // Phase 3: Load incidents for zone detail panel
      try {
        final incidentRes = await _api.getIncidents();
        if (mounted) {
          setState(() {
            _zoneIncidents = incidentRes['karachi_incidents'] ?? incidentRes['incidents'] ?? [];
          });
        }
      } catch (e) {
        debugPrint('Incidents load failed: $e');
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

    // Save values before clearing controllers
    final vehicleName = _vehicleCtrl.text.trim();
    final driverName = _driverCtrl.text.trim();

    try {
      final res = await _api.ingestMovement(
        driverName: driverName,
        vehicleId: vehicleName,
        originZone: _originZone ?? 'Unknown',
        destinationZone: _destZone ?? 'Unknown',
        sku: _moveSku ?? 'GENERAL',
        quantity: qty,
        status: 'in_transit',
      );
      if (mounted) {
        final movement = res['movement'] != null
            ? Map<String, dynamic>.from(res['movement'] as Map)
            : <String, dynamic>{};
        movement['event_type'] = 'logistics_movement';
        setState(() {
          _movements.insert(0, movement);
          _driverCtrl.clear();
          _vehicleCtrl.clear();
          _moveQtyCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Unit dispatched: $vehicleName ($driverName) in transit"),
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
            Text('Dispatch Emergency Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('DRIVER / OPERATOR NAME'),
                const SizedBox(height: 6),
                TextField(controller: _driverCtrl, decoration: const InputDecoration(hintText: 'e.g. Kamran Siddiqui')),
                const SizedBox(height: 12),
                _label('UNIT / VEHICLE ID'),
                const SizedBox(height: 6),
                TextField(controller: _vehicleCtrl, decoration: const InputDecoration(hintText: 'e.g. UNIT-092')),
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
                _label('RESOURCE / SKU (optional)'),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => _moveSku = v.trim().isEmpty ? null : v.trim(),
                  decoration: const InputDecoration(hintText: 'e.g. MED-001 or leave blank'),
                ),
                const SizedBox(height: 12),
                _label('QUANTITY (UNITS)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _moveQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 500'),
                ),
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
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;

    final zoneRisk = _zoneRiskData['zone_risk_map'] != null
        ? Map<String, dynamic>.from(_zoneRiskData['zone_risk_map'] as Map)
        : <String, dynamic>{};
    final riskSummary = _zoneRiskData['summary'] != null
        ? Map<String, dynamic>.from(_zoneRiskData['summary'] as Map)
        : <String, dynamic>{};
    final redZonesList = riskSummary['red_zones'] as List<dynamic>? ?? [];
    final redZones = redZonesList.length;
    final alertZones = riskSummary['alert_zones'] != null
        ? ((riskSummary['alert_zones'] ?? 0) as num).toInt()
        : 0;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Dispatch & Route Intelligence'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadAll),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
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
                  'Dispatch Unit',
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
      body: _loading && latestResult == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: AppTheme.primary,
                  child: _buildBody(zoneRisk, redZones, alertZones, latestResult),
                ),
    );
  }

  Widget _buildLiveAiFleetSandboxCard(Map<String, dynamic> latestResult) {
    final decision = latestResult['decision'] as Map<String, dynamic>? ?? {};
    final simulation = latestResult['simulation'] as Map<String, dynamic>? ?? {};
    final action = decision['selected_action'] as Map<String, dynamic>? ?? {};
    final actionType = action['type']?.toString() ?? 'ROUTE_CHANGE';

    final beforeState = simulation['before_state']?.toString() ?? 'Awaiting simulation data...';
    final afterState = simulation['after_state']?.toString() ?? 'Awaiting simulation data...';
    final metrics = simulation['impact_metrics'] as Map<String, dynamic>? ?? {};
    final delaySavings = metrics['delay_reduction']?.toString() ?? metrics['eta_improvement']?.toString() ?? 'N/A';
    final safetyImprovement = metrics['risk_reduction']?.toString() ?? metrics['alternative_route_safety']?.toString() ?? 'N/A';

    final isReroute = actionType == 'ROUTE_CHANGE';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE AI OPERATIONS COMMAND',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReroute ? AppTheme.warning.withOpacity(0.2) : AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isReroute ? AppTheme.warning : AppTheme.primary, width: 0.5),
                ),
                child: Text(
                  isReroute ? 'AI REROUTE ACTIVE' : 'AI DISPATCH ACTIVE',
                  style: TextStyle(
                    color: isReroute ? AppTheme.warning : Colors.blueAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            decision['primary_insight'] ?? 'Awaiting AI insights...',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          
          // Before vs After State
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.criticalRed, size: 14),
                    SizedBox(width: 8),
                    Text(
                      'PRE-OPTIMIZED STATE',
                      style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  beforeState,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 16),
                ),
                Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 8),
                    Text(
                      'POST-OPTIMIZED STATE (AI SANDBOX)',
                      style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  afterState,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Delay savings and safety metrics
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DELAY SAVED',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delaySavings,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SAFETY METRIC',
                        style: TextStyle(color: Colors.lightBlueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        safetyImprovement,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
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

  Widget _buildBody(Map<String, dynamic> zoneRisk, int redZones, int alertZones, Map<String, dynamic>? latestResult) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Live AI Operational Sandbox Card ──
        if (latestResult != null && latestResult['decision'] != null && latestResult['decision']['selected_action'] != null) ...[
          _buildLiveAiFleetSandboxCard(latestResult),
          const SizedBox(height: 16),
        ],

        // ── Recent Dispatched Movements (this session) ──
        if (_movements.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.swap_horiz, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Units Dispatched This Session', style: Theme.of(context).textTheme.headlineMedium),
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
                final driver = m['driver'] ?? m['driver_name'] ?? 'Operator';
                final vehicle = m['vehicle'] ?? m['vehicle_id'] ?? 'Unit';
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

        if (_movements.isEmpty && (latestResult == null || latestResult['decision'] == null))
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 56, color: AppTheme.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No dispatches yet', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the "Dispatch Unit" button below\nto send a vehicle to a zone.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVar),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Zone detail panel — uses real backend incidents
  Widget _buildZoneDetailPanel(Map<String, dynamic> zoneRisk) {
    final zoneData = zoneRisk[_selectedZoneRiskDetail!] != null
        ? Map<String, dynamic>.from(zoneRisk[_selectedZoneRiskDetail!] as Map)
        : <String, dynamic>{};
    final riskStr = zoneData['risk'] ?? 'GREEN';
    final riskLabel = riskStr == 'RED' ? 'Red Zone' : riskStr == 'YELLOW' ? 'Yellow Zone' : 'Green Zone';

    // Filter real incidents for selected zone
    final zoneIncidentList = _zoneIncidents
        .where((i) =>
            (i['location_zone'] ?? i['zone'] ?? '').toString().toLowerCase() ==
            _selectedZoneRiskDetail!.toLowerCase())
        .take(5)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F1E36), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF0F1E36),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'INCIDENT LOG: ${_selectedZoneRiskDetail!.toUpperCase()} ($riskLabel)',
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
                  onPressed: () => setState(() => _selectedZoneRiskDetail = null),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Safety factor cards
                Row(
                  children: [
                    Expanded(
                      child: _factorCard(
                        title: 'ROAD INCIDENTS',
                        value: '${zoneData['total_incidents'] ?? 0} Active',
                        subtitle: '${zoneData['critical_count'] ?? 0} Crit / ${zoneData['high_count'] ?? 0} High',
                        icon: Icons.traffic_outlined,
                        color: (zoneData['total_incidents'] ?? 0) > 0 ? AppTheme.criticalRed : AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _factorCard(
                        title: 'COMPLAINTS',
                        value: '${zoneData['complaint_count'] ?? 0} Active',
                        subtitle: 'Shortages & Stockouts',
                        icon: Icons.storefront_outlined,
                        color: (zoneData['complaint_count'] ?? 0) > 0 ? AppTheme.warning : AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _factorCard(
                        title: 'LOCAL WEATHER',
                        value: '${zoneData['weather_desc'] ?? 'Clear sky'}'.toUpperCase(),
                        subtitle: '${zoneData['weather_risk'] ?? 'LOW'} RISK',
                        icon: Icons.cloud_outlined,
                        color: (zoneData['weather_risk'] == 'HIGH') ? AppTheme.criticalRed : AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Real incidents from backend
                if (zoneIncidentList.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                        SizedBox(width: 8),
                        Text(
                          'No active incidents reported for this zone.',
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ),
                  )
                else
                  ...zoneIncidentList.map((incident) {
                    final severity = (incident['severity'] ?? 'low').toString().toLowerCase();
                    final isCritical = severity == 'critical';
                    final isHigh = severity == 'high';
                    final IconData icon = isCritical
                        ? Icons.warning
                        : isHigh
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline;
                    final Color iconColor = isCritical
                        ? AppTheme.criticalRed
                        : isHigh
                            ? AppTheme.warning
                            : Colors.black45;
                    final String timeStr = incident['timestamp'] ?? '';
                    String displayTime = '';
                    try {
                      final dt = DateTime.parse(timeStr).toLocal();
                      final h = dt.hour.toString().padLeft(2, '0');
                      final m = dt.minute.toString().padLeft(2, '0');
                      displayTime = '$h:$m';
                    } catch (_) {
                      displayTime = timeStr.isNotEmpty ? timeStr.substring(0, min(10, timeStr.length)) : 'Recent';
                    }

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
                              displayTime,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
                            ),
                            const SizedBox(width: 4),
                            const Text('|', style: TextStyle(color: Colors.black26, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                incident['message'] ?? 'Incident reported',
                                style: const TextStyle(fontSize: 10, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                severity.toUpperCase(),
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: iconColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
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
                  style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 7.5, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
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
}

int min(int a, int b) => a < b ? a : b;
