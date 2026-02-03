import 'package:loghr_mobile/data/models/loan.dart';
import 'package:loghr_mobile/data/services/loan_service.dart';

class LoanRepository {
  final LoanService _service;

  LoanRepository(this._service);

  Future<Map<String, dynamic>> getEmployeeEligibility(String userId) async {
    return await _service.getEmployeeEligibility(userId);
  }

  double? getMaxLoanAmount(int monthsWorked, double? grossSalary) {
    return _service.getMaxLoanAmount(monthsWorked, grossSalary);
  }

  Future<bool> applyForLoan({
    required String userId,
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    return await _service.applyForLoan(
      userId: userId,
      employeeId: employeeId,
      amount: amount,
      reason: reason,
    );
  }

  Future<List<LoanApplication>> getUserLoans(String userId) async {
    return await _service.getUserLoans(userId);
  }

  Future<List<LoanApplication>> getPendingLoans(String organizationId) async {
    return await _service.getPendingLoans(organizationId);
  }

  Future<bool> approveLoan({
    required String loanId,
    required String approvedBy,
  }) async {
    return await _service.approveLoan(
      loanId: loanId,
      approvedBy: approvedBy,
    );
  }

  Future<bool> rejectLoan({
    required String loanId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    return await _service.rejectLoan(
      loanId: loanId,
      rejectedBy: rejectedBy,
      rejectionReason: rejectionReason,
    );
  }
}

