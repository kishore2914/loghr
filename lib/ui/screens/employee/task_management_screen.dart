import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/task_provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/data/models/task.dart';
import 'package:loghr_mobile/ui/screens/employee/task_detail_screen.dart';

class TaskManagementScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const TaskManagementScreen({super.key, this.onNavigateToDashboard});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All Status';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;
      if (userId != null) {
        context.read<TaskProvider>().loadTasks(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () {
            if (widget.onNavigateToDashboard != null) {
              widget.onNavigateToDashboard!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Tasks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (taskProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      taskProvider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        final userId = context.read<AuthProvider>().user?.id;
                        if (userId != null) {
                          taskProvider.loadTasks(userId);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredTasks = taskProvider.filterTasks(
            status: _selectedStatus == 'All Status' ? null : _selectedStatus,
            searchQuery: _searchController.text,
          );

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeader(isDark),
                      _buildStatsRow(isDark, taskProvider.stats),
                      _buildSearchAndFilter(isDark),
                    ],
                  ),
                ),
                if (filteredTasks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            taskProvider.tasks.isEmpty
                                ? 'You don\'t have any tasks assigned yet.\nContact your manager to get assigned tasks.'
                                : 'No tasks match your current filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildTaskCard(filteredTasks[index], isDark),
                        childCount: filteredTasks.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: Colors.purple.shade600, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Task Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'View and update your assigned tasks',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, Map<String, int> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          return GridView.count(
            crossAxisCount: isSmallScreen ? 2 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isSmallScreen ? 1.5 : 1.1,
            children: [
              _buildStatCard('Total Tasks', '${stats['total']}', Colors.blue, isDark),
              _buildStatCard('To Do', '${stats['todo']}', Colors.blueGrey, isDark),
              _buildStatCard('In Progress', '${stats['in_progress']}', Colors.deepPurple, isDark),
              _buildStatCard('In Review', '${stats['in_review']}', Colors.orange, isDark),
              _buildStatCard('Completed', '${stats['completed']}', Colors.green, isDark),
              _buildStatCard('Overdue', '${stats['overdue']}', Colors.red, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                items: ['All Status', 'Completed', 'In Progress', 'To Do'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(task: task),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: task.taskType == 'feature' ? Colors.blue.withOpacity(0.1) : 
                  task.taskType == 'bug' ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildTag(task.taskType.toUpperCase(), _getTaskTypeColor(task.taskType)),
                    const SizedBox(width: 8),
                    _buildTag(task.priority.toUpperCase(), _getPriorityColor(task.priority), outline: true),
                  ],
                ),
                _buildStatusBadge(task.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            // Progress bar
            if (task.progressPercentage > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: task.progressPercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.progressPercentage == 100 ? Colors.green : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${task.progressPercentage}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(task.assigneeName ?? 'Unassigned', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                if (task.dueDate != null) ...[
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MM/dd/yyyy').format(task.dueDate!),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
                if (task.estimatedHours != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${task.estimatedHours}h', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ],
            ),
            // Action button for pending tasks
            if (task.status == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startTask(task),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskActionButtons(Task task) {
    switch (task.status) {
      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _startTask(task),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start Task'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      
      case 'in_progress':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pauseTask(task),
                icon: const Icon(Icons.pause, size: 18),
                label: const Text('Pause'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade700),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _completeTask(task),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        );
      
      case 'on_hold':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _resumeTask(task),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Resume Task'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      
      case 'completed':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Task Completed',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _startTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    final success = await taskProvider.updateTaskStatus(task.id, 'in_progress');
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started task: ${task.title}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start task'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pauseTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    final success = await taskProvider.updateTaskStatus(task.id, 'on_hold');
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paused task: ${task.title}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resumeTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    final success = await taskProvider.updateTaskStatus(task.id, 'in_progress');
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resumed task: ${task.title}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    final success = await taskProvider.updateTaskStatus(task.id, 'completed');
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completed task: ${task.title}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTag(String text, Color color, {bool outline = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(8),
        border: outline ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: outline ? color : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    Color borderColor;
    IconData icon;
    String displayStatus;

    switch (status.toLowerCase()) {
      case 'completed':
        badgeColor = Colors.green;
        borderColor = Colors.green;
        icon = Icons.check_circle;
        displayStatus = 'Completed';
        break;
      case 'in_progress':
        badgeColor = Colors.blue;
        borderColor = Colors.blue;
        icon = Icons.play_circle;
        displayStatus = 'In Progress';
        break;
      case 'pending':
        badgeColor = Colors.grey;
        borderColor = Colors.grey;
        icon = Icons.pending;
        displayStatus = 'To Do';
        break;
      case 'on_hold':
        badgeColor = Colors.orange;
        borderColor = Colors.orange;
        icon = Icons.pause_circle;
        displayStatus = 'In Review';
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        borderColor = Colors.red;
        icon = Icons.cancel;
        displayStatus = 'Cancelled';
        break;
      default:
        badgeColor = Colors.grey;
        borderColor = Colors.grey;
        icon = Icons.help_outline;
        displayStatus = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 14),
          const SizedBox(width: 4),
          Text(
            displayStatus,
            style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getTaskTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'feature': return Colors.blue;
      case 'bug': return Colors.red;
      case 'enhancement': return Colors.green;
      case 'documentation': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.blue;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }
}
