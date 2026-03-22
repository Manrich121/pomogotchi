import 'package:flutter/foundation.dart';

class AppConfig {
  static const String authRedirectScheme = 'com.example.pomogotchi';
  static const String authRedirectHost = 'login-callback';

  static String get _host {
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return (kIsWeb || isApple) ? 'http://localhost' : 'http://10.0.2.2';
  }

  static String get supabaseUrl => '$_host:54321';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  static String get powersyncUrl => '$_host:8080';

  static String get authRedirectUrl =>
      '$authRedirectScheme://$authRedirectHost';
}
