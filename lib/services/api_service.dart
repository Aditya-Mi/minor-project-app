import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService{
  static const String BASE_URL = 'http://192.168.2.159:5000';

  Future<bool> requestFireAlert(String? fcmToken) async {
    try {
      if (fcmToken == null) {
        throw Exception('FCM token not found');
      }

      final response = await http.post(
        Uri.parse('$BASE_URL/send-fire-alert'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        startStream();
        return true;
      } else {
        print('Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error requesting fire alert: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkServerStatus() async {
    final response = await http.get(Uri.parse('$BASE_URL/health'));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get server status');
    }
  }

  Future<Map<String, dynamic>> startStream() async {
    final response = await http.post(Uri.parse('$BASE_URL/stream/start'));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to start server');
    }
  }

  Future<Map<String, dynamic>> stopStream() async {
    final response = await http.post(Uri.parse('$BASE_URL/stream/stop'));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to stop server');
    }
  }
}