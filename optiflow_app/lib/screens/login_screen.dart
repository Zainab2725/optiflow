import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _showPass   = false;
  String _error    = '';

  void _showServerSettings() {
    final ctrl = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the backend server base URL. If using a physical phone, enter your computer\'s local network IP address (e.g. http://192.168.1.5:8000).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:8000',
                labelText: 'Server Base URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                ApiService.baseUrl = ctrl.text.trim();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server URL set to: ${ApiService.baseUrl}')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      // Authenticate with FastAPI backend — gets JWT + role
      await ApiService().login(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      // Optional: also sign into Firebase for any stream-based features
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } catch (_) { /* graceful fallback */ }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomPaint(painter: _LoginGridPainter(), child: const SizedBox.expand()),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.hub_outlined, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text('OptiFlow',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppTheme.primary)),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Secure Access',
                                    style: Theme.of(context).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Command Center Authorization Required',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(color: AppTheme.onSurfaceVar),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            // Form
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('OPERATOR_ID'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter ID',
                                      prefixIcon: Icon(Icons.person_outline, size: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _label('ACCESS_KEY'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _passCtrl,
                                    obscureText: !_showPass,
                                    decoration: InputDecoration(
                                      hintText: '••••••••',
                                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(() => _showPass = !_showPass),
                                        child: Icon(
                                          _showPass ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_error.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(_error,
                                        style: Theme.of(context).textTheme.bodySmall
                                            ?.copyWith(color: AppTheme.error)),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _loading ? null : _login,
                                      icon: _loading
                                          ? const SizedBox(width: 16, height: 16,
                                              child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.arrow_forward, size: 18),
                                      label: const Text('Authenticate'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('OR',
                                        style: Theme.of(context).textTheme.labelSmall),
                                    ),
                                    const Expanded(child: Divider()),
                                  ]),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                                      );
                                    },
                                    icon: const Icon(Icons.person_add_outlined, size: 18),
                                    label: const Text('Request Org Credentials'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: AppTheme.onSurfaceVar));
  }

  Widget _statusBadge(BuildContext ctx, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
        color: color.withOpacity(0.05),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ]),
    );
  }
}

class _LoginGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x080052D4)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}
