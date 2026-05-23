import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/transaction.dart';
import 'app_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    if (Platform.isAndroid) {
      final permissionStatus = await Permission.notification.status;
      if (!permissionStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(settings);
  }

  static Future<void> scheduleDailyNotifications() async {
    final monthlyLimit = AppSettings.getMonthlySpendingLimit();
    final currency = Hive.box('settings')
            .get(
              AppSettings.currencyKey,
              defaultValue: AppSettings.defaultCurrency,
            )
        as String;
    final transactions = Hive.box<Transaction>('transactions').values.toList();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final currentMonthExpense = transactions
        .where((t) => t.type == 'expense')
        .where((t) => DateTime(t.date.year, t.date.month) == monthStart)
        .fold(0.0, (sum, t) => sum + t.amount);
    final remaining =
        (monthlyLimit - currentMonthExpense).clamp(0.0, double.infinity);
    final remainingMessage = monthlyLimit > 0
        ? 'Your expense limit balance is ${AppSettings.formatCurrency(remaining, currency)}.'
        : 'Set your monthly expense limit in Settings to track your balance.';

    await _scheduleNotification(
      id: 1,
      title: 'Good Morning',
      body:
          'Good morning. $remainingMessage Plan your day for investments and expenses.',
      hour: 9,
      minute: 20,
    );

    await _scheduleNotification(
      id: 2,
      title: 'Expense Reminder',
      body: 'Please fill up your expenses for today.',
      hour: 14,
      minute: 20,
    );

    await _scheduleNotification(
      id: 3,
      title: 'Evening Expense Reminder',
      body: 'Please fill up your expenses before the day ends.',
      hour: 21,
      minute: 40,
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Daily reminders for money management',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details =
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'spending_alerts',
      'Spending Alerts',
      channelDescription: 'Alerts for spending milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(100, title, body, details);
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
