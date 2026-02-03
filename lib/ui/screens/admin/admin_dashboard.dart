import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:loghr_mobile/ui/widgets/dashboard_widgets.dart';
import 'package:loghr_mobile/logic/admin_provider.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_payroll_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_employees_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_reports_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_announcements_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/my_payroll_screen.dart';
import 'package:loghr_mobile/ui/screens/admin/admin_leave_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/attendance_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/performance_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/training_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/helpdesk_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex == 0) {
        context.read<AdminProvider>().loadDashboardData();
      }
    });
  }
  
  // Reusing the screen mapping from AdminMainScreen effectively, 
  // but usually AdminDashboard is just the dashboard *tab* of AdminMainScreen.
  // Assuming AdminDashboard is just the content widget here based on previous structure, 
  // but looking at the file it seems it has its own BottomNavBar logic which duplicates AdminMainScreen.
  // The user prompt was to update Dashboard details, so I will focus on _buildDashboardContent.
  
  Widget _buildDashboardContent() {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dashboard Overview',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'FIRSTMETA INFRASTRUCTURE...',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF137FEC),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF137FEC).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          DateFormat('EEE, MMM d, yyyy').format(DateTime.now()),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Stats Grid with Gradients
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: Consumer<AdminProvider>(
              builder: (context, adminProvider, _) {
                final formatCurrency = NumberFormat.compactCurrency(symbol: adminProvider.currency == 'INR' ? '₹' : adminProvider.currency, decimalDigits: 1);
                
                return SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    DashboardStatCard(
                      title: 'Total Employees',
                      value: '${adminProvider.totalEmployees}',
                      icon: Icons.people_outline,
                      baseColor: const Color(0xFF1E88E5),
                      backgroundColor: const Color(0xFFE3F2FD),
                      gradient: [const Color(0xFFE3F2FD), Colors.white],
                    ),
                    DashboardStatCard(
                      title: 'Active Today',
                      value: '${adminProvider.activeToday}',
                      subValue: '/${adminProvider.totalActive}',
                      icon: Icons.trending_up,
                      baseColor: const Color(0xFF43A047),
                      backgroundColor: const Color(0xFFE8F5E9),
                      gradient: [const Color(0xFFE8F5E9), Colors.white],
                    ),
                    DashboardStatCard(
                      title: 'Leave Pending',
                      value: '${adminProvider.pendingLeaves}',
                      icon: Icons.calendar_today_outlined,
                      baseColor: const Color(0xFFFDD835),
                      backgroundColor: const Color(0xFFFFFDE7),
                      gradient: [const Color(0xFFFFFDE7), Colors.white],
                    ),
                    DashboardStatCard(
                      title: 'Payroll This Month',
                      value: formatCurrency.format(adminProvider.monthlyPayroll),
                      icon: Icons.account_balance_wallet_outlined,
                      baseColor: const Color(0xFF8E24AA),
                      backgroundColor: const Color(0xFFF3E5F5),
                      gradient: [const Color(0xFFF3E5F5), Colors.white],
                    ),
                    DashboardStatCard(
                      title: 'Expenses Pending',
                      value: '${adminProvider.pendingExpenses}',
                      icon: Icons.receipt_long_outlined,
                      baseColor: const Color(0xFFE53935),
                      backgroundColor: const Color(0xFFFFEBEE),
                      gradient: [const Color(0xFFFFEBEE), Colors.white],
                    ),
                    DashboardStatCard(
                      title: 'Birthdays (7d)',
                      value: '${adminProvider.upcomingBirthdays}',
                      icon: Icons.cake_outlined,
                      baseColor: const Color(0xFFD81B60),
                      backgroundColor: const Color(0xFFFCE4EC),
                      gradient: [const Color(0xFFFCE4EC), Colors.white],
                    ),
                  ],
                );
              },
            ),
          ),

          // Monthly Payroll Summary
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Consumer<AdminProvider>(
                builder: (context, adminProvider, _) {
                  return PayrollSummarySection(
                    totalAmount: adminProvider.monthlyPayroll,
                    paidCount: adminProvider.paidCount,
                    pendingCount: adminProvider.pendingPayrollCount,
                    processingCount: adminProvider.processingPayrollCount,
                    currency: adminProvider.currency,
                  );
                },
              ),
            ),
          ),

          // Department Stats & Tasks Row (Grid of 2)
          SliverPadding(
             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
             sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85, 
                children: [
                   Consumer<AdminProvider>(
                     builder: (context, provider, _) => _buildDepartmentStatsCard(context, provider.departmentStats),
                   ),
                   Consumer<AdminProvider>(
                     builder: (context, provider, _) => _buildTasksOverviewCard(context, provider.tasksStats),
                   ),
                ],
             ),
          ),


          // Right Column Content (Salary Due, Birthdays, Leaves)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Consumer<AdminProvider>(
                builder: (context, adminProvider, _) {
                  return Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UpcomingBirthdaysCard(birthdays: adminProvider.upcomingBirthdaysList),
                      const SizedBox(height: 20),
                      SalaryDueList(salaryDueList: adminProvider.salaryDueList),
                      const SizedBox(height: 20),
                      LeaveBalanceCard(leaveBalances: adminProvider.leaveBalances),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentStatsCard(BuildContext context, List<Map<String, dynamic>> stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Department Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            Expanded(
              child: stats.isEmpty 
                ? const Center(child: Text('No data', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 20,
                      sections: stats.map((stat) {
                        return PieChartSectionData(
                          color: Color(stat['color'] as int),
                          value: (stat['count'] as num).toDouble(),
                          title: '${stat['count']}',
                          radius: 30,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            // Legend (Limited to 2 items to fit)
            ...stats.take(2).map((stat) => 
               Padding(
                 padding: const EdgeInsets.only(bottom: 4),
                 child: Row(
                   children: [
                     Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(stat['color']), shape: BoxShape.circle)),
                     const SizedBox(width: 8),
                     Expanded(child: Text(stat['name'], style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.black87), overflow: TextOverflow.ellipsis)),
                   ],
                 ),
               )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksOverviewCard(BuildContext context, Map<String, dynamic> stats) {
     final completionRate = (stats['completion_rate'] as num?)?.toDouble() ?? 0.0;
     final completed = stats['completed'] as int? ?? 0;
     final total = stats['total'] as int? ?? 0;

     return Card(
      elevation: 0,
       color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text('Tasks Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               ],
             ),
             const SizedBox(height: 8),
             Text('Completion Rate', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
             Text('${completionRate.toInt()}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[600])),
             const SizedBox(height: 12),
             LinearProgressIndicator(
               value: completionRate / 100,
               backgroundColor: Colors.green.withOpacity(0.1),
               color: Colors.green,
               borderRadius: BorderRadius.circular(4),
             ),
             const Spacer(),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildTaskStatItem('Completed', '$completed', Colors.green),
                 _buildTaskStatItem('Total', '$total', Colors.blue),
               ],
             )
          ],
        ),
      ),
     );
  }

  Widget _buildTaskStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // Currently AdminMainScreen handles the bottom nav and switching. 
  // AdminDashboard acts as the content for the first tab.
  @override
  Widget build(BuildContext context) {
    return _buildDashboardContent();
  }
}
