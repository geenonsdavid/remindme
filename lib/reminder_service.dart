// lib/services/reminder_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class ReminderService {
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  ReminderService(this.notificationsPlugin) {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));
  }

  Map<String, DateTime> entretiens = {};

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final iosPermission = await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final androidPermission =
        await notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();

    return iosPermission ?? androidPermission ?? false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;

    final androidEnabled =
        await notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
    if (androidEnabled != null) return androidEnabled;

    final iosPermissions =
        await notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
    return iosPermissions?.isEnabled ?? false;
  }

  Future<Set<int>> scheduledNotificationIds() async {
    if (kIsWeb) return <int>{};

    final pendingNotifications =
        await notificationsPlugin.pendingNotificationRequests();
    return pendingNotifications.map((notification) => notification.id).toSet();
  }

  Future<void> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('entretiens');
    if (storedData != null) {
      final decoded = jsonDecode(storedData) as Map<String, dynamic>;
      entretiens = decoded.map(
        (key, value) => MapEntry(key, DateTime.parse(value)),
      );
    }
  }

  Future<void> saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      entretiens.map((key, value) => MapEntry(key, value.toIso8601String())),
    );
    await prefs.setString('entretiens', jsonString);
  }

  int notificationsId(String name) => name.hashCode;

  Future<void> deleteEntretien(String name) async {
    entretiens.remove(name);
    await cancelNotification(name);
    await saveReminders();
  }

  Future<void> cancelNotification(String name) async {
    if (kIsWeb) return;

    await notificationsPlugin.cancel(notificationsId(name));
  }

  Future<void> updateEntretienDate(String name) async {
    final current = entretiens[name];
    if (current == null) return;
    final newDate = DateTime(current.year + 1, current.month, current.day);
    entretiens[name] = newDate;
    await saveReminders();
    await scheduleNotification(name, newDate);
  }

  Future<bool> scheduleNotification(String name, DateTime date) async {
    if (kIsWeb) return false;

    final fixedTime = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      9,
    );
    if (!fixedTime.isAfter(tz.TZDateTime.now(tz.local))) {
      await cancelNotification(name);
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      'entretien_reminders',
      'Rappels d’entretien',
      channelDescription: 'Rappels pour les entretiens enregistrés',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await notificationsPlugin.zonedSchedule(
      notificationsId(name),
      'Rappel d\'entretien',
      'N\'oubliez pas l\'entretien de $name !',
      fixedTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  Future<void> scheduleAll() async {
    if (kIsWeb || entretiens.isEmpty) return;

    await notificationsPlugin.cancelAll(); // éviter les doublons
    for (final entry in entretiens.entries) {
      await scheduleNotification(entry.key, entry.value);
    }
  }
}
