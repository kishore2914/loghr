import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/models/loan.dart';

class LoanService {
  // Get employee eligibility info
  Future<Map<String, dynamic>> getEmployeeEligibility(String userId) async {
    try {
      print('LoanService: Checking eligibility for user $userId');
      
      // Get employee profile with date of joining and status
      // We need to check both user_profiles and employees table for truth
      final profile = await supabase
          .from('user_profiles')
          .select('''
            status, 
            employee_id, 
            organization_id
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (profile == null) {
        return {
          'isEligible': false,
          'reason': 'Employee profile not found',
          'monthsWorked': 0,
          'status': null,
        };
      }

      String? dojStr; // Was profile['date_of_joining'], but that column doesn't exist in user_profiles
      String? status = profile['status'] as String? ?? 'active';
      String employeeId = profile['employee_id'] as String? ?? userId;

      // 1. FIRST PRIORITY: Try to find employee by user_id in employees table
      // This is the most reliable method as used in ProfileService
      try {
        final empDataByUserId = await supabase
            .from('employees')
            .select('id, date_of_joining, joining_date, doj, start_date, status')
            .eq('user_id', userId)
            .maybeSingle();

        if (empDataByUserId != null) {
          print('LoanService: Found employee record by user_id: $userId');

           // Capture the real UUID from the employees table
           // This is crucial for the foreign key in india_employee_loans
           if (empDataByUserId['id'] != null) {
              employeeId = empDataByUserId['id'] as String;
              print('LoanService: Updated employeeId to UUID: $employeeId');
           }

           // Check multiple possible column names for Date of Joining
           final possibleDoj = empDataByUserId['date_of_joining'] as String? ?? 
                               empDataByUserId['joining_date'] as String? ??
                               empDataByUserId['doj'] as String? ??
                               empDataByUserId['start_date'] as String?;
                               
           if (possibleDoj != null) {
             dojStr = possibleDoj;
             print('LoanService: Using DOJ from employees table (via user_id): $dojStr');
           }
           
           if (empDataByUserId['status'] != null) {
             status = empDataByUserId['status'] as String?;
             print('LoanService: Using status from employees table (via user_id): $status');
           }
        }
      } catch (e) {
        print('LoanService: Failed to fetch by user_id: $e');
      }

      // 2. SECOND PRIORITY: Try specific employee_id lookup if not found yet or if DOJ still null
      if (dojStr == null && employeeId != userId) {
         try {
           // Try to find by ID first, then employee_code (robust lookup)
           final empData = await supabase
               .from('employees')
               .select('date_of_joining, joining_date, doj, start_date, status')
               .or('id.eq.$employeeId,employee_code.eq.$employeeId')
               .limit(1)
               .maybeSingle();
               
           if (empData != null) {
             print('LoanService: Found employee record for $employeeId');
             
             // Check multiple possible column names for Date of Joining
             final possibleDoj = empData['date_of_joining'] as String? ?? 
                                 empData['joining_date'] as String? ??
                                 empData['doj'] as String? ??
                                 empData['start_date'] as String?;
                                 
             if (possibleDoj != null) {
               dojStr = possibleDoj;
               print('LoanService: Using DOJ from employees table: $dojStr');
             }
             
             if (empData['status'] != null) {
               status = empData['status'] as String?;
               print('LoanService: Using status from employees table: $status');
             }
           }
         } catch (e) {
           print('LoanService: Error fetching detailed employee data: $e');
         }
      }


      if (dojStr == null) {
        return {
          'isEligible': false,
          'reason': 'Date of joining not set',
          'monthsWorked': 0,
          'status': status,
        };
      }

      final doj = DateTime.parse(dojStr);
      final now = DateTime.now();
      
      // Calculate total months difference
      final monthsWorked = (now.year - doj.year) * 12 + (now.month - doj.month) + 
          (now.day >= doj.day ? 0 : -1); // Subtract 1 if current day < joining day
      
      print('LoanService: Calculated months worked: $monthsWorked (DOJ: $dojStr)');
      
      // Check if status is probation or active (or other valid statuses)
      final validStatuses = ['active', 'probation', 'confirmed', 'permanent', 'regular'];
      final statusLower = status?.toLowerCase() ?? '';
      
      final isStatusValid = validStatuses.contains(statusLower);

      // Eligible if 6+ months worked AND status is valid
      final isEligible = monthsWorked >= 6 && isStatusValid;

      // Get gross salary for loan amount calculation
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
        // Fallback for gross salary if payroll config missing
        // Could fetch from employees table if it had salary info
        print('Error fetching gross salary: $e');
      }

      return {
        'isEligible': isEligible,
        'reason': isEligible 
            ? null 
            : monthsWorked < 6 
                ? 'Must complete 6 months of service'
                : !isStatusValid
                    ? 'Employee status must be probation or active'
                    : 'Not eligible',
        'monthsWorked': monthsWorked < 0 ? 0 : monthsWorked,
        'status': status,
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
      // Get all user profiles in the organization first
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
      // We need to join with employees table to get names, as user_profiles might not be directly linked in this table
      final data = await supabase
          .from('india_employee_loans')
          .select('''
            *,
            employees!india_employee_loans_employee_id_fkey(full_name, employee_code, user_id)
          ''')
          .eq('status', 'pending')
          .eq('organization_id', organizationId) // Filter by org directly
          .order('created_at', ascending: false);

      final loans = (data as List)
          .map((json) => LoanApplication.fromJson(json))
          .toList();

      return loans;
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

