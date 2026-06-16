import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/expense.dart';

class ExpenseService {
  // Get user's expense claims
  Future<List<ExpenseClaim>> getUserExpenses(String userId) async {
    try {
      final response = await api.get('/expenses');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => ExpenseClaim.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching user expenses: $e');
      return [];
    }
  }

  // Get user's credit card or cash charges
  Future<List<ExpenseClaim>> getUserCharges(String userId) async {
    try {
      final response = await api.get('/expenses/charges');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => ExpenseClaim.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching user charges: $e');
      return [];
    }
  }

  // Get expense stats for a user
  Future<Map<String, dynamic>> getExpenseStats(String userId) async {
    try {
      final expenses = await getUserExpenses(userId);
      final totalClaims = expenses.length;
      final pending = expenses.where((e) => e.status == ExpenseStatus.pending || e.status == ExpenseStatus.draft).length;
      final approved = expenses.where((e) => e.status == ExpenseStatus.approved || e.status == ExpenseStatus.reimbursed).length;
      final rejected = expenses.where((e) => e.status == ExpenseStatus.rejected).length;
      
      double totalAmount = 0.0;
      for (var expense in expenses) {
        if (expense.amount > 0 && expense.amount <= 1000000000) {
          totalAmount += expense.amount;
        }
      }

      return {
        'total_claims': totalClaims,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total_amount': totalAmount,
      };
    } catch (e) {
      print('Error fetching expense stats: $e');
      return {
        'total_claims': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total_amount': 0.0,
      };
    }
  }

  // Get charge stats for a user
  Future<Map<String, dynamic>> getChargeStats(String userId) async {
    try {
      final charges = await getUserCharges(userId);
      final totalClaims = charges.length;
      final pending = charges.where((e) => e.status == ExpenseStatus.pending || e.status == ExpenseStatus.draft).length;
      final acknowledged = charges.where((e) => e.status == ExpenseStatus.acknowledged).length;
      final settled = charges.where((e) => e.status == ExpenseStatus.settled).length;
      
      double totalAmount = 0.0;
      for (var charge in charges) {
        if (charge.amount > 0 && charge.amount <= 1000000000) {
          totalAmount += charge.amount;
        }
      }

      return {
        'total_claims': totalClaims,
        'pending': pending,
        'acknowledged': acknowledged,
        'settled': settled,
        'total_amount': totalAmount,
      };
    } catch (e) {
      print('Error fetching charge stats: $e');
      return {
        'total_claims': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total_amount': 0.0,
      };
    }
  }

  // Get all expenses for an organization (for admin)
  Future<List<ExpenseClaim>> getOrganizationExpenses(String organizationId) async {
    try {
      final response = await api.get('/expenses/pending');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => ExpenseClaim.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching organization expenses: $e');
      return [];
    }
  }

  // Create a new expense claim
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
      // Find category first from categories list
      final categoriesResponse = await api.get('/expenses/categories');
      String? categoryId;
      if (categoriesResponse != null) {
        final categories = categoriesResponse as List;
        final matchingCategory = categories.firstWhere(
          (c) => c['name']?.toString().toLowerCase() == category.toLowerCase(),
          orElse: () => null,
        );
        if (matchingCategory != null) {
          categoryId = matchingCategory['id']?.toString();
        }
      }

      final response = await api.post('/expenses/create', {
        'categoryId': categoryId ?? category, // Fallback if no matching UUID
        'expenseDate': date.toIso8601String().split('T')[0],
        'amount': amount,
        'merchantName': merchant,
        'description': description,
        'receiptUrl': 'https://picsum.photos/400',
      });
      return response != null;
    } catch (e) {
      print('Error creating expense claim: $e');
      return false;
    }
  }

  // Helper filter methods
  List<ExpenseClaim> filterExpensesByStatus(List<ExpenseClaim> expenses, String? status) {
    if (status == null || status == 'All Status' || status.isEmpty) {
      return expenses;
    }
    ExpenseStatus? filterStatus;
    switch (status.toLowerCase()) {
      case 'pending':
        filterStatus = ExpenseStatus.pending;
        break;
      case 'approved':
        filterStatus = ExpenseStatus.approved;
        break;
      case 'rejected':
        filterStatus = ExpenseStatus.rejected;
        break;
      case 'acknowledged':
        filterStatus = ExpenseStatus.acknowledged;
        break;
      case 'settled':
        filterStatus = ExpenseStatus.settled;
        break;
      default:
        return expenses;
    }
    return expenses.where((e) => e.status == filterStatus).toList();
  }

  List<ExpenseClaim> filterExpensesByMethod(List<ExpenseClaim> expenses, String? method) {
    if (method == null || method == 'All Methods' || method.isEmpty) {
      return expenses;
    }
    final methodLower = method.toLowerCase().replaceAll(' ', '_');
    return expenses.where((e) {
      if (e.reimbursementMethod == null) return false;
      final expMethod = e.reimbursementMethod.toString().split('.').last.toLowerCase();
      return expMethod == methodLower;
    }).toList();
  }

  List<ExpenseClaim> searchExpenses(List<ExpenseClaim> expenses, String query) {
    if (query.isEmpty) return expenses;
    final lowerQuery = query.toLowerCase();
    return expenses.where((expense) {
      return expense.merchant.toLowerCase().contains(lowerQuery) ||
          expense.category.toLowerCase().contains(lowerQuery) ||
          expense.expenseId.toLowerCase().contains(lowerQuery) ||
          expense.employeeName.toLowerCase().contains(lowerQuery) ||
          (expense.claimantName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Approve expense (for admin)
  Future<bool> approveExpense(String expenseId) async {
    try {
      final response = await api.post('/expenses/$expenseId/approve', {});
      return response != null;
    } catch (e) {
      print('Error approving expense: $e');
      return false;
    }
  }

  // Reject expense (for admin)
  Future<bool> rejectExpense(String expenseId, String reason) async {
    try {
      final response = await api.post('/expenses/$expenseId/reject', {
        'rejectionReason': reason,
      });
      return response != null;
    } catch (e) {
      print('Error rejecting expense: $e');
      return false;
    }
  }
}
