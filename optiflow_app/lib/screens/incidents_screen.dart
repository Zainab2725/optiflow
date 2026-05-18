import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/firestore_service.dart';
import '../widgets/incident_tile.dart';
import '../widgets/resource_matrix.dart';
import 'report_incident_screen.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final _fs = FirestoreService();
  String _filter = 'ALL';
  Incident? _selectedIncident;

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Incident>>(
        stream: _fs.incidentsStream(),
        builder: (ctx, snap) {
          final all = snap.data ?? [];
          final critical = all.where((i) => i.severity == 'CRITICAL').toList();
          final high = all.where((i) => i.severity == 'HIGH').toList();
          final minor = all.where((i) =>
              i.severity != 'CRITICAL' && i.severity != 'HIGH').toList();
          final filtered = _filter == 'ALL' ? all
              : _filter == 'CRITICAL' ? critical
              : _filter == 'HIGH' ? high : minor;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Incident Intelligence',
                style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 4),
              Text('Real-time threat assessment and response coordination.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.onSurfaceVar)),
              const SizedBox(height: 16),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip(context, 'CRITICAL (${critical.length})',
                      AppTheme.criticalRed, 'CRITICAL'),
                  const SizedBox(width: 8),
                  _chip(context, 'HIGH (${high.length})',
                      AppTheme.primary, 'HIGH'),
                  const SizedBox(width: 8),
                  _chip(context, 'MINOR (${minor.length})',
                      AppTheme.onSurfaceVar, 'MINOR'),
                ]),
              ),
              const SizedBox(height: 16),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else ...[
                ...filtered.map((inc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _selectedIncident = _selectedIncident?.id == inc.id
                            ? null : inc),
                    child: IncidentTile(
                      incident: inc,
                      selected: _selectedIncident?.id == inc.id,
                    ),
                  ),
                )),
                const SizedBox(height: 20),
                if (_selectedIncident != null)
                  ResourceMatrix(incident: _selectedIncident!),
              ],
            ],
          );
        },
      ),
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
          border: Border.all(
            color: selected ? color : AppTheme.outlineVar, width: 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
            style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: color)),
        ]),
      ),
    );
  }
}
