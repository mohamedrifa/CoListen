import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/room_providers.dart';

class JoinCodeSheet extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinCodeSheet({super.key, this.initialCode});

  @override
  ConsumerState<JoinCodeSheet> createState() => _JoinCodeSheetState();
}

class _JoinCodeSheetState extends ConsumerState<JoinCodeSheet> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!.trim().toUpperCase();
    }
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    // Request focus once the sheet is mounted and visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim().toUpperCase() ?? '';
    if (text.isNotEmpty) {
      // Clean only alphanumeric characters
      final filtered = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (filtered.isNotEmpty) {
        final codeToSet = filtered.length >= AppConstants.roomCodeLength
            ? filtered.substring(0, AppConstants.roomCodeLength)
            : filtered;
        setState(() {
          _codeController.text = codeToSet;
          _errorMessage = '';
        });
        if (codeToSet.length == AppConstants.roomCodeLength) {
          _handleJoin();
        }
      }
    }
  }

  Future<void> _handleJoin() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final code = _codeController.text.trim().toUpperCase();
    if (code.length != AppConstants.roomCodeLength) {
      setState(() {
        _errorMessage = 'Please enter a complete 6-character room code.';
      });
      return;
    }

    final roomId = await ref.read(roomControllerProvider.notifier).joinRoomByCode(
          code: code,
          uid: user.uid,
          displayName: user.displayName,
        );

    if (mounted) {
      if (roomId != null) {
        Navigator.pop(context);
        context.push('/room/$roomId');
      } else {
        final error = ref.read(roomControllerProvider).error;
        setState(() {
          _errorMessage = error?.toString().replaceAll('Exception: ', '') ??
              'Failed to join room.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomControllerProvider);
    final isLoading = roomState.isLoading;
    final currentCode = _codeController.text.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: AppDimens.radiusLg,
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Join with Room Code', style: AppTypography.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Enter the 6-character room code to start listening in sync.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppDimens.lg),

            // 6-Character Interactive Box Display with Overlay TextField
            GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Visual 6-box representation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(AppConstants.roomCodeLength, (index) {
                      final char = index < currentCode.length ? currentCode[index] : '';
                      final isFocused = _focusNode.hasFocus;
                      final isCurrent = isFocused && index == currentCode.length;

                      return Container(
                        width: 44,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.primary
                                : char.isNotEmpty
                                    ? AppColors.secondary
                                    : AppColors.glassBorder,
                            width: isCurrent ? 2 : 1.5,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: char.isNotEmpty
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Overlay TextField spanning across all boxes
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.0,
                      child: TextField(
                        controller: _codeController,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.go,
                        maxLength: AppConstants.roomCodeLength,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return TextEditingValue(
                              text: newValue.text.toUpperCase(),
                              selection: newValue.selection,
                            );
                          }),
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(AppConstants.roomCodeLength),
                        ],
                        onChanged: (val) {
                          setState(() => _errorMessage = '');
                          if (val.length == AppConstants.roomCodeLength) {
                            _handleJoin();
                          }
                        },
                        onSubmitted: (_) => _handleJoin(),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.md),

            if (_errorMessage.isNotEmpty) ...[
              Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
              const SizedBox(height: AppDimens.sm),
            ],

            // Paste button
            Center(
              child: TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('Paste from Clipboard'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),

            // Join Button
            ElevatedButton(
              onPressed: isLoading ? null : _handleJoin,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Join Room Now'),
            ),
          ],
        ),
      ),
    );
  }
}
