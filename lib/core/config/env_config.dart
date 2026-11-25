import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }

  static String get(String key, {String fallback = ''}) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key] ??
            String.fromEnvironment(key, defaultValue: fallback);
      }
    } catch (_) {}
    return String.fromEnvironment(key, defaultValue: fallback);
  }

  // App Metadata
  static String get appEnv => get('APP_ENV', fallback: 'development');
  static String get appName => get('APP_NAME', fallback: 'CoListen');
  static String get appBaseUrl =>
      get('APP_BASE_URL', fallback: 'https://colisten.app');

  // Firebase Core (Single Realtime Database Architecture)
  static String get firebaseProjectId => get('FIREBASE_PROJECT_ID');
  static String get firebaseStorageBucket => get('FIREBASE_STORAGE_BUCKET');
  static String get firebaseDatabaseUrl => get('FIREBASE_DATABASE_URL');
  static String get firebaseAuthDomain => get('FIREBASE_AUTH_DOMAIN');

  // Platform API Keys
  static String get firebaseApiKeyAndroid => get('FIREBASE_API_KEY_ANDROID');
  static String get firebaseAppIdAndroid => get('FIREBASE_APP_ID_ANDROID');
  static String get firebaseApiKeyIos => get('FIREBASE_API_KEY_IOS');
  static String get firebaseAppIdIos => get('FIREBASE_APP_ID_IOS');
  static String get firebaseIosClientId => get('FIREBASE_IOS_CLIENT_ID');
  static String get firebaseIosBundleId =>
      get('FIREBASE_IOS_BUNDLE_ID', fallback: 'com.colisten.app');

  // External APIs
  static String get youtubeApiKey => get('YOUTUBE_DATA_API_KEY');

  // Version Control
  static String get firebaseVersionControlPath =>
      get('FIREBASE_VERSION_CONTROL_PATH', fallback: 'COLISTEN_APP');
}
