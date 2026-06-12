import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _service;

  // Dashboard statistics
  int _totalEmployees = 0;
  int _activeToday = 0;
  int _totalActive = 0;
  int _onLeaveToday = 0;
  int _pendingLeaves = 0;
  double _monthlyPayroll = 0.0;
  String _currency = 'INR';
  int _paidCount = 0;
  int _pendingPayrollCount = 0;
  int _processingPayrollCount = 0;
  int _pendingExpenses = 0;
  int _upcomingBirthdays = 0;

  // Lists
  List<Map<String, dynamic>> _salaryDueList = [];
  List<Map<String, dynamic>> _upcomingBirthdaysList = [];
  List<Map<String, dynamic>> _leaveBalances = [];
  List<Map<String, dynamic>> _departmentStats = [];
  List<String> _designations = [];
  Map<String, dynamic> _tasksStats = {};
  
  // Getters
  List<String> get designations => _designations;

  bool _isLoading = false;
  String? _error;

  AdminProvider(this._service);

  // Expose service for direct access when needed
  AdminService get service => _service;

  // Getters
  int get totalEmployees => _totalEmployees;
  int get activeToday => _activeToday;
  int get totalActive => _totalActive;
  int get onLeaveToday => _onLeaveToday;
  int get pendingLeaves => _pendingLeaves;
  double get monthlyPayroll => _monthlyPayroll;
  String get currency => _currency;
  int get paidCount => _paidCount;
  int get pendingPayrollCount => _pendingPayrollCount;
  int get processingPayrollCount => _processingPayrollCount;
  int get pendingExpenses => _pendingExpenses;
  int get upcomingBirthdays => _upcomingBirthdays;
  List<Map<String, dynamic>> get salaryDueList => _salaryDueList;
  List<Map<String, dynamic>> get upcomingBirthdaysList => _upcomingBirthdaysList;
  List<Map<String, dynamic>> get leaveBalances => _leaveBalances;
  List<Map<String, dynamic>> get departmentStats => _departmentStats;
  Map<String, dynamic> get tasksStats => _tasksStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all dashboard statistics in parallel
      final results = await Future.wait([
        _service.getTotalEmployees(),
        _service.getActiveTodayCount(),
        _service.getTotalActiveEmployees(),
        _service.getOnLeaveTodayCount(),
        _service.getPendingLeaveCount(),
        // _service.getMonthlyPayroll(), // Payroll table missing
        // _service.getPendingExpensesCount(),
        // _service.getUpcomingBirthdaysCount(),
        // _service.getSalaryDueList(), // Payroll table missing
        _service.getUpcomingBirthdays(),
        _service.getEmployeesLeaveBalances(),
        _service.getDepartmentStats(),
        _service.getTasksStats(),
      ]);

      _totalEmployees = results[0] as int;
      _activeToday = results[1] as int;
      _totalActive = results[2] as int;
      _onLeaveToday = results[3] as int;
      _pendingLeaves = results[4] as int;
      
      // final payrollData = results[5] as Map<String, dynamic>;
      // _monthlyPayroll = payrollData['total_amount'] as double? ?? 0.0;
      // _currency = payrollData['currency'] as String? ?? 'INR';
      // _paidCount = payrollData['paid_count'] as int? ?? 0;
      // _pendingPayrollCount = payrollData['pending_count'] as int? ?? 0;
      // _processingPayrollCount = payrollData['processing_count'] as int? ?? 0;
      
      _pendingExpenses = 0;
      _upcomingBirthdays = 0;
      _salaryDueList = [];
      
      _upcomingBirthdaysList = results[5] as List<Map<String, dynamic>>;
      _leaveBalances = results[6] as List<Map<String, dynamic>>;
      _departmentStats = results[7] as List<Map<String, dynamic>>;
      _tasksStats = results[8] as Map<String, dynamic>;
      


      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading dashboard data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Leave Dashboard Data
  Map<String, dynamic> _leaveAnalytics = {};
  List<Map<String, dynamic>> _leaveTypes = [];

  Map<String, dynamic> get leaveAnalytics => _leaveAnalytics;
  List<Map<String, dynamic>> get leaveTypes => _leaveTypes;

  Future<void> loadLeaveDashboardData() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final results = await Future.wait([
        _service.getLeaveAnalytics(),
        _service.getLeaveTypes(),
        _service.getDesignations(),
      ]);

      _leaveAnalytics = results[0] as Map<String, dynamic>;
      _leaveTypes = results[1] as List<Map<String, dynamic>>;
      _designations = results[2] as List<String>;
      
    } catch (e) {
      _error = e.toString();
      print('Error loading leave dashboard data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Tasks Data
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];

  List<Map<String, dynamic>> get tasks => _filteredTasks;
  
  Future<void> loadTasksData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getTasksStats(),
        _service.getAllTasks(),
      ]);
      
      _tasksStats = results[0] as Map<String, dynamic>;
      _tasks = results[1] as List<Map<String, dynamic>>;
      _filteredTasks = List.from(_tasks);
      
    } catch (e) {
      _error = e.toString();
      print('Error loading tasks data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterTasks({String? query, String? status, String? employee}) {
    _filteredTasks = _tasks.where((task) {
      final matchesQuery = query == null || query.isEmpty ||
          task['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
          task['id'].toString().toLowerCase().contains(query.toLowerCase());
      
      final matchesStatus = status == null || status == 'All Status' || 
          task['status'].toString().toUpperCase() == status.toUpperCase();

      // Mock employee filtering for now
      final matchesEmployee = employee == null || employee == 'All Employees'; 

      return matchesQuery && matchesStatus && matchesEmployee;
    }).toList();
    notifyListeners();
  }
}













