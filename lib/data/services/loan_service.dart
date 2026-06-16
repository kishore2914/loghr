import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/loan.dart';

class LoanService {
  // Get employee eligibility info
  Future<Map<String, dynamic>> getEmployeeEligibility(String userId, {Map<String, dynamic>? userProfile}) async {
    try {
      final response = await api.get('/loans/eligibility');
      if (response == null) {
        return {
          'isEligible': false,
          'reason': 'Error checking eligibility',
          'monthsWorked': 0,
          'status': 'UNKNOWN',
        };
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error checking eligibility: $e');
      return {
        'isEligible': false,
        'reason': 'Error checking eligibility: $e',
        'monthsWorked': 0,
        'status': 'UNKNOWN',
      };
    }
  }

  // Get maximum loan amount based on months worked
  double? getMaxLoanAmount(int monthsWorked, double? grossSalary) {
    if (grossSalary == null || grossSalary <= 0) return null;
    if (monthsWorked >= 12) return null; // No limit
    if (monthsWorked >= 6) return grossSalary / 2;
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
      final response = await api.post('/loans/apply', {
        'amount': amount,
        'installmentAmount': (amount / 12).roundToDouble(),
        'installmentsCount': 12,
        'loanType': 'personal',
        'interestRate': 0,
        'notes': reason,
      });
      return response != null;
    } catch (e) {
      print('Error applying for loan: $e');
      return false;
    }
  }

  // Get user's loan applications
  Future<List<LoanApplication>> getUserLoans(String userId) async {
    try {
      final response = await api.get('/loans');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => LoanApplication.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching user loans: $e');
      return [];
    }
  }

  // Get all pending loans (for admin)
  Future<List<LoanApplication>> getPendingLoans(String organizationId) async {
    try {
      final response = await api.get('/loans/pending');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => LoanApplication.fromJson(json)).toList();
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
      final response = await api.post('/loans/$loanId/approve', {});
      return response != null;
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
      final response = await api.post('/loans/$loanId/reject', {
        'rejectionReason': rejectionReason,
      });
      return response != null;
    } catch (e) {
      print('Error rejecting loan: $e');
      return false;
    }
  }
}
