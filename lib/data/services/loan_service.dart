import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/models/loan.dart';

class LoanService {
  // Get employee eligibility info
  Future<Map<String, dynamic>> getEmployeeEligibility(String userId, {Map<String, dynamic>? userProfile}) async {
    try {
      print('LoanService: Checking eligibility for user $userId');
      
      String? dojStr;
      String? status;
      String? employeeId;
      Map<String, dynamic>? employeeData;

      // 0. Use provided userProfile if available (Best Source of Truth)
      if (userProfile != null) {
        print('LoanService: Using provided userProfile data');
        
        if (userProfile['date_of_joining'] != null) {
          dojStr = userProfile['date_of_joining'] as String;
          print('LoanService: Using DOJ from ProfileProvider: $dojStr');
        }
        
        if (userProfile['status'] != null) {
          status = userProfile['status'] as String;
          print('LoanService: Using status from ProfileProvider: $status');
        }
        
        // Try to get employee ID from profile
        if (userProfile['employee_id'] != null) {
           // If it looks like a valid ID (not N/A), use it
           final pEmpId = userProfile['employee_id'] as String;
           if (pEmpId.isNotEmpty && pEmpId != 'N/A') {
             employeeId = pEmpId;
           }
        }
      }

      // If we have what we need from ProfileProvider, skip the robust lookup or use it as fallback
      if (dojStr != null && status != null) {
         // We still might want to get the actual employee record to ensure we have the UUID for foreign keys
         // if the profile provider only had the display code
         if (employeeId == null || employeeId == userId) {
            // Do a quick lookup just for ID
             try {
              final emp = await supabase
                  .from('employees')
                  .select('id')
                  .eq('user_id', userId)
                  .maybeSingle();
              if (emp != null) {
                employeeId = emp['id'] as String;
              }
            } catch (e) {}
         }
      } else {
        // Fallback to internal robust lookup if profile didn't have data
        try {
          employeeData = await supabase
              .from('employees')
              .select()
              .eq('user_id', userId)
              .maybeSingle();
              
          if (employeeData != null) {
            print('LoanService: Found employee by user_id');
          }
        } catch (e) {
          print('LoanService: Failed to fetch by user_id: $e');
        }
        
        // 2b. If not found, try by employee_id/employee_code
        if (employeeData == null && (employeeId?.isNotEmpty ?? false)) {
          try {
             employeeData = await supabase
                 .from('employees')
                 .select()
                 .or('id.eq.$employeeId,employee_code.eq.$employeeId')
                 .limit(1)
                 .maybeSingle();
                 
             if (employeeData != null) {
               print('LoanService: Found employee by ID/Code: $employeeId');
             }
          } catch (e) {
            print('LoanService: Failed to fetch by ID/Code: $e');
          }
        }
        
        // 3. Extract Data (Prioritizing employees table)
        if (employeeData != null) {
          // Update employeeId to the UUID from employees table (crucial for foreign keys)
          if (employeeData['id'] != null) {
            employeeId = employeeData['id'] as String;
          }
          
          // Status
          if (employeeData['status'] != null) {
            status = employeeData['status'] as String?;
          }
          
          // 4. Resolve Date of Joining (Check all possible columns)
          dojStr = employeeData['date_of_joining'] as String? ?? 
                   employeeData['joining_date'] as String? ??
                   employeeData['doj'] as String? ??
                   employeeData['start_date'] as String?;
        }
        
        // 5. Fallback: If still no DOJ, try views (last resort, similar to ProfileService)
        if (dojStr == null) {
          final viewPatterns = ['employees_with_details', 'employee_details', 'v_employees'];
          for (final pattern in viewPatterns) {
            try {
              final viewData = await supabase
                  .from(pattern)
                  .select()
                  .eq('user_id', userId)
                  .maybeSingle();
                  
              if (viewData != null) {
                dojStr = viewData['date_of_joining'] as String? ?? 
                         viewData['joining_date'] as String? ??
                         viewData['doj'] as String?;
                
                if (viewData['status'] != null) {
                  status = viewData['status'] as String?;
                }
                if (dojStr != null) break;
              }
            } catch (e) { continue; }
          }
        }
      }

      if (dojStr == null) {
        return {
          'isEligible': false,
          'reason': 'Date of joining not set',
          'monthsWorked': 0,
          'status': status?.toUpperCase() ?? 'UNKNOWN',
          'dateOfJoining': null,
        };
      }

      final doj = DateTime.parse(dojStr);
      final now = DateTime.now();
      
      // Calculate total months difference
      final monthsWorked = (now.year - doj.year) * 12 + (now.month - doj.month) + 
          (now.day >= doj.day ? 0 : -1);
      
      print('LoanService: Calculated months worked: $monthsWorked (DOJ: $dojStr)');
      
      // Check if status is probation or active
      final validStatuses = ['active', 'probation', 'confirmed', 'permanent', 'regular'];
      final statusLower = status?.toLowerCase().trim() ?? 'active';
      final isStatusValid = validStatuses.contains(statusLower);

      // Eligible ONLY if 6+ months worked AND status is valid
      final isEligible = monthsWorked >= 6 && isStatusValid;

      // Get gross salary
      double? grossSalary;
      try {
        final payroll = await supabase
            .from('india_payroll_config')
            .select('gross_salary')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        
        grossSalary = (payroll?['gross_salary'] as num?)?.toDouble();
      } catch (e) {
        print('Error fetching gross salary: $e');
      }

      return {
        'isEligible': isEligible,
        'reason': isEligible 
            ? null 
            : monthsWorked < 6 
                ? 'Must complete 6 months. Completed: $monthsWorked months.'
                : !isStatusValid
                    ? 'Status must be active/probation. Current: $statusLower'
                    : 'Not eligible',
        'monthsWorked': monthsWorked < 0 ? 0 : monthsWorked,
        'status': statusLower.toUpperCase(),
        'dateOfJoining': dojStr,
        'grossSalary': grossSalary,
        'employeeId': employeeId,
      };
    } catch (e) {
      print('Error getting employee eligibility: $e');
      return {
        'isEligible': false,
        'reason': 'Error checking eligibility: $e',
        'monthsWorked': 0,
        'status': null,
      };
    }
  }

