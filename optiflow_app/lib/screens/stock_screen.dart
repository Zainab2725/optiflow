import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/agent_state_provider.dart';
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

  List<Map<String, dynamic>> _criticalInventoryAlertsFromResult(Map<String, dynamic>? latestResult) {
    if (latestResult == null) return [];

    dynamic raw = latestResult['insights']?['stock_shortages']
        ?? latestResult['decision']?['stock_shortages']
        ?? latestResult['decision']?['low_stock_items']
        ?? latestResult['critical_stock_alerts']
        ?? latestResult['alerts'];

    if (raw is Map) raw = [raw];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> _availableSourceInventoryFromResult(Map<String, dynamic>? latestResult) {
    if (latestResult != null) {
      dynamic raw = latestResult['simulation']?['source_inventory']
          ?? latestResult['decision']?['available_sources']
          ?? latestResult['source_warehouses'];
      if (raw is Map) raw = [raw];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    final sources = <String, Map<String, dynamic>>{};
    for (final record in _records) {
      final qty = (record['quantity'] as num?)?.toInt() ?? 0;
      final thresh = (record['min_threshold'] as num?)?.toInt() ?? 0;
      if (qty >= thresh && record['zone'] != null) {
        final key = '${record['zone']}_${record['sku']}';
        sources.putIfAbsent(key, () => {
          'warehouse': record['zone'],
          'depot_name': record['depot_name'] ?? '${record['zone']} Depot',
          'sku': record['sku'],
          'quantity': qty,
        });
      }
    }
    return sources.values.toList();
  }

  List<Map<String, dynamic>> _redistributionActionsFromResult(Map<String, dynamic>? latestResult) {
    if (latestResult == null) return [];

    final actions = <Map<String, dynamic>>[];
    final action = latestResult['decision']?['selected_action'];
    if (action is Map && action.isNotEmpty) {
      actions.add(Map<String, dynamic>.from(action));
    }

    dynamic alt = latestResult['decision']?['recommendations']
        ?? latestResult['actions']
        ?? latestResult['redistribution_actions'];

    if (alt is Map) alt = [alt];
    if (alt is List) {
      for (final item in alt.whereType<Map>()) {
        actions.add(Map<String, dynamic>.from(item));
      }
    }

    return actions;
  }

  Map<String, dynamic> _simulationFromResult(Map<String, dynamic>? latestResult) {
    return Map<String, dynamic>.from(latestResult?['simulation'] ?? {});
  }

  List<String> get _availableZones {
    final list = _records.map((r) => r['zone']?.toString() ?? '').where((z) => z.isNotEmpty).toSet().toList();
    list.sort();
    return list;
  }

  List<Map<String, String>> get _availableSkus {
    return _records
        .map((r) => {
              'sku': r['sku']?.toString() ?? '',
              'name': r['item_name']?.toString() ?? r['sku']?.toString() ?? ''
            })
        .where((s) => s['sku']!.isNotEmpty)
        .fold<List<Map<String, String>>>([], (acc, s) {
          if (!acc.any((a) => a['sku'] == s['sku'])) acc.add(s);
          return acc;
        });
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
      Map<String, dynamic> stockRes;
      if (ApiService.cachedStock != null) {
        stockRes = ApiService.cachedStock!;
        ApiService.cachedStock = null; // Clear after use
      } else {
        stockRes = await _api.getStock();
      }

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
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;
    final criticalCount = _summary['critical_count'] ?? 0;
    final isCritical = criticalCount > 0;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Inventory'),
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
                  child: _buildBody(criticalCount, isCritical, latestResult),
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
            Text('Could not connect to server', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVar), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(int criticalCount, bool isCritical, Map<String, dynamic>? latestResult) {
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

                        final estHours = qty > 0 ? (qty / 10).ceil() : 0;
                        final estTime = estHours > 0 ? 'Est. ${estHours}h' : 'Depleted';
                        final riskLabel = isCritical ? 'Critical Stock' : 'Running Low';

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

        if (latestResult != null) ...[
          _buildCriticalInventoryAlertsSection(latestResult, criticalAlerts),
          const SizedBox(height: 16),
          _buildAvailableSourceInventorySection(latestResult),
          const SizedBox(height: 16),
          _buildAiRedistributionRecommendationsSection(latestResult),
          const SizedBox(height: 16),
          _buildTransferSimulationPanel(latestResult),
          const SizedBox(height: 24),
        ],

        // ── Unified Asset Performance ──
        Text(
          'Low Stock Action Board',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: merged.where((a) {
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
              if (qty < thresh * 0.5) {
                statusLabel = 'Critical';
                statusColor = AppTheme.criticalRed;
                statusBg = AppTheme.criticalRedBg;
              } else if (qty < thresh) {
                statusLabel = 'Warning';
                statusColor = AppTheme.warning;
                statusBg = AppTheme.warningBg;
              }
              
              final estHours = qty > 0 ? (qty / 10).ceil() : 0;
              final estDays = (estHours / 24).floor();
              String estDepletion = estDays >= 14 ? '14+ Days' : (estDays >= 1 ? '$estDays Days' : '< 1 Day');

              final double pct = thresh > 0 ? (qty / (thresh * 2) * 100).clamp(0.0, 100.0) : 0.0;
              final String stockLevelStr = '${pct.toInt()}%';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.outlineVar, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon + Sector
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(getSectorIcon(sector), size: 24, color: const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 16),
                    // Item Name & SKU
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['item_name'] ?? a['sku'] ?? 'Unknown Item',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${a['sku'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withOpacity(0.3), width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                              ),
                              const SizedBox(width: 6),
                              Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Stats
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level: $stockLevelStr',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Est. Depletion: $estDepletion',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    // Action Button
                    ElevatedButton.icon(
                      onPressed: () {
                        _selectedSku = a['sku'];
                        _selectedZone = a['zone'] ?? _availableZones.first;
                        _qtyCtrl.text = '';
                        _depotCtrl.text = a['depot_name'] ?? '${_selectedZone} Depot';
                        _showUpdateDialog(qty < thresh);
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        qty < thresh ? 'Restock' : 'View',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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

                  final estHours = qty > 0 ? (qty / 10).ceil() : 0;
                  final estDays = (estHours / 24).floor();
                  String estDepletion = estDays >= 14 ? '14+ Days' : (estDays >= 1 ? '$estDays Days' : '< 1 Day');

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

  Widget _buildCriticalInventoryAlertsSection(Map<String, dynamic> latestResult, List<Map<String, dynamic>> fallbackAlerts) {
    final alerts = _criticalInventoryAlertsFromResult(latestResult);
    final displayAlerts = alerts.isNotEmpty ? alerts : fallbackAlerts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.criticalRed, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Critical Inventory Alerts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.criticalRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayAlerts.isEmpty)
            const Text(
              'No active shortage alerts found in the AI redistribution feed.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...displayAlerts.take(5).map((alert) {
              final item = alert['item_name'] ?? alert['sku'] ?? alert['item'] ?? 'Inventory Item';
              final location = alert['zone'] ?? alert['warehouse'] ?? alert['location'] ?? 'Unknown location';
              final severity = alert['severity']?.toString().toLowerCase() ?? '';
              final quantity = alert['quantity']?.toString() ?? alert['current_quantity']?.toString() ?? '—';
              final threshold = alert['min_threshold']?.toString() ?? alert['threshold']?.toString() ?? '—';
              final badgeColor = severity.contains('critical') ? AppTheme.criticalRed : severity.contains('low') ? AppTheme.warning : AppTheme.primary;
              final badgeLabel = severity.isNotEmpty ? severity.toUpperCase() : (double.tryParse(quantity) != null && double.tryParse(threshold) != null && (double.parse(quantity) < double.parse(threshold) * 0.5) ? 'CRITICAL' : 'WARNING');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$item critically low at $location',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current: $quantity | Safety: $threshold',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withOpacity(0.32)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAvailableSourceInventorySection(Map<String, dynamic> latestResult) {
    final sources = _availableSourceInventoryFromResult(latestResult);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.storefront_outlined, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Available Source Inventory',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            const Text(
              'AI has not identified any source warehouses with surplus stock yet.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            )
          else
            ...sources.take(5).map((source) {
              final warehouse = source['warehouse'] ?? source['depot_name'] ?? 'Source Warehouse';
              final sku = source['sku'] ?? 'SKU';
              final quantity = source['quantity']?.toString() ?? '—';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$warehouse → $sku',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      '$quantity units',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAiRedistributionRecommendationsSection(Map<String, dynamic> latestResult) {
    final actions = _redistributionActionsFromResult(latestResult);
    final decision = latestResult['decision'] as Map<String, dynamic>? ?? {};
    final reason = decision['primary_insight']?.toString() ?? decision['summary']?.toString() ?? 'AI has identified redistribution needs based on current stock imbalances.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FEE7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome_mosaic_outlined, color: Color(0xFF15803D), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Redistribution Recommendations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
          ),
          const SizedBox(height: 14),
          if (actions.isEmpty)
            const Text(
              'No explicit transfer recommendation is available yet. The AI is still analyzing warehouse balance and shortage risk.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            )
          else
            ...actions.take(3).map((action) {
              final type = action['type']?.toString().toUpperCase() ?? 'REDISTRIBUTE';
              final from = action['from'] ?? action['source'] ?? 'Unknown source';
              final to = action['to'] ?? action['destination'] ?? 'Unknown destination';
              final sku = action['sku'] ?? action['item_name'] ?? 'SKU';
              final quantity = action['quantity']?.toString() ?? action['units']?.toString() ?? '—';
              final reasonDetail = action['reason'] ?? action['explanation'] ?? 'Critical shortage detected';

              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$type: $quantity units of $sku',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF134E4A)),
                    ),
                    const SizedBox(height: 6),
                    Text('FROM: $from', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 2),
                    Text('TO: $to', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    Text('Reason: $reasonDetail', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTransferSimulationPanel(Map<String, dynamic> latestResult) {
    final simulation = _simulationFromResult(latestResult);
    final before = Map<String, dynamic>.from(simulation['before_state'] ?? {});
    final after = Map<String, dynamic>.from(simulation['after_state'] ?? {});

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.compare_arrows_outlined, color: Color(0xFF1D4ED8), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transfer Simulation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSimulationStateCard('BEFORE', before, const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(child: _buildSimulationStateCard('AFTER', after, const Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationStateCard(String label, Map<String, dynamic> state, Color color) {
    final route = state['route']?.toString() ?? 'Pending AI route analysis';
    final status = state['status']?.toString() ?? 'Pending status update';
    final stockProfile = state['stock_profile']?.toString() ?? state['stock_level']?.toString() ?? 'Awaiting stock profile';
    final impact = state['impact']?.toString() ?? state['risk_mitigation']?.toString() ?? 'Awaiting impact summary';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(label == 'BEFORE' ? Icons.report_problem : Icons.check_circle_outline, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStateItemCard('ROUTE', route, color),
          const SizedBox(height: 8),
          _buildStateItemCard('STATUS', status, color),
          const SizedBox(height: 8),
          _buildStateItemCard('STOCK PROFILE', stockProfile, color),
          const SizedBox(height: 8),
          _buildStateItemCard('IMPACT', impact, color),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF475569),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildStateItemCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
          ),
        ],
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
