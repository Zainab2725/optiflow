import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});
  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _fs = FirestoreService();
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _zone = 'Gulshan Karachi';
  String _sku = 'MED-001';
  String _severity = 'high';
  bool _loading = false;
  String _toast = '';

  final _zones = ['Gulshan Karachi','PECHS','Defence','North Nazimabad',
    'Korangi','Saddar','Clifton','Orangi','Lyari','SITE','Malir'];
  final _skus = ['MED-001','MED-006','MED-035','MED-007','MED-090','GENERAL'];

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _msgCtrl.text.isEmpty) {
      setState(() => _toast = 'Please fill all fields');
      return;
    }
    setState(() => _loading = true);
    try {
      // 1. Submit to FastAPI secure backend pipeline to trigger alerting & rules
      await _api.ingestIncident(
        reporterName: _nameCtrl.text.trim(),
        reporterRole: ApiService.currentUser?['role'] ?? 'field_operator',
        locationZone: _zone,
        sku: _sku == 'GENERAL' ? null : _sku,
        message: _msgCtrl.text.trim(),
        severity: _severity,
      );

      // 2. Save in Firestore for live UI stream
      await _fs.addIncident(Incident(
        id: '',
        title: 'Field Report: $_zone',
        description: _msgCtrl.text.trim(),
        severity: _severity.toUpperCase(),
        zone: _zone,
        status: 'open',
        riskScore: _severity == 'high' ? 75 : _severity == 'critical' ? 90 : 40,
        sku: _sku,
        reporterName: _nameCtrl.text.trim(),
        timestamp: DateTime.now(),
        unitsActive: 0,
      ));
      setState(() { _toast = '✅ Incident reported successfully'; });
      _nameCtrl.clear(); _msgCtrl.clear();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() => _toast = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_toast.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _toast.startsWith('✅')
                    ? AppTheme.successBg : AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_toast,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _toast.startsWith('✅')
                      ? AppTheme.success : AppTheme.error)),
            ),
          _label('REPORTER NAME'),
          const SizedBox(height: 6),
          TextField(controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Your name')),
          const SizedBox(height: 16),
          _label('ZONE'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _zone,
            decoration: const InputDecoration(),
            items: _zones.map((z) => DropdownMenuItem(
                value: z, child: Text(z))).toList(),
            onChanged: (v) => setState(() => _zone = v!),
          ),
          const SizedBox(height: 16),
          _label('SKU / PRODUCT'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _sku,
            decoration: const InputDecoration(),
            items: _skus.map((s) => DropdownMenuItem(
                value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _sku = v!),
          ),
          const SizedBox(height: 16),
          _label('INCIDENT DESCRIPTION'),
          const SizedBox(height: 6),
          TextField(
            controller: _msgCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe the incident...',
            ),
          ),
          const SizedBox(height: 16),
          _label('SEVERITY'),
          const SizedBox(height: 8),
          Row(
            children: ['critical','high','low'].map((s) {
              final color = s == 'critical' ? AppTheme.criticalRed
                  : s == 'high' ? AppTheme.warning : AppTheme.success;
              final sel = _severity == s;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _severity = s),
                  child: Container(
                    margin: EdgeInsets.only(right: s != 'low' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.1) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: sel ? color : AppTheme.outlineVar),
                    ),
                    child: Center(
                      child: Text(s.toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: sel ? color : AppTheme.onSurfaceVar)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined, size: 18),
              label: const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: AppTheme.onSurfaceVar));
}
