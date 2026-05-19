import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _api = ApiService();
  final _orgNameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _sheetUrlCtrl = TextEditingController();
  String _orgType = 'NGO';
  bool _loading = false;
  String _error = '';

  final List<String> _orgTypes = ['NGO', 'GOVERNMENT', 'PHARMA_DISTRIBUTOR', 'HUMANITARIAN'];

  Future<void> _handleSignup() async {
    final orgName = _orgNameCtrl.text.trim();
    final adminName = _adminNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (orgName.isEmpty || adminName.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please complete all secure fields.');
      return;
    }

    // Strong password complexity validation
    if (pass.length < 8) {
      setState(() => _error = 'Passcode must be at least 8 characters long.');
      return;
    }
    final hasUppercase = pass.contains(RegExp(r'[A-Z]'));
    final hasDigits = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (!hasUppercase || !hasDigits || !hasSpecial) {
      setState(() => _error = 'Passcode must contain at least 1 uppercase letter, 1 digit, and 1 special character.');
      return;
    }

    final customSheetUrl = _sheetUrlCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // 1. Register organization on FastAPI Secure Backend
      final backendRes = await _api.signupOrg(
        orgName: orgName,
        orgType: _orgType,
        adminName: adminName,
        email: email,
        password: pass,
        customSheetUrl: customSheetUrl.isEmpty ? null : customSheetUrl,
      );

      final String orgId = backendRes['organization']?['org_id'] ?? 'org-${DateTime.now().millisecond}';

      // 2. Register on Firebase for real-time synchronization
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .set({
          'org_id': orgId,
          'name': orgName,
          'type': _orgType,
          'admin_name': adminName,
          'admin_email': email,
          'firebase_uid': cred.user!.uid,
          'created_at': FieldValue.serverTimestamp(),
          'configured': false,
        });

        // Set Firebase display name
        await cred.user!.updateDisplayName(adminName);
      } catch (fbErr) {
        // Continue even if Firebase isn't initialized locally
      }

      if (mounted) {
        // Steer to the Organization Setup workspace
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomPaint(
            painter: _SignupGridPainter(),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                // Custom Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.hub_outlined, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'OptiFlow',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
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
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Register Organization',
                                    style: Theme.of(context).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Establish isolated secure operational space',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.onSurfaceVar,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('ORGANIZATION NAME'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _orgNameCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Karachi Relief NGO',
                                      prefixIcon: Icon(Icons.business_outlined, size: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  _label('ORGANIZATION TYPE'),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _orgType,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.onSurfaceVar),
                                        items: _orgTypes.map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(
                                            t.replaceAll('_', ' '),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _orgType = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  _label('ADMIN OPERATOR NAME'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _adminNameCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Zainab Ali',
                                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  _label('ADMIN SECURE EMAIL'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      hintText: 'admin@organization.pk',
                                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  _label('ACCESS PASSCODE'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _passCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      hintText: '••••••••',
                                      prefixIcon: Icon(Icons.lock_outline, size: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  _label('WAREHOUSE SPREADSHEET URL (OPTIONAL)'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _sheetUrlCtrl,
                                    keyboardType: TextInputType.url,
                                    decoration: const InputDecoration(
                                      hintText: 'https://docs.google.com/spreadsheets/d/...',
                                      prefixIcon: Icon(Icons.table_chart_outlined, size: 18),
                                    ),
                                  ),
                                  
                                  if (_error.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _error,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _loading ? null : _handleSignup,
                                      icon: _loading
                                          ? const SizedBox(
                                              width: 16, height: 16,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Icon(Icons.check_circle_outline, size: 18),
                                      label: const Text('Provision Workspace'),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Already have an account? ",
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.onSurfaceVar,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                                          );
                                        },
                                        child: Text(
                                          "Sign In",
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
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
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.onSurfaceVar,
        fontSize: 10,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SignupGridPainter extends CustomPainter {
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
  @override
  bool shouldRepaint(_) => false;
}
