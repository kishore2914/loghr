import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/data/models/leave.dart';

class LeaveHistoryScreen extends StatefulWidget {
  final String? initialLeaveTypeId;
  const LeaveHistoryScreen({super.key, this.initialLeaveTypeId});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  String _selectedStatus = 'all'; // all, pending, approved, rejected
  String? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    _selectedTypeId = widget.initialLeaveTypeId;
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<LeaveProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredLeaves = leaveProvider.userLeaves.where((l) {
      final matchesStatus = _selectedStatus == 'all' || l.status.toString().split('.').last == _selectedStatus;
      final matchesType = _selectedTypeId == null || l.leaveTypeId == _selectedTypeId;
      return matchesStatus && matchesType;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Leave History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', 'approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),

          // History List
          Expanded(
            child: filteredLeaves.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No history found for $_selectedStatus',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = filteredLeaves[index];
                      return _buildLeaveHistoryCard(context, leave);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
        });
      },
      selectedColor: const Color(0xFF0FAE7B).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0FAE7B),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0FAE7B) : (isDark ? Colors.white70 : Colors.black54),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLeaveHistoryCard(BuildContext context, Leave leave) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(leave.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              leave.leaveTypeName,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${leave.days.toInt()} Days',
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormat('MMM dd').format(leave.startDate)} - ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(leave.status),
              ],
            ),
          ),
          if (leave.reason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reason:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(leave.reason, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
            ),
          if (leave.status == LeaveStatus.rejected && leave.rejectionReason != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HR Feedback:', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(leave.rejectionReason!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          if (leave.status == LeaveStatus.approved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.02),
                border: Border(top: BorderSide(color: Colors.green.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                   const Icon(Icons.verified_user, size: 12, color: Colors.green),
                   const SizedBox(width: 6),
                   Text(
                     'Approved by: ',
                     style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.bold),
                   ),
                   Text(
                     leave.approvedBy ?? 'HR Manager',
                     style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                   ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: #${leave.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(fontSize: 9, color: Colors.grey.withOpacity(0.5)),
                ),
                Text(
                  'Applied on ${DateFormat('MMM dd, yyyy').format(leave.createdAt)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case LeaveStatus.rejected:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 16, color: Colors.white),
        );
      case LeaveStatus.pending:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          child: const Icon(Icons.access_time_filled, size: 16, color: Colors.white),
        );
    }
  }

  Color _getStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved: return Colors.green;
      case LeaveStatus.rejected: return Colors.red;
      case LeaveStatus.pending: return Colors.orange;
    }
  }
}
