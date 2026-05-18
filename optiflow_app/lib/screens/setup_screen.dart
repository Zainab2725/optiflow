import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Config state
  final List<String> _selectedZones = ["Saddar", "Clifton", "Korangi", "SITE", "Lyari"];
  final List<String> _availableZones = [
    "Saddar", "Clifton", "SITE", "Korangi", 
    "Malir", "Faisal", "Gulshan", "PECHS",
    "North Nazimabad", "Orangi", "Lyari", "Defence"
  ];

  final List<String> _warehouses = ["Korangi Warehouse", "Saddar Warehouse", "Clifton Depot"];
  final _warehouseCtrl = TextEditingController();

  final List<String> _fleetUnits = ["RESCUE-01", "RELIEF-TRUCK-04", "MED-VAN-09"];
  final _fleetCtrl = TextEditingController();

  final List<String> _categories = ["Emergency Meds", "Clean Water", "Food Kits"];
  final _categoryCtrl = TextEditingController();

  final List<String> _roles = ["Admin", "Manager", "Driver", "Field Operator"];

  int _currentStep = 0;
  bool _saving = false;

  void _saveSetup() async {
    setState(() => _saving = true);

    // Save to static API state
    ApiService.activeZones = _selectedZones;
    ApiService.activeWarehouses = _warehouses;
    ApiService.activeFleetUnits = _fleetUnits;
    ApiService.activeCategories = _categories;
    ApiService.activeStaffRoles = _roles;

    // Save to Firestore if available
    try {
      final orgId = ApiService.currentUser?['org_id'] ?? 'org-demo';
      await FirebaseFirestore.instance.collection('organizations').doc(orgId).update({
        'configured': true,
        'config': {
          'zones': _selectedZones,
          'warehouses': _warehouses,
          'fleet': _fleetUnits,
          'categories': _categories,
          'roles': _roles,
        }
      });
    } catch (_) {
      // Continue if Firebase connection offline
    }

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operational workspace configured successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgName = ApiService.organization?['name'] ?? 'Your Organization';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Operational Command Setup'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _saving 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 20),
                Text('Configuring secure workspaces, please wait...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          )
        : Column(
            children: [
              // Top descriptive header
              Container(
                width: double.infinity,
                color: AppTheme.primary.withOpacity(0.05),
                padding: const EdgeInsets.all(16),
                border: const Border(bottom: BorderSide(color: AppTheme.outlineVar, width: 0.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orgName.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure your supply depots, sectors, and active assets below to establish tactical logistics routing in Karachi.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Step indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isCurrent = index == _currentStep;
                    final isPassed = index < _currentStep;
                    return Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent 
                              ? AppTheme.primary 
                              : (isPassed ? AppTheme.success : AppTheme.surfaceContainer),
                            border: Border.all(
                              color: isCurrent ? AppTheme.primary : AppTheme.outlineVar,
                            ),
                          ),
                          child: Center(
                            child: isPassed 
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? Colors.white : AppTheme.onSurfaceVar,
                                  ),
                                ),
                          ),
                        ),
                        if (index < 3)
                          Container(
                            width: 40, height: 2,
                            color: isPassed ? AppTheme.success : AppTheme.outlineVar,
                          ),
                      ],
                    );
                  }),
                ),
              ),

              // Content step area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStepContent(),
                ),
              ),

              // Bottom control buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.outlineVar, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox(),
                    
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          _saveSetup();
                        }
                      },
                      label: Text(_currentStep < 3 ? 'Continue' : 'Finalize & Boot'),
                      icon: Icon(_currentStep < 3 ? Icons.arrow_forward : Icons.power_settings_new),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _stepZones();
      case 1:
        return _stepWarehouses();
      case 2:
        return _stepFleet();
      case 3:
        return _stepCatalog();
      default:
        return const SizedBox();
    }
  }

  // Step 1: Zones of Operation
  Widget _stepZones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('1. Operating Corridors', 'Select the Karachi zones where your organization operates distribution pipelines.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _availableZones.map((zone) {
            final isSel = _selectedZones.contains(zone);
            return FilterChip(
              label: Text(zone),
              selected: isSel,
              selectedColor: AppTheme.primary.withOpacity(0.15),
              checkmarkColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.outlineVar),
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedZones.add(zone);
                  } else {
                    _selectedZones.remove(zone);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // Step 2: Warehouses
  Widget _stepWarehouses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('2. Logistics Depot Network', 'Define your warehouses, depots, or field camps where inventory is stored.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _warehouseCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Clifton Distribution Hub',
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                final txt = _warehouseCtrl.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    _warehouses.add(txt);
                    _warehouseCtrl.clear();
                  });
                }
              },
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(backgroundColor: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _warehouses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) => _listItem(
            _warehouses[idx],
            () => setState(() => _warehouses.removeAt(idx)),
          ),
        ),
      ],
    );
  }

  // Step 3: Fleet
  Widget _stepFleet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('3. Fleet Units & Convoys', 'Register your vehicles, delivery convoys, or field response vans.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fleetCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. AMB-VAN-12',
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                final txt = _fleetCtrl.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    _fleetUnits.add(txt);
                    _fleetCtrl.clear();
                  });
                }
              },
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(backgroundColor: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fleetUnits.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) => _listItem(
            _fleetUnits[idx],
            () => setState(() => _fleetUnits.removeAt(idx)),
          ),
        ),
      ],
    );
  }

  // Step 4: Catalog & Roles
  Widget _stepCatalog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('4. Operational Assets', 'Define your emergency stock categories to complete workspace initialization.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Tents & Blankets',
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                final txt = _categoryCtrl.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    _categories.add(txt);
                    _categoryCtrl.clear();
                  });
                }
              },
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(backgroundColor: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) => _listItem(
            _categories[idx],
            () => setState(() => _categories.removeAt(idx)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'ROLES PROVISIONED BY DEFAULT:',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 10, color: AppTheme.onSurfaceVar),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: _roles.map((r) => Chip(
            label: Text(r, style: const TextStyle(fontSize: 11)),
            backgroundColor: AppTheme.surfaceContainer,
            side: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
          )).toList(),
        ),
      ],
    );
  }

  Widget _stepHeader(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          desc,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVar),
        ),
      ],
    );
  }

  Widget _listItem(String title, VoidCallback onDelete) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.outlineVar, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline, color: AppTheme.criticalRed, size: 20),
          ),
        ],
      ),
    );
  }
}
