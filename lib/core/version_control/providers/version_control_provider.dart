import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_constants.dart';
import '../models/app_version_data.dart';
import '../services/version_control_service.dart';

class VersionControlState {
  final AppVersionData? remoteData;
  final bool isDismissed;

  const VersionControlState({
    this.remoteData,
    this.isDismissed = false,
  });

  bool get shouldShowPopup {
    if (remoteData == null || remoteData!.url.isEmpty) return false;
    final isSmaller = AppConstants.isVersionSmaller(
      AppConstants.appVersion,
      remoteData!.version,
    );
    if (!isSmaller) return false;
    if (remoteData!.isMandatoryUpdate) return true;
    return !isDismissed;
  }

  VersionControlState copyWith({
    AppVersionData? remoteData,
    bool? isDismissed,
  }) {
    return VersionControlState(
      remoteData: remoteData ?? this.remoteData,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

final versionControlServiceProvider = Provider<VersionControlService>((ref) {
  return VersionControlService();
});

final versionControlNotifierProvider =
    StateNotifierProvider<VersionControlNotifier, VersionControlState>((ref) {
  final service = ref.watch(versionControlServiceProvider);
  return VersionControlNotifier(service);
});

class VersionControlNotifier extends StateNotifier<VersionControlState> {
  final VersionControlService _service;
  StreamSubscription<AppVersionData>? _subscription;

  VersionControlNotifier(this._service) : super(const VersionControlState()) {
    _init();
  }

  void _init() {
    try {
      _subscription = _service.watchVersionControl().listen(
        (data) {
          state = state.copyWith(remoteData: data);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void dismissForSession() {
    state = state.copyWith(isDismissed: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
