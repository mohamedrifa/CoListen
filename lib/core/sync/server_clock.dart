import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerClock {
  final FirebaseDatabase? _database;
  int _offsetMs;

  ServerClock({FirebaseDatabase? database, int initialOffsetMs = 0})
      // ignore: prefer_initializing_formals
      : _database = database,
        _offsetMs = initialOffsetMs {
    _init();
  }

  void _init() {
    try {
      final db = _database ??
          (Firebase.apps.isNotEmpty ? FirebaseDatabase.instance : null);
      if (db == null) return;
      db.ref('.info/serverTimeOffset').onValue.listen((event) {
        final offset = event.snapshot.value;
        if (offset is num) {
          _offsetMs = offset.toInt();
        }
      });
    } catch (_) {}
  }

  int get offsetMs => _offsetMs;

  DateTime get currentServerTime {
    return DateTime.now().add(Duration(milliseconds: _offsetMs));
  }
}

final serverClockProvider = Provider<ServerClock>((ref) {
  return ServerClock();
});
