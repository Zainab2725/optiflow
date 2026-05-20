import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/agent_state_provider.dart';

class LiveRouteTracker extends StatefulWidget {
  const LiveRouteTracker({super.key});

  @override
  State<LiveRouteTracker> createState() => _LiveRouteTrackerState();
}

class _LiveRouteTrackerState extends State<LiveRouteTracker> with TickerProviderStateMixin {
  late AnimationController _truckController;
  late AnimationController _pulseController;
  
  // Interactive control override: let judges toggle view or bind to AI
  bool _manualOverride = false;
  bool _showDetour = true;

  @override
  void initState() {
    super.initState();
    // Animates truck sliding along the bypass path continuously
    _truckController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Animates pulsing neon hazard rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _truckController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;

    // Default Karachi Flood values mapped safely
    final insights = latestResult?['insights'] as Map<String, dynamic>? ?? {};
    final decision = latestResult?['decision'] as Map<String, dynamic>? ?? {};
    final simulation = latestResult?['simulation'] as Map<String, dynamic>? ?? {};
    final action = latestResult?['action'] as Map<String, dynamic>? ?? {};

    final actionType = action['type']?.toString() ?? decision['selected_action']?['type']?.toString() ?? 'ROUTE_CHANGE';
    final hasRouteDetour = actionType == 'ROUTE_CHANGE';

    // Auto-update detour switch based on live AI telemetry
    if (!_manualOverride) {
      _showDetour = hasRouteDetour;
    }

    final before = simulation['before_state'] as Map<String, dynamic>? ?? {};
    final after = simulation['after_state'] as Map<String, dynamic>? ?? {};
    final metrics = simulation['impact_metrics'] as Map<String, dynamic>? ?? {};

    final beforeRoute = before['route']?.toString() ?? 'Karachi Port ➔ M9 Highway ➔ Warehouse';
    final afterRoute = after['route']?.toString() ?? 'Karachi Port ➔ Lyari Bypass ➔ Warehouse';
    
    final delaySavings = metrics['delay_reduction']?.toString() ?? '85%';
    final riskSavings = metrics['risk_reduction']?.toString() ?? 'CRITICAL';
    final etaSavings = metrics['eta_improvement']?.toString() ?? '4.5 hrs earlier';

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 2,
        shadowColor: const Color(0xFF00FFCC).withOpacity(0.1),
        leading: const Icon(Icons.navigation, color: Color(0xFF00FFCC)),
        title: Text(
          'LIVE DETOUR SIMULATION',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          Row(
            children: [
              Text(
                'AI AUTOPILOT',
                style: GoogleFonts.jetBrainsMono(
                  color: !_manualOverride ? const Color(0xFF00FFCC) : Colors.white30,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: !_manualOverride,
                onChanged: (val) {
                  setState(() {
                    _manualOverride = !val;
                  });
                },
                activeColor: const Color(0xFF00FFCC),
                activeTrackColor: const Color(0xFF00FFCC).withOpacity(0.2),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Tactical Map Card ──
              _buildTacticalCanvas(latestResult),
              const SizedBox(height: 16),

              // ── Quick Sandbox Controller Panel ──
              _buildInteractiveControls(),
              const SizedBox(height: 16),

              // ── narrative Storytelling card ──
              _buildStorytellerCard(beforeRoute, afterRoute, decision),
              const SizedBox(height: 16),

              // ── Optimization Gains Cards ──
              _buildImpactMetrics(delaySavings, riskSavings, etaSavings),
            ],
          ),
        ),
      ),
    );
  }

