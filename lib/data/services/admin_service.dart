import 'package:loghr_mobile/config/api_client.dart';
import 'package:intl/intl.dart';

class AdminService {
  // Helper to fetch dashboard stats summary
  Future<Map<String, dynamic>?> _getSummaryStats() async {
    try {
      final response = await api.get('/admin/stats/summary');
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('AdminService: Error fetching summary stats: $e');
      return null;
    }
  }

  // Get total number of employees
  Future<int> getTotalEmployees() async {
    final stats = await _getSummaryStats();
    return stats?['totalEmployees'] as int? ?? 0;
  }

  // Get count of employees active today (checked in)
  Future<int> getActiveTodayCount() async {
    final stats = await _getSummaryStats();
    return stats?['activeToday'] as int? ?? 0;
  }

  // Get count of employees on leave today
  Future<int> getOnLeaveTodayCount() async {
    final stats = await _getSummaryStats();
    return stats?['onLeaveToday'] as int? ?? 0;
  }

  // Get total active employees (for denominator)
  Future<int> getTotalActiveEmployees() async {
    final stats = await _getSummaryStats();
    return stats?['totalEmployees'] as int? ?? 0;
  }

  // Get count of pending leave requests
  Future<int> getPendingLeaveCount() async {
    final stats = await _getSummaryStats();
    return stats?['pendingLeaves'] as int? ?? 0;
  }

  // Get all leave requests with employee details for admin
  Future<List<Map<String, dynamic>>> getAllLeaveRequests({String? status}) async {
    try {
      final response = await api.get('/leaves/pending');
      if (response == null) return [];
      
      final list = response as List;
      final mapped = list.map((leave) => {
        'id': leave['id'],
        'user_id': leave['employee_id'],
        'employee_name': leave['employee_name'] ?? 'Unknown',
        'employee_code': leave['employee_code'] ?? '',
        'employee_email': leave['personal_email'] ?? '',
        'type': leave['leave_type_name'] ?? '',
        'start_date': leave['start_date'],
        'end_date': leave['end_date'],
        'reason': leave['reason'] ?? '',
        'status': leave['status'] ?? 'pending',
        'created_at': leave['created_at'],
      }).toList();

      if (status != null && status.isNotEmpty) {
        return mapped.where((l) => l['status'].toString().toLowerCase() == status.toLowerCase()).toList();
      }
      return mapped;
    } catch (e) {
      print('Error fetching leaves in getAllLeaveRequests: $e');
      return [];
    }
  }

