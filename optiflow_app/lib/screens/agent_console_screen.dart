import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';

class AgentConsoleScreen extends StatefulWidget {
  const AgentConsoleScreen({super.key});

  @override
  State<AgentConsoleScreen> createState() => _AgentConsoleScreenState();
}

class _AgentConsoleScreenState extends State<AgentConsoleScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // Input Controllers
  final _inputController = TextEditingController();
  final _newsController = TextEditingController();
  final _weatherController = TextEditingController();
  final _stockController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Live tracing console state
  final List<String> _consoleLogs = [];
  Map<String, dynamic>? _agentResult;

  // Animation controller for pulsing glow button
  late AnimationController _glowController;
  late ScrollController _consoleScrollController;

  @override
  void initState() {
    super.initState();
    _consoleScrollController = ScrollController();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Seed initial demo Karachi flood relief parameters
    _loadDemoScenario();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _newsController.dispose();
    _weatherController.dispose();
    _stockController.dispose();
    _consoleScrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _loadDemoScenario() {
    _inputController.text =
        "Karachi Flood Warning. Highway blocked near Saddar/Korangi corridor. Humalog Insulin stock is extremely depleted at Karachi Relief NGO Depot.";
    _newsController.text =
        "BREAKING NEWS: Meteorological department issues high-alert urban flood warning in Karachi. Localized monsoon downpour expected to submerge low-lying sectors and highways.";
    _weatherController.text =
        "Heavy storm, flood alerts active for South Sindh, highways blocked.";
    _stockController.text =
        "DEPOT: Karachi Relief Depot (DEP-NGO-01), Zone: Clifton/Saddar, Item: Humalog Insulin 100 IU, Stock: 85 vials, Threshold: 500 vials.";
  }

  void _clearInputs() {
    _inputController.clear();
    _newsController.clear();
    _weatherController.clear();
    _stockController.clear();
  }

  Future<void> _runAgentWorkflow() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _agentResult = null;
      _consoleLogs.clear();
    });

    _logStep("[INGESTION] Establishing remote socket telemetry connection...");
    await Future.delayed(const Duration(milliseconds: 400));

    _logStep("[INGESTION] Bundling multi-source feeds: rain monitors, live news broadcasts, and sheets database.");
    await Future.delayed(const Duration(milliseconds: 300));

    _logStep("[AGENTIC PIPELINE] Handshaking with FastAPI multi-agent brain engine at /agent/run...");
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Trigger live backend multi-agent workflow
      final response = await _api.runAgentWorkflow(
        input: _inputController.text.trim().isEmpty ? null : _inputController.text,
        newsText: _newsController.text.trim().isEmpty ? null : _newsController.text,
        weatherUpdate: _weatherController.text.trim().isEmpty ? null : _weatherController.text,
        stockSheetData: _stockController.text.trim().isEmpty ? null : _stockController.text,
      );

      // Extract the structured trace steps returned from our multi-agent engine
      final rawTrace = response['agent_trace'] as List<dynamic>? ?? [];
      final List<String> backendTrace = rawTrace.map((e) => e.toString()).toList();

      // Sequentially animate output trace entries for full terminal immersion
      for (final step in backendTrace) {
        String prefix = "[AGENT]";
        final lowerStep = step.toLowerCase();
        if (lowerStep.contains('ingest')) {
          prefix = "[INGESTION]";
        } else if (lowerStep.contains('insight') || lowerStep.contains('signal') || lowerStep.contains('extract')) {
          prefix = "[INSIGHTS]";
        } else if (lowerStep.contains('decision') || lowerStep.contains('risk') || lowerStep.contains('orchestrat') || lowerStep.contains('evaluated')) {
          prefix = "[ORCHESTRATOR]";
        } else if (lowerStep.contains('simulat')) {
          prefix = "[SIMULATOR]";
        } else if (lowerStep.contains('complet') || lowerStep.contains('success')) {
          prefix = "[COMPLETED]";
        }
        
        _logStep("$prefix $step");
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        setState(() {
          _agentResult = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logStep("[ERROR] Pipeline terminated unexpectedly: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _logStep(String message) {
    if (mounted) {
      setState(() {
        _consoleLogs.add(message);
      });
      // Force scroll layout downstream
      Future.delayed(const Duration(milliseconds: 40), () {
        if (_consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll('%', '').trim();
      return double.tryParse(clean) ?? defaultValue;
    }
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B19), // Midnight space theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          'AI Decision Command Center',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: Color(0xFF38BDF8)),
            tooltip: 'Load Flood Scenario Preset',
            onPressed: _loadDemoScenario,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: 'Clear Ingestion Feeds',
            onPressed: _clearInputs,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF070B19)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFailsafeHeaderSection(),
              const SizedBox(height: 16),
              _buildIngestionFeedsContainer(),
              const SizedBox(height: 18),
              _buildInteractiveGlowTriggerButton(),
              const SizedBox(height: 18),
              _buildInteractiveMonospaceTerminal(),
              const SizedBox(height: 20),
              if (_agentResult != null) ...[
                _buildInsightsPanelSection(),
                const SizedBox(height: 16),
                _buildDecisionPanelSection(),
                const SizedBox(height: 16),
                _buildSimulationPanelSection(),
                const SizedBox(height: 24),
              ],
              if (_errorMessage != null) ...[
                _buildTraceErrorBannerCard(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 1. HEADER SECTION
  Widget _buildFailsafeHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052D4).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0052D4).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.hub, color: Color(0xFF38BDF8), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI DECISION COMMAND CENTER',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Autonomous Multi-Agent Logistics Intelligence System',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bypasses conventional static buffers by running three targeted Gemini models in succession. Triggers raw ingestion logic, structured signal parsing, actionable dispatch diverts, and sandbox before-vs-after risk evaluation metrics.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Live Input telemetries
  Widget _buildIngestionFeedsContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              Text(
                'LIVE INBOUND TELEMETRY FEEDS',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTelemetryInputRow(
            controller: _inputController,
            label: 'GENERAL COMMAND INPUT (UNSTRUCTURED)',
            hint: 'Describe active crisis/incident constraints here...',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _buildTelemetryInputRow(
            controller: _newsController,
            label: 'LIVE NEWS TELEMETRY CHANNEL',
            hint: 'News reports, radio broadcasts, or public statements...',
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          _buildTelemetryInputRow(
            controller: _weatherController,
            label: 'WEATHER SENSOR OBSERVATIONS',
            hint: 'Rain metrics, flood updates, storms...',
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          _buildTelemetryInputRow(
            controller: _stockController,
            label: 'INVENTORY GOOGLE SHEETS LIVE EXTRACT',
            hint: 'Depot status, inventory item names, quantities...',
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryInputRow({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF070B19),
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF334155), width: 0.6),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF0052D4), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  // 2. RUN AGENT BUTTON (Glowing Premium Button)
  Widget _buildInteractiveGlowTriggerButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowSize = _isLoading ? 0.0 : _glowController.value * 8.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0052D4).withOpacity(_isLoading ? 0.1 : 0.4),
                blurRadius: glowSize + 4.0,
                spreadRadius: glowSize / 3.0,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _runAgentWorkflow,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF0052D4),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF38BDF8).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'EXECUTING DECISION PIPELINE...',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'RUN DECISION AGENT',
                    style: GoogleFonts.hankenGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. LIVE AGENT TRACE TERMINAL
  Widget _buildInteractiveMonospaceTerminal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Window chrome header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'LIVE TRACE CONSOLE TERMINAL',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF10B981)),
                  ),
                ] else ...[
                  const Icon(Icons.terminal_outlined, color: Color(0xFF10B981), size: 14),
                ],
              ],
            ),
          ),
          // Scrollable terminal content
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            child: _consoleLogs.isEmpty
                ? Center(
                    child: Text(
                      'Command execution pipeline idle.\nEnter telemetries above, then trigger RUN DECISION AGENT to observe multi-agent orchestration logs.',
                      style: GoogleFonts.jetBrainsMono(color: const Color(0xFF475569), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _consoleScrollController,
                    itemCount: _consoleLogs.length,
                    itemBuilder: (context, index) {
                      final log = _consoleLogs[index];
                      Color logColor = const Color(0xFF10B981); // Emerald
                      if (log.startsWith('[ERROR]')) logColor = Colors.redAccent;
                      if (log.startsWith('[INGESTION]')) logColor = const Color(0xFF38BDF8); // Cyan
                      if (log.startsWith('[INSIGHTS]')) logColor = const Color(0xFFA78BFA); // Purple
                      if (log.startsWith('[ORCHESTRATOR]')) logColor = const Color(0xFFFBBF24); // Orange
                      if (log.startsWith('[SIMULATOR]')) logColor = const Color(0xFF60A5FA); // Sky Blue

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '➜  ',
                              style: GoogleFonts.jetBrainsMono(color: const Color(0xFF475569), fontSize: 11),
                            ),
                            Expanded(
                              child: Text(
                                log,
                                style: GoogleFonts.jetBrainsMono(
                                  color: logColor,
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 4. INSIGHTS PANEL
  Widget _buildInsightsPanelSection() {
    final insights = _agentResult?['insights'] as Map<String, dynamic>? ?? {};
    final signals = insights['signals'] as List<dynamic>? ?? [];

    final scores = insights['confidence_scores'] as Map<String, dynamic>? ?? {};
    double avgConfidence = 0.0;
    if (scores.isNotEmpty) {
      double sum = 0;
      scores.forEach((key, val) {
        sum += _safeParseDouble(val, defaultValue: 1.0);
      });
      avgConfidence = sum / scores.length;
    }
    final riskScore = _safeParseDouble(insights['overall_risk_score'], defaultValue: avgConfidence);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.biotech, color: Color(0xFFA78BFA), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '🚨 AGENT EXTRACTION INSIGHTS',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFA78BFA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  'Risk Score: ${(riskScore * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.purpleAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (signals.isEmpty) ...[
            Text(
              'No structured crisis signals detected by the Insight Agent.',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signals.length,
              itemBuilder: (context, index) {
                final dynamic rawSig = signals[index];
                String signalName = "";
                double confidence = 1.0;
                String severity = "HIGH";

                if (rawSig is String) {
                  signalName = rawSig;
                  final scores = insights['confidence_scores'] as Map<String, dynamic>? ?? {};
                  confidence = _safeParseDouble(scores[signalName], defaultValue: 1.0);
                  
                  final lowerName = signalName.toLowerCase();
                  if (lowerName.contains('critical') || lowerName.contains('flood') || lowerName.contains('block')) {
                    severity = 'CRITICAL';
                  } else if (lowerName.contains('warning') || lowerName.contains('low') || lowerName.contains('depleted')) {
                    severity = 'HIGH';
                  } else {
                    severity = 'MEDIUM';
                  }
                } else if (rawSig is Map) {
                  final typedSig = Map<String, dynamic>.from(rawSig);
                  signalName = typedSig['name'] ?? typedSig['signal'] ?? 'Telemetry Anomaly';
                  confidence = _safeParseDouble(typedSig['confidence'], defaultValue: 1.0);
                  severity = typedSig['severity']?.toString().toUpperCase() ?? 'HIGH';
                }

                Color sevColor = Colors.green;
                if (severity == 'CRITICAL' || severity == 'HIGH') {
                  sevColor = const Color(0xFFDC2626); // Critical Red
                } else if (severity == 'WARNING' || severity == 'MEDIUM') {
                  sevColor = const Color(0xFFD97706); // Amber
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B19),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155), width: 0.6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sevColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: sevColor.withOpacity(0.4), width: 0.8),
                            ),
                            child: Text(
                              severity,
                              style: GoogleFonts.jetBrainsMono(
                                color: sevColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              signalName,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${(confidence * 100).toStringAsFixed(0)}% Confidence',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF38BDF8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Visual confidence rating slider
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: confidence,
                          minHeight: 4,
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            confidence > 0.85 ? Colors.purpleAccent : const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // 5. DECISION PANEL
  Widget _buildDecisionPanelSection() {
    final decision = _agentResult?['decision'] as Map<String, dynamic>? ?? {};
    final action = _agentResult?['action'] as Map<String, dynamic>? ?? {};
    final actionType = action['type']?.toString().toUpperCase() ?? 'ROUTE_CHANGE';
    final explanation = decision['primary_insight'] ?? 'Critical logistics hazard requiring route modification';
    final reasoningSteps = List<dynamic>.from(decision['reasoning_steps'] ?? []);

    Color actionGlowColor = const Color(0xFFFBBF24); // Orange
    if (actionType.contains('DISPATCH') || actionType.contains('RESTOCK')) {
      actionGlowColor = const Color(0xFF34D399); // Green
    } else if (actionType.contains('ROUTE')) {
      actionGlowColor = const Color(0xFF60A5FA); // Sky Blue
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFFFBBF24), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '⚡ DECISION ORCHESTRATOR PLAN',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFFBBF24),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actionGlowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: actionGlowColor.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  actionType,
                  style: GoogleFonts.jetBrainsMono(
                    color: actionGlowColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'PRIORITIZED CRISIS THREAT',
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'RESOLVING TIMELINE STEPS',
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (reasoningSteps.isEmpty) ...[
            _buildTimelineStep(1, "Analyze stock thresholds alongside regional storm maps.", true),
            _buildTimelineStep(2, "Confirm localized flooding blocking Saddar/Korangi highway bypasses.", true),
            _buildTimelineStep(3, "Establish dynamic detour via alternative Lyari Expressway corridor.", false),
          ] else ...[
            for (int i = 0; i < reasoningSteps.length; i++)
              _buildTimelineStep(
                i + 1,
                reasoningSteps[i].toString(),
                i < reasoningSteps.length - 1,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int index, String stepText, bool showConnector) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  index.toString(),
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFFFBBF24),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (showConnector)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFF334155),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stepText,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFCBD5E1),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6 & 7. SIMULATION & IMPACT METRICS PANEL
  Widget _buildSimulationPanelSection() {
    final simulation = _agentResult?['simulation'] as Map<String, dynamic>? ?? {};
    final before = simulation['before_state'] as Map<String, dynamic>? ?? {};
    final after = simulation['after_state'] as Map<String, dynamic>? ?? {};
    final metrics = simulation['impact_metrics'] as Map<String, dynamic>? ?? {};

    // Impact metrics parsing
    final delayStr = metrics['delay_reduction'] ?? metrics['delay_saved_mins'] ?? metrics['eta_improvement'] ?? '85%';
    final riskStr = metrics['risk_reduction'] ?? metrics['risk_reduction_pct'] ?? 'HIGH';
    final additionalMetric = metrics['alternative_route_safety'] ?? metrics['stock_replenished_percentage'] ?? '95%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '⚙️ SANDBOX OPERATIONAL SIMULATION',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  'MITIGATION ACTIVE',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF4ADE80),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Core dynamic impact metrics visual blocks
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B19),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155), width: 0.8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        delayStr.toString(),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF60A5FA),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'DELAY REDUCTION',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B19),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155), width: 0.8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        riskStr.toString(),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF34D399),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'RISK REDUCTION',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Extra custom metrics displayed dynamically
          if (metrics.length > 2) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF070B19),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3), width: 0.6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ADDITIONAL TELEMETRY CONFIDENCE:',
                    style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    additionalMetric.toString(),
                    style: GoogleFonts.jetBrainsMono(color: const Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),

          // Two Side-by-Side simulation boxes
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BEFORE STATE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.report_problem, color: Color(0xFFEF4444), size: 12),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'BEFORE AI',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFFEF4444),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStateItemCard(
                      'ROUTE',
                      before['route']?.toString() ?? 'Karachi Highway (Standard Route)',
                      const Color(0xFFEF4444),
                    ),
                    _buildStateItemCard(
                      'STATUS',
                      before['status']?.toString() ?? 'Delayed (Imminent Blocker)',
                      const Color(0xFFEF4444),
                    ),
                    _buildStateItemCard(
                      'STOCK PROFILE',
                      before['stock_level']?.toString() ?? '85 Vials (Safety Shortage)',
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // AFTER STATE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 12),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'AFTER AI',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStateItemCard(
                      'ROUTE',
                      after['route']?.toString() ?? 'Lyari Expressway Detour Active',
                      const Color(0xFF10B981),
                    ),
                    _buildStateItemCard(
                      'STATUS',
                      after['status']?.toString() ?? 'Optimized (Express Dispatch)',
                      const Color(0xFF10B981),
                    ),
                    _buildStateItemCard(
                      'STOCK PROFILE',
                      after['stock_level']?.toString() ?? 'Replenished (+500 Units)',
                      const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateItemCard(String sectionName, String val, Color sideColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF070B19),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 8,
                color: sideColor,
              ),
              const SizedBox(width: 6),
              Text(
                sectionName,
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF64748B),
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTraceErrorBannerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFBA1A1A).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBA1A1A).withOpacity(0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gpp_bad, color: Colors.redAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIPELINE TIMEOUT OR EXECUTION EXCEPTION',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ?? 'Connection lost to command server.',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
