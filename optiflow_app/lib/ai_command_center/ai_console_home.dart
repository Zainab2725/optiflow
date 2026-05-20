import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/agent_state_provider.dart';
import '../screens/profile_screen.dart';

class AIConsoleHome extends StatefulWidget {
  const AIConsoleHome({super.key});

  @override
  State<AIConsoleHome> createState() => _AIConsoleHomeState();
}

class _AIConsoleHomeState extends State<AIConsoleHome> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _blinkController;
  
  // High-fidelity terminal log typing controller
  final List<String> _typingLogs = [];
  Timer? _typingTimer;
  int _logIndex = 0;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _blinkController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  // Animates typewriter terminal output of AI insights signals
  void _triggerTypewriter(List<dynamic> signals) {
    _typingTimer?.cancel();
    setState(() {
      _typingLogs.clear();
      _logIndex = 0;
      _isTyping = true;
    });

    if (signals.isEmpty) {
      setState(() => _isTyping = false);
      return;
    }

    _typingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_logIndex < signals.length) {
        final item = signals[_logIndex];
        String txt = "";
        if (item is Map) {
          final sig = item['signal']?.toString().toUpperCase() ?? 'UNKNOWN SIGNAL';
          final conf = (item['confidence'] != null) ? '${(item['confidence'] * 100).toStringAsFixed(0)}%' : '90%';
          final reason = item['reasoning']?.toString() ?? 'Telemetry anomaly identified';
          txt = "⚡ [$sig] (CONF: $conf) ➔ $reason";
        } else {
          txt = "⚡ ${item.toString()}";
        }

        setState(() {
          _typingLogs.add(txt);
          _logIndex++;
        });
      } else {
        timer.cancel();
        setState(() => _isTyping = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AgentStateProvider>();
    final latestResult = state.latestResult;
    final isLoading = state.isLoading;
    final errorMsg = state.errorMessage;

    // Trigger typewriter animation once when new results arrive
    if (latestResult != null && !_isTyping && _typingLogs.isEmpty && !isLoading) {
      final insights = latestResult['insights'] as Map<String, dynamic>? ?? {};
      final signals = insights['signals'] as List<dynamic>? ?? [];
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerTypewriter(signals));
    } else if (isLoading && _typingLogs.isNotEmpty) {
      // Clear typewriter when loading is triggered
      _typingLogs.clear();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B13), // Ultra premium control-room dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 2,
        shadowColor: const Color(0xFF00FFCC).withOpacity(0.1),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (ctx, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFCC).withOpacity(0.2 + (_glowController.value * 0.4)),
                    blurRadius: 8 + (_glowController.value * 8),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.hub, color: Color(0xFF00FFCC), size: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'OPTIFLOW COMMAND CENTER',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF00FFCC), width: 0.5),
              ),
              child: AnimatedBuilder(
                animation: _blinkController,
                builder: (ctx, child) => Opacity(
                  opacity: _blinkController.value > 0.5 ? 1.0 : 0.3,
                  child: Text(
                    'LIVE SYSTEM',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF00FFCC),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined, color: Colors.white70),
            onPressed: () => state.runWorkflow(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: isLoading && latestResult == null
          ? _buildCyberBootingState()
          : errorMsg != null
              ? _buildTerminalError(state, errorMsg)
              : _buildMainDashboard(state, latestResult),
    );
  }

  // Glowing High-Tech Loading Screen
  Widget _buildCyberBootingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF00FFCC),
                  ),
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (ctx, child) => Icon(
                      Icons.security,
                      color: const Color(0xFF00FFCC).withOpacity(0.4 + (_glowController.value * 0.6)),
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'INITIALIZING TELEMETRY PIPELINE',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF00FFCC),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 250,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Text(
                'SYSTEM TRACE: Synchronizing Karachi Flood Maps, Depot Stock level parameters and regional news feeds...',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white60,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Premium Terminal Error Card with Retry Loops
  Widget _buildTerminalError(AgentStateProvider state, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0B11),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBA1A1A), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBA1A1A).withOpacity(0.15),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.dangerous, color: Color(0xFFBA1A1A), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'TELEMETRY SYNC FAILURE',
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFFBA1A1A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'COGNITIVE REASONING AGENT REPORTED AN ERROR DURING POST:',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    error,
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFFF8888),
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => state.runWorkflow(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('RETRY PIPELINE SYNC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Primary Control Room Grid Board
  Widget _buildMainDashboard(AgentStateProvider state, Map<String, dynamic>? latestResult) {
    if (latestResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal, size: 52, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'AWAITING SIGNAL TRANSMISSION',
              style: GoogleFonts.orbitron(color: Colors.white60, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the reload icon in the top right to start the telemetry loop.',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final insights = latestResult['insights'] as Map<String, dynamic>? ?? {};
    final decision = latestResult['decision'] as Map<String, dynamic>? ?? {};
    final simulation = latestResult['simulation'] as Map<String, dynamic>? ?? {};
    final action = latestResult['action'] as Map<String, dynamic>? ?? {};

    final riskScore = (decision['risk_score'] ?? 80) as num;
    final decisionType = decision['decision_type']?.toString().toUpperCase() ?? 'ROUTE_CHANGE';
    final actionType = action['type']?.toString() ?? decision['selected_action']?['type']?.toString() ?? 'ROUTE_CHANGE';
    
    // Determine dynamic states
    Color riskColor = const Color(0xFF10B981); // Stable green
    String systemState = 'STABLE';
    if (riskScore > 70) {
      riskColor = const Color(0xFFEF4444); // Critical red
      systemState = 'CRITICAL';
    } else if (riskScore > 35) {
      riskColor = const Color(0xFFF59E0B); // Warning orange
      systemState = 'ALERT';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cyber Top Status Bar ──
          _buildStatusBar(riskScore.toInt(), decisionType, systemState, riskColor),
          const SizedBox(height: 16),

          // ── AI Thinking Panel (Terminal Trace Logs) ──
          _buildThinkingPanel(insights),
          const SizedBox(height: 16),

          // ── Decision Engine Card ──
          _buildDecisionCard(decision, actionType),
          const SizedBox(height: 16),

          // ── Action Simulation Card ──
          _buildSimulationCard(simulation),
          const SizedBox(height: 16),

          // ── Active Flow Pipeline strip ──
          _buildPipelineStrip(state.isLoading),
        ],
      ),
    );
  }

  // 1. Status Bar Card
  Widget _buildStatusBar(int riskScore, String decisionType, String stateLabel, Color riskColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Dial risk level representation
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: riskScore / 100,
                  backgroundColor: Colors.white12,
                  color: riskColor,
                  strokeWidth: 4,
                ),
                Text(
                  '$riskScore',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM STATE: $stateLabel',
                  style: GoogleFonts.orbitron(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STRATEGY PLAN: $decisionType',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white70,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: riskColor.withOpacity(0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'ACTIVE RISK',
                  style: GoogleFonts.jetBrainsMono(
                    color: riskColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. High fidelity dynamic typing logger widget
  Widget _buildThinkingPanel(Map<String, dynamic> insights) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF060910),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFCC).withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory, color: Color(0xFF00FFCC), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'COGNITIVE AGENT INGESTION DETECTIONS',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (_isTyping)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00FFCC),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(10),
            child: _typingLogs.isEmpty
                ? Center(
                    child: Text(
                      '➔ Syncing intelligence streams...',
                      style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10),
                    ),
                  )
                : ListView.builder(
                    itemCount: _typingLogs.length,
                    itemBuilder: (ctx, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _typingLogs[i],
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF00FFCC),
                            fontSize: 9.5,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 3. AI Strategy Decision intelligence Card
  Widget _buildDecisionCard(Map<String, dynamic> decision, String actionType) {
    final String reasoning = decision['reasoning']?.toString() ?? 'Strategic evaluation complete. Deploy bypass.';
    final String actionSummary = decision['primary_insight']?.toString() ?? 'Initiate route detour.';
    final String targetSku = decision['target_sku']?.toString() ?? 'INS-001';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'DECISION INTEL ENGINE',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4), width: 0.5),
                ),
                child: Text(
                  'PRIORITY CRITICAL',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF38BDF8),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('PROPOSED ACTION', actionSummary, const Color(0xFF38BDF8)),
          const SizedBox(height: 10),
          _buildInfoRow('TARGET ASSET', 'SKU: $targetSku (Critical inventory)', const Color(0xFF38BDF8)),
          const SizedBox(height: 10),
          _buildInfoRow('INTELLIGENCE RATIONALE', reasoning, const Color(0xFF38BDF8)),
        ],
      ),
    );
  }

  // 4. Sandboxed Performance Simulation Card
  Widget _buildSimulationCard(Map<String, dynamic> simulation) {
    final before = simulation['before_state'] as Map<String, dynamic>? ?? {};
    final after = simulation['after_state'] as Map<String, dynamic>? ?? {};
    final metrics = simulation['impact_metrics'] as Map<String, dynamic>? ?? {};

    final beforeRoute = before['route']?.toString() ?? 'Karachi Port → M9 Toll Plaza';
    final beforeStatus = before['status']?.toString() ?? 'BLOCKED (FLOOD HAZARD)';
    
    final afterRoute = after['route']?.toString() ?? 'Karachi Port → Lyari Expressway bypass';
    final afterStatus = after['status']?.toString() ?? 'ACTIVE DISPATCH (BYPASS)';

    final delaySavings = metrics['delay_reduction']?.toString() ?? '85%';
    final riskSavings = metrics['risk_reduction']?.toString() ?? 'CRITICAL REDUCTION';
    final etaSavings = metrics['eta_improvement']?.toString() ?? '4.5 hours earlier';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFFA855F7), size: 18),
              const SizedBox(width: 8),
              Text(
                'ACTION SIMULATOR METRICS',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // BEFORE STATE
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18151D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEFORE DETOUR',
                        style: GoogleFonts.orbitron(color: const Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        beforeRoute,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        beforeStatus.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(color: const Color(0xFFEF4444), fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.double_arrow, color: Color(0xFFA855F7), size: 16),
              const SizedBox(width: 10),
              // AFTER STATE
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111C1C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPTIMIZED BYPASS',
                        style: GoogleFonts.orbitron(color: const Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        afterRoute,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        afterStatus.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(color: const Color(0xFF10B981), fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Floating metrics highlights
          Row(
            children: [
              Expanded(child: _buildMetricTile('SAVINGS', delaySavings, const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('RISK LOWERED', riskSavings, const Color(0xFF38BDF8))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('ETA GAIN', etaSavings.split(' ')[0] + ' HR', const Color(0xFFA855F7))),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Active Pipeline progress bar widget (glowing dots)
  Widget _buildPipelineStrip(bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pipelineStep('INPUT', isLoading, true),
              _arrow(),
              _pipelineStep('INSIGHT', false, !isLoading),
              _arrow(),
              _pipelineStep('DECISION', false, !isLoading),
              _arrow(),
              _pipelineStep('SIMULATION', false, !isLoading),
              _arrow(),
              _pipelineStep('ACTION', false, !isLoading),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pipelineStep(String label, bool isPulsing, bool isActive) {
    Color col = isActive ? const Color(0xFF00FFCC) : Colors.white24;
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (ctx, child) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: col,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: col.withOpacity(0.3 + (_glowController.value * 0.4)),
                        blurRadius: 6 + (_glowController.value * 6),
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.orbitron(
            color: isActive ? Colors.white : Colors.white24,
            fontSize: 7,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _arrow() {
    return const Icon(Icons.arrow_forward_ios, size: 8, color: Colors.white24);
  }

  Widget _buildMetricTile(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: col.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(color: col.withOpacity(0.8), fontSize: 7, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: GoogleFonts.orbitron(color: col, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String val, Color highlight) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              color: highlight,
              fontWeight: FontWeight.bold,
              fontSize: 8,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
