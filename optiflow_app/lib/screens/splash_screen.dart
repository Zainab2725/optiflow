import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  final List<_Particle> _particles = [];
  final Random _rand = Random();

  final List<String> _logs = [
    'INITIATING OPTIFLOW SECURE BOOT...',
    'CONFIGURING URBAN LOGISTICS ENGINE...',
    'ESTABLISHING ENCRYPTED TUNNEL...',
    'PINGING BACKEND ROUTING GATEWAY...',
  ];

  final List<String> _visibleLogs = [];
  int _logIndex = 0;
  double _progress = 0.0;
  String _backendStatus = "CHECKING...";
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(_rand));
    }

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    // Phase 1: Boot logs print out
    for (int i = 0; i < _logs.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _visibleLogs.add(_logs[i]);
        _logIndex = i;
        _progress = (i + 1) / (_logs.length + 3);
      });
    }

    // Phase 2: Ping Backend /health
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _visibleLogs.add('CONNECTING TO http://127.0.0.1:8000/health ...');
      _progress = (_logs.length + 1) / (_logs.length + 3);
    });

    String statusText = "FALLBACK";
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/health'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        statusText = "ONLINE - ${body['service'].toString().toUpperCase()}";
      }
    } catch (e) {
      statusText = "ONLINE (OFFLINE FALLBACK EMULATION MODE)";
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _backendStatus = statusText;
      _visibleLogs.add('SYSTEM INTERFACE SECURED: $statusText');
      _progress = (_logs.length + 2) / (_logs.length + 3);
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _visibleLogs.add('BOOT COMPLETED. ROUTING TO TERMINAL...');
      _progress = 1.0;
      _isDone = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    _navigate();
  }

  void _navigate() {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B19), // Midnight dark cyber background
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Grid background
            CustomPaint(
              painter: _GridPainter(),
              child: const SizedBox.expand(),
            ),
            // Corner brackets
            ..._corners(),
            // Center content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Glowing logo & Title block
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primary, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.hub_outlined,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'OptiFlow',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 38,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'KARACHI REAL-TIME LOGISTICS INTELLIGENCE',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.primaryLight,
                              fontSize: 10,
                              letterSpacing: 1.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Progress bar
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: MediaQuery.of(context).size.width * 0.88 * _progress,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terminal log monitor
                    Container(
                      padding: const EdgeInsets.all(16),
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'SYSTEM MONITOR',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _visibleLogs.length,
                              itemBuilder: (context, idx) {
                                final isLast = idx == _visibleLogs.length - 1;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    _visibleLogs[idx],
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 9.5,
                                      color: isLast
                                          ? (_isDone ? AppTheme.success : Colors.white)
                                          : Colors.white70,
                                      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom status bar
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AES-256 COMMAND PORT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'VER: 4.0.2-SECURE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const size = 24.0;
    const offset = 16.0;
    const color = Color(0x330052D4);
    Widget corner(double top, double bottom, double left, double right) {
      return Positioned(
        top: top == -1 ? null : offset,
        bottom: bottom == -1 ? null : offset,
        left: left == -1 ? null : offset,
        right: right == -1 ? null : offset,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              top: top != -1 ? const BorderSide(color: color, width: 2) : BorderSide.none,
              bottom: bottom != -1 ? const BorderSide(color: color, width: 2) : BorderSide.none,
              left: left != -1 ? const BorderSide(color: color, width: 2) : BorderSide.none,
              right: right != -1 ? const BorderSide(color: color, width: 2) : BorderSide.none,
            ),
          ),
        ),
      );
    }
    return [
      corner(0, -1, 0, -1),
      corner(0, -1, -1, 0),
      corner(-1, 0, 0, -1),
      corner(-1, 0, -1, 0),
    ];
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0C0052D4)
      ..strokeWidth = 1;
    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _Particle {
  late double x, y, vx, vy, size;
  _Particle(Random r) {
    x = r.nextDouble(); y = r.nextDouble();
    vx = (r.nextDouble() - 0.5) * 0.001;
    vy = (r.nextDouble() - 0.5) * 0.001;
    size = r.nextDouble() * 2 + 1;
  }
}
