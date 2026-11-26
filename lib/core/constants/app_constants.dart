class AppConstants {
  static const String appName = 'CoListen';
  static const String appTagline = 'Hear what your friends hear.';
  static const String appVersion = '1.0.1';
  static const int appBuildNumber = 1;
  static const int roomCodeLength = 6;
  static const String roomCodeCharset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const int maxQueueCapacity = 100;
  static const Duration driftPollingInterval = Duration(seconds: 4);

  /// Compares [installedVersion] vs [remoteVersion].
  /// Returns `true` if installed is strictly smaller than remote.
  static bool isVersionSmaller(String installedVersion, String remoteVersion) {
    if (installedVersion.isEmpty || remoteVersion.isEmpty) return false;

    // Clean any prefix e.g. "v1.0.0" -> "1.0.0"
    final cleanInstalled = installedVersion.trim().replaceAll(RegExp(r'^[vV]'), '');
    final cleanRemote = remoteVersion.trim().replaceAll(RegExp(r'^[vV]'), '');

    final installedParts = cleanInstalled
        .split('.')
        .map((p) => int.tryParse(p.split('+').first.split('-').first) ?? 0)
        .toList();
    final remoteParts = cleanRemote
        .split('.')
        .map((p) => int.tryParse(p.split('+').first.split('-').first) ?? 0)
        .toList();

    while (installedParts.length < 3) {
      installedParts.add(0);
    }
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (installedParts[i] < remoteParts[i]) return true;
      if (installedParts[i] > remoteParts[i]) return false;
    }
    return false;
  }
}
