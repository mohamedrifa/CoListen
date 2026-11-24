import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'env_config.dart';

class FirebaseOptionsFactory {
  static FirebaseOptions get currentPlatformOptions {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: EnvConfig.get('FIREBASE_API_KEY_WEB'),
        appId: EnvConfig.get('FIREBASE_APP_ID_WEB'),
        messagingSenderId: '',
        projectId: EnvConfig.firebaseProjectId,
        authDomain: EnvConfig.firebaseAuthDomain,
        databaseURL: EnvConfig.firebaseDatabaseUrl,
        storageBucket: EnvConfig.firebaseStorageBucket,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: EnvConfig.firebaseApiKeyAndroid,
          appId: EnvConfig.firebaseAppIdAndroid,
          messagingSenderId: '',
          projectId: EnvConfig.firebaseProjectId,
          databaseURL: EnvConfig.firebaseDatabaseUrl,
          storageBucket: EnvConfig.firebaseStorageBucket,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return FirebaseOptions(
          apiKey: EnvConfig.firebaseApiKeyIos,
          appId: EnvConfig.firebaseAppIdIos,
          messagingSenderId: '',
          projectId: EnvConfig.firebaseProjectId,
          databaseURL: EnvConfig.firebaseDatabaseUrl,
          storageBucket: EnvConfig.firebaseStorageBucket,
          iosClientId: EnvConfig.firebaseIosClientId,
          iosBundleId: EnvConfig.firebaseIosBundleId,
        );
      default:
        return FirebaseOptions(
          apiKey: EnvConfig.firebaseApiKeyAndroid,
          appId: EnvConfig.firebaseAppIdAndroid,
          messagingSenderId: '',
          projectId: EnvConfig.firebaseProjectId,
          databaseURL: EnvConfig.firebaseDatabaseUrl,
          storageBucket: EnvConfig.firebaseStorageBucket,
        );
    }
  }
}
