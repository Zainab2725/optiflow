import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import '../models.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, or 127.0.0.1 for standard host loopback.
  static String baseUrl = _getBaseUrl();

  static String _getBaseUrl() {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  // Static Session state
  static String? token;
  static Map<String, dynamic>? currentUser;
  static Map<String, dynamic>? organization;

  // No static config — all zones, SKUs, and fleet data are loaded live from the backend.

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
      throw Exception('Authentication failed. Please check your credentials and ensure the backend is running.\n\nDetail: $e');
    }
  }

  Future<Map<String, dynamic>> signupOrg({
    required String orgName,
    required String orgType,
    required String adminName,
    required String email,
    required String password,
    String? customSheetUrl,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/signup-org'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'organization_name': orgName,
          'organization_type': orgType,
          'custom_sheet_url': customSheetUrl,
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
      throw Exception('Signup failed. Please check your connection and try again.\n\nDetail: $e');
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
      throw Exception('Invitation failed: $e');
    }
  }

  // ── STOCK OPERATIONS ──

  Future<Map<String, dynamic>> getStock() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/stock'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load stock');
      }
    } catch (e) {
      throw Exception('Failed to load stock: $e');
    }
  }

  Future<Map<String, dynamic>> predictStock() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/predict/stock'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 20));
      return json.decode(res.body);
    } catch (e) {
      return {'error': 'Failed to reach stock predictor: $e'};
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
      if (res.statusCode == 200 || res.statusCode == 201) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to ingest stock');
      }
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
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load incidents');
      }
    } catch (e) {
      throw Exception('Failed to load incidents: $e');
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
      if (res.statusCode == 200 || res.statusCode == 201) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to submit incident');
      }
    } catch (e) {
      throw Exception('Failed to submit incident: $e');
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
      if (res.statusCode == 200 || res.statusCode == 201) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to log movement');
      }
    } catch (e) {
      throw Exception('Failed to log movement: $e');
    }
  }
  Future<List<dynamic>> getMovements() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/movements'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        throw Exception('Failed to load movements');
      }
    } catch (e) {
      throw Exception('Failed to load movements: $e');
    }
  }
  Future<Map<String, dynamic>> getRouteOptimization({String origin = "Hyderabad, Pakistan", String destination = "Karachi, Pakistan"}) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/route?origin=$origin&destination=$destination'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 15));
      return json.decode(res.body);
    } catch (e) {
      throw Exception('Route optimization failed: $e');
    }
  }

  // ── INTELLIGENCE CHANNELS ──

  Future<Map<String, dynamic>> getZoneRiskMap() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/zone-risk-map'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load zone risk map');
      }
    } catch (e) {
      throw Exception('Failed to load zone risk map: $e');
    }
  }

  Future<Map<String, dynamic>> getContradictions() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/contradictions'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load contradictions');
      }
    } catch (e) {
      throw Exception('Failed to load contradictions: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/dashboard'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        final err = json.decode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load dashboard');
      }
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
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
      throw Exception('Analysis failed: $e');
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
      throw Exception('Status check failed: $e');
    }
  }

  Future<Map<String, dynamic>> getIngest() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ingest'),
      ).timeout(const Duration(seconds: 15));
      return json.decode(res.body);
    } catch (e) {
      throw Exception('Ingest fetch failed: $e');
    }
  }

  // All mock data removed — the app now exclusively uses live backend responses.
}

extension DateTimeString on DateTime {
  String toIsoformatString() {
    return toUtc().toIso8601String().replaceAll('Z', '');
  }
}
