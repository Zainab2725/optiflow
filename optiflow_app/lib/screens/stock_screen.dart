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
  List<Map<String, dynamic>> _predictions = [];
  Map<String, dynamic> _summary = {};
  String? _error;

  // Dialog state — populated dynamically from live records
  final _depotCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String? _selectedSku;
  String? _selectedZone;
  Map<String, dynamic>? _selectedInspectorAsset;

  List<Map<String, dynamic>> _getMergedAssets() {
    return _records;
  }

  String getSector(String sku) {
    final upper = sku.toUpperCase();
    if (upper.startsWith('MED')) return 'Medical';
    if (upper.startsWith('LOG')) return 'Logistics';
    if (upper.startsWith('WTR') || upper.startsWith('WAT')) return 'Water';
    if (upper.startsWith('FOOD') || upper.startsWith('FOD')) return 'Food';
    return 'General';
  }

  IconData getSectorIcon(String sectorName) {
    if (sectorName.contains('Medical')) return Icons.local_hospital_outlined;
    if (sectorName.contains('Logistics')) return Icons.local_shipping_outlined;
    if (sectorName.contains('Water')) return Icons.water_drop_outlined;
    if (sectorName.contains('Food')) return Icons.restaurant_outlined;
    return Icons.category_outlined;
  }

  Widget _sumStat(String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildLegendCard(Color color, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.12), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color, letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.black54, height: 1.3),
          ),
        ],
      ),
    );
  }

  // Derived from live records (with standard fallbacks for newly registered tenants)
  List<String> get _availableZones {
    final list = _records.map((r) => r['zone']?.toString() ?? '').where((z) => z.isNotEmpty).toSet().toList();
    if (list.isEmpty) {
      return [
        "Saddar", "Clifton", "SITE", "Korangi", 
        "Malir", "Faisal", "Gulshan", "PECHS",
        "North Nazimabad", "Orangi", "Lyari", "Defence"
      ];
    }
    list.sort();
    return list;
  }

  List<Map<String, String>> get _availableSkus {
    final list = _records.map((r) => {'sku': r['sku']?.toString() ?? '', 'name': r['item_name']?.toString() ?? r['sku']?.toString() ?? ''})
        .where((s) => s['sku']!.isNotEmpty)
        .fold<List<Map<String, String>>>([], (acc, s) {
          if (!acc.any((a) => a['sku'] == s['sku'])) acc.add(s);
          return acc;
        });
    if (list.isEmpty) {
      return [
        {'sku': 'MED-001', 'name': 'Panadol 500mg'},
        {'sku': 'MED-002', 'name': 'Insulin Vial'},
        {'sku': 'MED-003', 'name': 'Amoxicillin'},
        {'sku': 'MED-004', 'name': 'ORS Sachets'},
        {'sku': 'MED-005', 'name': 'Vaccine Vial'},
        {'sku': 'MED-006', 'name': 'Disprin Tablet'},
        {'sku': 'MED-007', 'name': 'Saline Infusion'},
        {'sku': 'LOG-001', 'name': 'Transport Fuel'},
        {'sku': 'LOG-002', 'name': 'Cargo Pallets'},
        {'sku': 'WTR-001', 'name': 'Purified Water 19L'},
        {'sku': 'FOOD-001', 'name': 'High-Energy Biscuits'},
      ];
    }
    return list;
  }

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
    setState(() { _loading = true; _error = null; });
    try {
      // Phase 1: Load core stock ledger instantly from host
      final stockRes = await _api.getStock();
      if (mounted) {
        setState(() {
          _records = (stockRes['records'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item))
              .toList() ?? [];
          _summary = Map<String, dynamic>.from(stockRes['summary'] ?? {});
          // seed first available sku/zone from live data
          if (_selectedSku == null && _availableSkus.isNotEmpty) {
            _selectedSku = _availableSkus.first['sku'];
          }
          if (_selectedZone == null && _availableZones.isNotEmpty) {
            _selectedZone = _availableZones.first;
          }
          _loading = false; // Core UI is ready and interactive!
        });
      }

      // Phase 2: Load contradictions and AI predictive forecasts in the background
      try {
        final contraRes = await _api.getContradictions();
        if (mounted) {
          setState(() {
            _contradictions = (contraRes['contradictions'] as List?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ?? [];
          });
        }
      } catch (e) {
        debugPrint('Optional background contradictions failed: $e');
      }

      try {
        final predictRes = await _api.predictStock();
        if (mounted && predictRes.containsKey('predictions')) {
          setState(() {
            _predictions = (predictRes['predictions'] as List?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ?? [];
          });
        }
      } catch (e) {
        debugPrint('Optional background stock predictions failed: $e');
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

  Future<void> _updateStock(BuildContext dialogContext, bool isDispatch) async {
    final depot = _depotCtrl.text.trim();
    final qtyText = _qtyCtrl.text.trim();
    if (depot.isEmpty || qtyText.isEmpty) return;
    if (_selectedSku == null || _selectedZone == null) return;

    final int qty = int.tryParse(qtyText) ?? 0;
    final currentItem = _records.lastWhere(
      (r) => r['sku'] == _selectedSku && r['zone'] == _selectedZone,
      orElse: () => <String, dynamic>{},
    );
    final int before = (currentItem['quantity'] != null) ? (currentItem['quantity'] as num).toInt() : 0;
    
    if (isDispatch && qty > before) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Cannot dispatch: Only $before units are currently in stock (requested $qty).'),
          backgroundColor: AppTheme.criticalRed,
        ));
      }
      Navigator.of(dialogContext).pop();
      return;
    }

    final int finalQty = isDispatch ? (before - qty).clamp(0, 999999) : (before + qty);
    final skuName = _availableSkus.firstWhere((s) => s['sku'] == _selectedSku, orElse: () => {'name': _selectedSku!})['name']!;

    setState(() => _loading = true);
    try {
      await _api.ingestStock(
        depotId: 'depot-${_selectedZone!.toLowerCase().replaceAll(' ', '-')}',
        depotName: depot,
        zone: _selectedZone!,
        sku: _selectedSku!,
        itemName: skuName,
        quantity: finalQty,
        minThreshold: (currentItem['min_threshold'] as num?)?.toInt() ?? 500,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $_selectedSku synced: $before → $finalQty units'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.criticalRed));
      }
    }
    _depotCtrl.clear();
    _qtyCtrl.clear();
    if (mounted) Navigator.of(dialogContext).pop();
    _loadData();
  }

  void _showUpdateDialog(bool isDispatch) {
    if (_availableZones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No stock records loaded yet. Please wait for data to load.'),
      ));
      return;
    }
    _selectedZone ??= _availableZones.first;
    _selectedSku ??= _availableSkus.first['sku'];
    _depotCtrl.text = '${_selectedZone!} Depot';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(children: [
            Icon(isDispatch ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: isDispatch ? AppTheme.criticalRed : AppTheme.success),
            const SizedBox(width: 8),
            Text(isDispatch ? 'Record Dispatch' : 'Receive Inventory',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('SELECT ZONE'),
              const SizedBox(height: 6),
              _dropdown<String>(
                value: _selectedZone,
                items: _availableZones,
                labelOf: (z) => z,
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
              const SizedBox(height: 12),
              _label('DEPOT NAME'),
              const SizedBox(height: 6),
              TextField(
                controller: _depotCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Saddar Main Warehouse'),
              ),
              const SizedBox(height: 12),
              _label('SELECT SKU'),
              const SizedBox(height: 6),
              _dropdown<String>(
                value: _selectedSku,
                items: _availableSkus.map((s) => s['sku']!).toList(),
                labelOf: (sku) {
                  final found = _availableSkus.firstWhere((s) => s['sku'] == sku, orElse: () => {'name': sku});
                  return '${found['name']} ($sku)';
                },
                onChanged: (val) {
                  if (val != null) {
                    setDlgState(() => _selectedSku = val);
                    setState(() => _selectedSku = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              _label(isDispatch ? 'SEND STOCK OUT (UNITS)' : 'ADD NEW STOCK (UNITS)'),
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
              onPressed: () => _updateStock(context, isDispatch),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDispatch ? AppTheme.criticalRed : AppTheme.success,
              ),
              child: Text(isDispatch ? 'Send Stock' : 'Add Stock'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = _summary['critical_count'] ?? 0;
    final isCritical = criticalCount > 0;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Warehouse Stock'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: _buildBody(criticalCount, isCritical),
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
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(int criticalCount, bool isCritical) {
    final merged = _getMergedAssets();

    // Compute status variables for the donut chart
    final int total = merged.length;
    final int healthy = merged.where((a) {
      final qty = ((a['quantity'] ?? 0) as num).toInt();
      final thresh = ((a['min_threshold'] ?? 500) as num).toInt();
      return qty >= thresh;
    }).length;
    final int warning = merged.where((a) {
      final qty = ((a['quantity'] ?? 0) as num).toInt();
      final thresh = ((a['min_threshold'] ?? 500) as num).toInt();
      return qty < thresh && qty >= thresh * 0.5;
    }).length;
    final int critical = total - healthy - warning;

    final double redPercent = total > 0 ? critical / total : 0;
    final double yellowPercent = total > 0 ? warning / total : 0;
    final double greenPercent = total > 0 ? healthy / total : 1;

    // Filter top critical alerts
    final criticalAlerts = merged.where((a) {
      final qty = ((a['quantity'] ?? 0) as num).toInt();
      final thresh = ((a['min_threshold'] ?? 500) as num).toInt();
      return qty < thresh;
    }).toList();
    // Sort critical alerts so that lower stock level ratios are shown first
    criticalAlerts.sort((a, b) {
      final double qtyA = ((a['quantity'] ?? 0) as num).toDouble();
      final double threshA = ((a['min_threshold'] ?? 500) as num).toDouble();
      final double aRatio = threshA > 0 ? (qtyA / threshA) : 0.0;

      final double qtyB = ((b['quantity'] ?? 0) as num).toDouble();
      final double threshB = ((b['min_threshold'] ?? 500) as num).toDouble();
      final double bRatio = threshB > 0 ? (qtyB / threshB) : 0.0;

      return aRatio.compareTo(bRatio);
    });

    // Group assets by sector for spatial mapping
    final Map<String, List<Map<String, dynamic>>> sectorGroups = {
      'Medical': [],
      'Logistics': [],
      'Water': [],
      'Food': [],
    };
    for (final a in merged) {
      final sector = getSector(a['sku'] ?? '');
      if (sectorGroups.containsKey(sector)) {
        sectorGroups[sector]!.add(a);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Overview & Alerts Title ──
        Row(
          children: [
            const Icon(Icons.notifications_none_outlined, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Stock Overview',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Overview & Alerts Cards Row ──
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 12) / 2;
            final bool useHorizontal = constraints.maxWidth > 550;

            final children = [
              // Executive Summary Card
              Container(
                width: useHorizontal ? cardWidth : double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // Light grey matching GRA Executive summary card
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock Health Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'All Sectors Monitored',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Stats labels
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sumStat('$total', 'Total Items'),
                              const SizedBox(height: 8),
                              _sumStat('$healthy', 'Sufficient Items'),
                              const SizedBox(height: 8),
                              _sumStat('$critical', 'Needs Restock'),
                            ],
                          ),
                        ),
                        // Donut Chart
                        Container(
                          width: 80,
                          height: 80,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: const Size(80, 80),
                                painter: DonutChartPainter(
                                  redPercent: redPercent,
                                  yellowPercent: yellowPercent,
                                  greenPercent: greenPercent,
                                ),
                              ),
                              const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Stock', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
                                    Text('Status', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Item Health Breakdown',
                        style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              // Critical Alerts Card
              Container(
                width: useHorizontal ? cardWidth : double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), // Light red matching GRA Critical Alerts card
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOW STOCK ALERTS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.criticalRed),
                    ),
                    const SizedBox(height: 12),
                    if (criticalAlerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'All stock levels are sufficient.',
                            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else
                      ...criticalAlerts.take(4).map((a) {
                        final qty = ((a['quantity'] ?? 0) as num).toInt();
                        final thresh = ((a['min_threshold'] ?? 500) as num).toInt();
                        final ratio = thresh > 0 ? (qty / thresh).clamp(0.0, 1.0) : 0.0;
                        final isCritical = qty < thresh * 0.5;

                        // Est. Time to Depletion: e.g. < 8h or < 36h
                        final estTime = isCritical ? 'Est. 8h' : 'Est. 36h';
                        final riskLabel = isCritical ? 'Very Low Stock' : 'Running Low';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${a['sku']}: $riskLabel ($estTime)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        backgroundColor: Colors.black12,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isCritical ? AppTheme.criticalRed : AppTheme.warning,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 26,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _selectedSku = a['sku'];
                                    _selectedZone = a['zone'] ?? _availableZones.first;
                                    _qtyCtrl.text = '';
                                    _depotCtrl.text = a['depot_name'] ?? '${_selectedZone} Depot';
                                    _showUpdateDialog(false); // Open receive dialog
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Colors.black26),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text('RESTOCK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ];

            if (useHorizontal) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  children[0],
                  const SizedBox(width: 12),
                  children[1],
                ],
              );
            } else {
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: 12),
                  children[1],
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // ── Unified Asset Performance ──
        Text(
          'Low Stock Action Board',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.outlineVar, width: 0.5),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
              dataRowHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text('Stock Level', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text('Days Left', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11))),
              ],
              rows: merged.where((a) {
                final qty = (a['quantity'] as num?)?.toInt() ?? 0;
                final thresh = (a['min_threshold'] as num?)?.toInt() ?? 500;
                return qty < thresh; // Only show Warning and Critical products!
              }).map((a) {
                final sector = getSector(a['sku'] ?? '');
                final qty = ((a['quantity'] ?? 0) as num).toInt();
                final thresh = ((a['min_threshold'] ?? 500) as num).toInt();

                // Status calculation
                String statusLabel = 'Nominal';
                Color statusColor = AppTheme.success;
                Color statusBg = AppTheme.success.withOpacity(0.12);
                String estDepletion = '14 Days';

                if (qty < thresh * 0.5) {
                  statusLabel = 'Critical';
                  statusColor = AppTheme.criticalRed;
                  statusBg = AppTheme.criticalRedBg;
                  estDepletion = '< 1 Day';
                } else if (qty < thresh) {
                  statusLabel = 'Warning';
                  statusColor = AppTheme.warning;
                  statusBg = AppTheme.warningBg;
                  estDepletion = '3 Days';
                }

                final double pct = thresh > 0 ? (qty / (thresh * 2) * 100).clamp(0.0, 100.0) : 0.0;
                final String stockLevelStr = '${pct.toInt()}%';

                return DataRow(
                  cells: [
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(getSectorIcon(sector), size: 14, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Text(sector, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    )),
                    DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          a['item_name'] ?? a['sku'] ?? 'Unknown Item',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                        ),
                        Text(
                          a['sku'] ?? '',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                          ),
                          const SizedBox(width: 6),
                          Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ],
                      ),
                    )),
                    DataCell(Text(stockLevelStr, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(estDepletion, style: const TextStyle(fontSize: 12))),
                    DataCell(
                      InkWell(
                        onTap: () {
                          _selectedSku = a['sku'];
                          _selectedZone = a['zone'] ?? _availableZones.first;
                          _qtyCtrl.text = '';
                          _depotCtrl.text = a['depot_name'] ?? '${_selectedZone} Depot';
                          _showUpdateDialog(qty < thresh); // open dispatch dialog if normal, replenishment if warning/critical
                        },
                        child: Text(
                          qty < thresh ? '[Restock]' : '[View]',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Stock Health Distribution ──
        Text(
          'Stock Level Breakdown',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.outlineVar, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stacked Bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 24,
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  child: Row(
                    children: [
                      if (critical > 0)
                        Expanded(
                          flex: (redPercent * 100).round().clamp(1, 100),
                          child: Container(
                            color: AppTheme.criticalRed,
                            alignment: Alignment.center,
                            child: Text(
                              '$critical',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (warning > 0)
                        Expanded(
                          flex: (yellowPercent * 100).round().clamp(1, 100),
                          child: Container(
                            color: AppTheme.warning,
                            alignment: Alignment.center,
                            child: Text(
                              '$warning',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (healthy > 0)
                        Expanded(
                          flex: (greenPercent * 100).round().clamp(1, 100),
                          child: Container(
                            color: AppTheme.success,
                            alignment: Alignment.center,
                            child: Text(
                              '$healthy',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // ── Status Legend & Meanings ──
              const Text(
                'WHAT DO THESE COLORS MEAN?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              
              // Responsive legend layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final useHorizontal = constraints.maxWidth > 550;
                  final double childWidth = useHorizontal ? (constraints.maxWidth - 12) / 2 : double.infinity;
                  
                  final legendItems = [
                    _buildLegendCard(AppTheme.criticalRed, '🔴 CRITICAL STOCK', 'Item quantity is extremely low, falling below 50% of the safety threshold. Urgent replenishment is required.'),
                    _buildLegendCard(AppTheme.warning, '🟡 WARNING STOCK', 'Item quantity has dropped below the minimum safety threshold (50% to 99%). Monitor closely.'),
                    _buildLegendCard(AppTheme.success, '🟢 HEALTHY STOCK', 'Item stock is sufficient and operational, meeting or exceeding 100% of the minimum safety threshold.'),
                  ];
                  
                  if (useHorizontal) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: legendItems.map((item) => SizedBox(width: childWidth, child: item)).toList(),
                    );
                  } else {
                    return Column(
                      children: legendItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: item,
                      )).toList(),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // ── Asset Inspector Card (hover-like popup) ──
        if (_selectedInspectorAsset != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black87, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${getSector(_selectedInspectorAsset!['sku'] ?? '')} & Transport: ${_selectedInspectorAsset!['sku']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _selectedInspectorAsset = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                () {
                  final a = _selectedInspectorAsset!;
                  final qty = ((a['quantity'] ?? 0) as num).toInt();
                  final thresh = ((a['min_threshold'] ?? 500) as num).toInt();

                  String estDepletion = '14 Days';
                  if (qty < thresh * 0.5) {
                    estDepletion = '8h';
                  } else if (qty < thresh) {
                    estDepletion = '36h';
                  }

                  final double pct = thresh > 0 ? (qty / (thresh * 2) * 100).clamp(0.0, 100.0) : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Est. Depletion: $estDepletion', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text('Stock: ${pct.toInt()}% ($qty / $thresh min threshold)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _selectedSku = a['sku'];
                              _selectedZone = a['zone'] ?? _availableZones.first;
                              _qtyCtrl.text = '';
                              _depotCtrl.text = a['depot_name'] ?? '${_selectedZone} Depot';
                              _showUpdateDialog(false);
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Ingest'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              _selectedSku = a['sku'];
                              _selectedZone = a['zone'] ?? _availableZones.first;
                              _qtyCtrl.text = '';
                              _depotCtrl.text = a['depot_name'] ?? '${_selectedZone} Depot';
                              _showUpdateDialog(true);
                            },
                            icon: const Icon(Icons.remove, size: 14),
                            label: const Text('Dispatch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.criticalRed,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
        color: AppTheme.onSurfaceVar,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelOf(item),
                style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double redPercent;
  final double yellowPercent;
  final double greenPercent;

  DonutChartPainter({
    required this.redPercent,
    required this.yellowPercent,
    required this.greenPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.25;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -3.14159 / 2; // Start from top

    // Red arc (alerts/critical)
    if (redPercent > 0) {
      paint.color = AppTheme.criticalRed;
      final sweepAngle = 2 * 3.14159 * redPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Yellow arc (warning)
    if (yellowPercent > 0) {
      paint.color = AppTheme.warning;
      final sweepAngle = 2 * 3.14159 * yellowPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Green arc (healthy)
    if (greenPercent > 0) {
      paint.color = AppTheme.success;
      final sweepAngle = 2 * 3.14159 * greenPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
