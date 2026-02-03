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
    
    final channel = supabase
        .channel('employee-$employeeId-tasks')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            print('NotificationService: [REALTIME] Task row received: ${payload.newRecord}');
            // Try matching both 'assigned_to' and 'assignee_id' just in case
            final assignedTo = payload.newRecord['assigned_to']?.toString();
            final assigneeId = payload.newRecord['assignee_id']?.toString();
            
            if (assignedTo == employeeId || assigneeId == employeeId) {
              print('NotificationService: [REALTIME] Match found! Triggering popup.');
              onNewTask(payload.newRecord);
            }
          },
        )
        .subscribe();
        
    return channel;
  }
}
