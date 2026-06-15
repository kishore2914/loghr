import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/services/notification_service.dart';
import 'package:loghr_mobile/data/models/notification.dart';
import 'package:loghr_mobile/config/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _taskChannel;
  RealtimeChannel? _leaveChannel;
  RealtimeChannel? _announcementChannel;
  RealtimeChannel? _payslipChannel;
  RealtimeChannel? _expenseChannel;
  RealtimeChannel? _chargeChannel;
  RealtimeChannel? _policyChannel;
  String? _organizationName;
  String? _logoLocalPath;

  NotificationProvider(this._service);

  // Getters
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Load notifications for a user
  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _service.getNotifications(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _service.markAllAsRead(userId);
      
      // Update local state
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _service.deleteNotification(notificationId);
      
      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Refresh notifications
  Future<void> refresh(String userId) async {
    await loadNotifications(userId);
  }

  // --- Realtime Support ---

  void initRealtimeNotifications(String userId) async {
    print('NotificationProvider: Initializing realtime notifications for user: $userId');
    
    // Cancel existing subscriptions if any
    _notificationChannel?.unsubscribe();
    _taskChannel?.unsubscribe();
    _leaveChannel?.unsubscribe();
    _announcementChannel?.unsubscribe();
    _payslipChannel?.unsubscribe();
    _expenseChannel?.unsubscribe();
    _chargeChannel?.unsubscribe();
    _policyChannel?.unsubscribe();
    
    // 1. SET UP LISTENERS IMMEDIATELY (using userId as a first guess for tasks too)
    // Most notifications are linked to userId (auth UID)
    _notificationChannel = _service.subscribeToNotifications(userId, (newNotification) {
      if (!_notifications.any((n) => n.id == newNotification.id)) {
        _notifications.insert(0, newNotification);
        notifyListeners();
        
        final brandedTitle = _organizationName != null 
            ? '[$_organizationName] ${newNotification.title}' 
            : newNotification.title;
            
        _service.showLocalPopup(
          id: newNotification.id.hashCode,
          title: brandedTitle,
          body: newNotification.message,
          payload: newNotification.toJson().toString(),
          organizationName: _organizationName,
          largeIconPath: _logoLocalPath,
        );
      }
    });

    // 2. Fetch Profile & Branding (Don't block listeners)
    _loadBrandingAndEmployeeId(userId);
  }

  Future<void> _loadBrandingAndEmployeeId(String userId) async {
    try {
      print('NotificationProvider: 🔍 Loading profile for branding');
      final profile = await api.get('/profile');
      if (profile != null) {
        _organizationName = profile['organization_name'] as String?;
        final logoUrl = profile['organization_logo'] as String?;
        final employeeId = profile['employee_id'] as String?;
        final orgId = profile['organization_id'] as String?;
        
        print('NotificationProvider: 🏢 Organization Name: $_organizationName');
        
        // Update ID-based Listeners if we found a valid ID
        final effectiveTaskId = employeeId ?? userId;
        
        _taskChannel?.unsubscribe();
        _taskChannel = _service.subscribeToTasks(effectiveTaskId, _onNewTask);

        if (employeeId != null) {
          _leaveChannel?.unsubscribe();
          _leaveChannel = _service.subscribeToLeaveUpdates(employeeId, _onLeaveUpdate);

          _payslipChannel?.unsubscribe();
          _payslipChannel = _service.subscribeToPayslips(employeeId, _onPayslipGenerated);

          _expenseChannel?.unsubscribe();
          _expenseChannel = _service.subscribeToExpenseUpdates(employeeId, _onExpenseUpdate);

          _chargeChannel?.unsubscribe();
          _chargeChannel = _service.subscribeToCharges(employeeId, _onNewCharge);
        }

        if (orgId != null) {
          _announcementChannel?.unsubscribe();
          _announcementChannel = _service.subscribeToAnnouncements(orgId, _onNewAnnouncement);

          _policyChannel?.unsubscribe();
          _policyChannel = _service.subscribeToPolicies(orgId, _onNewPolicy);
        }
        
        if (logoUrl != null && logoUrl.isNotEmpty) {
          print('NotificationProvider: 🖼️ Downloading logo from $logoUrl');
          _logoLocalPath = await _service.downloadLogo(logoUrl);
          print('NotificationProvider: 📁 Logo saved at: $_logoLocalPath');
        }
      }
      notifyListeners();
    } catch (e) {
      print('NotificationProvider: ❌ Error loading profile/branding: $e');
    }
  }

  void _onNewTask(Map<String, dynamic> newTaskRecord) {
    print('NotificationProvider: New Task Signal Received!');
    final taskTitle = newTaskRecord['title'] as String? ?? 'New Task Assigned';
    final taskDesc = newTaskRecord['description'] as String? ?? 'You have a new task assigned to you.';

    final brandedTitle = _organizationName != null 
        ? '[$_organizationName] New Task: $taskTitle' 
        : '📋 New Task: $taskTitle';
        
    _service.showLocalPopup(
      id: (newTaskRecord['id'] as String? ?? 'task').hashCode,
      title: brandedTitle,
      body: taskDesc,
      payload: newTaskRecord.toString(),
      organizationName: _organizationName,
      largeIconPath: _logoLocalPath,
    );
  }

  void _onLeaveUpdate(Map<String, dynamic> record) {
    final status = record['status'] as String? ?? 'updated';
    // Only notify on relevant status changes
    if (['approved', 'rejected'].contains(status.toLowerCase())) {
       final brandedTitle = _organizationName != null 
          ? '[$_organizationName] Leave $status' 
          : '📅 Leave ${status.toUpperCase()}';
          
       _service.showLocalPopup(
        id: (record['id'] as String? ?? 'leave').hashCode,
        title: brandedTitle,
        body: 'Your leave application starting ${record['start_date']?.toString().split('T')[0]} has been $status.',
        payload: record.toString(),
        organizationName: _organizationName,
        largeIconPath: _logoLocalPath,
      );
    }
  }

  void _onNewAnnouncement(Map<String, dynamic> record) {
    final title = record['title'] as String? ?? 'Announcement';
    final brandedTitle = _organizationName != null 
        ? '[$_organizationName] $title' 
        : '📢 $title';
        
    _service.showLocalPopup(
      id: (record['id'] as String? ?? 'ann').hashCode,
      title: brandedTitle,
      body: record['content'] as String? ?? 'New announcement posted.',
      payload: record.toString(),
      organizationName: _organizationName,
      largeIconPath: _logoLocalPath,
    );
  }

  void _onPayslipGenerated(Map<String, dynamic> record) {
    // Only notify if status is 'generated' or 'published' or similar if applicable
    // Assuming insert means it's available
    final month = record['pay_period_month'];
    final year = record['pay_period_year'];
    
    final brandedTitle = _organizationName != null 
        ? '[$_organizationName] Payslip Available' 
        : '💰 Payslip Available';
        
    _service.showLocalPopup(
      id: (record['id'] as String? ?? 'payslip').hashCode,
      title: brandedTitle,
      body: 'Payslip for $month/$year is now available.',
      payload: record.toString(),
      organizationName: _organizationName,
      largeIconPath: _logoLocalPath,
    );
  }

  void _onExpenseUpdate(Map<String, dynamic> record) {
    final status = record['status'] as String? ?? 'updated';
    // Notify on resolution
    if (['approved', 'rejected', 'settled', 'reimbursed'].contains(status.toLowerCase())) {
      final amount = record['amount']; 
      final brandedTitle = _organizationName != null 
          ? '[$_organizationName] Expense $status' 
          : '💸 Expense ${status.toUpperCase()}';
          
      _service.showLocalPopup(
        id: (record['id'] as String? ?? 'exp').hashCode,
        title: brandedTitle,
        body: 'Your expense claim for $amount has been $status.',
        payload: record.toString(),
        organizationName: _organizationName,
        largeIconPath: _logoLocalPath,
      );
    }
  }

  void _onNewCharge(Map<String, dynamic> record) {
    final amount = record['amount'];
    final type = record['charge_type'] ?? 'Deduction';
    
    final brandedTitle = _organizationName != null 
        ? '[$_organizationName] New Charge' 
        : '⚠️ New Charge Added';
        
    _service.showLocalPopup(
      id: (record['id'] as String? ?? 'charge').hashCode,
      title: brandedTitle,
      body: 'A new $type of $amount has been added to your record.',
      payload: record.toString(),
      organizationName: _organizationName,
      largeIconPath: _logoLocalPath,
    );
  }

  void _onNewPolicy(Map<String, dynamic> record) {
    final title = record['title'] as String? ?? 'New Policy';
    final brandedTitle = _organizationName != null 
        ? '[$_organizationName] Policy Update' 
        : '📜 New Policy Added';
        
    _service.showLocalPopup(
      id: (record['id'] as String? ?? 'pol').hashCode,
      title: brandedTitle,
      body: title,
      payload: record.toString(),
      organizationName: _organizationName,
      largeIconPath: _logoLocalPath,
    );
  }

  @override
  void dispose() {
    _notificationChannel?.unsubscribe();
    _taskChannel?.unsubscribe();
    _leaveChannel?.unsubscribe();
    _announcementChannel?.unsubscribe();
    _payslipChannel?.unsubscribe();
    _expenseChannel?.unsubscribe();
    _chargeChannel?.unsubscribe();
    _policyChannel?.unsubscribe();
    super.dispose();
  }
}
