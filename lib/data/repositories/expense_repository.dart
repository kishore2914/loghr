import 'package:loghr_mobile/data/models/expense.dart';
import 'package:loghr_mobile/data/services/expense_service.dart';

class ExpenseRepository {
  final ExpenseService _service;

  ExpenseRepository(this._service);

  Future<List<ExpenseClaim>> getUserExpenses(String userId) async {
    return await _service.getUserExpenses(userId);
  }

  Future<List<ExpenseClaim>> getUserCharges(String userId) async {
    return await _service.getUserCharges(userId);
  }

  Future<Map<String, dynamic>> getExpenseStats(String userId) async {
    return await _service.getExpenseStats(userId);
  }

  Future<Map<String, dynamic>> getChargeStats(String userId) async {
    return await _service.getChargeStats(userId);
  }

  Future<List<ExpenseClaim>> getOrganizationExpenses(String organizationId) async {
    return await _service.getOrganizationExpenses(organizationId);
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
    return await _service.createExpenseClaim(
      userId: userId,
      employeeId: employeeId,
      amount: amount,
      category: category,
      merchant: merchant,
      date: date,
      claimantName: claimantName,
      description: description,
    );
  }

  List<ExpenseClaim> filterExpensesByStatus(
    List<ExpenseClaim> expenses,
    String? status,
  ) {
    return _service.filterExpensesByStatus(expenses, status);
  }

  List<ExpenseClaim> filterExpensesByMethod(
    List<ExpenseClaim> expenses,
    String? method,
  ) {
    return _service.filterExpensesByMethod(expenses, method);
  }

  List<ExpenseClaim> searchExpenses(
    List<ExpenseClaim> expenses,
    String query,
  ) {
    return _service.searchExpenses(expenses, query);
  }
}
