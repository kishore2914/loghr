import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loghr_mobile/data/models/notification.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
        // Add basic support for other platforms if needed by the plugin version
        macOS: initializationSettingsIOS, 
      );

      await _notificationsPlugin.initialize(initializationSettings);
      
      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      
      _isInitialized = true;
      print('NotificationService: Initialized successfully');
    } catch (e) {
      print('NotificationService: Initialization failed: $e');
      _isInitialized = false;
    }
  }

  // --- Local Notifications ---

  Future<void> showLocalPopup({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? organizationName,
    String? largeIconPath,
  }) async {
    if (!_isInitialized) {
      print('NotificationService: showLocalPopup called before initialization. Attempting to initialize...');
      await initialize();
    }
    
    if (!_isInitialized) {
      print('NotificationService: Cannot show notification - initialization failed or not supported on this platform');
      return;
    }

    try {
      AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'loghr_urgent_channel_v3', // Forced new channel for OS reset
      'Urgent Alerts',
      channelDescription: 'High priority notifications for assigned tasks',
      importance: Importance.max,
      priority: Priority.max, // Increased to Max
      showWhen: true,
      subText: organizationName,
      ticker: 'Task Alert',
      enableVibration: true,
      playSound: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      fullScreenIntent: true,
      largeIcon: largeIconPath != null 
          ? FilePathAndroidBitmap(largeIconPath) 
          : null,
    );
    
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: organizationName,
      ),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  } catch (e) {
    print('NotificationService: Error showing local popup: $e');
  }
}

  Future<String?> downloadLogo(String logoUrl) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'org_logo_${logoUrl.hashCode}${p.extension(logoUrl).isEmpty ? ".png" : p.extension(logoUrl)}';
      final filePath = p.join(directory.path, fileName);
      
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      print('NotificationService: Error downloading logo: $e');
    }
    return null;
  }

  Future<void> schedule8HourNotification(DateTime checkInTime) async {
    final completionTime = checkInTime.add(const Duration(hours: 8));
    if (completionTime.isBefore(DateTime.now())) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        0,
        'Work Day Completed',
        'You have completed 8 hours of work. You can check out now!',
        tz.TZDateTime.from(completionTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'loghr_general_channel', // Consistent channel ID
            'LogHR Notifications',
            channelDescription: 'Notifications for attendance and general updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('NotificationService: Error scheduling exact alarm: $e. Falling back to inexact.');
      await _notificationsPlugin.zonedSchedule(
        0,
        'Work Day Completed',
        'You have completed 8 hours of work. You can check out now!',
        tz.TZDateTime.from(completionTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'loghr_general_channel',
            'LogHR Notifications',
            channelDescription: 'Notifications for attendance and general updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelNotifications() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      print('NotificationService: Error canceling notifications: $e');
    }
  }

  /// Inserts a notification into the Supabase `notifications` table for every
  /// admin in the employee's organization, alerting them that the employee was
  /// auto-checked out after 12 hours.
  Future<void> createAutoCheckoutAdminNotification({
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      // 1. Get the employee's organization_id
      final empData = await supabase
          .from('employees')
          .select('organization_id')
          .eq('id', employeeId)
          .maybeSingle();

      final organizationId = empData?['organization_id'] as String?;
      if (organizationId == null) {
        print('NotificationService: No organization_id found for employee $employeeId');
        return;
      }

      // 2. Find all admin users in the same organization
      final adminProfiles = await supabase
          .from('user_profiles')
          .select('user_id, role')
          .eq('organization_id', organizationId)
          .inFilter('role', ['admin', 'super_admin', 'hr_manager', 'manager']);

      if (adminProfiles == null || (adminProfiles as List).isEmpty) {
        print('NotificationService: No admin users found for org $organizationId');
        return;
      }

      // 3. Insert a notification for each admin
      final now = DateTime.now().toUtc().toIso8601String();
      final notifications = (adminProfiles as List).map((admin) => {
        'user_id': admin['user_id'] as String,
        'title': 'Auto-Checkout Alert',
        'message': '$employeeName was automatically checked out after 12 hours (forgot to check out)',
        'type': 'auto_checkout',
        'related_id': employeeId,
        'is_read': false,
        'created_at': now,
      }).toList();

      await supabase.from('notifications').insert(notifications);

      print('NotificationService: Sent auto-checkout admin notifications to ${notifications.length} admin(s)');
    } catch (e) {
      print('NotificationService: Error creating admin auto-checkout notification: $e');
    }
  }

  // --- Database Notifications (Supabase) ---

  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return (response as List).map((n) => AppNotification.fromJson(n)).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // --- Realtime Subscriptions ---

  RealtimeChannel subscribeToNotifications(
      String userId, Function(AppNotification) onNewNotification) {
    print('NotificationService: Subscribing to notifications channel for user: $userId');
    
    // Using a more generalized channel name to avoid subscription limits/crashes
    final channel = supabase
        .channel('user-$userId-notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            print('NotificationService: [REALTIME] Notification row received: ${payload.newRecord}');
            // Client-side filtering is more robust if server side has issues
            if (payload.newRecord['user_id'] == userId) {
              try {
                final newNotification = AppNotification.fromJson(payload.newRecord);
                onNewNotification(newNotification);
              } catch (e) {
                print('Error parsing realtime notification: $e');
              }
            }
          },
        )
        .subscribe();
        
    return channel;
  }

  RealtimeChannel subscribeToTasks(
      String employeeId, Function(Map<String, dynamic>) onNewTask) {
    print('NotificationService: Subscribing to tasks channel for employee: $employeeId');
    
    final channel = supabase.channel('employee-$employeeId-tasks')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            print('NotificationService: [REALTIME] Task row received: ${payload.newRecord}');
            final assignedTo = payload.newRecord['assigned_to']?.toString();
            final assigneeId = payload.newRecord['assignee_id']?.toString();
            
            if (assignedTo == employeeId || assigneeId == employeeId) {
              onNewTask(payload.newRecord);
            }
          },
        )
        .subscribe();
        
    return channel;
  }

  RealtimeChannel subscribeToLeaveUpdates(
      String employeeId, Function(Map<String, dynamic>) onLeaveUpdate) {
    print('NotificationService: Subscribing to leave updates for employee: $employeeId');
    
    return supabase.channel('employee-$employeeId-leaves')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'leave_applications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) {
            print('NotificationService: [REALTIME] Leave update received: ${payload.newRecord}');
            onLeaveUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToAnnouncements(
      String organizationId, Function(Map<String, dynamic>) onAnnouncement) {
    print('NotificationService: Subscribing to announcements for org: $organizationId');
    
    return supabase.channel('org-$organizationId-announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: organizationId,
          ),
          callback: (payload) {
            print('NotificationService: [REALTIME] New announcement: ${payload.newRecord}');
            onAnnouncement(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToPayslips(
      String employeeId, Function(Map<String, dynamic>) onPayslip) {
    print('NotificationService: Subscribing to payslips for employee: $employeeId');
    
    return supabase.channel('employee-$employeeId-payslips')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'india_payroll_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) {
            print('NotificationService: [REALTIME] New payslip: ${payload.newRecord}');
            onPayslip(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToExpenseUpdates(
      String employeeId, Function(Map<String, dynamic>) onExpenseUpdate) {
    print('NotificationService: Subscribing to expense updates for employee: $employeeId');
    
    return supabase.channel('employee-$employeeId-expenses')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'expenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) {
            print('NotificationService: [REALTIME] Expense update: ${payload.newRecord}');
            onExpenseUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToCharges(
      String employeeId, Function(Map<String, dynamic>) onCharge) {
    print('NotificationService: Subscribing to charges for employee: $employeeId');
    
    // Attempt to filter by employee_id if possible, or filter in callback
    // Note: If 'employee_charges' RLS allows it, checking by employee_id works
    return supabase.channel('employee-$employeeId-charges')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'employee_charges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) {
            print('NotificationService: [REALTIME] New charge: ${payload.newRecord}');
            onCharge(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToPolicies(
      String organizationId, Function(Map<String, dynamic>) onPolicy) {
    print('NotificationService: Subscribing to policies for org: $organizationId');
    
    return supabase.channel('org-$organizationId-policies')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'policies',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: organizationId,
          ),
          callback: (payload) {
            print('NotificationService: [REALTIME] New policy: ${payload.newRecord}');
            onPolicy(payload.newRecord);
          },
        )
        .subscribe();
  }
}
