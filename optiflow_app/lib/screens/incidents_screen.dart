import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/agent_state_provider.dart';
import '../widgets/incident_tile.dart';
import '../widgets/resource_matrix.dart';
import 'report_incident_screen.dart';
import 'profile_screen.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Incident> _allIncidents = [];
  List<Incident> _karachiIncidents = [];
  Incident? _selectedIncident;
  String _filter = 'ALL';
  String? _filterZone;
  List<String> _availableZones = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getIncidents(zone: null);
      final listRaw = data['incidents'] as List<dynamic>? ?? [];
      final incidents = listRaw
          .map((e) => Incident.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      incidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final karachiRaw = data['karachi_incidents'] as List<dynamic>? ?? [];
      final karachiIncidents = karachiRaw
          .map((e) => Incident.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      karachiIncidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // collect unique zones from live data
      final zones = {
        ...incidents.map((i) => i.zone),
        ...karachiIncidents.map((i) => i.zone)
      }.where((z) => z.isNotEmpty && z != 'Unknown').toList()..sort();

      if (mounted) {
        setState(() {
          _allIncidents = incidents;
          _karachiIncidents = karachiIncidents;
          _availableZones = zones;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;

    List<Incident> liveKarachiIncidents = List<Incident>.from(_karachiIncidents);
    if (latestResult != null) {
      final insights = latestResult['insights'] as Map<String, dynamic>? ?? {};
      final signals = insights['signals'] as List<dynamic>? ?? [];
      for (var i = 0; i < signals.length; i++) {
        final signalText = signals[i].toString();
        // Skip duplicate signals if already added
        if (liveKarachiIncidents.any((e) => e.message == signalText)) continue;

        String severity = 'HIGH';
        if (signalText.toLowerCase().contains('flood') || signalText.toLowerCase().contains('block') || signalText.toLowerCase().contains('critical')) {
          severity = 'CRITICAL';
        }
        
        // Match zone intelligently
        String zone = 'SITE';
        if (signalText.toLowerCase().contains('m9') || signalText.toLowerCase().contains('motorway')) {
          zone = 'Malir';
        } else if (signalText.toLowerCase().contains('clifton')) {
          zone = 'Clifton';
        } else if (signalText.toLowerCase().contains('saddar')) {
          zone = 'Saddar';
        } else if (signalText.toLowerCase().contains('korangi')) {
          zone = 'Korangi';
        }

        liveKarachiIncidents.insert(0, Incident(
          id: 'ai-signal-$i',
          title: 'AI Operational Alert',
          message: signalText,
          severity: severity,
          zone: zone,
          timestamp: DateTime.now().subtract(Duration(minutes: i * 5)).toIso8601String(),
          reporter: 'Autonomous Safety Agent',
        ));
      }
    }

    final zoneFiltered = _filterZone == null
        ? _allIncidents
        : _allIncidents.where((i) => i.zone.toLowerCase() == _filterZone!.toLowerCase()).toList();

    final critical = zoneFiltered.where((i) => i.severity == 'CRITICAL').toList();
    final high     = zoneFiltered.where((i) => i.severity == 'HIGH').toList();
    final minor    = zoneFiltered.where((i) => i.severity != 'CRITICAL' && i.severity != 'HIGH').toList();

    final filtered = _filter == 'ALL'
        ? zoneFiltered
        : _filter == 'CRITICAL'
            ? critical
            : _filter == 'HIGH'
                ? high
                : minor;

    final zoneFilteredKarachi = _filterZone == null
        ? liveKarachiIncidents
        : liveKarachiIncidents.where((i) => i.zone.toLowerCase() == _filterZone!.toLowerCase()).toList();

    final criticalKarachi = zoneFilteredKarachi.where((i) => i.severity == 'CRITICAL').toList();
    final highKarachi     = zoneFilteredKarachi.where((i) => i.severity == 'HIGH').toList();
    final minorKarachi    = zoneFilteredKarachi.where((i) => i.severity != 'CRITICAL' && i.severity != 'HIGH').toList();

    final filteredKarachi = _filter == 'ALL'
        ? zoneFilteredKarachi
        : _filter == 'CRITICAL'
            ? criticalKarachi
            : _filter == 'HIGH'
                ? highKarachi
                : minorKarachi;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Supply & Safety Alerts'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
          );
          _loadData(); // refresh after reporting
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading && latestResult == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: _buildBody(
                    critical: critical,
                    high: high,
                    minor: minor,
                    filtered: filtered,
                    criticalKarachi: criticalKarachi,
                    highKarachi: highKarachi,
                    minorKarachi: minorKarachi,
                    filteredKarachi: filteredKarachi,
                    latestResult: latestResult,
                  ),
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
            Text('Could not load incidents.', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVar), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<Incident> critical,
    required List<Incident> high,
    required List<Incident> minor,
    required List<Incident> filtered,
    required List<Incident> criticalKarachi,
    required List<Incident> highKarachi,
    required List<Incident> minorKarachi,
    required List<Incident> filteredKarachi,
    required Map<String, dynamic>? latestResult,
  }) {
    // Dynamic zone incident count lookup map (combining both)
    final Map<String, int> zoneIncidentCounts = {};
    for (var inc in _allIncidents) {
      final zoneName = inc.zone.trim();
      if (zoneName.isNotEmpty && zoneName != 'Unknown') {
        zoneIncidentCounts[zoneName] = (zoneIncidentCounts[zoneName] ?? 0) + 1;
      }
    }
    for (var inc in filteredKarachi) {
      final zoneName = inc.zone.trim();
      if (zoneName.isNotEmpty && zoneName != 'Unknown') {
        zoneIncidentCounts[zoneName] = (zoneIncidentCounts[zoneName] ?? 0) + 1;
      }
    }

    final totalCount = _allIncidents.length + filteredKarachi.length;
    final totalCritical = critical.length + criticalKarachi.length;
    final totalHigh = high.length + highKarachi.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Page Header ──
        Text('Active Risks & Alerts', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(
          '$totalCount total reports · $totalCritical critical · $totalHigh high',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVar),
        ),
        const SizedBox(height: 16),

        // ── Dynamic Zone Overview Board ──
        _buildZoneSummaryBoard(zoneIncidentCounts),

        // ── Crisis-Aware Corridor Status Card (AI) ──
        if (latestResult != null) ...[
          _buildCrisisCorridorsCard(latestResult),
        ],

        // ── 8 Sources AI Intelligence Banner ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'REAL-TIME RISK MONITORING (AI)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, size: 6, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'LIVE SCAN',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Our AI scans 8 distinct channels in Karachi (Weather, News, Traffic, Suppliers, etc.) to identify logistics and safety hazards. The list below highlights active workspace risks alongside regional alerts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVar,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _sourceBadge('Weather Feeds'),
                  _sourceBadge('News & RSS'),
                  _sourceBadge('Social Media'),
                  _sourceBadge('Traffic Status'),
                  _sourceBadge('Govt Sheets'),
                  _sourceBadge('Port Logs'),
                  _sourceBadge('NGO Activity'),
                  _sourceBadge('Emergency Calls'),
                ],
              ),
            ],
          ),
        ),

        // ── Severity Summary Cards ──
        Row(children: [
          Expanded(child: _summaryCard('CRITICAL', totalCritical, AppTheme.criticalRed)),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard('HIGH', totalHigh, AppTheme.warning)),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard('MINOR', minor.length + minorKarachi.length, AppTheme.onSurfaceVar)),
        ]),
        const SizedBox(height: 16),

        // ── Severity Filter Chips ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(context, 'ALL ($totalCount)', AppTheme.primary, 'ALL'),
            const SizedBox(width: 8),
            _chip(context, 'CRITICAL ($totalCritical)', AppTheme.criticalRed, 'CRITICAL'),
            const SizedBox(width: 8),
            _chip(context, 'HIGH ($totalHigh)', AppTheme.primary, 'HIGH'),
            const SizedBox(width: 8),
            _chip(context, 'MINOR (${minor.length + minorKarachi.length})', AppTheme.onSurfaceVar, 'MINOR'),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Section 1: My Workspace Reports ──
        Text(
          'My Workspace Reports',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.onSurfaceVar, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No active workspace reports recorded. Click the + button below to log a road blockage.',
                    style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVar.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          )
        else
          ...filtered.map((inc) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() =>
                _selectedIncident = _selectedIncident?.id == inc.id ? null : inc),
              child: IncidentTile(
                incident: inc,
                selected: _selectedIncident?.id == inc.id,
              ),
            ),
          )),

        const SizedBox(height: 24),

        // ── Section 2: Karachi City-Wide Reports ──
        Text(
          'Karachi City-Wide Reports',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (filteredKarachi.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.onSurfaceVar, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No public reports matching current zone or filters.',
                    style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVar.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          )
        else
          ...filteredKarachi.map((inc) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() =>
                _selectedIncident = _selectedIncident?.id == inc.id ? null : inc),
              child: IncidentTile(
                incident: inc,
                selected: _selectedIncident?.id == inc.id,
              ),
            ),
          )),

        // ── Resource Matrix for selected incident ──
        const SizedBox(height: 8),
        if (_selectedIncident != null)
          ResourceMatrix(incident: _selectedIncident!),
        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _chip(BuildContext ctx, String label, Color color, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = selected ? 'ALL' : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? color : AppTheme.outlineVar, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: color)),
        ]),
      ),
    );
  }

  Widget _zoneChip(String label, String? zone) {
    final selected = _filterZone == zone;
    return GestureDetector(
      onTap: () {
        setState(() => _filterZone = selected ? null : zone);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.outlineVar, width: 1),
        ),
        child: Text(
          '📍 $label',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? AppTheme.primary : AppTheme.onSurfaceVar),
        ),
      ),
    );
  }

  Widget _sourceBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 10, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVar),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneSummaryBoard(Map<String, int> zoneIncidentCounts) {
    final activeZones = _availableZones.isEmpty 
        ? ['Saddar', 'Clifton', 'SITE', 'Korangi', 'Malir'] 
        : _availableZones;
    
    return Container(
      height: 72,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: activeZones.length,
        itemBuilder: (ctx, idx) {
          final zone = activeZones[idx];
          final count = zoneIncidentCounts[zone] ?? 0;
          final isSelected = _filterZone?.toLowerCase() == zone.toLowerCase();
          
          Color riskColor = AppTheme.success;
          String emoji = '🟢';
          if (count > 5) {
            riskColor = AppTheme.criticalRed;
            emoji = '🔴';
          } else if (count > 0) {
            riskColor = AppTheme.warning;
            emoji = '🟡';
          }
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _filterZone = isSelected ? null : zone;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 124,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? riskColor.withOpacity(0.08) : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? riskColor : AppTheme.outlineVar,
                  width: isSelected ? 1.5 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          zone.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? riskColor : AppTheme.onSurfaceVar,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(emoji, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count Incident${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: count > 0 ? Colors.black87 : AppTheme.onSurfaceVar.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCrisisCorridorsCard(Map<String, dynamic> latestResult) {
    final decision = latestResult['decision'] as Map<String, dynamic>? ?? {};
    final action = decision['selected_action'] as Map<String, dynamic>? ?? {};
    final params = action['parameters'] as Map<String, dynamic>? ?? {};
    
    final blockedRoad = params['blocked_road']?.toString() ?? 'M9 Motorway Corridor';
    final altRoute = params['alternative_route']?.toString() ?? 'Lyari Expressway detour';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_outlined, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Crisis-Aware Corridor Status',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Corridor 1: M9 Motorway
          _buildCorridorRow(
            name: blockedRoad,
            status: 'BLOCKED',
            badgeColor: AppTheme.criticalRed,
            desc: 'Severe flooding hazard & structural blockage reported.',
          ),
          const Divider(height: 16),
          
          // Corridor 2: Lyari Expressway Detour
          _buildCorridorRow(
            name: altRoute,
            status: 'OPTIMIZED DETOUR APPROVED',
            badgeColor: AppTheme.success,
            desc: 'Nominal conditions. Re-routed emergency traffic flowing.',
          ),
          const Divider(height: 16),
          
          // Corridor 3: SITE / Saddar Central Hub
          _buildCorridorRow(
            name: 'SITE / Saddar Central Hub',
            status: 'WARNING / FLOOD-RISK ACTIVE',
            badgeColor: AppTheme.warning,
            desc: 'Localized rain accumulation. Nominal transit advised.',
          ),
        ],
      ),
    );
  }

  Widget _buildCorridorRow({
    required String name,
    required String status,
    required Color badgeColor,
    required String desc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor, width: 0.8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVar),
        ),
      ],
    );
  }
}
