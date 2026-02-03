import 'package:flutter/material.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_dashboard.dart';
import 'package:loghr_mobile/ui/screens/employee/attendance_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_leave_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/announcements_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/training_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/performance_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/helpdesk_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_payroll_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_employees_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_reports_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_announcements_screen.dart';
import 'package:loghr_mobile/ui/widgets/admin_navigation_drawer.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_attendance_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_loan_screen.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/notification_provider.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  late final List<Widget> _screens;

  final List<NavItem> _navItems = [
    NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    NavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'Payroll',
    ),
    NavItem(
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      label: 'Reports',
    ),
    NavItem(
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
      label: 'Tasks',
    ),
    NavItem(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Work Reports',
    ),
    NavItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Employees',
    ),
    NavItem(
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time,
      label: 'Attendance',
    ),
    NavItem(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Leave',
    ),
    NavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'Loans',
    ),
    NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Expenses',
    ),
    NavItem(
      icon: Icons.trending_up_outlined,
      selectedIcon: Icons.trending_up,
      label: 'Performance',
    ),
    NavItem(
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      label: 'Training',
    ),
    NavItem(
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent,
      label: 'Helpdesk',
    ),
    NavItem(
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      label: 'Announcements',
    ),
    NavItem(
      icon: Icons.help_outline,
      selectedIcon: Icons.help,
      label: 'Help & Guide',
    ),
    NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  Widget _buildPlaceholderScreen(String title) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade600,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 64,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<NotificationProvider>().initRealtimeNotifications(user.id);
      }
    });

    // Order must match _navItems order
    _screens = [
      const AdminDashboard(),              // 0 - Dashboard
      const AdminPayrollScreen(),          // 1 - Payroll
      const AdminReportsScreen(),          // 2 - Reports
      _buildPlaceholderScreen('Tasks'),    // 3 - Tasks
      _buildPlaceholderScreen('Work Reports'), // 4 - Work Reports
      const AdminEmployeesScreen(),        // 5 - Employees
      const AdminAttendanceScreen(),       // 6 - Attendance
      const AdminLeaveScreen(),            // 7 - Leave
      const AdminLoanScreen(),             // 8 - Loans
      _buildPlaceholderScreen('Expenses'),  // 9 - Expenses
      const PerformanceScreen(),           // 10 - Performance
      const TrainingScreen(),              // 11 - Training
      const HelpdeskScreen(),              // 12 - Helpdesk
      const AdminAnnouncementsScreen(),    // 13 - Announcements
      _buildPlaceholderScreen('Help & Guide'), // 14 - Help & Guide
      _buildPlaceholderScreen('Settings'), // 15 - Settings
    ];
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
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildScrollableBottomBar(isDark),
    );
  }

  Widget _buildScrollableBottomBar(bool isDark) {
    return Container(
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
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isSelected = _currentIndex == index;
            final activeColor = Colors.blue.shade700;
            
            return InkWell(
              onTap: () => _onItemTapped(index),
              child: Container(
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? activeColor : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? activeColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// Ensure this matches the NavItem expected by AdminNavigationDrawer
// Or better, import it from admin_navigation_drawer.dart and delete this class definition to avoid conflict if I didn't import the file properly.
// I will import the file at the top and remove this class.

