class AppConstants {
  static const String appName = 'CoListen';
  static const String appTagline = 'Hear what your friends hear.';
  static const int roomCodeLength = 6;
  static const String roomCodeCharset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const int maxQueueCapacity = 100;
  static const Duration driftPollingInterval = Duration(seconds: 4);
}
