import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(settings);
  }

  static Future<void> scheduleDailyNotifications() async {
    // Morning 8:10 AM
    await _scheduleNotification(
      id: 1,
      title: 'Good Morning!',
      body: 'Plan your day and money flow.',
      hour: 8,
      minute: 10,
    );

    // Morning 11:20 AM
    await _scheduleNotification(
      id: 2,
      title: 'Mid-Morning Check',
      body: 'How is your money flow going?',
      hour: 11,
      minute: 20,
    );

    // Evening 6:20 PM
    await _scheduleNotification(
      id: 3,
      title: 'Evening Update',
      body: 'Time to review your expenses.',
      hour: 18,
      minute: 20,
    );

    // Night 9:20 PM
    await _scheduleNotification(
      id: 4,
      title: 'Night Wrap-up',
      body: 'Enter your money flow for the day.',
      hour: 21,
      minute: 20,
    );
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Daily reminders for money management',
      importance: Importance.high,
      priority: Priority.high,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> showSpendingNotification(double percentage) async {
    final title = 'Spending Alert';
    final body =
        'You have spent ${percentage.toStringAsFixed(0)}% of your monthly limit.';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'spending_alerts',
      'Spending Alerts',
      channelDescription: 'Alerts for spending milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(100, title, body, details);
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
