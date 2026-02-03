import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/loan.dart';
import 'package:loghr_mobile/data/repositories/loan_repository.dart';

class LoanProvider extends ChangeNotifier {
  final LoanRepository _repository;
  
  Map<String, dynamic>? _eligibility;
  List<LoanApplication> _userLoans = [];
  List<LoanApplication> _pendingLoans = [];
  bool _isLoading = false;
  String? _error;

  LoanProvider(this._repository);

  Map<String, dynamic>? get eligibility => _eligibility;
  List<LoanApplication> get userLoans => _userLoans;
  List<LoanApplication> get pendingLoans => _pendingLoans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isEligible => _eligibility?['isEligible'] == true;
  int get monthsWorked => _eligibility?['monthsWorked'] ?? 0;
  double? get maxLoanAmount {
    if (_eligibility == null) return null;
    final months = _eligibility!['monthsWorked'] ?? 0;
    final grossSalary = _eligibility!['grossSalary'] as double?;
    return _repository.getMaxLoanAmount(months, grossSalary);
  }

  Future<void> checkEligibility(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _eligibility = await _repository.getEmployeeEligibility(userId);
      if (_eligibility != null && _eligibility!['isEligible'] == true) {
        // Calculate max loan amount
        final months = _eligibility!['monthsWorked'] ?? 0;
        final grossSalary = _eligibility!['grossSalary'];
        _eligibility!['maxLoanAmount'] = _repository.getMaxLoanAmount(months, grossSalary);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> applyForLoan({
    required String userId,
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.applyForLoan(
        userId: userId,
        employeeId: employeeId,
        amount: amount,
        reason: reason,
      );

      if (success) {
        await loadUserLoans(userId);
      }

      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserLoans(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userLoans = await _repository.getUserLoans(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingLoans(String organizationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pendingLoans = await _repository.getPendingLoans(organizationId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveLoan({
    required String loanId,
    required String approvedBy,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.approveLoan(
        loanId: loanId,
        approvedBy: approvedBy,
      );

      if (success) {
        // Remove approved loan from pending list
        _pendingLoans.removeWhere((loan) => loan.id == loanId);
      }

      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> rejectLoan({
    required String loanId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.rejectLoan(
        loanId: loanId,
        rejectedBy: rejectedBy,
        rejectionReason: rejectionReason,
      );

      if (success) {
        // Remove approved loan from pending list
        _pendingLoans.removeWhere((loan) => loan.id == loanId);
      }

      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

