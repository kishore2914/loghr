import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/task.dart';

class TaskService {
  // Get tasks for a specific user (employee)
  Future<List<Task>> getTasksForUser(String userId) async {
    try {
      final response = await api.get('/tasks');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('TaskService: Error fetching tasks: $e');
      return [];
    }
  }

  // Get task statistics for a user
  Future<Map<String, int>> getTaskStats(String userId) async {
    try {
      final tasks = await getTasksForUser(userId);
      return {
        'total': tasks.length,
        'todo': tasks.where((t) => t.status == 'pending').length,
        'in_progress': tasks.where((t) => t.status == 'in_progress').length,
        'in_review': tasks.where((t) => t.status == 'on_hold').length,
        'completed': tasks.where((t) => t.status == 'completed').length,
        'overdue': tasks.where((t) => 
          t.status != 'completed' && 
          t.dueDate != null && 
          t.dueDate!.isBefore(DateTime.now())
        ).length,
      };
    } catch (e) {
      print('Error fetching task stats: $e');
      return {
        'total': 0,
        'todo': 0,
        'in_progress': 0,
        'in_review': 0,
        'completed': 0,
        'overdue': 0,
      };
    }
  }

  // Update task status
  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final response = await api.post('/tasks/update-status', {
        'taskId': taskId,
        'status': newStatus,
      });
      return response != null;
    } catch (e) {
      print('Error updating task status: $e');
      return false;
    }
  }

  // Update task progress
  Future<bool> updateTaskProgress(String taskId, int progressPercentage) async {
    try {
      final response = await api.post('/tasks/update-status', {
        'taskId': taskId,
        'status': progressPercentage == 100 ? 'completed' : 'in_progress',
        'progressPercentage': progressPercentage,
      });
      return response != null;
    } catch (e) {
      print('Error updating task progress: $e');
      return false;
    }
  }
}
