import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/attendance_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/logic/task_provider.dart';
import 'package:loghr_mobile/data/services/performance_service.dart';
import 'package:loghr_mobile/data/models/task.dart';
import 'package:loghr_mobile/data/models/performance_review.dart';
import 'package:loghr_mobile/ui/widgets/dashboard_widgets.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/data/models/attendance.dart';

class EmployeeDashboard extends StatefulWidget {
  final Function(int)? onNavigateToScreen;
  
  const EmployeeDashboard({
    super.key,
    this.onNavigateToScreen,
  });

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  List<Task> _recentTasks = [];
  List<PerformanceReview> _recentReviews = [];
  bool _isLoadingTasks = false;
  bool _isLoadingReviews = false;
  double _avgProgress = 0.0;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      context.read<ProfileProvider>().loadProfile(user.id);
      context.read<AttendanceProvider>().loadTodayAttendance(user.id);
      context.read<AttendanceProvider>().loadHistory(user.id);
      context.read<LeaveProvider>().loadLeaveBalances(user.id);
      context.read<LeaveProvider>().loadUserLeaves(user.id);
      _loadRecentTasks(user.id);
      _loadRecentReviews(user.id);
      _loadPerformanceStats(user.id);
    }
  }

  Future<void> _loadPerformanceStats(String userId) async {
    setState(() => _isLoadingStats = true);
    try {
      final performanceService = PerformanceService();
      final stats = await performanceService.getPerformanceStats(userId);
      if (mounted) {
        setState(() {
          _avgProgress = (stats['avgProgress'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print('Error loading performance stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadRecentTasks(String userId) async {
    setState(() => _isLoadingTasks = true);
    try {
      await context.read<TaskProvider>().loadTasks(userId);
      final tasks = context.read<TaskProvider>().tasks;
      // Get recent tasks (limit to 5, sorted by due date)
      _recentTasks = tasks.take(5).toList();
    } catch (e) {
      print('Error loading recent tasks: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }

  Future<void> _loadRecentReviews(String userId) async {
    setState(() => _isLoadingReviews = true);
    try {
      final performanceService = PerformanceService();
      final reviews = await performanceService.getReviews(userId);
      // Get recent reviews (limit to 3, already sorted by created_at desc)
      _recentReviews = reviews.take(3).toList();
    } catch (e) {
      print('Error loading recent reviews: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final user = authProvider.user;
    
    // Use name from ProfileProvider if available, otherwise fallback to AuthProvider user name
    final displayName = profileProvider.profileData?['full_name'] as String? ?? user?.name ?? 'Employee';

    // Update recent tasks when TaskProvider updates
    if (taskProvider.tasks.isNotEmpty) {
      final newRecentTasks = taskProvider.tasks.take(5).toList();
      if (_recentTasks.length != newRecentTasks.length || 
          _recentTasks.isEmpty ||
          _recentTasks.first.id != newRecentTasks.first.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _recentTasks = newRecentTasks;
            });
          }
        });
      }
    }

    // ===== High-level stats =====
    // Leave balance (sum of all leave types)
    final leaveBalance =
        leaveProvider.leaveBalances.fold<double>(0, (sum, balance) => sum + balance.available).toInt();

    // Today's attendance
    final todayAttendance = attendanceProvider.todayAttendance;
    final now = DateTime.now();

    String todayStatus = 'Not Checked In';
    DateTime? checkInTime = todayAttendance?.checkInTime;
    DateTime? checkOutTime = todayAttendance?.checkOutTime;
    Duration workedToday = Duration.zero;

    if (checkInTime != null && checkOutTime == null) {
      todayStatus = 'Checked In';
      workedToday = now.difference(checkInTime);
    } else if (checkInTime != null && checkOutTime != null) {
      todayStatus = 'Checked Out';
      workedToday = checkOutTime.difference(checkInTime);
    }

    String _formatDuration(Duration d) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    }

    // This week hours (last 7 days from today)
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    Duration weekTotal = Duration.zero;

    for (final a in attendanceProvider.history) {
      final ci = a.checkInTime;
      final co = a.checkOutTime;
      if (ci == null || co == null) continue;

      final dateOnly = DateTime(ci.year, ci.month, ci.day);
      if (dateOnly.isBefore(weekStart) ||
          dateOnly.isAfter(DateTime(now.year, now.month, now.day))) {
        continue;
      }
      weekTotal += co.difference(ci);
    }

    final weekDays = 7;
    final double avgPerDayHours =
        weekDays > 0 ? weekTotal.inMinutes / 60.0 / weekDays : 0.0;

    // ===== Login insights (Actual history records) =====
    final insights = attendanceProvider.history.map((record) {
      final ci = record.checkInTime;
      final co = record.checkOutTime;
      final date = record.checkInTime ?? record.date;
      
      final duration = (ci != null && co != null) ? co.difference(ci) : Duration.zero;
      
      // Determine status: Use record status if available, otherwise calculate
      String status = record.status ?? 'Incomplete';
      if (record.status == null) {
        if (ci != null && co != null) {
          status = 'Present';
        } else if (ci != null) {
          status = 'Incomplete';
        } else {
          status = 'Absent';
        }
      }

      return _LoginInsight(
        date: date,
        checkIn: ci,
        checkOut: co,
        hours: duration,
        status: status,
        workType: record.workType,
      );
    }).toList();

    // Sort insights by date descending (most recent first) and take the top 7
    insights.sort((a, b) => b.date.compareTo(a.date));
    final displayInsights = insights.take(7).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Ensure we use the theme background (Cool Grey), effectively overriding any parent gradient
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
              : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ... existing slivers ...
              // (I will update the map call below as well)
              // ===== Top welcome + summary cards (like reference design) =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF2D3748),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          if (profileProvider.organizationData?['logo_url'] != null)
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: NetworkImage(profileProvider.organizationData!['logo_url']),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
  
                      // Summary cards grid (2x2 layout)
                      // Summary cards grid (2x2 layout)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmall = constraints.maxWidth < 600;
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: isSmall ? 1.6 : 1.6,
                            children: [
                              _SummaryCard(
                                title: 'Attendance',
                                primary: todayStatus,
                                secondary: checkInTime != null
                                    ? 'Check-in: ${DateFormat('hh:mm').format(checkInTime)}'
                                    : 'Not checked in',
                                trailing: checkInTime != null
                                    ? _formatDuration(workedToday)
                                    : '0h 0m',
                                accentColor: const Color(0xFF00C48C),
                                icon: Icons.timer_outlined,
                              ),
                              _SummaryCard(
                                title: 'This Week',
                                primary:
                                    '${weekTotal.inHours}h ${weekTotal.inMinutes.remainder(60)}m',
                                secondary:
                                    'Avg: ${avgPerDayHours.toStringAsFixed(1)}h/day',
                                trailing: '',
                                accentColor: const Color(0xFF7B61FF),
                                icon: Icons.date_range,
                              ),
                              _SummaryCard(
                                title: 'Leave Balance',
                                primary: '$leaveBalance Days',
                                secondary: 'Annual Left',
                                trailing: '',
                                accentColor: const Color(0xFFFF9F1C),
                                icon: Icons.beach_access,
                              ),
                              _SummaryCard(
                                title: 'Performance',
                                primary: '${_avgProgress.toInt()}%',
                                secondary: 'Avg. Progress',
                                trailing: '',
                                accentColor: const Color(0xFF2196F3),
                                icon: Icons.trending_up,
                              ),
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),

  
              // ===== Quick Actions =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionBtn(
                              context,
                              'Apply Leave',
                              Icons.calendar_today_rounded,
                              Colors.blue.shade700,
                              () {
                                if (widget.onNavigateToScreen != null) {
                                  widget.onNavigateToScreen!(7); // Leave screen index
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickActionBtn(
                              context,
                              'Payslips',
                              Icons.receipt_long_rounded,
                              Colors.blue.shade700,
                              () {
                                if (widget.onNavigateToScreen != null) {
                                  widget.onNavigateToScreen!(1); // My Payroll screen index
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickActionBtn(
                              context,
                              'Attendance',
                              Icons.access_time_filled_rounded,
                              Colors.blue.shade700,
                              () {
                                if (widget.onNavigateToScreen != null) {
                                  widget.onNavigateToScreen!(6); // Attendance screen index
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
  
              // ===== Login Insights - Last 7 days =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                           onPressed: () {
                             if (widget.onNavigateToScreen != null) widget.onNavigateToScreen!(6); // Attendance screen index
                           },
                           child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (displayInsights.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                           decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.history, size: 40, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 10),
                              const Text(
                                'No recent activity',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ...displayInsights.map(
                          (i) => _LoginInsightRow(
                            insight: i,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ===== Recent Tasks and Recent Reviews =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recent Tasks Section
                      Expanded(
                        child: _RecentTasksSection(
                          tasks: _recentTasks,
                          isLoading: _isLoadingTasks,
                          onViewAll: () {
                            if (widget.onNavigateToScreen != null) {
                              widget.onNavigateToScreen!(2); // Tasks screen index
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Recent Reviews Section
                      Expanded(
                        child: _RecentReviewsSection(
                          reviews: _recentReviews,
                          isLoading: _isLoadingReviews,
                          onViewAll: () {
                            if (widget.onNavigateToScreen != null) {
                              widget.onNavigateToScreen!(4); // Performance screen index
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100), // Spacing for bottom nav
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
             boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label, 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87
                )
              ),
            ],
          ),
        ),
      );
  }
}

/// Summary card widget matching the dashboard style
class _SummaryCard extends StatelessWidget {
  final String title;
  final String primary;
  final String secondary;
  final String trailing;
  final Color accentColor;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.trailing,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            primary,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              secondary,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (trailing.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Model for login insight rows
class _LoginInsight {
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final Duration hours;
  final String status;
  final String? workType;

  _LoginInsight({
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.hours,
    required this.status,
    this.workType,
  });
}

/// Row widget for login insights
class _LoginInsightRow extends StatelessWidget {
  final _LoginInsight insight;
  const _LoginInsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final statusColor = _statusColor(insight.status);
    
    final workType = insight.workType?.toLowerCase();
    final isRemote = workType == 'remote';
    final isHybrid = workType == 'hybrid';
    final isInOffice = workType == 'in office';

    String _formatTime(DateTime? t) {
      if (t == null) return '--:--';
      return DateFormat('HH:mm').format(t);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd').format(insight.date).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    insight.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isRemote)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Remote',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isHybrid) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.indigo.shade900.withOpacity(0.3) : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Hybrid',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isInOffice) ...[
                  if (isRemote || isHybrid) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'In Office',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check In',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(insight.checkIn),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check Out',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(insight.checkOut),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hours',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${insight.hours.inHours}h ${insight.hours.inMinutes.remainder(60)}m',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF00C48C);
      case 'incomplete':
        return Colors.orangeAccent;
      case 'absent':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}

/// Recent Tasks Section Widget
class _RecentTasksSection extends StatelessWidget {
  final List<Task> tasks;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _RecentTasksSection({
    required this.tasks,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Recent Tasks',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 40, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 10),
                    Text(
                      'No tasks',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...tasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              return _TaskItem(
                task: task,
                isLast: index == tasks.length - 1,
              );
            }),
        ],
      ),
    );
  }
}

/// Task Item Widget
class _TaskItem extends StatelessWidget {
  final Task task;
  final bool isLast;

  const _TaskItem({required this.task, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    Color _getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'completed':
          return Colors.green;
        case 'in_progress':
          return Colors.blue;
        case 'pending':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    Color _getPriorityColor(String priority) {
      switch (priority.toLowerCase()) {
        case 'high':
        case 'urgent':
          return Colors.red;
        case 'medium':
          return Colors.orange;
        case 'low':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(task.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.status.replaceAll('_', ' ').toLowerCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(task.status),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(task.priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.priority.toLowerCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getPriorityColor(task.priority),
                  ),
                ),
              ),
            ],
          ),
          if (task.dueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(task.dueDate!),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          if (!isLast)
            Divider(height: 24, color: Colors.grey.withOpacity(0.1)),
        ],
      ),
    );
  }
}

/// Recent Reviews Section Widget
class _RecentReviewsSection extends StatelessWidget {
  final List<PerformanceReview> reviews;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _RecentReviewsSection({
    required this.reviews,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 20, color: Colors.purple.shade600),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Recent Reviews',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.star_outline, size: 40, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 10),
                    Text(
                      'No reviews',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...reviews.asMap().entries.map((entry) {
              final index = entry.key;
              final review = entry.value;
              return _ReviewItem(
                review: review,
                isLast: index == reviews.length - 1,
              );
            }),
        ],
      ),
    );
  }
}

/// Review Item Widget
class _ReviewItem extends StatelessWidget {
  final PerformanceReview review;
  final bool isLast;

  const _ReviewItem({required this.review, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    Color _getStatusColor(ReviewStatus status) {
      switch (status) {
        case ReviewStatus.completed:
          return Colors.green;
        case ReviewStatus.pending:
          return Colors.orange;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.period,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(review.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  review.status.displayName.toLowerCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(review.status),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${review.rating.toStringAsFixed(1)}/5',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.createdAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(review.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          if (!isLast)
            Divider(height: 24, color: Colors.grey.withOpacity(0.1)),
        ],
      ),
    );
  }
}
