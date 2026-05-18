import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── Incidents ──
  Stream<List<Incident>> incidentsStream() {
    return _db
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(Incident.fromFirestore).toList());
  }

  Future<void> addIncident(Incident incident) async {
    await _db.collection('incidents').add(incident.toFirestore());
  }

  Future<void> updateIncidentStatus(String id, String status) async {
    await _db.collection('incidents').doc(id).update({'status': status});
  }

  // ── Fleet ──
  Stream<List<FleetUnit>> fleetStream() {
    return _db
        .collection('fleet')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((s) => s.docs.map(FleetUnit.fromFirestore).toList());
  }

  // ── Dashboard KPIs ──
  Stream<Map<String, dynamic>> dashboardStream() {
    return _db
        .collection('incidents')
        .snapshots()
        .map((s) {
          final docs = s.docs;
          final critical = docs.where((d) =>
              (d['severity'] ?? '').toString().toLowerCase() == 'critical').length;
          final high = docs.where((d) =>
              (d['severity'] ?? '').toString().toLowerCase() == 'high').length;
          final open = docs.where((d) =>
              (d['status'] ?? '').toString().toLowerCase() == 'open').length;
          return {
            'total': docs.length,
            'critical': critical,
            'high': high,
            'open': open,
            'system_health': critical == 0 ? 99.8 : (99.8 - critical * 2.3),
          };
        });
  }

  // ── Seed demo data if Firestore is empty ──
  Future<void> seedDemoData() async {
    final existing = await _db.collection('incidents').limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final demoIncidents = [
      {
        'title': 'Lyari Expressway Flooding',
        'message': '2 feet water level. 200 vehicles stranded. Rescue boats needed urgently.',
        'severity': 'critical',
        'location_zone': 'Lyari',
        'status': 'open',
        'risk_score': 94,
        'sku': 'FLOOD-001',
        'reporter_name': 'Flood Response Unit',
        'units_active': 3,
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'title': 'SITE Warehouse Fire',
        'message': 'Industrial Area SITE-B. Hazardous materials. 3 fire engines deployed.',
        'severity': 'critical',
        'location_zone': 'SITE Karachi',
        'status': 'open',
        'risk_score': 91,
        'sku': 'RESCUE-001',
        'reporter_name': 'Fire Station 7',
        'units_active': 5,
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Orangi Water Crisis',
        'message': '500 families without clean water. Distribution center inaccessible.',
        'severity': 'critical',
        'location_zone': 'Orangi',
        'status': 'open',
        'risk_score': 88,
        'sku': 'RELIEF-001',
        'reporter_name': 'NGO Field Operator',
        'units_active': 2,
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Saddar Road Blockage',
        'message': 'MA Jinnah Road blocked. All supply convoys rerouted via Shahrah-e-Faisal.',
        'severity': 'high',
        'location_zone': 'Saddar',
        'status': 'open',
        'risk_score': 74,
        'sku': 'GENERAL',
        'reporter_name': 'Traffic Control',
        'units_active': 1,
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Korangi Food Supply Gap',
        'message': 'Distribution center reports 40 percent shortfall. 1200 families affected.',
        'severity': 'high',
        'location_zone': 'Korangi',
        'status': 'open',
        'risk_score': 71,
        'sku': 'RELIEF-002',
        'reporter_name': 'Relief Coordinator',
        'units_active': 0,
        'timestamp': FieldValue.serverTimestamp(),
      }
    ];

    final batch = _db.batch();
    for (final inc in demoIncidents) {
      batch.set(_db.collection('incidents').doc(), inc);
    }

    final demoFleet = [
      {
        'vehicle_id': 'RESCUE-01',
        'status': 'IN_TRANSIT',
        'destination_zone': 'Lyari',
        'cargo_type': 'Rescue Boats + Equipment',
        'fuel_efficiency': 0.7,
        'eta_minutes': 8,
        'delay_minutes': 0,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'vehicle_id': 'RELIEF-TRUCK-04',
        'status': 'DELAYED',
        'destination_zone': 'Orangi',
        'cargo_type': 'Clean Water Packets',
        'fuel_efficiency': 0.4,
        'eta_minutes': 55,
        'delay_minutes': 35,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'vehicle_id': 'MED-VAN-09',
        'status': 'IN_TRANSIT',
        'destination_zone': 'Saddar Civil Hospital',
        'cargo_type': 'Emergency Medical Kits',
        'fuel_efficiency': 0.9,
        'eta_minutes': 12,
        'delay_minutes': 0,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'vehicle_id': 'FOOD-CONVOY-02',
        'status': 'LOADING',
        'destination_zone': 'Korangi Distribution Center',
        'cargo_type': 'Emergency Food Packs',
        'fuel_efficiency': 0.0,
        'eta_minutes': 90,
        'delay_minutes': 0,
        'created_at': FieldValue.serverTimestamp(),
      }
    ];

    for (final fl in demoFleet) {
      batch.set(_db.collection('fleet').doc(), fl);
    }

    await batch.commit();
  }
}