  // Get payroll total for current month
  Future<Map<String, dynamic>> getMonthlyPayroll() async {
    try {
      final response = await api.get('/admin/stats/payroll-monthly');
      if (response == null) {
        return {
          'total_amount': 0.0,
          'paid_count': 0,
          'pending_count': 0,
          'processing_count': 0,
          'currency': 'INR',
        };
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error fetching monthly payroll: $e');
      return {
        'total_amount': 0.0,
        'paid_count': 0,
        'pending_count': 0,
        'processing_count': 0,
        'currency': 'INR',
      };
    }
  }

  // Get count of pending expenses
  Future<int> getPendingExpensesCount() async {
    final stats = await _getSummaryStats();
    return stats?['pendingExpenses'] as int? ?? 0;
  }

  // Get employees with birthdays in next 7 days
  Future<int> getUpcomingBirthdaysCount() async {
    final stats = await _getSummaryStats();
    return stats?['upcomingBirthdays'] as int? ?? 0;
  }

  // Get salary due list
  Future<List<Map<String, dynamic>>> getSalaryDueList() async {
    try {
      final response = await api.get('/admin/stats/salary-due');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching salary due list: $e');
      return [];
    }
  }

  // Get upcoming birthdays list
  Future<List<Map<String, dynamic>>> getUpcomingBirthdays() async {
    try {
      final response = await api.get('/admin/stats/birthdays');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching upcoming birthdays: $e');
      return [];
    }
  }

  // Get employees leave balances (for admin list)
  Future<List<Map<String, dynamic>>> getEmployeesLeaveBalances() async {
    try {
      final response = await api.get('/admin/leave-balances');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching employees leave balances: $e');
      return [];
    }
  }

  // Get payroll employees (list for payroll dashboard)
  Future<List<Map<String, dynamic>>> getPayrollEmployees({
    int? month,
    int? year,
  }) async {
    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;
      final response = await api.get('/admin/payroll-employees?month=$m&year=$y');
      if (response == null) return [];

      final list = response as List;
      return list.map((record) => {
        'id': record['employee_id'],
        'employee_name': record['name'] ?? 'Unknown',
        'employee_code': record['employee_code'] ?? '',
        'pan': record['pan_number'] ?? '',
        'basic_salary': (record['basic_salary'] as num?)?.toDouble() ?? 0.0,
        'da': 0.0,
        'hra': (record['hra'] as num?)?.toDouble() ?? 0.0,
        'special': 0.0,
        'gross_salary': (record['gross_salary'] as num?)?.toDouble() ?? 0.0,
        'pf': (record['gross_salary'] as num?)?.toDouble() != null ? ((record['gross_salary'] as num).toDouble() * 0.12) : 0.0,
        'esi': 0.0,
        'tds': 0.0,
        'professional_tax': 0.0,
        'net_salary': (record['gross_salary'] as num?)?.toDouble() != null ? ((record['gross_salary'] as num).toDouble() * 0.88) : 0.0,
        'status': record['payroll_status'] ?? 'unprocessed',
        'currency': 'INR',
      }).toList();
    } catch (e) {
      print('Error fetching payroll employees: $e');
      return [];
    }
  }

