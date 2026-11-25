import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/version_control_provider.dart';
import 'app_update_dialog.dart';

class VersionControlGate extends ConsumerWidget {
  const VersionControlGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(versionControlNotifierProvider);

    if (!state.shouldShowPopup || state.remoteData == null) {
      return const SizedBox.shrink();
    }

    final isMandatory = state.remoteData!.isMandatoryUpdate;

    return Stack(
      children: [
        // Modal Barrier
        ModalBarrier(
          dismissible: !isMandatory,
          color: Colors.black.withValues(alpha: isMandatory ? 0.85 : 0.65),
          onDismiss: isMandatory
              ? null
              : () {
                  ref
                      .read(versionControlNotifierProvider.notifier)
                      .dismissForSession();
                },
        ),

        // Dialog View
        AppUpdateDialog(data: state.remoteData!),
      ],
    );
  }
}
