import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class ApiService {
  // Use 127.0.0.1 for local execution, or standard loopback.
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Static Session state
  static String? token;
  static Map<String, dynamic>? currentUser;
  static Map<String, dynamic>? organization;

  // Active setup configuration
  static List<String> activeZones = ["Saddar", "Clifton", "Korangi", "SITE"];
  static List<String> activeWarehouses = ["Korangi Depot", "Saddar Depot"];
  static List<String> activeFleetUnits = ["RESCUE-01", "RELIEF-TRUCK-04"];
  static List<String> activeCategories = ["Emergency Meds", "Clean Water", "Food Kits"];
  static List<String> activeStaffRoles = ["Admin", "Manager", "Driver"];

  // Helper to generate authorized headers
  Map<String, String> _headers() {
    final Map<String, String> h = {'Content-Type': 'application/json'};
    if (token != null) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ── AUTHENTICATION FLOWS ──

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        token = data['access_token'];
        currentUser = data['user'];
        // If login succeeded, also fetch dashboard data to sync org details
        try {
          final dash = await getDashboardData();
          organization = {
            'org_id': dash['org_id'] ?? currentUser?['org_id'],
            'name': currentUser?['org_name'] ?? 'Command Workspace',
          };
        } catch (_) {}
        return data;
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Login failed');
      }
    } catch (e) {
      // Offline fallback for demo & testing if server is offline
      if (email.contains('@optiflow.pk') && password == 'optiflow123') {
        token = 'mock-jwt-token-xyz';
        currentUser = {
          'user_id': email.contains('admin') ? 'usr-001' : 'usr-002',
          'name': email.contains('admin') ? 'Zainab Ali' : 'Kamran Siddiqui',
          'role': email.contains('admin') ? 'admin' : 'manager',
          'org_id': 'org-demo',
          'org_name': 'Karachi Crisis Response NGO',
        };
        organization = {
          'org_id': 'org-demo',
          'name': 'Karachi Crisis Response NGO',
        };
        return {'access_token': token, 'user': currentUser};
      }
      throw Exception('Authentication gateway timeout. Please check if backend is running.');
    }
  }

  Future<Map<String, dynamic>> signupOrg({
    required String orgName,
    required String orgType,
    required String adminName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/signup-org'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'organization_name': orgName,
          'organization_type': orgType,
          'admin_name': adminName,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = json.decode(res.body);
        token = data['token'] ?? data['access_token'];
        currentUser = data['user'];
        organization = data['organization'];
        return data;
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Signup failed');
      }
    } catch (e) {
      // Mock signup for fallback
      token = 'mock-jwt-token-new';
      currentUser = {
        'user_id': 'usr-new-admin',
        'name': adminName,
        'role': 'admin',
        'org_id': 'org-new-id',
        'org_name': orgName,
      };
      organization = {
        'org_id': 'org-new-id',
        'name': orgName,
        'type': orgType,
      };
      return {'token': token, 'user': currentUser, 'organization': organization};
    }
  }

  Future<Map<String, dynamic>> inviteUser({
    required String name,
    required String email,
    required String role,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/users/invite'),
        headers: _headers(),
        body: json.encode({'name': name, 'email': email, 'role': role}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 201) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Invitation failed');
      }
    } catch (e) {
      return {
        'status': 'invited',
        'default_password': 'welcome123',
        'message': '$name invited successfully (Offline Simulation Mode)'
      };
    }
  }

  // ── STOCK OPERATIONS ──

  Future<Map<String, dynamic>> getStock() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/stock'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'records': [
          {'depot_name': 'Korangi Depot', 'zone': 'Korangi', 'sku': 'MED-001', 'item_name': 'Panadol 500mg', 'quantity': 12000, 'min_threshold': 500},
          {'depot_name': 'Saddar Depot', 'zone': 'Saddar', 'sku': 'MED-006', 'item_name': 'ORS Sachets', 'quantity': 320, 'min_threshold': 500},
        ],
        'summary': {
          'total_records': 2,
          'critical_count': 1,
          'normal_count': 1,
          'critical_skus': ['MED-006']
        }
      };
    }
  }

  Future<Map<String, dynamic>> ingestStock({
    required String depotId,
    required String depotName,
    required String zone,
    required String sku,
    required String itemName,
    required int quantity,
    int minThreshold = 500,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/ingest/stock'),
        headers: _headers(),
        body: json.encode({
          'depot_id': depotId,
          'depot_name': depotName,
          'zone': zone,
          'sku': sku,
          'item_name': itemName,
          'quantity': quantity,
          'min_threshold': minThreshold
        }),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      final breached = quantity < minThreshold;
      return {
        'status': 'ingested',
        'record_id': 'mock-rec-123',
        'rules_evaluated': {
          'stock_threshold_breached': breached,
          'current_level': quantity,
          'min_limit': minThreshold,
          'status': breached ? 'CRITICAL' : 'NORMAL'
        }
      };
    }
  }

  // ── INCIDENT OPERATIONS ──

  Future<Map<String, dynamic>> getIncidents({String? zone}) async {
    try {
      String url = '$baseUrl/api/v1/incidents';
      if (zone != null) {
        url += '?zone=$zone';
      }
      final res = await http.get(
        Uri.parse(url),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'incidents': [
          {'reporter_name': 'Dr. Farhan', 'location_zone': 'Lyari', 'sku': 'MED-006', 'message': 'Medicine shortage in Lyari Clinic', 'severity': 'critical', 'timestamp': DateTime.now().toIsoformatString(), 'resolved': false},
        ],
        'total': 1
      };
    }
  }

  Future<Map<String, dynamic>> ingestIncident({
    required String reporterName,
    required String reporterRole,
    required String locationZone,
    String? sku,
    required String message,
    String severity = 'high',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/ingest/incident'),
        headers: _headers(),
        body: json.encode({
          'reporter_name': reporterName,
          'reporter_role': reporterRole,
          'location_zone': locationZone,
          'sku': sku ?? 'GENERAL',
          'message': message,
          'severity': severity.toLowerCase()
        }),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'status': 'ingested',
        'incident_id': 'mock-inc-999',
        'rules_evaluated': {
          'location_risk_tagged': severity == 'critical' ? 'RED' : 'YELLOW',
          'zone': locationZone,
          'severity': severity
        }
      };
    }
  }

  // ── MOVEMENT TRACKING ──

  Future<Map<String, dynamic>> ingestMovement({
    required String driverName,
    required String vehicleId,
    required String originZone,
    required String destinationZone,
    required String sku,
    required int quantity,
    String status = 'in_transit',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/ingest/movement'),
        headers: _headers(),
        body: json.encode({
          'driver_name': driverName,
          'vehicle_id': vehicleId,
          'origin_zone': originZone,
          'destination_zone': destinationZone,
          'sku': sku,
          'quantity': quantity,
          'status': status
        }),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'status': 'ingested',
        'movement': {
          'driver': driverName,
          'vehicle': vehicleId,
          'from': originZone,
          'to': destinationZone,
          'status': status,
        }
      };
    }
  }

  // ── INTELLIGENCE CHANNELS ──

  Future<Map<String, dynamic>> getZoneRiskMap() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/zone-risk-map'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'zone_risk_map': {
          'Korangi': {'risk': 'YELLOW', 'active_incidents': 1, 'critical_incidents': 0},
          'Lyari': {'risk': 'RED', 'active_incidents': 3, 'critical_incidents': 2},
          'Saddar': {'risk': 'GREEN', 'active_incidents': 0, 'critical_incidents': 0},
        }
      };
    }
  }

  Future<Map<String, dynamic>> getContradictions() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/contradictions'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'contradictions': [
          {
            'sku': 'MED-001',
            'item_name': 'Panadol 500mg',
            'depot': 'Korangi Depot',
            'zone': 'Korangi',
            'ledger_quantity': 12000,
            'ground_reports': 3,
            'anomaly': 'DISTRIBUTION_GAP',
            'explanation': 'Ledger shows 12000 units but 3 ground shortages are reported.',
          }
        ],
        'total_found': 1
      };
    }
  }

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/dashboard'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {
        'org_id': currentUser?['org_id'] ?? 'org-demo',
        'role': currentUser?['role'] ?? 'admin',
        'overview': {
          'total_stock_records': 5,
          'critical_stock_count': 1,
          'active_incidents': 3,
          'red_zones': ['Lyari'],
          'contradictions_found': 1,
          'complaint_spike': false
        }
      };
    }
  }

  // ── CORE AGENT CONTROLLERS ──

  Future<Map<String, dynamic>> runAnalysis() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: _headers(),
        body: json.encode({}),
      ).timeout(const Duration(seconds: 30));
      return json.decode(res.body);
    } catch (e) {
      return _mockAnalysis();
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/analyze/status'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) {
      return {'complaint_spike': false, 'total_complaints': 5, 'ready': true};
    }
  }

  Future<Map<String, dynamic>> getIngest() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ingest'),
      ).timeout(const Duration(seconds: 15));
      return json.decode(res.body);
    } catch (e) {
      return {
        'weather': {'data': {'condition': 'Clear', 'logistics_risk': 'LOW'}},
        'currency': {'data': {'usd_to_pkr': 278.5}},
        'meta': {'sources_healthy': 6},
      };
    }
  }

  Map<String, dynamic> _mockAnalysis() => {
    'ai_analysis': {
      'summary': 'Critical shortage detected for MED-001 in Gulshan. '
          '3 complaints confirmed against warehouse stock of 10,000 units. '
          'Supply chain contradiction flagged.',
      'alerts': [
        {
          'sku': 'MED-001',
          'item_name': 'Panadol 500mg',
          'risk_level': 'CRITICAL',
          'location': 'Gulshan Karachi',
          'reason': 'Warehouse shows 10,000 units but 3 high-severity shortage complaints received',
        },
        {
          'sku': 'MED-006',
          'item_name': 'ORS Sachets',
          'risk_level': 'WARNING',
          'location': 'Lyari',
          'reason': 'Stock depleting rapidly. Predicted stockout in 48 hours.',
        },
      ],
      'critical_count': 1,
      'warning_count': 1,
    },
    'action_chain': {
      'before_state': {
        'stockout_risk': 'HIGH',
        'supplier_status': 'unverified',
        'emergency_orders': 0,
      },
      'after_state': {
        'stockout_risk': 'REDUCED',
        'supplier_status': 'emergency_order_placed',
        'emergency_orders': 1,
      },
      'chain_results': [
        {'step': 1, 'action': 'validate_stock', 'status': 'completed'},
        {'step': 2, 'action': 'notify_procurement', 'status': 'completed'},
        {'step': 3, 'action': 'simulate_emergency_order', 'status': 'completed',
          'orders': [{'po_number': 'EMG-20260518-MED001'}]},
        {'step': 4, 'action': 'update_customer_notifications', 'status': 'completed'},
        {'step': 5, 'action': 'schedule_monitoring', 'status': 'completed'},
      ],
    },
    'ingest_summary': {
      'pkr_rate': 278.5,
      'complaint_spike': true,
      'total_complaints': 8,
    },
  };
}

extension DateTimeString on DateTime {
  String toIsoformatString() {
    return toUtc().toIso8601String().replaceAll('Z', '');
  }
}
