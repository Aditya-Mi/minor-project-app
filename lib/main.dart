import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:minor_project/screens/home_page.dart';
import 'package:minor_project/services/alert_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseMessagingService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: FirebaseMessagingService().navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Material App',
      home: const HomePage(),
    );
  }
}
