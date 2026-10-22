// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications/src/platform_flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remindme/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home page displays the add-entretien action', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance =
        MethodChannelFlutterLocalNotificationsPlugin();
    const notificationChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async {
          if (call.method == 'areNotificationsEnabled') return true;
          if (call.method == 'pendingNotificationRequests') {
            return <Map<String, Object?>>[];
          }
          return null;
        });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('RemindMe'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Adding an entretien closes the add dialog', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance =
        MethodChannelFlutterLocalNotificationsPlugin();
    const notificationChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async {
          if (call.method == 'areNotificationsEnabled') return true;
          if (call.method == 'pendingNotificationRequests') {
            return <Map<String, Object?>>[];
          }
          return null;
        });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Contrôle technique');
    await tester.tap(find.text('Choisir une date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un entretien'), findsNothing);
    expect(find.text('Contrôle technique'), findsOneWidget);
  });
}
