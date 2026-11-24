import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class NativeShareService {
  static Future<void> shareRoom({
    required String roomName,
    required String roomCode,
  }) async {
    final link = 'https://colisten.app/join/$roomCode';
    final shareText =
        'Join my music room "$roomName" on CoListen! 🎧\nRoom Code: $roomCode\n$link';

    try {
      // 1. Copy to clipboard for instant access
      await Clipboard.setData(ClipboardData(text: link));

      // 2. Trigger native OS share sheet (WhatsApp, Messages, AirDrop, etc.)
      await Share.share(
        shareText,
        subject: 'Listen together on CoListen: $roomName',
      );
    } catch (_) {
      // Fallback: clipboard data was already placed
    }
  }
}
