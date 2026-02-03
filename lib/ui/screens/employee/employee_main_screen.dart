import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/theme_provider.dart';
import 'package:loghr_mobile/ui/screens/employee/employee_dashboard.dart';
import 'package:loghr_mobile/ui/screens/employee/attendance_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/leave_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/profile_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/announcements_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/task_management_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/performance_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/loan_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/expense_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/loyalty_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/policies_screen.dart';

import 'package:loghr_mobile/ui/screens/employee/calendar_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/my_payroll_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/settings_screen.dart';
import 'package:loghr_mobile/logic/notification_provider.dart';


class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<NotificationProvider>().initRealtimeNotifications(user.id);
      }
    });
  }
  final Map<int, Widget> _screenCache = {};
  final GlobalKey<AttendanceScreenState> _attendanceScreenKey = GlobalKey<AttendanceScreenState>();

  final List<NavItem> _navItems = [
    NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    NavItem(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'My Payroll',
    ),
    NavItem(
      icon: Icons.assignment_turned_in_outlined,
      selectedIcon: Icons.assignment_turned_in,
      label: 'Tasks',
    ),
    NavItem(
      icon: Icons.stars_outlined,
      selectedIcon: Icons.stars,
      label: 'Loyalty',
    ),
    NavItem(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
      label: 'Performance',
    ),
    NavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
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
      label: 'Loan',
    ),
    NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Expenses',
    ),
    NavItem(
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      label: 'Announcements',
    ),
    NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
    NavItem(
      icon: Icons.policy_outlined,
      selectedIcon: Icons.policy,
      label: 'Policies',
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

  Widget _getScreen(int index) {
    if (_screenCache.containsKey(index)) {
      return _screenCache[index]!;
    }

    Widget screen;
    switch (index) {
      case 0:
        screen = EmployeeDashboard(
          onNavigateToScreen: _onItemTapped,
        );
        break;
      case 1:
        screen = MyPayrollScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 2:
        screen = TaskManagementScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 3:
        screen = LoyaltyScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 4:
        screen = PerformanceScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 5:
        screen = ProfileScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 6:
        screen = AttendanceScreen(
          key: _attendanceScreenKey,
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 7:
        screen = LeaveScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 8:
        screen = LoanScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 9:
        screen = ExpenseScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 10:
        screen = AnnouncementsScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      case 11:
        screen = SettingsScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;

      case 12:
        screen = PoliciesScreen(
          onNavigateToDashboard: () => _onItemTapped(0),
        );
        break;
      default:
        screen = const SizedBox();
    }

    _screenCache[index] = screen;
    return screen;
  }

  void _navigateToAttendanceWithTab(int tabIndex) {
    setState(() {
      _currentIndex = 6; // Navigate to Attendance screen
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final navShadowColor = isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05);

    // Create screens for IndexedStack - only create screens that have been accessed
    // This ensures lazy loading while preserving state for visited screens
    final screens = <Widget>[];
    for (int i = 0; i < 13; i++) {
      if (i == _currentIndex || _screenCache.containsKey(i)) {
        screens.add(_getScreen(i));
      } else {
        // Placeholder to maintain index
        screens.add(const SizedBox.shrink());
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: navBgColor,
          boxShadow: [
            BoxShadow(
              color: navShadowColor,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _navItems.length,
          itemBuilder: (context, index) {
            final item = _navItems[index];
            final isSelected = _currentIndex == index;
            final selectedColor = Colors.blue.shade600;
            final unselectedColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

            return InkWell(
              onTap: () => _onItemTapped(index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? selectedColor : unselectedColor,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? selectedColor : unselectedColor,
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

class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

