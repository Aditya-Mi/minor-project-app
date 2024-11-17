import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String TOKEN_KEY = 'fcm_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TOKEN_KEY, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(TOKEN_KEY);
  }
}