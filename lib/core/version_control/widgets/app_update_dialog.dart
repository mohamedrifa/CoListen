import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../models/app_version_data.dart';
import '../providers/version_control_provider.dart';

class AppUpdateDialog extends ConsumerWidget {
  final AppVersionData data;

  const AppUpdateDialog({super.key, required this.data});

  Future<void> _launchUpdateUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMandatory = data.isMandatoryUpdate;

    final dialogContent = Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(AppDimens.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: isMandatory
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isMandatory ? AppColors.error : AppColors.primary)
                    .withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isMandatory ? AppColors.error : AppColors.primary)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMandatory ? AppColors.error : AppColors.primary,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isMandatory
                        ? Icons.security_update_warning_rounded
                        : Icons.system_update_rounded,
                    color: isMandatory ? AppColors.error : AppColors.secondary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.md),

              // Title
              Text(
                isMandatory
                    ? 'Critical Update Required'
                    : (data.title.isNotEmpty
                        ? data.title
                        : 'New Update Available'),
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isMandatory ? AppColors.error : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.xs),

              // Version Transition Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'v${AppConstants.appVersion}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 12, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'v${data.version}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.md),

              // Mandatory warning banner
              if (isMandatory) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: AppDimens.xs),
                      Expanded(
                        child: Text(
                          'All room audio and sync features require updating to continue.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.md),
              ],

              // Release notes
              if (data.releaseNotes.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'What\'s New:',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    data.releaseNotes,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
              ],

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchUpdateUrl(data.url),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Update Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMandatory
                        ? AppColors.error
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                ),
              ),

              // Dismiss / Remind Me Later (only for optional updates)
              if (!isMandatory) ...[
                const SizedBox(height: AppDimens.xs),
                TextButton(
                  onPressed: () {
                    ref
                        .read(versionControlNotifierProvider.notifier)
                        .dismissForSession();
                  },
                  child: Text(
                    'Remind Me Later',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isMandatory) {
      return PopScope(
        canPop: false,
        child: dialogContent,
      );
    }

    return dialogContent;
  }
}