  // Get payroll summary for a specific month/year (India Payroll)
  Future<Map<String, dynamic>> getPayrollSummary({
    int? month,
    int? year,
  }) async {
    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;
      final response = await api.get('/admin/payroll-summary?month=$m&year=$y');
      if (response == null) {
        return {
          'total_employees': 0,
          'paid_count': 0,
          'pending_count': 0,
          'total_amount': 0.0,
          'currency': 'INR',
        };
      }
      final data = response as Map<String, dynamic>;
      final totalEmployees = await getTotalEmployees();
      return {
        'total_employees': totalEmployees,
        'paid_count': int.tryParse(data['paid_count']?.toString() ?? '0') ?? 0,
        'pending_count': int.tryParse(data['pending_count']?.toString() ?? '0') ?? 0,
        'total_amount': double.tryParse(data['total_gross']?.toString() ?? '0.0') ?? 0.0,
        'currency': 'INR',
      };
    } catch (e) {
      print('Error fetching payroll summary: $e');
      return {
        'total_employees': 0,
        'paid_count': 0,
        'pending_count': 0,
        'total_amount': 0.0,
        'currency': 'INR',
      };
    }
  }

  // Get statutory compliance data for India Payroll
  Future<Map<String, dynamic>> getStatutoryCompliance({
    int? month,
    int? year,
  }) async {
    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;
      final response = await api.get('/admin/statutory-compliance?month=$m&year=$y');
      if (response == null) {
        return {
          'pf_employee': 0.0,
          'pf_employer': 0.0,
          'total_pf': 0.0,
          'esi_employee': 0.0,
          'esi_employer': 0.0,
          'total_esi': 0.0,
          'tds': 0.0,
          'professional_tax': 0.0,
          'total_tax': 0.0,
        };
      }
      final data = response as Map<String, dynamic>;
      final pf = double.tryParse(data['pf_compliance']?.toString() ?? '0.0') ?? 0.0;
      final esi = double.tryParse(data['esi_compliance']?.toString() ?? '0.0') ?? 0.0;
      final tds = double.tryParse(data['tds_compliance']?.toString() ?? '0.0') ?? 0.0;
      return {
        'pf_employee': pf / 2,
        'pf_employer': pf / 2,
        'total_pf': pf,
        'esi_employee': esi * 0.1875, // approximate ratio
        'esi_employer': esi * 0.8125,
        'total_esi': esi,
        'tds': tds,
        'professional_tax': 0.0,
        'total_tax': tds,
      };
    } catch (e) {
      print('Error fetching statutory compliance: $e');
      return {
        'pf_employee': 0.0,
        'pf_employer': 0.0,
        'total_pf': 0.0,
        'esi_employee': 0.0,
        'esi_employer': 0.0,
        'total_esi': 0.0,
        'tds': 0.0,
        'professional_tax': 0.0,
        'total_tax': 0.0,
      };
    }
  }

  // Get all employees with full details
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    try {
      final response = await api.get('/admin/employees');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching all employees: $e');
      return [];
    }
  }

  // Create new employee
  Future<bool> createEmployee(Map<String, dynamic> employeeData) async {
    try {
      final response = await api.post('/admin/employees', employeeData);
      return response != null && response['success'] == true;
    } catch (e) {
      print('Error creating employee: $e');
      return false;
    }
  }

  // Update employee
  Future<bool> updateEmployee(String id, Map<String, dynamic> employeeData) async {
    try {
      final response = await api.put('/admin/employees/$id', employeeData);
      return response != null && response['success'] == true;
    } catch (e) {
      print('Error updating employee: $e');
      return false;
    }
  }

  // Process Payroll for a month
  Future<bool> processPayroll({required int month, required int year}) async {
    try {
      final response = await api.post('/admin/payroll/process', {
        'month': month,
        'year': year,
      });
      return response != null && response['success'] == true;
    } catch (e) {
      print('Error processing payroll: $e');
      return false;
    }
  }

  // Get all attendance records for a specific date
  Future<List<Map<String, dynamic>>> getAllAttendance({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final response = await api.get('/admin/attendance?date=$dateStr');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((record) => {
        ...record as Map<String, dynamic>,
        'user_profiles': {
          'user_id': record['employee_id'],
          'full_name': record['employee_name'] ?? 'Unknown',
        }
      }).toList();
    } catch (e) {
      print('Error fetching all attendance: $e');
      return [];
    }
  }

  // Create Announcement
  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    try {
      final response = await api.post('/admin/announcements', data);
      return response != null;
    } catch (e) {
      print('Error creating announcement: $e');
      return false;
    }
  }

  // Get Department Stats
  Future<List<Map<String, dynamic>>> getDepartmentStats() async {
    try {
      final response = await api.get('/admin/department-stats');
      if (response == null) return [];
      
      final list = response as List;
      final colors = [0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0, 0xFFE91E63];
      int colorIndex = 0;

      return list.map((d) {
        final color = colors[colorIndex % colors.length];
        colorIndex++;
        return {
          'name': d['department_name']?.toString() ?? 'Unknown',
          'count': int.tryParse(d['employee_count']?.toString() ?? '0') ?? 0,
          'color': color,
        };
      }).toList();
    } catch (e) {
      print('Error fetching department stats: $e');
      return [];
    }
  }

  // Get Actual Designations from Database
  Future<List<String>> getDesignations() async {
    try {
      final response = await api.get('/admin/designations');
      if (response == null) return [];
      return List<String>.from(response as List);
    } catch (e) {
      print('Error fetching designations: $e');
      return ['Technical', 'Operations', 'Management', 'HR'];
    }
  }

  // Get Tasks Stats
  Future<Map<String, dynamic>> getTasksStats() async {
    try {
      final response = await api.get('/admin/tasks/stats');
      if (response == null) {
        return {
          'total': 0,
          'todo': 0,
          'in_progress': 0,
          'in_review': 0,
          'completed': 0,
          'overdue': 0,
        };
      }
      final data = response as Map<String, dynamic>;
      final total = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      final completed = int.tryParse(data['completed']?.toString() ?? '0') ?? 0;
      final pending = int.tryParse(data['pending']?.toString() ?? '0') ?? 0;
      final inProgress = int.tryParse(data['in_progress']?.toString() ?? '0') ?? 0;
      return {
        'total': total,
        'todo': pending - inProgress,
        'in_progress': inProgress,
        'in_review': 0,
        'completed': completed,
        'overdue': 0,
      };
    } catch (e) {
      print('Error fetching tasks stats: $e');
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

  // Get All Tasks
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    try {
      final response = await api.get('/admin/tasks/all');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((record) => {
        'id': record['id']?.toString().substring(0, 8) ?? 'TASK',
        'title': record['title'] ?? 'Task',
        'type': record['priority'] ?? 'FEATURE',
        'priority': record['priority'] ?? 'MEDIUM',
        'assignee': {'name': record['assignee_name'] ?? 'Assignee', 'avatar': null},
        'due_date': record['due_date']?.toString().split('T')[0] ?? '',
        'status': record['status']?.toString().toUpperCase() ?? 'TODO',
      }).toList();
    } catch (e) {
      print('Error fetching all tasks: $e');
      return [];
    }
  }

  // Get Leave Analytics
  Future<Map<String, dynamic>> getLeaveAnalytics() async {
    try {
      final response = await api.get('/admin/leaves/analytics');
      final onLeaveToday = await getOnLeaveTodayCount();
      if (response == null) {
        return {
          'totalRequests': 0,
          'pendingRequests': 0,
          'approvedRequests': 0,
          'rejectedRequests': 0,
          'onLeaveToday': onLeaveToday,
          'upcomingLeaves': 0,
          'monthlyTrends': [],
          'typeDistribution': [],
        };
      }
      final data = response as Map<String, dynamic>;
      final total = int.tryParse(data['total_requests']?.toString() ?? '0') ?? 0;
      final approved = int.tryParse(data['approved']?.toString() ?? '0') ?? 0;
      final pending = int.tryParse(data['pending']?.toString() ?? '0') ?? 0;
      final rejected = int.tryParse(data['rejected']?.toString() ?? '0') ?? 0;

      return {
        'totalRequests': total,
        'pendingRequests': pending,
        'approvedRequests': approved,
        'rejectedRequests': rejected,
        'onLeaveToday': onLeaveToday,
        'upcomingLeaves': 0,
        'monthlyTrends': [
          {'month': 'Current', 'count': total},
        ],
        'typeDistribution': [
          {'name': 'Approved', 'count': approved, 'color': 0xFF4CAF50},
          {'name': 'Pending', 'count': pending, 'color': 0xFF2196F3},
          {'name': 'Rejected', 'count': rejected, 'color': 0xFFF44336},
        ],
      };
    } catch (e) {
      print('Error fetching leave analytics: $e');
      return {
        'totalRequests': 0,
        'pendingRequests': 0,
        'approvedRequests': 0,
        'rejectedRequests': 0,
        'onLeaveToday': 0,
        'upcomingLeaves': 0,
        'monthlyTrends': [],
        'typeDistribution': [],
      };
    }
  }

  // Get Leave Types
  Future<List<Map<String, dynamic>>> getLeaveTypes() async {
    try {
      final response = await api.get('/admin/leaves/types');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((record) => {
        'id': record['id'],
        'name': record['name'] ?? 'Leave Type',
        'code': record['code'] ?? '',
        'description': record['description'] ?? '',
        'paid': record['is_paid'] ?? true,
        'maxDays': (record['max_days_per_request'] as num?)?.toDouble(),
        'requiresDoc': record['requires_document'] ?? false,
        'carryForward': record['max_carry_forward'] != null && (record['max_carry_forward'] as num) > 0,
        'status': (record['is_active'] ?? false) ? 'Active' : 'Inactive',
        'allocated': (record['days_per_year'] as num?)?.toDouble() ?? 0.0,
      }).toList();
    } catch (e) {
      print('Error fetching leave types: $e');
      return [];
    }
  }
}
