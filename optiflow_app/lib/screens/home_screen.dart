import 'package:flutter/material.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'stock_screen.dart';
import 'incidents_screen.dart';
import 'dispatch_screen.dart';
import 'analytics_screen.dart';
import 'agent_console_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    StockScreen(),
    IncidentsScreen(),
    DispatchScreen(),
    AnalyticsScreen(),
    AgentConsoleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.outlineVar, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_outlined),
              activeIcon: Icon(Icons.space_dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_outlined),
              activeIcon: Icon(Icons.warning_amber),
              label: 'Incidents',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'Dispatch',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'AI Assistant',
            ),
          ],
        ),
      ),
    );
  }
}
