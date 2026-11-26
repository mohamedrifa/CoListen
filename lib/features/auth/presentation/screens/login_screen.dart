import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/colisten_logo.dart';
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
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg),
              ),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              AppDimens.sm,
              AppDimens.lg,
              AppDimens.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),

                // Sheet Title & Description
                Text(
                  'Choose your DJ handle',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: AppDimens.xs),
                Text(
                  'This is how other listeners will see you in rooms.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppDimens.lg),

                // Handle Input Field
                TextField(
                  controller: _handleController,
                  autofocus: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. SonicFox or BeatsMaster',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.alternate_email,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.md,
                      vertical: AppDimens.md,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.lg),

                // Enter as Guest Button (Gradient Pill)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      onTap: () {
                        final handle = _handleController.text.trim();
                        Navigator.pop(ctx);
                        ref
                            .read(authControllerProvider.notifier)
                            .signInAnonymously(handle);
                      },
                      child: const Center(
                        child: Text(
                          'Enter as Guest',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),

              // Midnight Studio Vector Logo with Ambient Glow
              const Center(
                child: CoListenLogo(
                  size: 96,
                  showGlow: true,
                  animate: true,
                ),
              ),
              const SizedBox(height: AppDimens.xl),

              // Headline & Tagline
              Center(
                child: Text(
                  'Listen together. In sync.',
                  style: AppTypography.displayLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              Center(
                child: Text(
                  'Real-time music rooms with zero drift.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 4),

              // Action Buttons Stack
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else ...[
                // Google Sign In (White Pill, Dark Text)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).signInWithGoogle();
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),

                // Guest Mode (Translucent Glass Outline Pill)
                OutlinedButton.icon(
                  onPressed: _showGuestHandleDialog,
                  icon: const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  label: const Text(
                    'Continue as Guest',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(
                      color: AppColors.glassBorder,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
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
