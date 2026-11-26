import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/lifecycle/app_lifecycle_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/version_control/widgets/version_control_gate.dart';

class CoListenApp extends ConsumerWidget {
  const CoListenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) => AppLifecycleManager(
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const VersionControlGate(),
          ],
        ),
      ),
    );
  }
}
