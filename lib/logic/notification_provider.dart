import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/services/notification_service.dart';
import 'package:loghr_mobile/data/models/notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loghr_mobile/config/supabase_config.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _taskChannel;
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
      print('NotificationProvider: 🔍 Loading profile for $userId');
      
      // 1. Try user_profiles first
      var userProfile = await supabase
          .from('user_profiles')
          .select('organization_id, employee_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      String? orgId = userProfile?['organization_id'] as String?;
      String? employeeId = userProfile?['employee_id'] as String?;

      // 2. Fallback to employees table if organization_id is missing
      if (orgId == null) {
        print('NotificationProvider: 🔍 organization_id missing in user_profiles, trying employees table...');
        final employeeProfile = await supabase
            .from('employees')
            .select('organization_id, id')
            .or('user_id.eq.$userId,id.eq.$userId')
            .maybeSingle();
        
        orgId = employeeProfile?['organization_id'] as String?;
        employeeId ??= employeeProfile?['id'] as String?;
      }

      print('NotificationProvider: 📍 Found orgId: $orgId, employeeId: $employeeId');

      // Update Task Listener if we found a valid ID
      final effectiveTaskId = employeeId ?? userId;
      _taskChannel?.unsubscribe();
      _taskChannel = _service.subscribeToTasks(effectiveTaskId, _onNewTask);

      // 3. Fetch Organization Branding
      if (orgId != null) {
        final orgQuery = await supabase
            .from('organizations')
            .select()
            .eq('id', orgId)
            .maybeSingle();
        
        if (orgQuery != null) {
          _organizationName = orgQuery['name'] as String? ?? 
                             orgQuery['company_name'] as String? ?? 
                             orgQuery['organization_name'] as String?;
          
          print('NotificationProvider: 🏢 Organization Name: $_organizationName');
          
          final logoUrl = orgQuery['logo_url'] as String? ?? orgQuery['company_logo'] as String?;
          
          if (logoUrl != null && logoUrl.isNotEmpty) {
            String? fullLogoUrl;
            if (logoUrl.startsWith('http')) {
              fullLogoUrl = logoUrl;
            } else {
              // Robust bucket check (matching profile_service logic)
              final buckets = ['organizations', 'company-logos', 'logos', 'public'];
              final cleanPath = logoUrl.startsWith('/') ? logoUrl.substring(1) : logoUrl;
              
              for (final bucket in buckets) {
                try {
                  fullLogoUrl = supabase.storage.from(bucket).getPublicUrl(cleanPath);
                  // We don't check if it exists here to avoid network lag, 
                  // but we take the first guess from 'organizations' as primary.
                  if (bucket == 'organizations') break; 
                } catch (_) {}
              }
            }
            
            if (fullLogoUrl != null) {
              print('NotificationProvider: 🖼️ Downloading logo from $fullLogoUrl');
              _logoLocalPath = await _service.downloadLogo(fullLogoUrl);
              print('NotificationProvider: 📁 Logo saved at: $_logoLocalPath');
            }
          }
        } else {
          print('NotificationProvider: ⚠️ Organization record not found for ID: $orgId');
        }
      } else {
        print('NotificationProvider: ⚠️ No organization ID found for user: $userId');
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
      id: newTaskRecord['id'].hashCode,
      title: brandedTitle,
      body: taskDesc,
      payload: newTaskRecord.toString(),
      organizationName: _organizationName,
      largeIconPath: _logoLocalPath,
    );
  }

  @override
  void dispose() {
    _notificationChannel?.unsubscribe();
    _taskChannel?.unsubscribe();
    super.dispose();
  }
}
