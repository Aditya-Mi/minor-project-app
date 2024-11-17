import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:minor_project/screens/home_page.dart';
import 'package:minor_project/services/shared_prefs_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Fire Alert!',
    message.notification?.body ?? 'Fire detected! Please evacuate immediately!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'fire_alert_channel',
        'Fire Alert Notifications',
        channelDescription: 'High importance notifications for fire alerts',
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        color: Color.fromARGB(255, 255, 0, 0),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    await _initializeLocalNotifications();
    await _setupMessageHandling();
    await _getAndSaveToken();
    _handleInitialMessage();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      'fire_alert_channel',
      'Fire Alert Notifications',
      description: 'High importance notifications for fire alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android:  AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS:  DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          requestCriticalPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _navigateToHomeScreen();
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _setupMessageHandling() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
    });

    // Message opens app from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToHomeScreen();
    });
  }

  Future<void> _handleInitialMessage() async {
    // Get any messages that caused the app to open from terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _navigateToHomeScreen();
    }
  }

  void _navigateToHomeScreen() {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
            (route) => false,
      );
    }
  }

  Future<void> _getAndSaveToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await SharedPrefsService.saveToken(token);
      print('FCM Token saved: $token');
    }

    _firebaseMessaging.onTokenRefresh.listen((String token) {
      SharedPrefsService.saveToken(token);
      print('FCM Token refreshed and saved: $token');
    });
  }

  Future<void> _showNotification(RemoteMessage message) async {
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Fire Alert!',
      message.notification?.body ?? 'Fire detected! Please evacuate immediately!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fire_alert_channel',
          'Fire Alert Notifications',
          channelDescription: 'High importance notifications for fire alerts',
          importance: Importance.max,
          priority: Priority.high,
          enableLights: true,
          color: Color.fromARGB(255, 255, 0, 0),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}