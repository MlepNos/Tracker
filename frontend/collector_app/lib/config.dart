import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl {
    // If you run on Android emulator, use 10.0.2.2 for host machine
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000";
    }
    return "http://localhost:8000";
  }
}
