import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/data/models/leave.dart';
import 'package:loghr_mobile/ui/widgets/swipeable_card.dart';
import 'package:loghr_mobile/ui/widgets/dashboard_widgets.dart'; // DashboardStatCard
import 'package:loghr_mobile/ui/widgets/apply_leave_sheet.dart';
import 'package:loghr_mobile/utils/helpers.dart';
import 'package:loghr_mobile/ui/screens/employee/leave_history_screen.dart';

class LeaveScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const LeaveScreen({super.key, this.onNavigateToDashboard});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  String _selectedFilter = 'all'; // all, pending, approved, rejected

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
      context.read<LeaveProvider>().loadData(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user data')),
      );
    }

    final totalBalance = leaveProvider.leaveBalances.fold<double>(0, (sum, val) => sum + val.available);
    final approvedLeaves = leaveProvider.userLeaves
        .where((l) => l.status == LeaveStatus.approved)
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          onPressed: () {
            if (widget.onNavigateToDashboard != null) {
              widget.onNavigateToDashboard!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Leave Management',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: 0),
              const Text(
                'Manage your leave applications and balances',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Leave Balance Cards (vertical layout)
              ...leaveProvider.leaveBalances.map((balance) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LeaveHistoryScreen(
                            initialLeaveTypeId: balance.leaveTypeId,
                          ),
                        ),
                      );
                    },
                    child: _buildLeaveBalanceCard(context, balance),
                  ),
                );
              }).toList(),
              
              if (leaveProvider.leaveBalances.isEmpty && !leaveProvider.isLoading)
                 Container(
                   width: double.infinity,
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(
                     color: Colors.orange.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.orange.withOpacity(0.3)),
                   ),
                   child: const Text('No leave balances found. Contact HR if this is an error.'),
                 ),

              const SizedBox(height: 32),

              // My Leave requests
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Leave Applications',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LeaveHistoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.history, color: Color(0xFF0FAE7B)),
                        tooltip: 'View Full History',
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ApplyLeaveSheet(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Apply Leave'),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF0FAE7B), // WhatsApp-like green used in website
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Chips for Quick Access
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildQuickFilterChip('Pending', 'pending'),
                    const SizedBox(width: 8),
                    _buildQuickFilterChip('Approved', 'approved'),
                    const SizedBox(width: 8),
                    _buildQuickFilterChip('Rejected', 'rejected'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              if (leaveProvider.isLoading && leaveProvider.userLeaves.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (leaveProvider.userLeaves.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No leave application history', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...leaveProvider.userLeaves
                    .where((l) => _selectedFilter == 'all' || l.status.toString().split('.').last == _selectedFilter)
                    .take(10) // Show only latest 10 on main screen
                    .map((leave) => _buildLeaveHistoryCard(context, leave)),
                
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLeaveBalanceCard(BuildContext context, LeaveBalance balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and leave name
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${balance.leaveName} (${balance.leaveCode})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total, Used, Available (matching web design - left aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBalanceItem('Total', balance.total.toInt(), textColor),
              ),
              Expanded(
                child: _buildBalanceItem('Used', balance.used.toInt(), Colors.orange),
              ),
              Expanded(
                child: _buildBalanceItem('Available', balance.available.toInt(), Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, int value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLeaveHistoryCard(BuildContext context, Leave leave) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(leave.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.leaveTypeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(leave.startDate)} → ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leave.status == LeaveStatus.approved) 
                        const Icon(Icons.check_circle, size: 12, color: Colors.green)
                      else if (leave.status == LeaveStatus.rejected)
                        const Icon(Icons.cancel, size: 12, color: Colors.red)
                      else 
                        const Icon(Icons.access_time_filled, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        leave.status.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reason: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Expanded(child: Text(leave.reason, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                  ],
                ),
                if (leave.status == LeaveStatus.approved) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.verified_user, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Approved by: ${leave.approvedBy ?? 'HR Manager'}',
                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ] else if (leave.status == LeaveStatus.rejected && leave.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rejection Reason:', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(leave.rejectionReason!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Applied: ${DateFormat('MM/dd/yyyy').format(leave.createdAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
      case LeaveStatus.pending:
        return Colors.orange;
    }
  }

  Widget _buildQuickFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: const Color(0xFF0FAE7B).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0FAE7B) : (isDark ? Colors.white70 : Colors.black54),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
