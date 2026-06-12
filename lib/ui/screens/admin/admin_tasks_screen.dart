import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/admin_provider.dart';
import 'package:intl/intl.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadTasksData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTasks() {
    context.read<AdminProvider>().filterTasks(
      query: _searchController.text,
      status: _selectedStatus,
      employee: _selectedEmployee,
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: ['All Status', 'TODO', 'IN_PROGRESS', 'IN_REVIEW', 'COMPLETED', 'OVERDUE']
            .map((status) => ListTile(
                  title: Text(status),
                  onTap: () {
                    setState(() => _selectedStatus = status == 'All Status' ? null : status);
                    _filterTasks();
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _showEmployeeFilter() {
    // Placeholder for employee filter
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: ['All Employees', 'Virat Kohli', 'Rohit Sharma']
            .map((emp) => ListTile(
                  title: Text(emp),
                  onTap: () {
                    setState(() => _selectedEmployee = emp == 'All Employees' ? null : emp);
                    _filterTasks();
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage and track team tasks with GitHub integration',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {}, // Placeholder
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Task'),
                     style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0), // Purple accent
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  final stats = provider.tasksStats;
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    children: [
                      _buildStatCard('Total Tasks', '${stats['total'] ?? 0}', isDark),
                      _buildStatCard('To Do', '${stats['todo'] ?? 0}', isDark),
                      _buildStatCard('In Progress', '${stats['in_progress'] ?? 0}', isDark),
                      _buildStatCard('In Review', '${stats['in_review'] ?? 0}', isDark),
                      _buildStatCard('Completed', '${stats['completed'] ?? 0}', isDark),
                      _buildStatCard('Overdue', '${stats['overdue'] ?? 0}', isDark, isOverdue: true),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Search & Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                   Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _filterTasks(),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                   const SizedBox(height: 12),
                   Row(
                    children: [
                      _buildFilterChip(
                        label: _selectedStatus ?? 'All Status',
                        icon: Icons.filter_list,
                        isSelected: _selectedStatus != null,
                        onTap: _showStatusFilter,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: _selectedEmployee ?? 'All Employees',
                        icon: Icons.person_outline,
                        isSelected: _selectedEmployee != null,
                        onTap: _showEmployeeFilter,
                        isDark: isDark,
                      ),
                    ],
                   ),
                ],
              ),
            ),

             const SizedBox(height: 10),

            // Task List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Task', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Priority', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Due Date', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 40), // Spacing for actions
                ],
              ),
            ),

            // Task List
            Consumer<AdminProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.tasks.isEmpty) {
                   return Center(
                      child: Text(
                        'No tasks found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: provider.tasks.length,
                  itemBuilder: (context, index) {
                    final task = provider.tasks[index];
                    return KeyedSubtree(
                      key: ValueKey(task['id']),
                      child: _buildTaskCard(task, isDark),
                    );
                  },
                );
              },
            ),
          ],
        ), // Column
      ), // SingleChildScrollView
      ), // SafeArea
    ); // Scaffold
  }

  Widget _buildStatCard(String title, String value, bool isDark, {bool isOverdue = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isOverdue ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isOverdue ? Colors.red : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF1E1E1E) // Match dark theme even if selected for consistency with provided design
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
             // Design didn't show active color for filter buttons, kept subtle
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, bool isDark) {
    // Style Helpers
    Color getPriorityColor(String priority) {
      switch (priority.toUpperCase()) {
        case 'HIGH': return Colors.orange;
        case 'MEDIUM': return Colors.blue;
        case 'LOW': return Colors.green;
        default: return Colors.grey;
      }
    }

    Color getStatusColor(String status) {
       switch (status.toUpperCase()) {
        case 'COMPLETED': return Colors.green;
        case 'TODO': return Colors.grey;
        case 'IN_PROGRESS': return Colors.blue;
        default: return Colors.grey;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Title and Type
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Expanded(
                flex: 3,
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                        task['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['id'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                   ],
                 ),
               ),
               
               // Priority Pill
               Expanded(
                 flex: 2,
                 child: Align(
                   alignment: Alignment.centerLeft,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                       border: Border.all(color: getPriorityColor(task['priority']).withOpacity(0.5)),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Text(
                        task['priority'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: getPriorityColor(task['priority']),
                        ),
                     ),
                   ),
                 ),
               ),
               
               // Due Date
               Expanded(
                 flex: 2,
                 child: Text(
                    task['due_date'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                 ),
               ),

               // Actions
               Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.visibility_outlined, size: 18, color: Colors.blue.shade400),
                   const SizedBox(width: 8),
                   Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade400),
                   const SizedBox(width: 8),
                   Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                 ],
               ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Row 2: Assignee and Status
          Row(
            children: [
              // Type
               Text(
                task['type'],
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Assuming dark bg for type logic if needed, but keeping simple
                ),
              ),
              const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: getStatusColor(task['status']).withOpacity(0.2),
                   border: Border.all(color: getStatusColor(task['status'])),
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Row(
                   children: [
                     Icon(
                       task['status'] == 'COMPLETED' ? Icons.check_circle_outline : Icons.schedule,
                       size: 12,
                       color: getStatusColor(task['status']),
                     ),
                     const SizedBox(width: 4),
                     Text(
                        task['status'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: getStatusColor(task['status']),
                        ),
                     ),
                   ],
                 ),
               ),
            ],
          ),
           const SizedBox(height: 8),
           // Assignee Row
           Row(
             children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.grey.shade800,
                  child: Text(
                    (task['assignee']['name'] as String)[0],
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  task['assignee']['name'],
                   style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                ),
             ],
           ),
        ],
      ),
    );
  }
}