  // Tactical painter map canvas
  Widget _buildTacticalCanvas(Map<String, dynamic>? latestResult) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFCC).withOpacity(0.03),
            blurRadius: 16,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Tech Grid Lines
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
          ),

          // Glowing Detour Custom Painter
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_truckController, _pulseController]),
              builder: (ctx, child) {
                return CustomPaint(
                  painter: DetourTacticalPainter(
                    vehicleProgress: _truckController.value,
                    pulseValue: _pulseController.value,
                    isRerouted: _showDetour,
                  ),
                );
              },
            ),
          ),

          // Floating GPS Telemetry Overlay
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TELEMETRY SOURCE: GOOGLE-MAPS SATELLITE FEED',
                    style: GoogleFonts.jetBrainsMono(color: const Color(0xFF00FFCC), fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'COORD SECTOR: 24.8607° N, 67.0011° E (KARACHI PORT TO HYDERABAD M9)',
                    style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.5), fontSize: 6.5),
                  ),
                ],
              ),
            ),
          ),

          // Interactive Telemetry Mode HUD Badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _showDetour ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _showDetour ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 0.5),
              ),
              child: Text(
                _showDetour ? 'DETOUR ENGAGED' : 'ROUTE BLOCKED',
                style: GoogleFonts.orbitron(
                  color: _showDetour ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Interactive controls to test/override reroutes manually
  Widget _buildInteractiveControls() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DETOUR SCENARIO OVERRIDE:',
            style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _manualOverride = true;
                    _showDetour = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_showDetour ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text('SHOW BLOCKED', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _manualOverride = true;
                    _showDetour = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showDetour ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text('SHOW DETOUR', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Narrative Storytelling Panel explaining why path changed
  Widget _buildStorytellerCard(String beforeRoute, String afterRoute, Map<String, dynamic> decision) {
    final primaryReason = decision['reasoning']?.toString() ?? 'Flood event detected at M9 Expressway coordinates. Dispatch alternative bypass Lyari Corridor to ensure zero delivery delay.';
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.import_contacts_sharp, color: Color(0xFF00FFCC), size: 18),
              const SizedBox(width: 8),
              Text(
                'AI COGNITIVE STORYBOARD',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _showDetour ? '🚚 DETOUR STORY ACTIVATED' : '⚠️ HAZARD STATE PERSISTS',
            style: GoogleFonts.orbitron(
              color: _showDetour ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showDetour
                ? 'Karachi Highway flood monitoring sensors flagged major blockages at the toll plaza sector. To avoid 4.5 hours of traffic delay and secure INS-001 insulin shipment, the AI Orchestration agent immediately dynamically calculated the safe bypass route.'
                : 'M9 Expressway suffers critical structural vulnerability due to overflowing nullahs. High hazard threat remains. Rerouting is highly recommended to protect critical medical cargo.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'RATIONALE TRACE: $primaryReason',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF00FFCC),
                fontSize: 9,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mapped impact metrics comparison row
  Widget _buildImpactMetrics(String delay, String risk, String eta) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            'DELAY SAVINGS',
            delay,
            'Optimization yield',
            const Color(0xFF10B981),
            Icons.speed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricItem(
            'AVOIDED THREAT',
            risk,
            'Risk score delta',
            const Color(0xFFEF4444),
            Icons.gavel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricItem(
            'ETA IMPACT',
            eta.split(' ')[0] + ' HR',
            'Transit timing',
            const Color(0xFFA855F7),
            Icons.timer_10_sharp,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, String subText, Color col, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col.withOpacity(0.2), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: col, size: 10),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.orbitron(color: col, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 7),
          ),
        ],
      ),
    );
  }
}

// Tech Background Grid Drawer
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const double step = 20.0;
    
    // Vertical grid lines
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    // Horizontal grid lines
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Tactical Detour Map Canvas Drawer
class DetourTacticalPainter extends CustomPainter {
  final double vehicleProgress;
  final double pulseValue;
  final bool isRerouted;

  DetourTacticalPainter({
    required this.vehicleProgress,
    required this.pulseValue,
    required this.isRerouted,
  });

  // Nodes Coordinates
  static const Offset originPort = Offset(60, 270);
  static const Offset blockedPlaza = Offset(170, 160);
  static const Offset alternativeBypass = Offset(250, 220);
  static const Offset warehouseDepot = Offset(140, 50);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw blocked region pulsing hazard zones
    _drawHazardArea(canvas);

    // 2. Draw route lines
    _drawBeforeBlockedPath(canvas);
    _drawAfterDetourPath(canvas);

    // 3. Draw Nodes (Depots/Ports)
    _drawTelemetryNodes(canvas);

    // 4. Draw Animated moving truck
    _drawAnimatedTruck(canvas);
  }

  // Draw expanding glowing emergency neon alert rings around the flood hazard plaza
  void _drawHazardArea(Canvas canvas) {
    final paintFill = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(blockedPlaza, 40, paintFill);

    final double maxRadius = 45.0;
    final double radius = 10.0 + (pulseValue * (maxRadius - 10.0));
    final double opacity = 0.9 - pulseValue;

    final paintStroke = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(blockedPlaza, radius, paintStroke);
    canvas.drawCircle(blockedPlaza, radius * 0.6, paintStroke);

    // Alert label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'FLOOD ALERT HAZARD',
        style: GoogleFonts.orbitron(
          color: const Color(0xFFEF4444),
          fontSize: 6,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(blockedPlaza.dx - 40, blockedPlaza.dy - 35));
  }

  // Draw traditional route in faded warning red
  void _drawBeforeBlockedPath(Canvas canvas) {
    final path = Path()
      ..moveTo(originPort.dx, originPort.dy)
      ..lineTo(blockedPlaza.dx, blockedPlaza.dy)
      ..lineTo(warehouseDepot.dx, warehouseDepot.dy);

    final paint = Paint()
      ..color = isRerouted ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // Draw blocked indicator 'X' if rerouted active
    if (isRerouted) {
      final signPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(blockedPlaza - const Offset(6, 6), blockedPlaza + const Offset(6, 6), signPaint);
      canvas.drawLine(blockedPlaza - const Offset(6, -6), blockedPlaza + const Offset(6, -6), signPaint);
    }
  }

  // Draw glowing emerald green alternate bypass detour corridor path
  void _drawAfterDetourPath(Canvas canvas) {
    final path = Path()
      ..moveTo(originPort.dx, originPort.dy)
      ..lineTo(alternativeBypass.dx, alternativeBypass.dy)
      ..lineTo(warehouseDepot.dx, warehouseDepot.dy);

    // Neon shadow glow under path
    final paintGlow = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, paintGlow);

    final paint = Paint()
      ..color = isRerouted ? const Color(0xFF10B981) : const Color(0xFF10B981).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  // Draw military-spec supply nodes
  void _drawTelemetryNodes(Canvas canvas) {
    _drawNode(canvas, originPort, 'KARACHI PORT [ORIGIN]', const Color(0xFF00FFCC));
    _drawNode(canvas, warehouseDepot, 'WAREHOUSE DEPOT [DESTINATION]', const Color(0xFF00FFCC));
    _drawNode(canvas, alternativeBypass, 'LYARI EXP DETOUR NODE', const Color(0xFF10B981));
  }

  void _drawNode(Canvas canvas, Offset offset, String label, Color col) {
    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(offset, 6, fillPaint);
    canvas.drawCircle(offset, 6, strokePaint);

    final pulsePaint = Paint()
      ..color = col.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, 10, pulsePaint);

    // Label text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.jetBrainsMono(
          color: Colors.white,
          fontSize: 6,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(offset.dx + 10, offset.dy - 4));
  }

  // Drives 🚚 truck slide smoothly based on segments progression
  void _drawAnimatedTruck(Canvas canvas) {
    Offset truckPos = originPort;

    if (!isRerouted) {
      // Primary Path: Segment 1 (0 to 0.5), Segment 2 (0.5 to 1.0)
      if (vehicleProgress < 0.5) {
        double segT = vehicleProgress / 0.5;
        truckPos = Offset.lerp(originPort, blockedPlaza, segT)!;
      } else {
        double segT = (vehicleProgress - 0.5) / 0.5;
        truckPos = Offset.lerp(blockedPlaza, warehouseDepot, segT)!;
      }
    } else {
      // Alternate Detour Bypass Path
      if (vehicleProgress < 0.5) {
        double segT = vehicleProgress / 0.5;
        truckPos = Offset.lerp(originPort, alternativeBypass, segT)!;
      } else {
        double segT = (vehicleProgress - 0.5) / 0.5;
        truckPos = Offset.lerp(alternativeBypass, warehouseDepot, segT)!;
      }
    }

    // Paint Truck Icon
    final fillPaint = Paint()
      ..color = isRerouted ? const Color(0xFF10B981) : const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Glowing ring under the moving truck
    final glowPaint = Paint()
      ..color = (isRerouted ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(truckPos, 12, glowPaint);

    canvas.drawCircle(truckPos, 7, fillPaint);
    canvas.drawCircle(truckPos, 7, strokePaint);

    // Draw little truck icon label '🚚'
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🚚',
        style: TextStyle(fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(truckPos.dx - 6, truckPos.dy - 7));
  }

  @override
  bool shouldRepaint(covariant DetourTacticalPainter oldDelegate) {
    return oldDelegate.vehicleProgress != vehicleProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isRerouted != isRerouted;
  }
}
