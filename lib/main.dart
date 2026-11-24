import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/env_config.dart';
import 'core/config/firebase_options_factory.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables dynamically
  await EnvConfig.init();

  // 2. Initialize Firebase with dynamic platform options
  await Firebase.initializeApp(
    options: FirebaseOptionsFactory.currentPlatformOptions,
  );

  runApp(
    const ProviderScope(
      child: CoListenApp(),
    ),
  );
}
