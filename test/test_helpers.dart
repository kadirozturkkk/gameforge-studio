import 'dart:io';

import 'package:gameforge_studio/project/project_index.dart';
import 'package:gameforge_studio/project/project_service.dart';
import 'package:gameforge_studio/project/project_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A project service backed by a temporary folder and an in-memory SQLite
/// database, using the same code paths as the app.
class TestEnv {
  TestEnv._(this.dir, this.index, this.service);

  final Directory dir;
  final ProjectIndex index;
  final ProjectService service;

  static bool _ffiReady = false;

  static Future<TestEnv> create() async {
    if (!_ffiReady) {
      sqfliteFfiInit();
      _ffiReady = true;
    }
    final dir = await Directory.systemTemp.createTemp('gameforge_test_');
    final index = await ProjectIndex.open(
        databaseFactoryFfi, '${dir.path}${Platform.pathSeparator}index.db');
    final storage = ProjectStorage(Directory('${dir.path}${Platform.pathSeparator}projects'));
    return TestEnv._(dir, index, ProjectService(storage, index));
  }

  Future<void> dispose() async {
    await index.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
