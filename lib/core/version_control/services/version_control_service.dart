import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../config/env_config.dart';
import '../models/app_version_data.dart';

class VersionControlService {
  final FirebaseDatabase? _database;
  final String _path;

  VersionControlService({
    this._database,
    String? path,
  }) : _path = path ?? EnvConfig.firebaseVersionControlPath;

  FirebaseDatabase? get _db {
    if (_database != null) return _database;
    try {
      if (Firebase.apps.isNotEmpty) return FirebaseDatabase.instance;
    } catch (_) {}
    return null;
  }

  /// Streams real-time version control updates directly from Firebase Realtime Database
  Stream<AppVersionData> watchVersionControl() {
    final db = _db;
    if (db == null) {
      return Stream.value(const AppVersionData(version: '1.0.0', url: ''));
    }

    return db.ref(_path).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        return AppVersionData.fromMap(value);
      }
      return const AppVersionData(version: '1.0.0', url: '');
    });
  }

  /// One-shot fetch of version data
  Future<AppVersionData> fetchVersionData() async {
    final db = _db;
    if (db == null) {
      return const AppVersionData(version: '1.0.0', url: '');
    }

    try {
      final snap = await db.ref(_path).get();
      if (snap.exists && snap.value is Map) {
        return AppVersionData.fromMap(snap.value as Map);
      }
    } catch (_) {}
    return const AppVersionData(version: '1.0.0', url: '');
  }
}