  // Get maximum loan amount based on months worked
  double? getMaxLoanAmount(int monthsWorked, double? grossSalary) {
    if (grossSalary == null || grossSalary <= 0) return null;
    
    if (monthsWorked >= 12) {
      // After 1 year, can apply for any amount (no limit, but will need approval)
      return null; // null means no limit
    } else if (monthsWorked >= 6) {
      // After 6 months, can apply for half of gross salary
      return grossSalary / 2;
    }
    
    return 0; // Not eligible
  }

  // Apply for loan
  Future<bool> applyForLoan({
    required String userId,
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Fetch organization_id directly from user profile as it's required
      final userProfile = await supabase
          .from('user_profiles')
          .select('organization_id')
          .eq('user_id', userId)
          .maybeSingle();
          
      if (userProfile == null || userProfile['organization_id'] == null) {
        print('Error: Organization ID not found for user $userId');
        return false;
      }
      
      final organizationId = userProfile['organization_id'] as String;

      await supabase
          .from('india_employee_loans')
          .insert({
            'organization_id': organizationId,
            'employee_id': employeeId, // Must be UUID referencing employees(id)
            'loan_amount': amount,
            'notes': reason,
            'loan_type': 'personal', // Default
            'status': 'pending',
            'start_date': now.toIso8601String(), // Required
            'total_installments': 12, // Default to 12 months if not specified
            'installment_amount': (amount / 12).roundToDouble(), // Rough calc
            'created_at': now.toIso8601String(),
          });

      return true;
    } catch (e) {
      print('Error applying for loan: $e');
      return false;
    }
  }

