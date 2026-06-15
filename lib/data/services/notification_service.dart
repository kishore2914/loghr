import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:loghr_mobile/config/api_client.dart';
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
        macOS: initializationSettingsIOS, 
      );

      await _notificationsPlugin.initialize(initializationSettings);
      
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
      'loghr_urgent_channel_v3',
      'Urgent Alerts',
      channelDescription: 'High priority notifications for assigned tasks',
      importance: Importance.max,
      priority: Priority.max,
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
      // Simple path construction
      final fileName = 'org_logo_${logoUrl.hashCode}.png';
      final filePath = '${directory.path}/$fileName';
      
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
            'loghr_general_channel',
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

  Future<void> createAutoCheckoutAdminNotification({
    required String employeeId,
    required String employeeName,
  }) async {
    // Stubbed since client handles auto checkout trigger locally
    print('NotificationService: createAutoCheckoutAdminNotification stubbed');
  }

  // --- Database Notifications ---

  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final response = await api.get('/misc/notifications');
      if (response == null) return [];
      final list = response as List;
      return list.map((n) => AppNotification.fromJson(n)).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await api.post('/misc/notifications/mark-read', {'id': notificationId});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await api.post('/misc/notifications/mark-all-read', {});
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await api.delete('/misc/notifications/$notificationId');
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // --- Realtime Subscriptions (Mocked) ---

  RealtimeChannel subscribeToNotifications(
      String userId, Function(AppNotification) onNewNotification) {
    print('NotificationService: Subscribing mock notifications for user: $userId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToTasks(
      String employeeId, Function(Map<String, dynamic>) onNewTask) {
    print('NotificationService: Subscribing mock tasks for employee: $employeeId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToLeaveUpdates(
      String employeeId, Function(Map<String, dynamic>) onLeaveUpdate) {
    print('NotificationService: Subscribing mock leaves for employee: $employeeId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToAnnouncements(
      String organizationId, Function(Map<String, dynamic>) onAnnouncement) {
    print('NotificationService: Subscribing mock announcements for org: $organizationId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToPayslips(
      String employeeId, Function(Map<String, dynamic>) onPayslip) {
    print('NotificationService: Subscribing mock payslips for employee: $employeeId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToExpenseUpdates(
      String employeeId, Function(Map<String, dynamic>) onExpenseUpdate) {
    print('NotificationService: Subscribing mock expenses for employee: $employeeId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToCharges(
      String employeeId, Function(Map<String, dynamic>) onCharge) {
    print('NotificationService: Subscribing mock charges for employee: $employeeId');
    return RealtimeChannel();
  }

  RealtimeChannel subscribeToPolicies(
      String organizationId, Function(Map<String, dynamic>) onPolicy) {
    print('NotificationService: Subscribing mock policies for org: $organizationId');
    return RealtimeChannel();
  }
}
