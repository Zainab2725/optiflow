import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class TacticalZoneMap extends StatefulWidget {
  final Map<String, dynamic> zoneRisk;
  final String? selectedZone;
  final Function(String?) onZoneSelected;
  final String? beforeRouteStr;
  final String? afterRouteStr;

  const TacticalZoneMap({
    super.key,
    required this.zoneRisk,
    required this.selectedZone,
    required this.onZoneSelected,
    this.beforeRouteStr,
    this.afterRouteStr,
  });

  @override
  State<TacticalZoneMap> createState() => _TacticalZoneMapState();
}

class _TacticalZoneMapState extends State<TacticalZoneMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  // Normalized topological coordinates for Karachi sectors
  static const Map<String, Offset> _zoneCoords = {
    'Orangi': Offset(0.15, 0.18),
    'SITE': Offset(0.22, 0.38),
    'Lyari': Offset(0.18, 0.60),
    'North Nazimabad': Offset(0.42, 0.20),
    'Saddar': Offset(0.35, 0.68),
    'Clifton': Offset(0.30, 0.88),
    'Gulshan': Offset(0.62, 0.35),
    'PECHS': Offset(0.50, 0.58),
    'Defence': Offset(0.52, 0.86),
    'Faisal': Offset(0.75, 0.50),
    'Korangi': Offset(0.78, 0.78),
    'Malir': Offset(0.88, 0.40),
  };

  // Fixed main logistics arterials connecting sectors
  static const List<List<String>> _standardCorridors = [
    ['Orangi', 'SITE'],
    ['SITE', 'Lyari'],
    ['SITE', 'North Nazimabad'],
    ['North Nazimabad', 'Gulshan'],
    ['Gulshan', 'PECHS'],
    ['Lyari', 'Saddar'],
    ['Saddar', 'Clifton'],
    ['Saddar', 'PECHS'],
    ['PECHS', 'Defence'],
    ['Clifton', 'Defence'],
    ['PECHS', 'Faisal'],
    ['Gulshan', 'Malir'],
    ['Faisal', 'Malir'],
    ['Faisal', 'Korangi'],
    ['Defence', 'Korangi'],
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<String> _parseRoute(String? routeStr) {
    if (routeStr == null || routeStr.trim().isEmpty) return [];
    return routeStr
        .split(RegExp(r'(➔|->|->|>|➔)'))
        .map((s) => s.trim())
        .map((s) {
          // Normalize names to match map keys
          if (s.toLowerCase().contains('port')) return 'Lyari';
          if (s.toLowerCase().contains('warehouse')) return 'SITE';
          if (s.toLowerCase().contains('depot')) return 'SITE';
          // Find closest key matching
          for (var key in _zoneCoords.keys) {
            if (s.toLowerCase().contains(key.toLowerCase())) {
              return key;
            }
          }
          return s;
        })
        .where((s) => _zoneCoords.containsKey(s))
        .toList();
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = details.localPosition;
    
    // Convert tap position to normalized coordinates
    final nx = localPosition.dx / constraints.maxWidth;
    final ny = localPosition.dy / constraints.maxHeight;

    String? closestZone;
    double minDistance = 9999.0;
    
    // Tap tolerance of 0.08 normalized unit
    const double tolerance = 0.08;

    _zoneCoords.forEach((zoneName, coord) {
      final dx = nx - coord.dx;
      final dy = ny - coord.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < minDistance && dist < tolerance) {
        minDistance = dist;
        closestZone = zoneName;
      }
    });

    if (closestZone != null) {
      widget.onZoneSelected(closestZone == widget.selectedZone ? null : closestZone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final beforeRoute = _parseRoute(widget.beforeRouteStr);
    final afterRoute = _parseRoute(widget.afterRouteStr);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _handleTap(details, constraints),
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Glowing vector mesh grid background
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.05,
                    child: CustomPaint(
                      painter: _GridMeshPainter(),
                    ),
                  ),
                ),
                // Custom tactical zone painter
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ZoneMapPainter(
                          zoneRisk: widget.zoneRisk,
                          selectedZone: widget.selectedZone,
                          beforeRoute: beforeRoute,
                          afterRoute: afterRoute,
                          pulseValue: _pulseController.value,
                          zoneCoords: _zoneCoords,
                          standardCorridors: _standardCorridors,
                        ),
                      );
                    },
                  ),
                ),
                // Glowing HUD overlay with dynamic metadata
                Positioned(
                  top: 10,
                  left: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white12, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00FFCC),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'DYNAMIC RISK TELEMETRY',
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFF00FFCC),
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.selectedZone != null
                                ? 'FOCUSED ON: ${widget.selectedZone!.toUpperCase()}'
                                : 'TAP ZONE NODE TO VIEW GROUND INCIDENTS',
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white70,
                              fontSize: 6.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Floating legend
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legendItem(const Color(0xFFEF4444), 'CRITICAL (RED)'),
                          const SizedBox(height: 3),
                          _legendItem(const Color(0xFFF59E0B), 'WARNING (YELLOW)'),
                          const SizedBox(height: 3),
                          _legendItem(const Color(0xFF10B981), 'NORMAL (NOMINAL)'),
                          const SizedBox(height: 3),
                          _legendItem(const Color(0xFF06B6D4), 'ACTIVE INCIDENT (ALERT)', isAlert: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String label, {bool isAlert = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: isAlert ? Border.all(color: Colors.white, width: 0.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white70,
            fontSize: 6.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GridMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const double step = 20.0;
    
    // Draw vertical tech grid lines
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    // Draw horizontal grid lines
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZoneMapPainter extends CustomPainter {
  final Map<String, dynamic> zoneRisk;
  final String? selectedZone;
  final List<String> beforeRoute;
  final List<String> afterRoute;
  final double pulseValue;
  final Map<String, Offset> zoneCoords;
  final List<List<String>> standardCorridors;

  _ZoneMapPainter({
    required this.zoneRisk,
    required this.selectedZone,
    required this.beforeRoute,
    required this.afterRoute,
    required this.pulseValue,
    required this.zoneCoords,
    required this.standardCorridors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw corridor arterial connections
    for (var corridor in standardCorridors) {
      final z1 = corridor[0];
      final z2 = corridor[1];
      
      final c1 = zoneCoords[z1];
      final c2 = zoneCoords[z2];
      if (c1 == null || c2 == null) continue;

      final p1 = Offset(c1.dx * size.width, c1.dy * size.height);
      final p2 = Offset(c2.dx * size.width, c2.dy * size.height);

      // Determine if this connection lies on our before/after routes
      bool isBeforeRouteLine = false;
      bool isAfterRouteLine = false;

      if (beforeRoute.isNotEmpty) {
        for (int i = 0; i < beforeRoute.length - 1; i++) {
          if ((beforeRoute[i] == z1 && beforeRoute[i+1] == z2) ||
              (beforeRoute[i] == z2 && beforeRoute[i+1] == z1)) {
            isBeforeRouteLine = true;
            break;
          }
        }
      }

      if (afterRoute.isNotEmpty) {
        for (int i = 0; i < afterRoute.length - 1; i++) {
          if ((afterRoute[i] == z1 && afterRoute[i+1] == z2) ||
              (afterRoute[i] == z2 && afterRoute[i+1] == z1)) {
            isAfterRouteLine = true;
            break;
          }
        }
      }

      Color lineColor = const Color(0xFF1E293B);
      double thickness = 1.0;
      bool isDashed = false;

      if (isAfterRouteLine) {
        lineColor = const Color(0xFF10B981); // Neon Green for recommended route
        thickness = 3.0;
      } else if (isBeforeRouteLine) {
        lineColor = const Color(0xFFEF4444).withOpacity(0.6); // Muted red for blocked route
        thickness = 2.0;
        isDashed = true;
      } else {
        lineColor = const Color(0xFF334155).withOpacity(0.35); // Standard corridor line
      }

      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (isDashed) {
        _drawDashedLine(canvas, p1, p2, paint);
      } else {
        canvas.drawLine(p1, p2, paint);
      }
    }

    // 2. Draw nodes (Zones) with dynamic telemetry
    zoneCoords.forEach((zoneName, coord) {
      final p = Offset(coord.dx * size.width, coord.dy * size.height);
      
      final details = zoneRisk[zoneName] != null
          ? Map<String, dynamic>.from(zoneRisk[zoneName] as Map)
          : <String, dynamic>{};
      
      final riskStr = details['risk']?.toString() ?? 'GREEN';
      final activeIncidents = details['active_incidents'] ?? 0;
      final isSelected = selectedZone == zoneName;

      // Color mapping
      Color nodeColor = const Color(0xFF10B981); // Default Emerald Green
      if (riskStr == 'RED') {
        nodeColor = const Color(0xFFEF4444); // Neon Red
      } else if (riskStr == 'YELLOW') {
        nodeColor = const Color(0xFFF59E0B); // Neon Yellow
      }

      // Draw glow ring around selected node
      if (isSelected) {
        final glowPaint = Paint()
          ..color = nodeColor.withOpacity(0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(p, 18, glowPaint);

        final ringPaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(p, 12, ringPaint);
      }

      // Draw expanding warning pulse ring if incidents are active (Alert status)
      if (activeIncidents > 0) {
        final double maxRadius = 22.0;
        final double radius = 8.0 + (pulseValue * (maxRadius - 8.0));
        final double opacity = (1.0 - pulseValue).clamp(0.0, 1.0);

        final alertPaint = Paint()
          ..color = const Color(0xFF06B6D4).withOpacity(opacity * 0.7) // Cyber Cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(p, radius, alertPaint);
      }

      // Draw solid node center
      final centerPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 5, centerPaint);

      final centerOutline = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(p, 5, centerOutline);

      // Label text
      final textPainter = TextPainter(
        text: TextSpan(
          text: zoneName.toUpperCase(),
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: isSelected ? 8.5 : 7.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.2,
            shadows: isSelected
                ? [
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    )
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Center the text slightly below the node
      textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, p.dy + 8));
    });
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    
    final double cosTheta = dx / distance;
    final double sinTheta = dy / distance;
    
    double currentDist = 0.0;
    while (currentDist < distance) {
      final double endX = p1.dx + (currentDist + dashWidth).clamp(0.0, distance) * cosTheta;
      final double endY = p1.dy + (currentDist + dashWidth).clamp(0.0, distance) * sinTheta;
      
      canvas.drawLine(
        Offset(p1.dx + currentDist * cosTheta, p1.dy + currentDist * sinTheta),
        Offset(endX, endY),
        paint,
      );
      
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneMapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.selectedZone != selectedZone ||
        oldDelegate.zoneRisk != zoneRisk ||
        oldDelegate.beforeRoute != beforeRoute ||
        oldDelegate.afterRoute != afterRoute;
  }
}
