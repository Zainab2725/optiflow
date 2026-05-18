import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _contradictions = [];
  Map<String, dynamic> _summary = {};

  final _depotCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _selectedSku = 'MED-001';
  String _selectedZone = 'Korangi';
  
  final Map<String, String> _skuNames = {
    'MED-001': 'Panadol 500mg (Paracetamol)',
    'MED-006': 'ORS Hydration Sachets',
    'MED-035': 'Lactated Ringers 500ml',
    'MED-007': 'Amoxicillin 250mg Suspension',
    'MED-090': 'Emergency First Aid Packs',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _depotCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stockRes = await _api.getStock();
      final contraRes = await _api.getContradictions();
      setState(() {
        _records = List<Map<String, dynamic>>.from(stockRes['records'] ?? []);
        _summary = Map<String, dynamic>.from(stockRes['summary'] ?? {});
        _contradictions = List<Map<String, dynamic>>.from(contraRes['contradictions'] ?? []);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _updateStock(bool isDispatch) async {
    final depot = _depotCtrl.text.trim();
    final qtyText = _qtyCtrl.text.trim();
    if (depot.isEmpty || qtyText.isEmpty) return;

    final int quantity = int.tryParse(qtyText) ?? 0;
    
    // Find current stock
    final currentItem = _records.firstWhere(
      (r) => r['sku'] == _selectedSku && r['zone'] == _selectedZone,
      orElse: () => {},
    );
    final int beforeQty = currentItem.isNotEmpty ? (currentItem['quantity'] as int) : 500;
    final int finalQty = isDispatch ? (beforeQty - quantity).clamp(0, 999999) : (beforeQty + quantity);

    setState(() => _loading = true);
    
    try {
      // Ingest the stock update to the backend secure pipeline
      await _api.ingestStock(
        depotId: 'depot-${_selectedZone.toLowerCase()}',
        depotName: depot,
        zone: _selectedZone,
        sku: _selectedSku,
        itemName: _skuNames[_selectedSku] ?? 'Medical Item',
        quantity: finalQty,
        minThreshold: 500,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Inventory Sync: $_selectedSku adjusted from $beforeQty to $finalQty.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.criticalRed),
        );
      }
    }

    _depotCtrl.clear();
    _qtyCtrl.clear();
    Navigator.of(context).pop();
    _loadData();
  }

  void _showUpdateDialog(bool isDispatch) {
    _depotCtrl.text = _selectedZone == 'Korangi' ? 'Korangi Warehouse' : 'Saddar Warehouse';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              Icon(
                isDispatch ? Icons.unarchive_outlined : Icons.archive_outlined,
                color: isDispatch ? AppTheme.criticalRed : AppTheme.success,
              ),
              const SizedBox(width: 8),
              Text(
                isDispatch ? 'Record Dispatch' : 'Receive Inventory',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('SELECT ZONE / SECTOR'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedZone,
                    isExpanded: true,
                    items: ApiService.activeZones.map((z) => DropdownMenuItem(
                      value: z, child: Text(z),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() {
                          _selectedZone = val;
                          _depotCtrl.text = '$val Depot';
                        });
                        setState(() => _selectedZone = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              _label('WAREHOUSE DEPOT NAME'),
              const SizedBox(height: 6),
              TextField(
                controller: _depotCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Saddar Main Warehouse'),
              ),
              const SizedBox(height: 12),
              
              _label('SELECT MEDICAL SKU'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSku,
                    isExpanded: true,
                    items: _skuNames.keys.map((k) => DropdownMenuItem(
                      value: k, child: Text(_skuNames[k]!),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => _selectedSku = val);
                        setState(() => _selectedSku = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              _label(isDispatch ? 'DISPATCH QUANTITY (UNITS)' : 'RECEIVE QUANTITY (UNITS)'),
              const SizedBox(height: 6),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 380'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _updateStock(isDispatch),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDispatch ? AppTheme.criticalRed : AppTheme.success,
              ),
              child: Text(isDispatch ? 'Confirm Dispatch' : 'Sync Ingest'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = (_summary['critical_count'] ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Inventory Command'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StockScreen()), // Re-sync view
              );
            },
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── AI ANOMALY ALERT BANNER ──
                if (_contradictions.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.criticalRedBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.criticalRed.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.criticalRed, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'AI RISK: COHERENCE ANOMALY DETECTED',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppTheme.criticalRed,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._contradictions.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            '⚠️ [${c['sku']}] at ${c['depot']} (${c['zone']}): ${c['explanation']}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.criticalRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── LEDGER STATS CARDS ──
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'LEDGER RECORDS',
                        '${_records.length} SKUs',
                        Icons.library_books_outlined,
                        AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'CRITICAL SHORTAGES',
                        '${_summary['critical_count'] ?? 0} ITEMS',
                        Icons.gpp_maybe_outlined,
                        isCritical ? AppTheme.criticalRed : AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── QUICK ACTIONS ──
                Text(
                  'LEDGER OPERATIONS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurfaceVar, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateDialog(false),
                        icon: const Icon(Icons.archive_outlined, size: 16, color: AppTheme.success),
                        label: const Text('Receive Supply', style: TextStyle(color: AppTheme.success)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateDialog(true),
                        icon: const Icon(Icons.unarchive_outlined, size: 16, color: AppTheme.criticalRed),
                        label: const Text('Record Dispatch', style: TextStyle(color: AppTheme.criticalRed)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.criticalRed),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── INVENTORY LEDGER LIST ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SECURE DEPOT LEDGER',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurfaceVar, fontSize: 10),
                    ),
                    Text(
                      'TENANT STATUS: ISOLATED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                  ),
                  child: _records.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No active inventory records in this workspace.')),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = _records[idx];
                          final qty = item['quantity'] ?? 0;
                          final threshold = item['min_threshold'] ?? 500;
                          final isBelow = qty < threshold;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isBelow ? AppTheme.criticalRed : AppTheme.success).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                isBelow ? Icons.trending_down : Icons.check_circle_outline,
                                color: isBelow ? AppTheme.criticalRed : AppTheme.success,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['item_name'] ?? 'Pharma Item',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '📍 Depot: ${item['depot_name']} (${item['zone']})  |  SKU: ${item['sku']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$qty Units',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isBelow ? AppTheme.criticalRed : AppTheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isBelow ? AppTheme.criticalRed : AppTheme.success).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    isBelow ? 'CRITICAL' : 'OPTIMAL',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isBelow ? AppTheme.criticalRed : AppTheme.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.onSurfaceVar,
        fontSize: 9,
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
