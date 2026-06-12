import 'package:flutter/material.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_dashboard.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_employees_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_team_management_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_reports_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_tasks_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_loan_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_payroll_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_announcements_screen.dart';
import 'package:loghr_mobile/ui/screens/shared/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/notification_provider.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  final ScrollController _navScrollController = ScrollController();
  
  late final List<Widget> _screens;
  late final List<Map<String, dynamic>> _navItems;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<NotificationProvider>().initRealtimeNotifications(user.id);
      }
    });

    _navItems = [
      {'label': 'Dashboard', 'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard},
      {'label': 'People', 'icon': Icons.people_outline, 'selectedIcon': Icons.people},
      {'label': 'Team Mgmt', 'icon': Icons.calendar_today_outlined, 'selectedIcon': Icons.calendar_today},
      {'label': 'Reports', 'icon': Icons.description_outlined, 'selectedIcon': Icons.description},
      {'label': 'Tasks', 'icon': Icons.check_circle_outline, 'selectedIcon': Icons.check_circle},
      {'label': 'Loans', 'icon': Icons.account_balance_wallet_outlined, 'selectedIcon': Icons.account_balance_wallet},
      {'label': 'Payroll', 'icon': Icons.payments_outlined, 'selectedIcon': Icons.payments},
      {'label': 'Announcements', 'icon': Icons.campaign_outlined, 'selectedIcon': Icons.campaign},
      {'label': 'Expenses', 'icon': Icons.receipt_long_outlined, 'selectedIcon': Icons.receipt_long},
      {'label': 'Training', 'icon': Icons.school_outlined, 'selectedIcon': Icons.school},
      {'label': 'Settings', 'icon': Icons.settings_outlined, 'selectedIcon': Icons.settings},
    ];

    _screens = [
      const AdminDashboard(),
      const AdminEmployeesScreen(),
      const AdminTeamManagementScreen(),
      const AdminReportsScreen(),
      const AdminTasksScreen(),
      const AdminLoanScreen(),
      const AdminPayrollScreen(),
      const AdminAnnouncementsScreen(),
      _buildPlaceholder('Expenses'),
      _buildPlaceholder('Training'),
      SettingsScreen(onNavigateToDashboard: () => _onItemTapped(0)),
    ];
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '$title coming soon',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ListView.builder(
          controller: _navScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _navItems.length,
          itemBuilder: (context, index) {
            final item = _navItems[index];
            final isSelected = _currentIndex == index;
            final color = isSelected ? const Color(0xFF1565C0) : Colors.grey.shade500;
            
            return InkWell(
              onTap: () => _onItemTapped(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item['selectedIcon'] : item['icon'],
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'],
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: isSelected ? 20 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Ensure this matches the NavItem expected by AdminNavigationDrawer
// Or better, import it from admin_navigation_drawer.dart and delete this class definition to avoid conflict if I didn't import the file properly.
// I will import the file at the top and remove this class.

