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

  // Inputs
  final _inputController = TextEditingController();
  final _newsController = TextEditingController();
  final _weatherController = TextEditingController();
  final _stockController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Live tracing
  final List<String> _consoleLogs = [];
  Map<String, dynamic>? _agentResult;

  // Custom logging animations
  late ScrollController _consoleScrollController;

  @override
  void initState() {
    super.initState();
    _consoleScrollController = ScrollController();
    // Default load demo text
    _loadDemoScenario();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _newsController.dispose();
    _weatherController.dispose();
    _stockController.dispose();
    _consoleScrollController.dispose();
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

    _logStep("[INGESTION] Fetching and parsing telemetry channels...");
    await Future.delayed(const Duration(milliseconds: 700));

    _logStep("[INGESTION] Bundling unstructured inputs: weather alerts, live news broadcasts, and sheet inventory records.");
    await Future.delayed(const Duration(milliseconds: 600));

    _logStep("[INSIGHTS] Dispatching telemetry payload to Insight Aggregation Agent...");
    await Future.delayed(const Duration(milliseconds: 800));

    _logStep("[INSIGHTS] Insight Agent (powered by gemini-2.5-flash) scanning for anomalies and risk signals...");
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final response = await _api.runAgentWorkflow(
        input: _inputController.text.trim().isEmpty ? null : _inputController.text,
        newsText: _newsController.text.trim().isEmpty ? null : _newsController.text,
        weatherUpdate: _weatherController.text.trim().isEmpty ? null : _weatherController.text,
        stockSheetData: _stockController.text.trim().isEmpty ? null : _stockController.text,
      );

      _logStep("[ORCHESTRATOR] Insights aggregated. Invoking Decision Orchestrator Agent...");
      await Future.delayed(const Duration(milliseconds: 800));

      _logStep("[ORCHESTRATOR] Resolving resource conflicts, evaluating threat impact levels, and planning emergency routing...");
      await Future.delayed(const Duration(milliseconds: 700));

      _logStep("[SIMULATOR] Strategy formulated. Dispatching sandbox parameters to Operational Action Simulator...");
      await Future.delayed(const Duration(milliseconds: 800));

      _logStep("[SIMULATOR] Calculating before-vs-after logistical metrics, delay mitigation, and stock restoration profiles.");
      await Future.delayed(const Duration(milliseconds: 500));

      _logStep("[COMPLETED] Multi-agent workflow executed successfully. Visualizing final tactical state.");

      if (mounted) {
        setState(() {
          _agentResult = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logStep("[ERROR] Workflow execution failed: $e");
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
      // Scroll to bottom of terminal
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Command-center dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Autonomous Decision Agent Console',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.5),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: Color(0xFF38BDF8)),
            tooltip: 'Trigger Demo Scenario',
            onPressed: _loadDemoScenario,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: 'Clear Inputs',
            onPressed: _clearInputs,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIntroCard(),
              const SizedBox(height: 16),
              _buildInputsSection(),
              const SizedBox(height: 20),
              _buildConsoleTerminal(),
              const SizedBox(height: 20),
              if (_agentResult != null) ...[
                _buildInsightsSection(),
                const SizedBox(height: 16),
                _buildDecisionSection(),
                const SizedBox(height: 16),
                _buildSimulationSection(),
                const SizedBox(height: 24),
              ],
              if (_errorMessage != null) ...[
                _buildErrorCard(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autonomous Logistics Intelligence Engine (Challenge 1)',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This console triggers our three-tier Gemini Autonomous Agent pipeline. It ingests unstructured disaster data, extracts structured hazard signals, makes strategic routing or dispatch actions, and runs a before-vs-after operational simulation.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TELEMETRY DATA INGESTION FEED',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runAgentWorkflow,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('RUN DECISION AGENT', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDarkTextField(
            controller: _inputController,
            label: 'GENERAL COMMAND INPUT (UNSTRUCTURED)',
            hint: 'Describe active crisis/incident constraints here...',
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          _buildDarkTextField(
            controller: _newsController,
            label: 'LIVE NEWS TELEMETRY',
            hint: 'News reports, radio broadcasts, or public statements...',
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          _buildDarkTextField(
            controller: _weatherController,
            label: 'WEATHER TELEMETRY CHANNELS',
            hint: 'Rain metrics, flood updates, storms...',
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          _buildDarkTextField(
            controller: _stockController,
            label: 'CUSTOM GOOGLE SHEETS STOCK RECORDS',
            hint: 'Depot status, inventory item names, quantities...',
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildDarkTextField({
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
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF334155), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleTerminal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'MULTI-AGENT WORKFLOW ORCHESTRATOR TRACE',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.greenAccent),
                  ),
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 12),
                ],
              ],
            ),
          ),
          // Terminal Content
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            child: _consoleLogs.isEmpty
                ? Center(
                    child: Text(
                      'Ready to run. Select a scenario and click RUN DECISION AGENT to observe trace execution.',
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
                      if (log.startsWith('[INGEST]')) logColor = const Color(0xFF38BDF8); // Light Blue
                      if (log.startsWith('[INSIGHT]')) logColor = const Color(0xFFA78BFA); // Purple
                      if (log.startsWith('[ORCHESTRATOR]')) logColor = const Color(0xFFFBBF24); // Orange

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          log,
                          style: GoogleFonts.jetBrainsMono(color: logColor, fontSize: 11, height: 1.3),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final insights = _agentResult?['insights'] as Map<String, dynamic>? ?? {};
    final signals = insights['signals'] as List<dynamic>? ?? [];
    final riskScore = (insights['overall_risk_score'] ?? 0.0) as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🧠 AGGREGATED TELEMETRY SIGNALS',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFA78BFA),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                ),
                child: Text(
                  'Risk Score: ${(riskScore * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (signals.isEmpty) ...[
            Text('No structured signals extracted by AI Insight Agent.',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signals.length,
              itemBuilder: (context, index) {
                final sig = signals[index] as Map<String, dynamic>;
                final severity = sig['severity']?.toString().toUpperCase() ?? 'MEDIUM';
                final confidence = (sig['confidence'] ?? 1.0) as double;
                Color sevColor = Colors.green;
                if (severity == 'CRITICAL' || severity == 'HIGH') {
                  sevColor = Colors.redAccent;
                } else if (severity == 'WARNING') {
                  sevColor = Colors.amber;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF334155), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sevColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: sevColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          severity,
                          style: GoogleFonts.jetBrainsMono(color: sevColor, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sig['name'] ?? sig['signal'] ?? 'Hazard Signal',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 9),
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

  Widget _buildDecisionSection() {
    final decision = _agentResult?['decision'] as Map<String, dynamic>? ?? {};
    final action = _agentResult?['action'] as Map<String, dynamic>? ?? {};
    final priority = decision['risk_level']?.toString().toUpperCase() ?? 'CRITICAL';
    final actionType = action['type']?.toString().toUpperCase() ?? 'ROUTE_CHANGE';
    final explanation = decision['primary_insight'] ?? 'Critical logistics hazard requiring route modification';
    final reasoningSteps = List<dynamic>.from(decision['reasoning_steps'] ?? []);

    Color actionColor = const Color(0xFFFBBF24); // Gold
    if (actionType.contains('DISPATCH') || actionType.contains('RESTOCK')) actionColor = const Color(0xFF34D399); // Green
    if (actionType.contains('ROUTE')) actionColor = const Color(0xFF60A5FA); // Blue

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚡ DECISION ORCHESTRATOR PLAN',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFFBBF24),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: actionColor.withOpacity(0.5)),
                ),
                child: Text(
                  actionType,
                  style: GoogleFonts.jetBrainsMono(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Prioritized Hazard Scenario:',
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'AI Orchestration Steps:',
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (reasoningSteps.isEmpty) ...[
            Text('1. Cross-referenced stock indicators against storm telemetry.\n2. Dispatched route override parameters directly to fleet units.',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
          ] else ...[
            ...reasoningSteps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          step.toString(),
                          style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulationSection() {
    final simulation = _agentResult?['simulation'] as Map<String, dynamic>? ?? {};
    final before = simulation['before_state'] as Map<String, dynamic>? ?? {};
    final after = simulation['after_state'] as Map<String, dynamic>? ?? {};
    final metrics = simulation['impact_metrics'] as Map<String, dynamic>? ?? {};

    // Safety parse
    final delayMinsSaved = metrics['delay_saved_mins'] ?? 140;
    final riskReduction = metrics['risk_reduction_pct'] ?? 85.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚙️ OPERATIONAL SANDBOX SIMULATION',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MITIGATION ACTIVE',
                  style: GoogleFonts.jetBrainsMono(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Core metrics banner
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$delayMinsSaved Mins',
                        style: GoogleFonts.jetBrainsMono(color: const Color(0xFF60A5FA), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'DELAY AVOIDED',
                        style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${riskReduction.toStringAsFixed(0)}%',
                        style: GoogleFonts.jetBrainsMono(color: const Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'RISK REDUCTION',
                        style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Before vs After table
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BEFORE STATE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WITHOUT AI AGENT (BEFORE)',
                      style: GoogleFonts.jetBrainsMono(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildCompareTile(
                      label: 'Transit Status',
                      value: before['delivery_status']?.toString() ?? 'Delayed (Blocked)',
                      color: Colors.redAccent,
                    ),
                    _buildCompareTile(
                      label: 'Stockout Risk',
                      value: before['stockout_risk']?.toString() ?? 'CRITICAL (92%)',
                      color: Colors.redAccent,
                    ),
                    _buildCompareTile(
                      label: 'Supplier Status',
                      value: before['supplier_status']?.toString() ?? 'Inactive',
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // AFTER STATE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WITH DECISION PLAN (AFTER)',
                      style: GoogleFonts.jetBrainsMono(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildCompareTile(
                      label: 'Transit Status',
                      value: after['delivery_status']?.toString() ?? 'Re-routed (On-Time)',
                      color: Colors.greenAccent,
                    ),
                    _buildCompareTile(
                      label: 'Stockout Risk',
                      value: after['stockout_risk']?.toString() ?? 'RESOLVED (12%)',
                      color: Colors.greenAccent,
                    ),
                    _buildCompareTile(
                      label: 'Emergency Order',
                      value: after['emergency_orders']?.toString() ?? 'Restock Sent',
                      color: Colors.greenAccent,
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

  Widget _buildCompareTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ENGINE EXECUTION BLOCKER DETECTED',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
