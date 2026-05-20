import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  bool _inviting = false;
  final _inviteNameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  String _inviteRole = 'driver';
  List<String> _liveZones = [];
  bool _zonesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final res = await _api.getZoneRiskMap();
      final map = res['zone_risk_map'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _liveZones = map.keys.toList()..sort();
          _zonesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _zonesLoading = false);
    }
  }

  @override
  void dispose() {
    _inviteNameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppTheme.surface,
          title: Row(
            children: [
              const Icon(Icons.person_add_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Add Staff Member',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a new team member to your organization.',
              ),
              const SizedBox(height: 16),
              _label('Full Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _inviteNameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Ahmed Raza',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              _label('Email'),
              const SizedBox(height: 6),
              TextField(
                controller: _inviteEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'driver@optiflow.pk',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              _label('Role'),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.outlineVar, width: 0.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _inviteRole,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'driver', child: Text('Driver')),
                      DropdownMenuItem(
                          value: 'field_operator',
                          child: Text('Field Operator')),
                    ],
                    onChanged: (val) =>
                        setDlgState(() => _inviteRole = val ?? _inviteRole),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _inviteNameCtrl.clear();
                _inviteEmailCtrl.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _inviting
                  ? null
                  : () async {
                      final name = _inviteNameCtrl.text.trim();
                      final email = _inviteEmailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) return;
                      setDlgState(() => _inviting = true);
                      try {
                        final res = await _api.inviteUser(
                          name: name,
                          email: email,
                          role: _inviteRole,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  res['message'] ?? 'Operator registered!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppTheme.criticalRed,
                            ),
                          );
                        }
                      } finally {
                        setDlgState(() => _inviting = false);
                        _inviteNameCtrl.clear();
                        _inviteEmailCtrl.clear();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout() {
    ApiService.token = null;
    ApiService.currentUser = null;
    ApiService.organization = null;
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _label(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppTheme.onSurfaceVar, fontSize: 9),
      );

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppTheme.primary;
      case 'manager':
        return Colors.teal;
      case 'driver':
        return AppTheme.warning;
      case 'field_operator':
        return Colors.deepOrange;
      default:
        return AppTheme.onSurfaceVar;
    }
  }

  Widget _infoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final org = ApiService.organization;

    if (user == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleLogout());
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final roleName =
        user['role']?.toString().toUpperCase() ?? 'OPERATOR';
    final roleColor = _getRoleColor(roleName);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── User Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: roleColor.withValues(alpha: 0.1),
                  child: Icon(Icons.security, color: roleColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'System Operator',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? 'operator@optiflow.pk',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          roleName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Organization Info ──
          Text(
            'ORGANIZATION PIPELINE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.onSurfaceVar,
                  fontSize: 10,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                    'Workspace Name',
                    org?['name'] ??
                        user['org_name'] ??
                        '—'),
                const Divider(height: 20),
                _infoRow(
                    'Organization ID',
                    org?['org_id'] ??
                        user['org_id'] ??
                        '—'),
                const Divider(height: 20),
                _infoRow('Operator ID', user['user_id'] ?? '—'),
                const Divider(height: 20),
                _infoRow('Isolation Scope', 'MULTI-TENANT SECURE CLOUD'),
                const Divider(height: 20),
                Text(
                  'Live Zone Risk Coverage:',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_zonesLoading)
                  const SizedBox(
                    height: 24,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                else if (_liveZones.isEmpty)
                  Text(
                    'No zones loaded.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.onSurfaceVar),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _liveZones.map((zone) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.primary
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          zone,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── System Config Controls ──
          Text(
            'LOGISTICS SYSTEMS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.onSurfaceVar,
                  fontSize: 10,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Column(
              children: [
                _menuTile(
                  icon: Icons.person_add_outlined,
                  title: 'Invite Operator Staff',
                  subtitle: 'Add drivers or managers to this node',
                  onTap: _showInviteDialog,
                ),
                const Divider(height: 1),
                _menuTile(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Reconfigure Workspace Assets',
                  subtitle:
                      'Update warehouses, categories, and corridors',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SetupScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                _menuTile(
                  icon: Icons.sync_outlined,
                  title: 'Sync Ground Database Ledger',
                  subtitle:
                      'Force sync stocks and incidents with backend',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Synchronizing logs with Central Karachi Gateway...'),
                        backgroundColor: AppTheme.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Logout Button ──
          ElevatedButton.icon(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.criticalRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.power_settings_new),
            label: const Text('DISCONNECT SECURE NODE'),
          ),
        ],
      ),
    );
  }
}
