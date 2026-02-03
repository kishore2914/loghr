import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/task.dart';
import 'package:loghr_mobile/data/repositories/task_repository.dart';

class TaskProvider extends ChangeNotifier {
  final TaskRepository _repository = TaskRepository();

  List<Task> _tasks = [];
  Map<String, int> _stats = {
    'total': 0,
    'todo': 0,
    'in_progress': 0,
    'in_review': 0,
    'completed': 0,
    'overdue': 0,
  };
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTasks(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _repository.getTasksForUser(userId);
      _stats = await _repository.getTaskStats(userId);
      _error = null;
      
      // Log if no tasks found
      if (_tasks.isEmpty) {
        print('TaskProvider: No tasks found for user: $userId');
        print('TaskProvider: This could mean:');
        print('  1. No tasks are assigned to this user');
        print('  2. The tasks table does not exist in Supabase');
        print('  3. The user does not have an employee_id set');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      print('TaskProvider: Error loading tasks: $e');
      print('TaskProvider: Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final success = await _repository.updateTaskStatus(taskId, newStatus);
      if (success) {
        // Update local task
        final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          // Get userId from the task's assignedTo field
          final employeeId = _tasks[taskIndex].assignedTo;
          if (employeeId != null) {
            // We need to get the user_id from employee_id, but for now just reload all tasks
            // This is simpler and ensures data consistency
            final currentUserId = _tasks.isNotEmpty ? _tasks.first.createdBy : null;
            if (currentUserId != null) {
              await loadTasks(currentUserId);
            }
          }
        }
      }
      return success;
    } catch (e) {
      print('Error updating task status: $e');
      return false;
    }
  }

  List<Task> filterTasks({String? status, String? searchQuery}) {
    var filtered = _tasks;

    // Map filter display names to actual database status values
    if (status != null && status != 'All Status') {
      String? mappedStatus;
      switch (status) {
        case 'To Do':
          mappedStatus = 'pending';
          break;
        case 'In Progress':
          mappedStatus = 'in_progress';
          break;
        case 'Completed':
          mappedStatus = 'completed';
          break;
        case 'In Review':
          mappedStatus = 'on_hold';
          break;
        default:
          mappedStatus = status.toLowerCase().replaceAll(' ', '_');
      }
      
      if (mappedStatus != null) {
        filtered = filtered.where((task) => task.status == mappedStatus).toList();
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(query) ||
            (task.description?.toLowerCase().contains(query) ?? false) ||
            task.taskType.toLowerCase().contains(query) ||
            (task.assigneeName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }
}