  // Get user's loan applications
  Future<List<LoanApplication>> getUserLoans(String userId) async {
    try {
      // We need employee_id to fetch loans
      // Fetch employee ID for this user first
      final employeeData = await supabase
          .from('employees')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (employeeData == null) return [];
      
      final employeeId = employeeData['id'] as String;

      final data = await supabase
          .from('india_employee_loans')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => LoanApplication.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user loans: $e');
      return [];
    }
  }

  // Get all pending loans (for admin)
  Future<List<LoanApplication>> getPendingLoans(String organizationId) async {
    try {
      // Get all user profiles in the organization first (Optimization: just get user_ids)
      final profiles = await supabase
          .from('user_profiles')
          .select('user_id')
          .eq('organization_id', organizationId);

      final userIds = (profiles as List)
          .map((p) => p['user_id'] as String?)
          .whereType<String>()
          .toList();

      if (userIds.isEmpty) return [];

      // Get pending loans for these users
      // Fetch loans first without join to avoid error
      final data = await supabase
          .from('india_employee_loans')
          .select('*')
          .eq('status', 'pending')
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);

      final loansList = List<Map<String, dynamic>>.from(data as List);
      
      if (loansList.isEmpty) return [];

      // Manual Fetch for Names
      try {
        // 1. Get Employee IDs from loans
        final employeeIds = loansList
            .map((l) => l['employee_id'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
            
        // 2. Fetch Employees to get User IDs (if needed, or if we can link directly)
        // Since we filtered profiles by org initially, let's fetch profiles for these specific loans to get names
        // But first we need user_id corresponding to employee_id
        final employees = await supabase
            .from('employees')
            .select('id, user_id')
            .inFilter('id', employeeIds);
            
        final empUserMap = {
          for (var e in employees) e['id'] as String: e['user_id'] as String?
        };
        
        // 3. Get User IDs
        final loanUserIds = empUserMap.values.whereType<String>().toSet().toList();
        
        // 4. Fetch Names from User Profiles
        final userProfiles = await supabase
            .from('user_profiles')
            .select('user_id, full_name')
            .inFilter('user_id', loanUserIds);
            
        final nameMap = {
          for (var u in userProfiles) u['user_id'] as String: u['full_name'] as String?
        };
        
        // 5. Merge Names into Loan Data
        final loans = loansList.map((json) {
          final empId = json['employee_id'] as String?;
          final userId = empUserMap[empId];
          final name = nameMap[userId] ?? 'Unknown Employee';
          
          // Inject name into json for fromJson or use constructor
          // We updated fromJson to look for 'employee_name', so let's add it
          return LoanApplication.fromJson({
            ...json,
            'employee_name': name,
          });
        }).toList();
        
        return loans;
        
      } catch (e) {
        print('Error fetching details for pending loans: $e');
        // Return basic loans if details fetch fails
        return loansList.map((json) => LoanApplication.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching pending loans: $e');
      return [];
    }
  }

  // Approve loan
  Future<bool> approveLoan({
    required String loanId,
    required String approvedBy,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      await supabase
          .from('india_employee_loans')
          .update({
            'status': 'approved',
            'approved_by': approvedBy,
            'approved_at': now.toIso8601String(),
          })
          .eq('id', loanId);

      return true;
    } catch (e) {
      print('Error approving loan: $e');
      return false;
    }
  }

  // Reject loan
  Future<bool> rejectLoan({
    required String loanId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      await supabase
          .from('india_employee_loans')
          .update({
            'status': 'rejected',
            // 'rejected_by': rejectedBy, // Column often missing in standard schemas, sticking to status update primarily or adding 'notes' update if needed
            // 'rejection_reason': rejectionReason, 
            // Updating notes with rejection reason if separate column doesn't exist
            'notes': 'REJECTED: $rejectionReason', // Append to notes or overwrite
            'updated_at': now.toIso8601String(),
          })
          .eq('id', loanId);

      return true;
    } catch (e) {
      print('Error rejecting loan: $e');
      return false;
    }
  }
}

