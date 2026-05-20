import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import 'stock_screen.dart';
import 'incidents_screen.dart';
import 'agent_console_screen.dart';

class TechnicalDebugScreen extends StatefulWidget {
  const TechnicalDebugScreen({super.key});

  @override
  State<TechnicalDebugScreen> createState() => _TechnicalDebugScreenState();
}

class _TechnicalDebugScreenState extends State<TechnicalDebugScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 2,
        shadowColor: const Color(0xFF00FFCC).withOpacity(0.05),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TECHNICAL CONSOLE & LOGS',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'SYSTEM DATA (TECHNICAL DEBUG ONLY)',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 7.5,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FFCC),
          labelColor: const Color(0xFF00FFCC),
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.inventory, size: 18),
              text: 'STOCK DATA',
            ),
            Tab(
              icon: Icon(Icons.warning_amber, size: 18),
              text: 'INCIDENTS FEED',
            ),
            Tab(
              icon: Icon(Icons.terminal, size: 18),
              text: 'CONSOLE LOGS',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StockScreen(),
          IncidentsScreen(),
          AgentConsoleScreen(),
        ],
      ),
    );
  }
}
