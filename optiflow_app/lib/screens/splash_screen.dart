import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  final List<_Particle> _particles = [];
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(_rand));
    }
    _dotController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    Future.delayed(const Duration(seconds: 3), _navigate);
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
    _dotController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'OptiFlow',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'URBAN CRISIS MANAGEMENT',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.onSurfaceVar,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  AnimatedBuilder(
                    animation: _dotController,
                    builder: (_, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final delay = i * 0.15;
                        final t = (_dotController.value - delay).clamp(0.0, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.3 + t * 0.7),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom status bar
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AES-256 ENCRYPTED TUNNEL',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    'VER: 4.0.2-STABLE',
                    style: Theme.of(context).textTheme.labelSmall,
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
      ..color = const Color(0x080052D4)
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
