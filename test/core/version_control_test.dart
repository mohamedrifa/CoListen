import 'package:flutter_test/flutter_test.dart';
import 'package:colisten/core/constants/app_constants.dart';
import 'package:colisten/core/version_control/models/app_version_data.dart';
import 'package:colisten/core/version_control/providers/version_control_provider.dart';

void main() {
  group('VersionControl Tests', () {
    test('AppConstants.isVersionSmaller comparisons', () {
      expect(AppConstants.isVersionSmaller('1.0.0', '1.0.1'), isTrue);
      expect(AppConstants.isVersionSmaller('1.0.0', '1.1.0'), isTrue);
      expect(AppConstants.isVersionSmaller('1.0.0', '2.0.0'), isTrue);
      expect(AppConstants.isVersionSmaller('1.0.1', '1.0.0'), isFalse);
      expect(AppConstants.isVersionSmaller('1.0.0', '1.0.0'), isFalse);
      expect(AppConstants.isVersionSmaller('v1.0.0', 'v1.0.1'), isTrue);
      expect(AppConstants.isVersionSmaller('1.0.0+1', '1.0.1+2'), isTrue);
    });

    test('AppVersionData parsing from map', () {
      final map = {
        'version': '1.2.0',
        'isMandatoryUpdate': true,
        'url': 'https://colisten.app/download',
        'title': 'Critical Audio Engine Update',
        'releaseNotes': 'New low-latency audio sync',
      };

      final data = AppVersionData.fromMap(map);
      expect(data.version, equals('1.2.0'));
      expect(data.isMandatoryUpdate, isTrue);
      expect(data.url, equals('https://colisten.app/download'));
      expect(data.title, equals('Critical Audio Engine Update'));
      expect(data.releaseNotes, equals('New low-latency audio sync'));
    });

    test('VersionControlState.shouldShowPopup optional vs mandatory logic', () {
      // 1. Up to date -> popup false
      const upToDateState = VersionControlState(
        remoteData: AppVersionData(
          version: '1.0.0',
          url: 'https://example.com',
          isMandatoryUpdate: false,
        ),
      );
      expect(upToDateState.shouldShowPopup, isFalse);

      // 2. Outdated + optional -> popup true
      const outdatedOptionalState = VersionControlState(
        remoteData: AppVersionData(
          version: '1.1.0',
          url: 'https://example.com',
          isMandatoryUpdate: false,
        ),
        isDismissed: false,
      );
      expect(outdatedOptionalState.shouldShowPopup, isTrue);

      // 3. Outdated + optional + dismissed -> popup false
      final dismissedOptionalState = outdatedOptionalState.copyWith(isDismissed: true);
      expect(dismissedOptionalState.shouldShowPopup, isFalse);

      // 4. Outdated + mandatory + dismissed -> popup TRUE (mandatory cannot be dismissed)
      const mandatoryDismissedState = VersionControlState(
        remoteData: AppVersionData(
          version: '1.1.0',
          url: 'https://example.com',
          isMandatoryUpdate: true,
        ),
        isDismissed: true,
      );
      expect(mandatoryDismissedState.shouldShowPopup, isTrue);
    });
  });
}
