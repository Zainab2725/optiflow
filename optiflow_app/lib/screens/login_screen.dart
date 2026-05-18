import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController(text: 'admin@optiflow.pk');
  final _passCtrl     = TextEditingController(text: 'optiflow123');
  bool _loading       = false;
  bool _showPass      = false;
  bool _showSignup    = false;
  String _error       = '';
  final _nameCtrl     = TextEditingController();
  final _orgCtrl      = TextEditingController();

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Authentication failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signup() async {
    if (_nameCtrl.text.isEmpty || _orgCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(cred.user!.uid)
          .set({
        'name': _orgCtrl.text.trim(),
        'admin_name': _nameCtrl.text.trim(),
        'admin_email': _emailCtrl.text.trim(),
        'org_id': cred.user!.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Signup failed');
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.hub_outlined, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 6),
                        Text('OptiFlow',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: AppTheme.primary)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.outlineVar),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(children: [
                          const Icon(Icons.shield_outlined, size: 12, color: AppTheme.onSurfaceVar),
                          const SizedBox(width: 4),
                          Text('ENCRYPTED_CHANNEL',
                            style: Theme.of(context).textTheme.labelSmall),
                        ]),
                      ),
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
                                    _showSignup ? 'Secure Access' : 'Secure Access',
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
                                  if (_showSignup) ...[
                                    _label('FULL NAME'),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _nameCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter legal name',
                                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _label('ORGANIZATION'),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _orgCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'Organization name',
                                        prefixIcon: Icon(Icons.business_outlined, size: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
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
                                      onPressed: _loading ? null
                                          : (_showSignup ? _signup : _login),
                                      icon: _loading
                                          ? const SizedBox(width: 16, height: 16,
                                              child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.arrow_forward, size: 18),
                                      label: Text(_showSignup
                                          ? 'Submit Request' : 'Authenticate'),
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
                                    onPressed: () => setState(() => _showSignup = !_showSignup),
                                    icon: Icon(_showSignup
                                        ? Icons.login : Icons.person_add_outlined,
                                      size: 18),
                                    label: Text(_showSignup
                                        ? 'Return to Operator Login'
                                        : 'Request Credentials'),
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
                // Bottom status
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statusBadge(context, Icons.shield_outlined,
                          'FIREWALL_ACTIVE', AppTheme.criticalRed),
                      _statusBadge(context, Icons.language_outlined,
                          'IP_WHITELISTED', AppTheme.primary),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppTheme.success)),
                        const SizedBox(width: 6),
                        Text('SYSTEM STATUS: OPTIMAL',
                          style: Theme.of(context).textTheme.labelSmall),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('TERMINAL ID: KRC-09-ADM',
                          style: Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
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
