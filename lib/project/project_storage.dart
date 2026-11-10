import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors.dart';
import '../core/safe_file.dart';
import '../engine/scene/scene.dart';
import 'project_meta.dart';

/// Result of loading a file, flagging if a backup had to be used.
class Loaded<T> {
  Loaded(this.value, {this.recovered = false});
  final T value;
  final bool recovered;
}

/// Owns the on-disk layout of projects. Every project lives in its own
/// folder under [root]:
///
///   <root>/<projectId>/project.json
///   <root>/<projectId>/scenes/<sceneId>.scene.json
///   <root>/<projectId>/assets/ scripts/ animations/ ui/ build/
///   <root>/<projectId>/.recovery/<sceneId>.scene.json
class ProjectStorage {
  ProjectStorage(this.root);

  final Directory root;

  static const projectFileName = 'project.json';
  static const subfolders = [
    'scenes',
    'assets',
    'scripts',
    'animations',
    'ui',
    'build',
    '.recovery',
  ];

  Directory projectDir(String projectId) {
    if (projectId.isEmpty || projectId.contains(RegExp(r'[/\\.]'))) {
      throw ValidationException(ValidationError.projectNotFound);
    }
    return Directory(p.join(root.path, projectId));
  }

  File metaFile(String projectId) =>
      File(p.join(projectDir(projectId).path, projectFileName));

  File sceneFile(String projectId, String sceneId) =>
      File(p.join(projectDir(projectId).path, 'scenes', '$sceneId.scene.json'));

  File recoveryFile(String projectId, String sceneId) =>
      File(p.join(projectDir(projectId).path, '.recovery', '$sceneId.scene.json'));

  Future<bool> exists(String projectId) => metaFile(projectId).exists();

  Future<void> createLayout(String projectId) async {
    final dir = projectDir(projectId);
    for (final sub in subfolders) {
      await Directory(p.join(dir.path, sub)).create(recursive: true);
    }
  }

  // ---- project.json ----

  Future<void> writeMeta(ProjectMeta meta) =>
      SafeFile.writeJson(metaFile(meta.id), meta.toJson());

  Future<Loaded<ProjectMeta>> readMeta(String projectId) async {
    final file = metaFile(projectId);
    if (!await file.exists() && !await SafeFile.backupOf(file).exists()) {
      throw ValidationException(ValidationError.projectNotFound);
    }
    final r = await SafeFile.readJson(file, ProjectMeta.fromJson);
    if (r.value.id != projectId) {
      throw DataFormatException('Project id does not match folder', path: file.path);
    }
    return Loaded(r.value, recovered: r.recoveredFromBackup);
  }

  // ---- scenes ----

  Future<void> writeScene(String projectId, Scene scene) =>
      SafeFile.writeJson(sceneFile(projectId, scene.id), scene.toJson());

  Future<Loaded<Scene>> readScene(String projectId, String sceneId) async {
    final file = sceneFile(projectId, sceneId);
    if (!await file.exists() && !await SafeFile.backupOf(file).exists()) {
      throw ValidationException(ValidationError.sceneNotFound);
    }
    final r = await SafeFile.readJson(file, Scene.fromJson);
    return Loaded(r.value, recovered: r.recoveredFromBackup);
  }

  Future<void> deleteScene(String projectId, String sceneId) async {
    await SafeFile.delete(sceneFile(projectId, sceneId));
    await clearRecovery(projectId, sceneId);
  }

  /// Scene ids that exist on disk.
  Future<List<String>> listSceneIds(String projectId) async {
    final dir = Directory(p.join(projectDir(projectId).path, 'scenes'));
    if (!await dir.exists()) return [];
    final ids = <String>[];
    await for (final e in dir.list()) {
      final name = p.basename(e.path);
      if (e is File && name.endsWith('.scene.json')) {
        ids.add(name.substring(0, name.length - '.scene.json'.length));
      }
    }
    return ids;
  }

  // ---- crash recovery snapshots ----

  Future<void> writeRecovery(String projectId, Scene scene) => SafeFile.writeJson(
      recoveryFile(projectId, scene.id), scene.toJson(),
      keepBackup: false);

  /// Returns the unsaved snapshot of a scene if one exists and is valid.
  Future<Scene?> readRecovery(String projectId, String sceneId) async {
    final file = recoveryFile(projectId, sceneId);
    if (!await file.exists()) return null;
    try {
      final r = await SafeFile.readJson(file, Scene.fromJson);
      return r.value;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRecovery(String projectId, String sceneId) =>
      SafeFile.delete(recoveryFile(projectId, sceneId));

  // ---- whole projects ----

  Future<void> deleteProject(String projectId) async {
    final dir = projectDir(projectId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Ids of all project folders that contain a project file.
  Future<List<String>> listProjectIds() async {
    if (!await root.exists()) return [];
    final ids = <String>[];
    await for (final e in root.list()) {
      if (e is Directory) {
        final id = p.basename(e.path);
        final meta = File(p.join(e.path, projectFileName));
        if (await meta.exists() || await SafeFile.backupOf(meta).exists()) {
          ids.add(id);
        }
      }
    }
    return ids;
  }
}
