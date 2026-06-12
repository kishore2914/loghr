import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:intl/intl.dart';

class AdminService {
  // Get total number of employees
  Future<int> getTotalEmployees() async {
    try {
      final data = await supabase
          .from('user_profiles')
          .select('id')
          .eq('is_active', true);
      
      return data.length;
    } catch (e) {
      print('Error fetching total employees: $e');
      return 0;
    }
  }

  // Get count of employees active today (checked in)
  Future<int> getActiveTodayCount() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Try different possible column names
      try {
        final data = await supabase
            .from('attendance')
            .select('user_id')
            .gte('check_in_time', startOfDay.toIso8601String())
            .lt('check_in_time', endOfDay.toIso8601String())
            .isFilter('check_out_time', null);

        final uniqueUsers = <String>{};
        for (var record in data) {
          final userId = record['user_id'] as String?;
          if (userId != null) uniqueUsers.add(userId);
        }
        return uniqueUsers.length;
      } catch (e) {
        // Try with employee_id if user_id doesn't exist
        try {
          final data = await supabase
              .from('attendance')
              .select('employee_id')
              .gte('check_in_time', startOfDay.toIso8601String())
              .lt('check_in_time', endOfDay.toIso8601String())
              .isFilter('check_out_time', null);

          final uniqueUsers = <String>{};
          for (var record in data) {
            final empId = record['employee_id'] as String?;
            if (empId != null) uniqueUsers.add(empId);
          }
          return uniqueUsers.length;
        } catch (e2) {
          print('Error fetching active today count (tried both user_id and employee_id): $e2');
          return 0;
        }
      }
    } catch (e) {
      print('Error fetching active today count: $e');
      return 0;
    }
  }

  // Get count of employees on leave today
  Future<int> getOnLeaveTodayCount() async {
    try {
      final today = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(today);

      final tables = ['leave_applications', 'leaves', 'leave_requests'];
      for (var table in tables) {
        try {
          final data = await supabase
              .from(table)
              .select('id')
              .eq('status', 'approved')
              .lte('start_date', dateStr)
              .gte('end_date', dateStr);
          return data.length;
        } catch (e) {
          continue;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching on leave today count: $e');
      return 0;
    }
  }

  // Get total active employees (for denominator)
  Future<int> getTotalActiveEmployees() async {
    try {
      final data = await supabase
          .from('user_profiles')
          .select('id')
          .eq('is_active', true);
      
      return data.length;
    } catch (e) {
      print('Error fetching total active employees: $e');
      return 0;
    }
  }

  // Get count of pending leave requests
  Future<int> getPendingLeaveCount() async {
    final tables = ['leave_applications', 'leaves', 'leave_requests'];
    for (var table in tables) {
      try {
        final data = await supabase
            .from(table)
            .select('id')
            .eq('status', 'pending');
        return data.length;
      } catch (e) {
        continue;
      }
    }
    return 0;
  }

  // Get all leave requests with employee details for admin
  Future<List<Map<String, dynamic>>> getAllLeaveRequests({String? status}) async {
    final tables = ['leave_applications', 'leaves', 'leave_requests'];
    List<dynamic> leaves = [];
    
    for (var table in tables) {
      try {
        var query = supabase.from(table).select('*');
        if (status != null) {
          query = query.eq('status', status);
        }
        leaves = await query.order('created_at', ascending: false);
        if (leaves.isNotEmpty) break;
      } catch (e) {
        continue;
      }
    }

    if (leaves.isEmpty) return [];

    try {
      // Manually fetch user profiles to be safe
      final userIds = leaves.map((l) => l['user_id'] as String? ?? l['employee_id'] as String?).whereType<String>().toSet();
      if (userIds.isNotEmpty) {
        final allProfiles = await supabase.from('user_profiles').select('*').limit(1000);
        final profileMap = {for (var p in allProfiles) p['user_id'] ?? p['id']: p};
        
        leaves = leaves.map((leave) {
          final userId = leave['user_id'] as String? ?? leave['employee_id'] as String?;
          final profile = userId != null ? profileMap[userId] : null;
          return {
            ...leave as Map<String, dynamic>,
            'user_profiles': profile,
          };
        }).toList();
      }
    } catch (e) {
      print('Error merging profiles in getAllLeaveRequests: $e');
    }

    return (leaves as List).map((leave) {
      final profile = leave['user_profiles'] as Map<String, dynamic>? ?? {};
      return {
        'id': leave['id'],
        'user_id': leave['user_id'] ?? leave['employee_id'],
        'employee_name': profile['full_name'] ?? 'Unknown',
        'employee_code': profile['employee_id'] ?? '',
        'employee_email': profile['email'] ?? '',
        'type': leave['type'] ?? '',
        'start_date': leave['start_date'],
        'end_date': leave['end_date'],
        'reason': leave['reason'] ?? '',
        'status': leave['status'] ?? 'pending',
        'created_at': leave['created_at'],
      };
    }).toList();
  }

  // Get payroll total for current month
  Future<Map<String, dynamic>> getMonthlyPayroll() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Try different possible table names
      List<dynamic> data = [];
      final tables = ['india_payroll_config', 'payroll_settings', 'payroll'];
      for (var table in tables) {
        try {
          data = await supabase
              .from(table)
              .select()
              .gte('pay_period_start', startOfMonth.toIso8601String())
              .lte('pay_period_end', endOfMonth.toIso8601String());
          if (data.isNotEmpty) break;
        } catch (e) {
          continue;
        }
      }
      
      if (data.isEmpty) {
        print('Payroll tables not found or empty, returning defaults');
        return {
          'total_amount': 0.0,
          'paid_count': 0,
          'pending_count': 0,
          'processing_count': 0,
          'currency': 'INR',
        };
      }

      double totalAmount = 0;
      int paidCount = 0;
      int pendingCount = 0;
      int processingCount = 0;

      for (var record in data) {
        final amount = (record['gross_salary'] as num?)?.toDouble() ?? 0.0;
        totalAmount += amount;

        final status = record['status'] as String? ?? 'pending';
        if (status == 'paid') {
          paidCount++;
        } else if (status == 'pending') {
          pendingCount++;
        } else if (status == 'processing') {
          processingCount++;
        }
      }

      return {
        'total_amount': totalAmount,
        'paid_count': paidCount,
        'pending_count': pendingCount,
        'processing_count': processingCount,
        'currency': 'INR', // You can fetch this from organization settings
      };
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
    try {
      final data = await supabase
          .from('expenses')
          .select('id')
          .eq('status', 'pending');

      return data.length;
    } catch (e) {
      // Table might not exist yet
      print('Error fetching pending expenses count (table may not exist): $e');
      return 0;
    }
  }

  // Get employees with birthdays in next 7 days
  Future<int> getUpcomingBirthdaysCount() async {
    try {
      // Note: Birthday queries are complex - this is a simplified version
      // You may need to adjust based on your actual schema
      List<dynamic> data = [];
      try {
        data = await supabase
            .from('employees')
            .select('id, date_of_birth');
      } catch (e) {
        // Try with user_profiles if employees table doesn't exist
        try {
          // Try fetching without specific columns if select fails
          data = await supabase
              .from('user_profiles')
              .select('id, date_of_birth');
        } catch (e2) {
          try {
            data = await supabase
                .from('employees')
                .select('*'); // Fallback to select all
          } catch (e3) {
            print('Error: Neither employees nor user_profiles table has date_of_birth: $e3');
            return 0;
          }
        }
      }

      if (data.isEmpty) return 0;

      final today = DateTime.now();
      int count = 0;

      for (var record in data) {
        final dobStr = record['date_of_birth'] as String?;
        if (dobStr == null) continue;

        try {
          final dob = DateTime.parse(dobStr);
          final thisYearBirthday = DateTime(today.year, dob.month, dob.day);
          final daysUntil = thisYearBirthday.difference(today).inDays;

          if (daysUntil >= 0 && daysUntil <= 7) {
            count++;
          }
        } catch (e) {
          continue;
        }
      }

      return count;
    } catch (e) {
      print('Error fetching upcoming birthdays count: $e');
      return 0;
    }
  }


  // Get salary due list
  Future<List<Map<String, dynamic>>> getSalaryDueList() async {
    try {
      List<dynamic> data = [];
      try {
        // Fetch payroll records first
        data = await supabase
            .from('india_payroll_config')
            .select('*')
            .eq('status', 'pending')
            .order('created_at', ascending: false) // Using created_at since due_date might be missing
            .limit(10);
        
        if (data.isNotEmpty) {
          final userIds = data.map((r) => r['user_id'] as String?).whereType<String>().toList();
          if (userIds.isNotEmpty) {
            final allProfiles = await supabase.from('user_profiles').select('user_id, full_name, employee_id').limit(1000);
            final profileMap = {for (var p in allProfiles) p['user_id']: p};
            data = data.map((r) => {...r, 'user_profiles': profileMap[r['user_id']]}).toList();
          }
        }
      } catch (e) {
        try {
          data = await supabase
              .from('payroll')
              .select('*')
              .eq('status', 'pending')
              .limit(10);
        } catch (e2) {
          print('Payroll table not found for salary due list: $e2');
          return [];
        }
      }

      return (data as List).map((record) {
        final employee = record['user_profiles'] as Map<String, dynamic>? ?? {};
        final name = employee['full_name'] as String? ?? 'Unknown';
        return {
          'name': name,
          'amount': (record['gross_salary'] as num?)?.toDouble() ?? 
                   (record['net_salary'] as num?)?.toDouble() ?? 0.0,
          'currency': record['currency'] as String? ?? 'INR',
        };
      }).toList();
    } catch (e) {
      print('Error fetching salary due list: $e');
      return [];
    }
  }

  // Get upcoming birthdays list
  Future<List<Map<String, dynamic>>> getUpcomingBirthdays() async {
    try {
      final today = DateTime.now();
      final in7Days = today.add(const Duration(days: 7));

      List<dynamic> data = [];
      try {
        data = await supabase.from('employees').select('*').limit(50);
      } catch (e) {
        try {
          data = await supabase.from('user_profiles').select('*').limit(50);
        } catch (e2) {
          print('Error fetching birthdays from both employees and user_profiles: $e2');
          return [];
        }
      }
      
      final birthdays = <Map<String, dynamic>>[];
      
      for (var record in data) {
        final dobStr = record['date_of_birth'] as String?;
        if (dobStr == null) continue;

        try {
          final dob = DateTime.parse(dobStr);
          final thisYearBirthday = DateTime(today.year, dob.month, dob.day);
          final daysUntil = thisYearBirthday.difference(today).inDays;

          if (daysUntil >= 0 && daysUntil <= 7) {
            final name = record['full_name'] as String? ?? 
                        record['name'] as String? ?? 
                        'Unknown';
            birthdays.add({
              'name': name,
              'date_of_birth': dobStr,
            });
          }
        } catch (e) {
          continue;
        }
      }
      
      return birthdays.take(10).toList();
    } catch (e) {
      print('Error fetching upcoming birthdays: $e');
      return [];
    }
  }

  // Get leave balances for employees
  Future<List<Map<String, dynamic>>> getEmployeesLeaveBalances() async {
    try {
      List<dynamic> data = [];
      try {
        data = await supabase.from('leave_balances').select('*').limit(10);
        
        if (data.isNotEmpty) {
          // Fetch profiles separately to avoid join issues
          final userIds = data.map((r) => r['user_id'] as String?).whereType<String>().toList();
          if (userIds.isNotEmpty) {
            final allProfiles = await supabase.from('user_profiles').select('user_id, full_name').limit(1000);
            final profileMap = {for (var p in allProfiles) p['user_id']: p};
            data = data.map((r) => {...r, 'user_profiles': profileMap[r['user_id']]}).toList();
          }
        }
      } catch (e) {
        print('Error fetching leave balances: $e');
        return [];
      }

      return (data as List).map((record) {
        // Try to get name from different possible relationships
        final profile = record['user_profiles'] as Map<String, dynamic>? ?? 
                       record['employees'] as Map<String, dynamic>? ?? {};
        final name = profile['full_name'] as String? ?? 'Unknown';
        
        return {
          'name': name,
          'annual': record['annual'] as int? ?? 0,
          'sick': record['sick'] as int? ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching employees leave balances: $e');
      return [];
    }
  }

  // Get payroll employees list for a specific month/year (India Payroll)
  Future<List<Map<String, dynamic>>> getPayrollEmployees({
    int? month,
    int? year,
  }) async {
    try {
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;
      final startOfMonth = DateTime(targetYear, targetMonth, 1);
      final endOfMonth = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);

      List<dynamic> data = [];
      
      // Use india_payroll_config table (India payroll)
      try {
        // First, get payroll records
        data = await supabase
            .from('india_payroll_config')
            .select('*')
            .gte('pay_period_start', startOfMonth.toIso8601String())
            .lte('pay_period_end', endOfMonth.toIso8601String())
            .order('created_at', ascending: true);
        
        // Then fetch user profiles separately and merge
        if (data.isNotEmpty) {
          final userIds = data.map((record) => record['user_id'] as String?).whereType<String>().toList();
          if (userIds.isNotEmpty) {
            // Fetch all profiles and filter in code (since inFilter may not be available)
            final allProfiles = await supabase
                .from('user_profiles')
                .select('user_id, full_name, employee_id, pan')
                .limit(1000);
            
            // Filter profiles to only those in userIds
            final profiles = (allProfiles as List).where((profile) {
              final userId = profile['user_id'] as String?;
              return userId != null && userIds.contains(userId);
            }).toList();
            
            // Create a map for quick lookup
            final profileMap = <String, Map<String, dynamic>>{};
            for (var profile in profiles) {
              final userId = profile['user_id'] as String?;
              if (userId != null) {
                profileMap[userId] = profile as Map<String, dynamic>;
              }
            }
            
            // Merge payroll data with profile data
            data = data.map((record) {
              final userId = record['user_id'] as String?;
              final profile = userId != null ? profileMap[userId] : null;
              return {
                ...record,
                'user_profiles': profile,
              };
            }).toList();
          }
        }
      } catch (e) {
        print('Error fetching payroll employees: $e');
        return [];
      }

      return (data as List).map((record) {
        final employee = record['user_profiles'] as Map<String, dynamic>? ?? {};
        
        final basic = (record['basic_salary'] as num?)?.toDouble() ?? 0.0;
        final da = (record['da'] as num?)?.toDouble() ?? 0.0;
        final hra = (record['hra'] as num?)?.toDouble() ?? 0.0;
        final special = (record['special'] as num?)?.toDouble() ?? 0.0;
        final gross = (record['gross_salary'] as num?)?.toDouble() ?? 
                     (basic + da + hra + special);
        final pf = (record['pf'] as num?)?.toDouble() ?? (gross * 0.12);
        final esi = (record['esi'] as num?)?.toDouble() ?? 0.0;
        final tds = (record['tds'] as num?)?.toDouble() ?? 0.0;
        final professionalTax = (record['professional_tax'] as num?)?.toDouble() ?? 0.0;
        final netSalary = (record['net_salary'] as num?)?.toDouble() ?? 
                         (gross - pf - esi - tds - professionalTax);
        
        return {
          'id': record['id'],
          'employee_name': employee['full_name'] as String? ?? 'Unknown',
          'employee_code': employee['employee_id'] as String? ?? '',
          'pan': employee['pan'] as String? ?? record['pan'] as String? ?? '',
          'basic_salary': basic,
          'da': da,
          'hra': hra,
          'special': special,
          'gross_salary': gross,
          'pf': pf,
          'esi': esi,
          'tds': tds,
          'professional_tax': professionalTax,
          'net_salary': netSalary,
          'status': record['status'] as String? ?? 'pending',
          'currency': record['currency'] as String? ?? 'INR',
        };
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
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;
      final startOfMonth = DateTime(targetYear, targetMonth, 1);
      final endOfMonth = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);

      // Get total employees count
      final totalEmployees = await getTotalEmployees();

      // Use a resilient table fetch
      List<dynamic> data = [];
      final tables = ['india_payroll_config', 'payroll_settings', 'payroll'];
      for (var table in tables) {
        try {
          data = await supabase
              .from(table)
              .select()
              .gte('pay_period_start', startOfMonth.toIso8601String())
              .lte('pay_period_end', endOfMonth.toIso8601String());
          if (data.isNotEmpty) break;
        } catch (e) {
          continue;
        }
      }
      
      if (data.isEmpty) {
        return {
          'total_employees': totalEmployees,
          'paid_count': 0,
          'pending_count': 0,
          'total_amount': 0.0,
          'currency': 'INR',
        };
      }

      double totalAmount = 0;
      int paidCount = 0;
      int pendingCount = 0;

      for (var record in data) {
        final amount = (record['net_salary'] as num?)?.toDouble() ?? 
                      ((record['gross_salary'] as num?)?.toDouble() ?? 0.0);
        totalAmount += amount;

        final status = record['status'] as String? ?? 'pending';
        if (status == 'paid' || status == 'approved_paid' || status == 'PAID') {
          paidCount++;
        } else if (status == 'pending' || status == 'PENDING') {
          pendingCount++;
        }
      }

      return {
        'total_employees': totalEmployees,
        'paid_count': paidCount,
        'pending_count': pendingCount,
        'total_amount': totalAmount,
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
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;
      final startOfMonth = DateTime(targetYear, targetMonth, 1);
      final endOfMonth = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);

      List<dynamic> data = [];
      final tables = ['india_payroll_config', 'payroll_settings', 'payroll'];
      for (var table in tables) {
        try {
          data = await supabase
              .from(table)
              .select()
              .gte('pay_period_start', startOfMonth.toIso8601String())
              .lte('pay_period_end', endOfMonth.toIso8601String());
          if (data.isNotEmpty) break;
        } catch (e) {
          continue;
        }
      }
      
      if (data.isEmpty) {
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

      double totalPFEmployee = 0;
      double totalPFEmployer = 0;
      double totalESIEmployee = 0;
      double totalESIEmployer = 0;
      double totalTDS = 0;
      double totalProfessionalTax = 0;

      for (var record in data) {
        final gross = (record['gross_salary'] as num?)?.toDouble() ?? 0.0;
        
        // PF calculation (12% each)
        final pfEmployee = (record['pf_employee'] as num?)?.toDouble() ?? (gross * 0.12);
        final pfEmployer = (record['pf_employer'] as num?)?.toDouble() ?? (gross * 0.12);
        totalPFEmployee += pfEmployee;
        totalPFEmployer += pfEmployer;
        
        // ESI calculation (only if gross <= 21000)
        if (gross <= 21000) {
          final esiEmployee = (record['esi_employee'] as num?)?.toDouble() ?? (gross * 0.0075);
          final esiEmployer = (record['esi_employer'] as num?)?.toDouble() ?? (gross * 0.0325);
          totalESIEmployee += esiEmployee;
          totalESIEmployer += esiEmployer;
        }
        
        // TDS and Professional Tax
        totalTDS += (record['tds'] as num?)?.toDouble() ?? 0.0;
        totalProfessionalTax += (record['professional_tax'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'pf_employee': totalPFEmployee,
        'pf_employer': totalPFEmployer,
        'total_pf': totalPFEmployee + totalPFEmployer,
        'esi_employee': totalESIEmployee,
        'esi_employer': totalESIEmployer,
        'total_esi': totalESIEmployee + totalESIEmployer,
        'tds': totalTDS,
        'professional_tax': totalProfessionalTax,
        'total_tax': totalTDS + totalProfessionalTax,
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
      // Try fetching from user_profiles first (single source of truth for auth + profile)
      final data = await supabase
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching all employees: $e');
      return [];
    }
  }

  // Create new employee
  Future<bool> createEmployee(Map<String, dynamic> employeeData) async {
    try {
      // Note: In a real Supabase app, creating a user usually involves auth.admin.createUser
      // but here we might just be creating the profile record if the auth user is created separately
      // or via a trigger. We'll try inserting into user_profiles directly.
      
      await supabase.from('user_profiles').insert(employeeData);
      return true;
    } catch (e) {
      print('Error creating employee: $e');
      return false;
    }
  }

  // Update employee
  Future<bool> updateEmployee(String id, Map<String, dynamic> employeeData) async {
    try {
      await supabase
          .from('user_profiles')
          .update(employeeData)
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating employee: $e');
      return false;
    }
  }

  // Process Payroll for a month
  Future<bool> processPayroll({required int month, required int year}) async {
    try {
      // This is a mock implementation of the logic that would run on the backend (Edge Function).
      // In a real app, we'd call an RPC or Edge Function.
      // Here we will try to insert a record into a 'payroll_runs' or similar log if it exists,
      // or just return true to simulate success for the UI as requested.
      
      // Simulating network delay
      await Future.delayed(const Duration(seconds: 2));
      
      // If we had an RPC function:
      // await supabase.rpc('process_monthly_payroll', params: {'month': month, 'year': year});
      
      return true;
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
      
      // 1. Fetch attendance with employees to get user_id
      final data = await supabase
          .from('attendance_records')
          .select('*, employees(user_id)') 
          .eq('date', dateStr)
          .order('check_in_time', ascending: false);
      
      final records = List<Map<String, dynamic>>.from(data as List);
      
      if (records.isEmpty) return [];

      // 2. Extract User IDs
      final userIds = <String>{};
      for (var record in records) {
        final employees = record['employees'] as Map<String, dynamic>?;
        if (employees != null && employees['user_id'] != null) {
          userIds.add(employees['user_id'] as String);
        }
      }

      if (userIds.isEmpty) return records;

      // 3. Fetch User Profiles
      final profiles = await supabase
          .from('user_profiles')
          .select('user_id, full_name')
          .inFilter('user_id', userIds.toList());
      
      final profileMap = {
        for (var p in profiles) p['user_id'] as String: p
      };

      // 4. Inject user_profiles into records
      return records.map((record) {
        final employees = record['employees'] as Map<String, dynamic>?;
        final userId = employees?['user_id'] as String?;
        final profile = userId != null ? profileMap[userId] : null;

        return {
          ...record,
          'user_profiles': profile, // Injecting explicitly for UI compatibility
        };
      }).toList();

    } catch (e) {
      print('Error fetching all attendance: $e');
      // Try fallback to 'attendance' table if 'attendance_records' fails
      try {
        final targetDate = date ?? DateTime.now();
        final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
        final data = await supabase
            .from('attendance')
            .select('*, user_profiles(*)')
            .eq('date', dateStr);
        return List<Map<String, dynamic>>.from(data);
      } catch (e2) {
        return [];
      }
    }
  }

  // Create Announcement
  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    try {
      await supabase.from('announcements').insert({
        ...data,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true, 
      });
      return true;
    } catch (e) {
      print('Error creating announcement: $e');
      return false;
    }
  }
  // Get Department Stats (Mock)
  Future<List<Map<String, dynamic>>> getDepartmentStats() async {
    // Simulating loading
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'name': 'Engineering', 'count': 15, 'color': 0xFF2196F3}, // Blue
      {'name': 'Sales', 'count': 8, 'color': 0xFF4CAF50}, // Green
      {'name': 'Marketing', 'count': 5, 'color': 0xFFFF9800}, // Orange
      {'name': 'Finance', 'count': 3, 'color': 0xFF9C27B0}, // Purple
      {'name': 'HR', 'count': 4, 'color': 0xFFE91E63}, // Pink
    ];
  }

  // Get Actual Designations from Database
  Future<List<String>> getDesignations() async {
    try {
      // Try fetching from designations table first
      final data = await supabase
          .from('designations')
          .select('name')
          .order('name', ascending: true);
      
      if (data != null && (data as List).isNotEmpty) {
        return (data as List).map((d) => d['name'].toString()).toList();
      }
      
      // Fallback: try fetching unique designations from user_profiles
      final profileData = await supabase
          .from('user_profiles')
          .select('designation')
          .not('designation', 'is', null);
      
      final distinctDesignations = (profileData as List)
          .map((item) => item['designation']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      
      distinctDesignations.sort();
      return distinctDesignations;
    } catch (e) {
      print('Error fetching designations: $e');
      return ['Technical', 'Operations', 'Management', 'HR']; // Safe defaults if everything fails
    }
  }

  // Get Tasks Stats (Mock)
  Future<Map<String, dynamic>> getTasksStats() async {
    // Simulating loading
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'total': 2,
      'todo': 0,
      'in_progress': 0,
      'in_review': 0,
      'completed': 1,
      'overdue': 0,
    };
  }

  // Get All Tasks (Mock)
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {
        'id': 'TASK-102',
        'title': 'Task',
        'type': 'FEATURE',
        'priority': 'MEDIUM',
        'assignee': {'name': 'Virat Kohli', 'avatar': null},
        'due_date': '2026-01-31',
        'status': 'COMPLETED',
      },
       {
        'id': 'TASK-103',
        'title': 'API Integration',
        'type': 'BUG',
        'priority': 'HIGH',
        'assignee': {'name': 'Rohit Sharma', 'avatar': null},
        'due_date': '2026-02-20',
        'status': 'TODO',
      },
    ];
  }

  // Get Leave Analytics (Mock)
  Future<Map<String, dynamic>> getLeaveAnalytics() async {
    // Simulating loading
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock Data
    return {
      'totalRequests': 24,
      'pendingRequests': 5,
      'approvedRequests': 18,
      'rejectedRequests': 1,
      'onLeaveToday': 2,
      'upcomingLeaves': 3,
      'monthlyTrends': [
        {'month': 'Sep', 'count': 12},
        {'month': 'Oct', 'count': 8},
        {'month': 'Nov', 'count': 15},
        {'month': 'Dec', 'count': 22},
        {'month': 'Jan', 'count': 18},
        {'month': 'Feb', 'count': 24},
      ],
      'typeDistribution': [
        {'name': 'Casual Leave', 'count': 40, 'color': 0xFF2196F3},
        {'name': 'Sick Leave', 'count': 30, 'color': 0xFFF44336},
        {'name': 'Earned Leave', 'count': 20, 'color': 0xFF4CAF50},
        {'name': 'WFH', 'count': 10, 'color': 0xFFFF9800},
      ],
    };
  }

  // Get Leave Types (Mock)
  Future<List<Map<String, dynamic>>> getLeaveTypes() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {
        'id': '1',
        'name': 'Annual Leave Global',
        'code': 'AL',
        'description': '-',
        'paid': true,
        'maxDays': null,
        'requiresDoc': false,
        'carryForward': false,
        'status': 'Active',
        'allocated': 24,
      },
      {
        'id': '2',
        'name': 'Work From Home 2 Global',
        'code': 'WFH',
        'description': '-',
        'paid': true,
        'maxDays': null,
        'requiresDoc': false,
        'carryForward': false,
        'status': 'Active',
        'allocated': 24,
      },
       {
        'id': '3',
        'name': 'Sick Leave',
        'code': 'SL',
        'description': 'Medical certificate required > 2 days',
        'paid': true,
        'maxDays': 12,
        'requiresDoc': true,
        'carryForward': true,
        'status': 'Active',
        'allocated': 12,
      },
       {
        'id': '4',
        'name': 'Loss of Pay',
        'code': 'LOP',
        'description': 'Unpaid leave',
        'paid': false,
        'maxDays': null,
        'requiresDoc': false,
        'carryForward': false,
        'status': 'Active',
        'allocated': 0,
      },
    ];
  }
}

