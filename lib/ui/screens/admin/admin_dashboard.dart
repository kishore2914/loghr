import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Retaining for pie chart
import 'package:loghr_mobile/logic/admin_provider.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/ui/widgets/admin_dashboard_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDashboardData();
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<ProfileProvider>().loadProfile(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<AdminProvider>().loadDashboardData();
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Consumer2<AdminProvider, ProfileProvider>(
              builder: (context, adminProvider, profileProvider, _) {
                final orgName = profileProvider.organizationData?['name'] ?? 'Loading...';
                final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

                // Mock Attention Items based on stats
                final attentionItems = [
                  if (adminProvider.pendingLeaves > 0)
                    AttentionItem(
                      title: 'Leave Requests',
                      subtitle: '${adminProvider.pendingLeaves} pending approval',
                      actionLabel: 'Review',
                      icon: Icons.calendar_today,
                      color: const Color(0xFFFDD835), // Amber
                      onTap: () {
                         // TODO: Navigate to Leave Request tab (Index 2 in main screen)
                      },
                    ),
                  if (adminProvider.pendingExpenses > 0)
                    AttentionItem(
                      title: 'Expense Claims',
                      subtitle: '${adminProvider.pendingExpenses} pending claims',
                      actionLabel: 'Verify',
                      icon: Icons.receipt_long,
                      color: const Color(0xFFE53935), // Red
                      onTap: () {},
                    ),
                   // Always show payroll generic item if no data, purely for demo of layout
                   AttentionItem(
                      title: 'Payroll Cycle',
                      subtitle: 'Next cycle starts in 5 days',
                      actionLabel: 'Manage',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF1565C0), // Blue
                      onTap: () {},
                    ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header
                    DashboardHeader(
                      organizationName: orgName,
                      date: dateStr,
                      onSearchTap: () {
                        // TODO: Open global search
                      },
                    ),

                    // 2. Primary Stats (Two big cards)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 160, // Fixed height for consistency
                              child: PrimaryStatCard(
                                title: 'Total Employees',
                                value: '${adminProvider.totalEmployees}',
                                icon: Icons.people,
                                baseColor: const Color(0xFF1565C0), // Deep Blue
                                backgroundColor: const Color(0xFFE3F2FD), // Light Blue
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: PrimaryStatCard(
                                title: 'Active Today',
                                value: '${adminProvider.activeToday}',
                                subValue: '${(adminProvider.activeToday / (adminProvider.totalActive == 0 ? 1 : adminProvider.totalActive) * 100).toInt()}%',
                                icon: Icons.check_circle,
                                baseColor: const Color(0xFF00BFA5), // Teal
                                backgroundColor: const Color(0xFFE0F2F1), // Light Teal
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Secondary Stats Carousel
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            SecondaryStatCard(
                              title: 'Leave Pending',
                              value: '${adminProvider.pendingLeaves}',
                              color: const Color(0xFFFDD835), // Amber
                              icon: Icons.calendar_today_outlined,
                            ),
                            SecondaryStatCard(
                              title: 'Expenses',
                              value: '${adminProvider.pendingExpenses}',
                              color: const Color(0xFFE53935), // Red
                              icon: Icons.receipt_long_outlined,
                            ),
                            SecondaryStatCard(
                              title: 'On Leave',
                              value: '${adminProvider.onLeaveToday}',
                              color: Colors.orange,
                              icon: Icons.beach_access_outlined,
                            ),
                            SecondaryStatCard(
                              title: 'Tasks Due',
                              value: '${adminProvider.tasksStats['pending'] ?? 0}', // Use actual task stat if available
                              color: Colors.purple,
                              icon: Icons.task_alt,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Attention Needed Section
                    AttentionSection(items: attentionItems),

                    const SizedBox(height: 24),

                    // 5. Department Stats (Retaining Chart for depth)
                    if (adminProvider.departmentStats.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Department Distribution',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Simplified chart container for now
                      Container(
                        height: 200,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                           color: Theme.of(context).cardColor,
                           borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                  sections: adminProvider.departmentStats.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final stat = entry.value;
                                    final color = stat['color'] != null 
                                        ? Color(stat['color'] as int) 
                                        : Colors.primaries[index % Colors.primaries.length];
                                        
                                    return PieChartSectionData(
                                      color: color,
                                      value: (stat['count'] as num).toDouble(),
                                      title: '${stat['count']}',
                                      radius: 40,
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: adminProvider.departmentStats.take(4).map((stat) {
                                   return Padding(
                                     padding: const EdgeInsets.only(bottom: 8),
                                     child: Row(
                                       children: [
                                         Container(
                                           width: 10, height: 10,
                                           decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: stat['color'] != null ? Color(stat['color']) : Colors.grey,
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: Text(
                                             stat['name'],
                                             style: const TextStyle(fontSize: 12),
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         ),
                                       ],
                                     ),
                                   );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
