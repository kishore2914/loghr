import 'package:loghr_mobile/data/models/task.dart';
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/services/loyalty_service.dart';

class TaskService {
  // Helper method to try fetching tasks using user_id directly as employee_id
  Future<List<Task>?> _tryDirectTaskQuery(String userId) async {
    try {
      print('TaskService: Attempting fallback - using user_id directly as employee_id');
      final directTasks = await supabase
          .from('tasks')
          .select('*')
          .eq('assigned_to', userId)
          .order('due_date', ascending: true);
      
      if ((directTasks as List).isNotEmpty) {
        print('TaskService: Found ${directTasks.length} tasks using user_id directly as employee_id');
        return (directTasks as List).map((json) => Task.fromJson(json)).toList();
      }
      print('TaskService: No tasks found with user_id fallback');
      return null;
    } catch (e2) {
      print('TaskService: Error with direct task query fallback: $e2');
      return null;
    }
  }

  // Get tasks for a specific user (employee)
  Future<List<Task>> getTasksForUser(String userId) async {
    try {
      print('TaskService: Fetching tasks for user: $userId');
      
      // First get the employee_id from user_profiles
      Map<String, dynamic>? profileData;
      try {
        profileData = await supabase
            .from('user_profiles')
            .select('employee_id, full_name')
            .eq('user_id', userId)
            .maybeSingle();
      } catch (e) {
        print('TaskService: Error fetching profile: $e');
        // Try fallback: use user_id directly as employee_id
        final fallbackTasks = await _tryDirectTaskQuery(userId);
        return fallbackTasks ?? [];
      }

      print('TaskService: Profile data: $profileData');

      if (profileData == null) {
        print('TaskService: No profile found for user: $userId');
        // Try fallback: use user_id directly as employee_id
        final fallbackTasks = await _tryDirectTaskQuery(userId);
        return fallbackTasks ?? [];
      }

      final employeeId = profileData['employee_id'] as String?;
      
      if (employeeId == null) {
        print('TaskService: No employee_id in profile for user: $userId');
        // Try fallback: use user_id directly as employee_id
        final fallbackTasks = await _tryDirectTaskQuery(userId);
        return fallbackTasks ?? [];
      }

      print('TaskService: Employee ID: $employeeId');

      // Fetch tasks assigned to this employee - simplified query first
      List<dynamic> data;
      try {
        data = await supabase
            .from('tasks')
            .select('*')
            .eq('assigned_to', employeeId)
            .order('due_date', ascending: true);
        
        print('TaskService: Fetched ${data.length} tasks');

        if (data.isEmpty) {
          print('TaskService: No tasks found for employee_id: $employeeId');
          return [];
        }
      } catch (e) {
        print('TaskService: Error querying tasks table: $e');
        // Check if the table exists by trying a simple query
        try {
          await supabase.from('tasks').select('id').limit(1);
          print('TaskService: Tasks table exists but query failed');
        } catch (tableError) {
          print('TaskService: Tasks table might not exist: $tableError');
          throw Exception('Tasks table not found or inaccessible. Please ensure the tasks table exists in your Supabase database.');
        }
        rethrow;
      }

      // Batch fetch assignee names from employees table for all tasks
      final result = <Task>[];
      
      // Collect all unique employee_ids from tasks
      final employeeIds = (data as List)
          .map((task) => task['assigned_to'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      
      // Batch fetch employee names from employees table
      final employeeNameMap = <String, String>{};
      if (employeeIds.isNotEmpty) {
        try {
          print('TaskService: Batch fetching employee names for ${employeeIds.length} employees');
          final employeesData = await supabase
              .from('employees')
              .select()
              .inFilter('id', employeeIds);
          
          for (var empData in employeesData) {
            final empId = empData['id'] as String?;
            if (empId == null) continue;
            
            // Try different possible column names for name
            final empName = empData['full_name'] as String? ?? 
                          empData['name'] as String? ??
                          empData['first_name'] as String? ??
                          empData['employee_name'] as String?;
            
            if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
              employeeNameMap[empId] = empName.trim();
              print('TaskService: Found employee name from employees table: $empName for $empId');
            }
          }
        } catch (e) {
          print('TaskService: Error batch fetching from employees table: $e');
        }
        
        // Fallback: fetch from user_profiles for any missing names
        final missingIds = employeeIds.where((id) => !employeeNameMap.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            print('TaskService: Fetching missing names from user_profiles');
            final profiles = await supabase
                .from('user_profiles')
                .select('employee_id, full_name')
                .inFilter('employee_id', missingIds);
            
            for (var profile in profiles) {
              final empId = profile['employee_id'] as String?;
              final name = profile['full_name'] as String?;
              if (empId != null && name != null && name.isNotEmpty && !employeeNameMap.containsKey(empId)) {
                employeeNameMap[empId] = name;
                print('TaskService: Using name from user_profiles: $name for $empId');
              }
            }
          } catch (e) {
            print('TaskService: Error fetching from user_profiles: $e');
          }
        }
      }
      
      // Map tasks with assignee names
      for (var taskJson in data as List) {
        final assignedTo = taskJson['assigned_to'] as String?;
        final assigneeName = assignedTo != null ? employeeNameMap[assignedTo] : null;
        
        result.add(Task.fromJson({
          ...taskJson,
          'assignee_name': assigneeName,
        }));
      }
      
      print('TaskService: Returned ${result.length} tasks with assignee names');
      return result;
    } catch (e, stackTrace) {
      print('TaskService: Error fetching tasks: $e');
      print('TaskService: Stack trace: $stackTrace');
      // Re-throw the error so the provider can handle it
      throw e;
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
      await supabase
          .from('tasks')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
            if (newStatus == 'completed') 'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      // Award 20 loyalty points for task completion
      if (newStatus == 'completed') {
        try {
          final task = await supabase
              .from('tasks')
              .select('assigned_to')
              .eq('id', taskId)
              .single();
          
          final employeeId = task['assigned_to'] as String?;
          if (employeeId != null) {
            await LoyaltyService().awardPoints(
              employeeId: employeeId,
              points: 20,
              type: 'task_completion',
              description: 'Completed task: $taskId',
              referenceId: taskId,
            );
          }
        } catch (e) {
          print('Error awarding loyalty points for task completion: $e');
        }
      }

      return true;
    } catch (e) {
      print('Error updating task status: $e');
      return false;
    }
  }

  // Update task progress
  Future<bool> updateTaskProgress(String taskId, int progressPercentage) async {
    try {
      await supabase
          .from('tasks')
          .update({
            'progress_percentage': progressPercentage,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      return true;
    } catch (e) {
      print('Error updating task progress: $e');
      return false;
    }
  }
}
