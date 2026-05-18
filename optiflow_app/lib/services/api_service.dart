import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';
  // For Windows desktop use: http://127.0.0.1:8000

  Future<Map<String, dynamic>> runAnalysis() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
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
