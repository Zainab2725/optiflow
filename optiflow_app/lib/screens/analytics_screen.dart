import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = ApiService();
  bool _loading = false;
  bool _ran = false;
  Map<String, dynamic>? _result;
  int _visibleSteps = 0;

  Future<void> _runAnalysis() async {
    setState(() { _loading = true; _ran = false; _result = null; _visibleSteps = 0; });
    final data = await _api.runAnalysis();
    setState(() { _result = data; _loading = false; _ran = true; });
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _visibleSteps = i);
    }
  }

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL': return AppTheme.criticalRed;
      case 'WARNING': return AppTheme.warning;
      default: return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _result?['ai_analysis']?['alerts'] as List? ?? [];
    final chain = _result?['action_chain'];
    final before = chain?['before_state'];
    final after = chain?['after_state'];
    final summary = _result?['ai_analysis']?['summary'] ?? '';

    final stepLabels = [
      'Stock Validated',
      'Procurement Notified',
      'Emergency Order Placed',
      'Customers Notified',
      'Monitoring Scheduled',
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
        ),
        title: const Text('Karachi Command'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SYSTEM INTELLIGENCE',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppTheme.primary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Text('Analytics & Prediction',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Execute button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _runAnalysis,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt, size: 18),
              label: Text(_loading
                  ? 'Analyzing 100 SKUs...'
                  : 'Execute Contingency Plan'),
            ),
          ),
          const SizedBox(height: 16),
          // ── AI Prediction box ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('AI Engine Prediction',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('LIVE ANALYSIS',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  _ran && summary.isNotEmpty
                      ? summary
                      : 'Based on current velocity trends and historical load, '
                        'a high-density bottleneck is predicted in Saddar North '
                        'within 45 minutes. System recommends immediate preemptive deployment.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Priority Directives (AI Alerts) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PRIORITY DIRECTIVES',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppTheme.onSurfaceVar)),
              Text('View All →',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_ran && alerts.isNotEmpty)
            ...alerts.map((a) => _alertCard(context, a))
          else ...[
            _staticDirective(context,
              tag: 'URGENT', tagColor: AppTheme.criticalRed,
              title: 'Reroute Priority A-7',
              subtitle: 'Critical gridlock prevention in Lyari sector',
              body: 'Fleet entering Lyari must be diverted via MT Khan road to avoid '
                  'the projected 12km gridlock. Estimated delay if not rerouted: 48 mins.',
              borderColor: AppTheme.criticalRed,
            ),
            const SizedBox(height: 12),
            _staticDirective(context,
              tag: 'OPTIMIZE', tagColor: AppTheme.primary,
              title: 'Clifton Reserve Activation',
              subtitle: 'Strategic resource rebalancing',
              body: 'Shift 15% of standby units from Clifton to Saddar buffer zones by 14:00. '
                  'Projected impact: -22% peak congestion.',
              borderColor: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            _staticDirective(context,
              tag: 'STABLE', tagColor: AppTheme.success,
              title: 'Korangi Flow Steady',
              subtitle: 'Maintenance of current status',
              body: 'Industrial corridors in Korangi maintaining 40km/h average. '
                  'No tactical adjustments required at this interval.',
              borderColor: AppTheme.outlineVar,
            ),
          ],
          // ── Action Chain steps (after running) ──
          if (_ran && _visibleSteps > 0) ...[
            const SizedBox(height: 20),
            Text('ACTION CHAIN EXECUTION',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppTheme.onSurfaceVar)),
            const SizedBox(height: 12),
            ...List.generate(_visibleSteps.clamp(0, stepLabels.length), (i) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(
                        color: AppTheme.success, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(stepLabels[i],
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text('DONE',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppTheme.success)),
                  ]),
                ),
              ),
            ),
          ],
          // ── Before / After state ──
          if (_ran && before != null && after != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _stateCard(context, 'BEFORE', before,
                  AppTheme.criticalRed)),
              const SizedBox(width: 12),
              Expanded(child: _stateCard(context, 'AFTER', after,
                  AppTheme.success)),
            ]),
          ],
          const SizedBox(height: 20),
          // ── Areal Risk Distribution ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.bar_chart, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text('Areal Risk Distribution',
                    style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  Text('Current vs Baseline',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppTheme.onSurfaceVar)),
                ]),
                const SizedBox(height: 16),
                _riskBar(context, 'Saddar', '+24% Over Baseline', 0.74,
                    AppTheme.criticalRed),
                const SizedBox(height: 10),
                _riskBar(context, 'Lyari', '+18% Over Baseline', 0.68,
                    AppTheme.criticalRed),
                const SizedBox(height: 10),
                _riskBar(context, 'Korangi', '-5% Under Baseline', 0.40,
                    AppTheme.primary),
                const SizedBox(height: 10),
                _riskBar(context, 'Clifton', '-12% Under Baseline', 0.30,
                    AppTheme.primary),
                const SizedBox(height: 12),
                Row(children: [
                  _legend(context, AppTheme.surfaceHigh, 'Historical Baseline'),
                  const SizedBox(width: 16),
                  _legend(context, AppTheme.criticalRed, 'High Risk Variance'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Aggregate Trend Chart ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVar, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.trending_up,
                    size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text('Aggregate Trend',
                    style: Theme.of(context).textTheme.headlineSmall),
                ]),
                const SizedBox(height: 16),
                SizedBox(height: 120, child: _trendChart()),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const ['06:00','12:00','18:00','00:00'].map((t) =>
                    Text(t, style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVar))
                  ).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('System Status: Nominal',
                style: Theme.of(context).textTheme.bodySmall),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Download Report'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertCard(BuildContext ctx, Map alert) {
    final color = _riskColor(alert['risk_level'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
          right: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
          bottom: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _badge(ctx, alert['sku'] ?? '', AppTheme.primary),
          const SizedBox(width: 8),
          _badge(ctx, alert['risk_level'] ?? '', color),
        ]),
        const SizedBox(height: 8),
        Text(alert['item_name'] ?? '',
          style: Theme.of(ctx).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('📍 ${alert['location'] ?? ''}',
          style: Theme.of(ctx).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(alert['reason'] ?? '',
          style: Theme.of(ctx).textTheme.bodySmall
              ?.copyWith(color: AppTheme.onSurfaceVar)),
      ]),
    );
  }

  Widget _staticDirective(BuildContext ctx, {
    required String tag, required Color tagColor,
    required String title, required String subtitle,
    required String body, required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
          top: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
          right: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
          bottom: const BorderSide(color: AppTheme.outlineVar, width: 0.5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: Theme.of(ctx).textTheme.headlineSmall),
              Text(subtitle,
                style: Theme.of(ctx).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.onSurfaceVar)),
            ]),
            _badge(ctx, tag, tagColor),
          ],
        ),
        const SizedBox(height: 10),
        Text(body,
          style: Theme.of(ctx).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.onSurfaceVar)),
      ]),
    );
  }

  Widget _stateCard(BuildContext ctx, String title,
      Map data, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: color)),
        const SizedBox(height: 8),
        Text('Risk: ${data['stockout_risk'] ?? ''}',
          style: Theme.of(ctx).textTheme.bodySmall),
        Text('Supplier: ${data['supplier_status'] ?? ''}',
          style: Theme.of(ctx).textTheme.bodySmall),
        Text('Orders: ${data['emergency_orders'] ?? 0}',
          style: Theme.of(ctx).textTheme.bodySmall),
      ]),
    );
  }

  Widget _badge(BuildContext ctx, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: color)),
    );
  }

  Widget _riskBar(BuildContext ctx, String zone, String label,
      double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(zone, style: Theme.of(ctx).textTheme.bodySmall),
          Text(label,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
      const SizedBox(height: 4),
      Stack(children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        FractionallySizedBox(
          widthFactor: value,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _legend(BuildContext ctx, Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(ctx).textTheme.labelSmall),
    ]);
  }

  Widget _trendChart() {
    final spots = [
      const FlSpot(0, 42), const FlSpot(1, 38), const FlSpot(2, 55),
      const FlSpot(3, 48), const FlSpot(4, 62), const FlSpot(5, 58),
      const FlSpot(6, 70), const FlSpot(7, 65),
    ];
    return LineChart(LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primary,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.primary.withOpacity(0.1),
          ),
        ),
      ],
    ));
  }
}
