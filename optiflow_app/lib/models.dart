import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String id;
  final String title;
  final String description;
  final String severity;   // CRITICAL, HIGH, MINOR
  final String zone;
  final String status;
  final int riskScore;
  final String sku;
  final String reporterName;
  final DateTime timestamp;
  final int unitsActive;

  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.zone,
    required this.status,
    required this.riskScore,
    required this.sku,
    required this.reporterName,
    required this.timestamp,
    required this.unitsActive,
  });

  factory Incident.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Incident(
      id: doc.id,
      title: d['title'] ?? d['message'] ?? 'Incident',
      description: d['message'] ?? d['description'] ?? '',
      severity: (d['severity'] ?? 'minor').toUpperCase(),
      zone: d['location_zone'] ?? d['zone'] ?? 'Unknown',
      status: d['status'] ?? 'open',
      riskScore: d['risk_score'] ?? _riskFromSeverity(d['severity'] ?? 'minor'),
      sku: d['sku'] ?? 'GENERAL',
      reporterName: d['reporter_name'] ?? 'Field Operator',
      timestamp: d['timestamp'] != null
          ? (d['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      unitsActive: d['units_active'] ?? 0,
    );
  }

  static int _riskFromSeverity(String s) {
    switch (s.toLowerCase()) {
      case 'critical': return 90 + DateTime.now().millisecond % 10;
      case 'high':     return 65 + DateTime.now().millisecond % 15;
      default:         return 30 + DateTime.now().millisecond % 20;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'message': description,
    'severity': severity.toLowerCase(),
    'location_zone': zone,
    'status': status,
    'risk_score': riskScore,
    'sku': sku,
    'reporter_name': reporterName,
    'timestamp': FieldValue.serverTimestamp(),
    'units_active': unitsActive,
  };
}

class FleetUnit {
  final String id;
  final String vehicleId;
  final String status;      // IN_TRANSIT, DELAYED, LOADING
  final String destination;
  final String cargoType;
  final double fuelEff;
  final int etaMinutes;
  final int delayMinutes;

  FleetUnit({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.destination,
    required this.cargoType,
    required this.fuelEff,
    required this.etaMinutes,
    required this.delayMinutes,
  });

  factory FleetUnit.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FleetUnit(
      id: doc.id,
      vehicleId: d['vehicle_id'] ?? 'VH-000',
      status: (d['status'] ?? 'IN_TRANSIT').toUpperCase(),
      destination: d['destination_zone'] ?? 'Unknown',
      cargoType: d['cargo_type'] ?? 'General',
      fuelEff: (d['fuel_efficiency'] ?? 0.8).toDouble(),
      etaMinutes: d['eta_minutes'] ?? 30,
      delayMinutes: d['delay_minutes'] ?? 0,
    );
  }
}

class StockAlert {
  final String sku;
  final String productName;
  final String riskLevel;
  final String zone;
  final int quantity;
  final String reason;

  StockAlert({
    required this.sku,
    required this.productName,
    required this.riskLevel,
    required this.zone,
    required this.quantity,
    required this.reason,
  });

  factory StockAlert.fromMap(Map<String, dynamic> d) => StockAlert(
    sku: d['sku'] ?? '',
    productName: d['item_name'] ?? d['product_name'] ?? '',
    riskLevel: d['risk_level'] ?? 'WARNING',
    zone: d['location'] ?? 'Karachi',
    quantity: d['quantity'] ?? 0,
    reason: d['reason'] ?? '',
  );
}
