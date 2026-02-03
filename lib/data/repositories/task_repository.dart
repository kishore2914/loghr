import 'package:loghr_mobile/data/models/task.dart';
import 'package:loghr_mobile/data/services/task_service.dart';

class TaskRepository {
  final TaskService _service = TaskService();

  Future<List<Task>> getTasksForUser(String userId) async {
    return await _service.getTasksForUser(userId);
  }

  Future<Map<String, int>> getTaskStats(String userId) async {
    return await _service.getTaskStats(userId);
  }

  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    return await _service.updateTaskStatus(taskId, newStatus);
  }
}
