import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'signup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    // Show the splash screen for a minimum amount of time
    await Future.delayed(const Duration(seconds: 2));

    try {
      await http.get(Uri.parse('${ApiService.baseUrl}/health'))
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      // Ignore errors for now, allow fallback logic to handle later
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SignupScreen(),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1C4FF6), // Lighter blue at top
              Color(0xFF1027A1), // Darker blue at bottom
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hub_outlined, // Network/hub icon matching the logo
                      color: Color(0xFF1C4FF6),
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'OptiFlow',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ) ?? const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Karachi Crisis Intelligence System',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ) ?? TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 64),
                
                // Loading Dots
                const _LoadingDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots({Key? key}) : super(key: key);

  @override
  __LoadingDotsState createState() => __LoadingDotsState();
}

class __LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Calculate a pulsating offset for each dot
            double offset = sin((_controller.value * 2 * pi) - (index * pi / 4));
            double opacity = (offset + 1) / 2 * 0.7 + 0.3; // Range 0.3 to 1.0
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
