class Logger {
  static const String tag = "VideoStream";

  static void log(String message, {String level = "INFO"}) {
    final timestamp = DateTime.now().toIso8601String();
    print("[$tag][$level][$timestamp] $message");
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    print("[$tag][ERROR][$timestamp] $message");
    if (error != null) {
      print("Error details: $error");
      if (stackTrace != null) {
        print("Stack trace:\n$stackTrace");
      }
    }
  }
}
