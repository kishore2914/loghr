import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/expense.dart';
import 'package:loghr_mobile/data/repositories/expense_repository.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _repository;
  
  List<ExpenseClaim> _expenses = [];
  List<ExpenseClaim> _charges = [];
  Map<String, dynamic> _stats = {
    'total_claims': 0,
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'total_amount': 0.0,
  };
  Map<String, dynamic> _chargeStats = {
    'total_claims': 0,
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'total_amount': 0.0,
  };
  bool _isLoading = false;
  bool _isChargesLoading = false;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'All Status';
  String _methodFilter = 'All Methods';

  ExpenseProvider(this._repository);

  List<ExpenseClaim> get expenses => _expenses;
  List<ExpenseClaim> get charges => _charges;
  Map<String, dynamic> get stats => _stats;
  Map<String, dynamic> get chargeStats => _chargeStats;
  bool get isLoading => _isLoading;
  bool get isChargesLoading => _isChargesLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get methodFilter => _methodFilter;

  List<ExpenseClaim> get filteredExpenses {
    var filtered = _expenses;
    
    // Apply status filter
    if (_statusFilter != 'All Status' && _statusFilter.isNotEmpty) {
      filtered = _repository.filterExpensesByStatus(filtered, _statusFilter);
    }
    
    // Apply method filter
    if (_methodFilter != 'All Methods' && _methodFilter.isNotEmpty) {
      filtered = _repository.filterExpensesByMethod(filtered, _methodFilter);
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = _repository.searchExpenses(filtered, _searchQuery);
    }
    
    return filtered;
  }

  List<ExpenseClaim> get filteredCharges {
    var filtered = _charges;
    if (_statusFilter != 'All Status' && _statusFilter.isNotEmpty) {
      filtered = _repository.filterExpensesByStatus(filtered, _statusFilter);
    }
    if (_methodFilter != 'All Methods' && _methodFilter.isNotEmpty) {
      filtered = _repository.filterExpensesByMethod(filtered, _methodFilter);
    }
    if (_searchQuery.isNotEmpty) {
      filtered = _repository.searchExpenses(filtered, _searchQuery);
    }
    return filtered;
  }

  Future<void> loadExpenses(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('ExpenseProvider: Loading expenses for user $userId');
      _expenses = await _repository.getUserExpenses(userId);
      print('ExpenseProvider: Loaded ${_expenses.length} expenses');

      // Compute stats locally from the loaded expenses so that
      // the header cards always match what is shown in the list.
      final totalClaims = _expenses.length;
      final pending = _expenses
          .where((e) =>
              e.status == ExpenseStatus.pending ||
              e.status == ExpenseStatus.draft)
          .length;
      final approved = _expenses
          .where((e) =>
              e.status == ExpenseStatus.approved ||
              e.status == ExpenseStatus.reimbursed)
          .length;
      final rejected =
          _expenses.where((e) => e.status == ExpenseStatus.rejected).length;
      // Calculate total amount with validation
      double totalAmount = 0.0;
      int zeroAmountCount = 0;
      for (var expense in _expenses) {
        // Validate amount is reasonable before adding
        if (expense.amount > 0 && expense.amount <= 1000000000) {
          totalAmount += expense.amount;
        } else if (expense.amount == 0.0) {
          zeroAmountCount++;
          print('ExpenseProvider: ⚠ Expense ${expense.expenseNumber} has amount 0.0 - this might indicate missing data in database');
        } else {
          print('ExpenseProvider: ⚠ Skipping invalid amount for expense ${expense.expenseNumber}: ${expense.amount}');
        }
      }
      
      if (zeroAmountCount > 0) {
        print('ExpenseProvider: ⚠ Found $zeroAmountCount expenses with 0.0 amount. Check database for missing amount values.');
      }

      _stats = {
        'total_claims': totalClaims,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total_amount': totalAmount,
      };

      print(
          'ExpenseProvider: Computed stats - Total: $totalClaims, Pending: $pending, Approved: $approved, Rejected: $rejected, Amount: $totalAmount');

      if (_expenses.isEmpty) {
        print('ExpenseProvider: No expenses found for user $userId');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      print('Error loading expenses: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCharges(String userId) async {
    _isChargesLoading = true;
    _error = null;
    notifyListeners();

    try {
      _charges = await _repository.getUserCharges(userId);
      
      // Calculate stats for charges
      final totalClaims = _charges.length;
      final pending = _charges.where((e) => e.status == ExpenseStatus.pending || e.status == ExpenseStatus.draft).length;
      final acknowledged = _charges.where((e) => e.status == ExpenseStatus.acknowledged).length;
      final settled = _charges.where((e) => e.status == ExpenseStatus.settled || e.status == ExpenseStatus.deducted).length;
      
      double totalAmount = 0.0;
      for (var charge in _charges) {
        if (charge.amount > 0 && charge.amount <= 1000000000) {
          totalAmount += charge.amount;
        }
      }

      _chargeStats = {
        'total_claims': totalClaims,
        'pending': pending,
        'acknowledged': acknowledged,
        'settled': settled,
        'total_amount': totalAmount,
      };
    } catch (e, stackTrace) {
      _error = e.toString();
      print('Error loading charges: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isChargesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrganizationExpenses(String organizationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _repository.getOrganizationExpenses(organizationId);
      
      // Calculate stats for organization expenses
      final totalClaims = _expenses.length;
      final pending = _expenses.where((e) => e.status == ExpenseStatus.pending).length;
      final approved = _expenses.where((e) => e.status == ExpenseStatus.approved).length;
      final rejected = _expenses.where((e) => e.status == ExpenseStatus.rejected).length;
      // Calculate total amount with validation
      double totalAmount = 0.0;
      int zeroAmountCount = 0;
      for (var expense in _expenses) {
        // Validate amount is reasonable before adding
        if (expense.amount > 0 && expense.amount <= 1000000000) {
          totalAmount += expense.amount;
        } else if (expense.amount == 0.0) {
          zeroAmountCount++;
          print('ExpenseProvider: ⚠ Expense ${expense.expenseNumber} has amount 0.0 - this might indicate missing data in database');
        } else {
          print('ExpenseProvider: ⚠ Skipping invalid amount for expense ${expense.expenseNumber}: ${expense.amount}');
        }
      }
      
      if (zeroAmountCount > 0) {
        print('ExpenseProvider: ⚠ Found $zeroAmountCount expenses with 0.0 amount. Check database for missing amount values.');
      }
      
      _stats = {
        'total_claims': totalClaims,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total_amount': totalAmount,
      };
    } catch (e) {
      _error = e.toString();
      print('Error loading organization expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createExpenseClaim({
    required String userId,
    required String employeeId,
    required double amount,
    required String category,
    required String merchant,
    required DateTime date,
    String? claimantName,
    String? description,
  }) async {
    try {
      final success = await _repository.createExpenseClaim(
        userId: userId,
        employeeId: employeeId,
        amount: amount,
        category: category,
        merchant: merchant,
        date: date,
        claimantName: claimantName,
        description: description,
      );

      if (success) {
        // Reload expenses
        await loadExpenses(userId);
      }

      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setMethodFilter(String method) {
    _methodFilter = method;
    notifyListeners();
  }
}
