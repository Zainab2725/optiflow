import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});
  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String? _zone;
  String? _sku;
  String _severity = 'high';
  bool _loading = false;
  bool _dataLoading = true;
  String _toast = '';
  String _toastType = '';

  // Loaded from backend
  List<String> _zones = [];
  List<Map<String, String>> _skuOptions = []; // [{sku, name}, ...]

  @override
  void initState() {
    super.initState();
    // Pre-fill reporter name from session
    _nameCtrl.text = ApiService.currentUser?['name'] ?? '';
    _loadOptions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  /// Load available zones from zone-risk-map and SKUs from stock ledger
  Future<void> _loadOptions() async {
    setState(() => _dataLoading = true);
    try {
      final results = await Future.wait([
        _api.getZoneRiskMap(),
        _api.getStock(),
      ]);

      final zoneMap = results[0]['zone_risk_map'] as Map<String, dynamic>? ?? {};
      final zones = zoneMap.keys.toList()..sort();

      final records = List<Map<String, dynamic>>.from(results[1]['records'] ?? []);
      // Build unique SKU list from live stock ledger
      final skuSet = <String>{};
      final skus = <Map<String, String>>[];
      for (final r in records) {
        final sku = r['sku']?.toString() ?? '';
        if (sku.isNotEmpty && skuSet.add(sku)) {
          skus.add({'sku': sku, 'name': r['item_name']?.toString() ?? sku});
        }
      }
      // Always include a GENERAL option
      if (!skuSet.contains('GENERAL')) {
        skus.add({'sku': 'GENERAL', 'name': 'General / No Specific SKU'});
      }

      if (mounted) {
        setState(() {
          _zones = zones;
          _zone = zones.isNotEmpty ? zones.first : null;
          _skuOptions = skus;
          _sku = skus.isNotEmpty ? skus.first['sku'] : 'GENERAL';
          _dataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback: at least allow free-text entry with empty selects
          _zones = [];
          _skuOptions = [{'sku': 'GENERAL', 'name': 'General / No Specific SKU'}];
          _sku = 'GENERAL';
          _dataLoading = false;
          _toast = 'Could not load live zones/SKUs from backend. Please check connection.';
          _toastType = 'error';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      setState(() {
        _toast = 'Please fill in your name and incident description.';
        _toastType = 'warning';
      });
      return;
    }
    if (_zone == null) {
      setState(() {
        _toast = 'Please select a zone.';
        _toastType = 'warning';
      });
      return;
    }
    setState(() { _loading = true; _toast = ''; _toastType = ''; });
    try {
      await _api.ingestIncident(
        reporterName: _nameCtrl.text.trim(),
        reporterRole: ApiService.currentUser?['role'] ?? 'field_operator',
        locationZone: _zone!,
        sku: (_sku == null || _sku == 'GENERAL') ? null : _sku,
        message: _msgCtrl.text.trim(),
        severity: _severity,
      );
      if (mounted) {
        setState(() {
          _toast = 'Incident submitted successfully to backend.';
          _toastType = 'success';
        });
        _msgCtrl.clear();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _toast = 'Error: $e';
          _toastType = 'error';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        leading: const BackButton(),
      ),
      body: _dataLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Toast notification ──
                if (_toast.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _toastType == 'success'
                          ? AppTheme.successBg
                          : _toastType == 'warning'
                              ? AppTheme.warning.withOpacity(0.1)
                              : AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _toast,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _toastType == 'success'
                            ? AppTheme.success
                            : _toastType == 'warning'
                                ? AppTheme.warning
                                : AppTheme.error,
                      ),
                    ),
                  ),

                // ── Reporter Name (pre-filled from session) ──
                _label('REPORTER NAME'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    suffixIcon: ApiService.currentUser?['name'] != null
                        ? const Tooltip(
                            message: 'Pre-filled from your session',
                            child: Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.success))
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Zone (live from backend) ──
                _label('AFFECTED ZONE  (${_zones.length} zones from backend)'),
                const SizedBox(height: 6),
                _zones.isEmpty
                    ? TextField(
                        onChanged: (v) => _zone = v.trim(),
                        decoration: const InputDecoration(hintText: 'Enter zone manually (backend offline)'),
                      )
                    : DropdownButtonFormField<String>(
                        value: _zone,
                        decoration: const InputDecoration(),
                        items: _zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                        onChanged: (v) => setState(() => _zone = v),
                      ),
                const SizedBox(height: 16),

                // ── SKU (live from stock ledger) ──
                _label('RELATED SKU / PRODUCT  (${_skuOptions.length} SKUs from stock ledger)'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _sku,
                  decoration: const InputDecoration(),
                  items: _skuOptions.map((s) => DropdownMenuItem(
                    value: s['sku'],
                    child: Text('${s['sku']} — ${s['name']}', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() => _sku = v),
                ),
                const SizedBox(height: 16),

                // ── Description ──
                _label('INCIDENT DESCRIPTION'),
                const SizedBox(height: 6),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe what you observed on the ground…',
                  ),
                ),
                const SizedBox(height: 16),

                // ── Severity ──
                _label('SEVERITY LEVEL'),
                const SizedBox(height: 8),
                Row(
                  children: ['critical', 'high', 'low'].map((s) {
                    final color = s == 'critical'
                        ? AppTheme.criticalRed
                        : s == 'high'
                            ? AppTheme.warning
                            : AppTheme.success;
                    final sel = _severity == s;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _severity = s),
                        child: Container(
                          margin: EdgeInsets.only(right: s != 'low' ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel ? color.withOpacity(0.12) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: sel ? color : AppTheme.outlineVar, width: sel ? 1.5 : 0.5),
                          ),
                          child: Center(
                            child: Column(children: [
                              Icon(
                                s == 'critical' ? Icons.crisis_alert : s == 'high' ? Icons.warning_amber_outlined : Icons.info_outline,
                                size: 18, color: sel ? color : AppTheme.onSurfaceVar,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: sel ? color : AppTheme.onSurfaceVar,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Submit ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(_loading ? 'Submitting to Backend…' : 'Submit Field Report'),
                  ),
                ),

                // ── Session info footnote ──
                const SizedBox(height: 12),
                Text(
                  'Reporting as: ${ApiService.currentUser?['name'] ?? 'Unknown'}  '
                  '(${(ApiService.currentUser?['role'] ?? 'field_operator').toString().toUpperCase()})  '
                  '·  Org: ${ApiService.currentUser?['org_id'] ?? '—'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.onSurfaceVar),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurfaceVar, fontSize: 10),
  );
}
