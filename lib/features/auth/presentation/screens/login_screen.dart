import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_eq_bars.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _handleController = TextEditingController();

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  void _showGuestHandleDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: GlassContainer(
            borderRadius: AppDimens.radiusLg,
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose your DJ Handle',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: AppDimens.xs),
                Text(
                  'This is how other listeners will see you in rooms.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppDimens.md),
                TextField(
                  controller: _handleController,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. SonicFox or BeatsMaster',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person_outline,
                        color: AppColors.primaryLight),
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                ElevatedButton(
                  onPressed: () {
                    final handle = _handleController.text.trim();
                    Navigator.pop(ctx);
                    ref
                        .read(authControllerProvider.notifier)
                        .signInAnonymously(handle);
                  },
                  child: const Text('Enter as Guest'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Logo & Animated Waves
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x337C3AED),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: AnimatedEqBars(
                      isPlaying: true,
                      color: AppColors.secondary,
                      height: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.lg),

              // Title & Tagline
              Center(
                child: Text('CoListen', style: AppTypography.displayLarge),
              ),
              const SizedBox(height: AppDimens.xs),
              Center(
                child: Text(
                  'Hear what your friends hear.',
                  style: AppTypography.bodyMedium,
                ),
              ),

              const Spacer(),

              // Sign in buttons
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else ...[
                // Google Sign In
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).signInWithGoogle();
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: AppDimens.md),

                // Guest Mode
                OutlinedButton.icon(
                  onPressed: _showGuestHandleDialog,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Quick Guest Mode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppDimens.xl),
            ],
          ),
        ),
      ),
    );
  }
}
