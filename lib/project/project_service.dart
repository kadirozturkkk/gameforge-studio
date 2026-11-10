import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../core/errors.dart';
import '../core/ids.dart';
import '../core/safe_file.dart';
import '../engine/scene/scene.dart';
import 'project_index.dart';
import 'project_meta.dart';
import 'project_storage.dart';
import 'templates.dart';

/// High level project operations used by the dashboard and editor.
class ProjectService {
  ProjectService(this.storage, this.index);

  final ProjectStorage storage;
  final ProjectIndex index;

  static const packageExtension = 'gfproj';

  /// Makes the SQLite index match the project folders on disk: adds
  /// projects found on disk, removes entries whose folder is gone.
  /// Returns the ids of projects that could not be read.
  Future<List<String>> syncIndexWithDisk() async {
    final broken = <String>[];
    final onDisk = await storage.listProjectIds();
    for (final id in onDisk) {
      try {
        final meta = await storage.readMeta(id);
        await index.upsert(meta.value);
      } catch (_) {
        broken.add(id);
      }
    }
    final diskSet = onDisk.toSet();
    for (final id in await index.allIds()) {
      if (!diskSet.contains(id)) await index.remove(id);
    }
    return broken;
  }

  Future<ProjectMeta> createProject(String name, ProjectTemplate template) async {
    final cleanName = validateName(name);
    final (settings, scenes) = ProjectTemplates.build(template);
    final now = DateTime.now();
    final meta = ProjectMeta(
      id: newId(),
      name: cleanName,
      template: template,
      createdAt: now,
      modifiedAt: now,
      startSceneId: scenes.first.id,
      sceneOrder: [for (final s in scenes) s.id],
      settings: settings,
    );
    try {
      await storage.createLayout(meta.id);
      for (final s in scenes) {
        await storage.writeScene(meta.id, s);
      }
      await storage.writeMeta(meta);
      await index.upsert(meta);
    } catch (_) {
      await storage.deleteProject(meta.id);
      rethrow;
    }
    return meta;
  }

  Future<List<ProjectRecord>> listProjects(
          {String query = '', ProjectSort sort = ProjectSort.lastModified}) =>
      index.search(query: query, sort: sort);

  Future<List<ProjectRecord>> recentProjects({int limit = 5}) => index.recent(limit: limit);

  /// Loads the project, repairs its scene list against the files on disk
  /// and records it as recently opened.
  Future<Loaded<ProjectMeta>> openProject(String id) async {
    final loaded = await storage.readMeta(id);
    final meta = loaded.value;
    final onDisk = (await storage.listSceneIds(id)).toSet();
    var changed = loaded.recovered;
    final before = meta.sceneOrder.length;
    meta.sceneOrder.removeWhere((s) => !onDisk.contains(s));
    for (final s in onDisk) {
      if (!meta.sceneOrder.contains(s)) meta.sceneOrder.add(s);
    }
    if (meta.sceneOrder.length != before) changed = true;
    if (meta.sceneOrder.isEmpty) {
      final scene = Scene(name: 'Main');
      await storage.writeScene(id, scene);
      meta.sceneOrder.add(scene.id);
      changed = true;
    }
    if (!meta.sceneOrder.contains(meta.startSceneId)) {
      meta.startSceneId = meta.sceneOrder.first;
      changed = true;
    }
    if (changed) await storage.writeMeta(meta);
    await index.upsert(meta);
    await index.markOpened(id, DateTime.now());
    return Loaded(meta, recovered: loaded.recovered);
  }

  Future<void> saveMeta(ProjectMeta meta) async {
    meta.modifiedAt = DateTime.now();
    await storage.writeMeta(meta);
    await index.upsert(meta);
  }

  Future<ProjectMeta> rename(String id, String newName) async {
    final meta = (await storage.readMeta(id)).value;
    meta.name = validateName(newName);
    await saveMeta(meta);
    return meta;
  }

  Future<void> delete(String id) async {
    await storage.deleteProject(id);
    await index.remove(id);
  }

  /// Copies a project into a new independent project.
  Future<ProjectMeta> duplicate(String id, String newName) async {
    final cleanName = validateName(newName);
    final source = (await storage.readMeta(id)).value;
    final newProjectId = newId();
    final target = storage.projectDir(newProjectId);
    try {
      await SafeFile.copyDirectory(storage.projectDir(id), target);
      await _clearDir(Directory(p.join(target.path, '.recovery')));
      final now = DateTime.now();
      final meta = ProjectMeta(
        id: newProjectId,
        name: cleanName,
        template: source.template,
        createdAt: now,
        modifiedAt: now,
        startSceneId: source.startSceneId,
        sceneOrder: List.of(source.sceneOrder),
        settings: ProjectSettings.fromJson(source.settings.toJson()),
      );
      await storage.writeMeta(meta);
      await SafeFile.delete(File('${storage.metaFile(newProjectId).path}.bak'));
      await index.upsert(meta);
      return meta;
    } catch (_) {
      await storage.deleteProject(newProjectId);
      rethrow;
    }
  }

  // ---- scenes ----

  Future<Scene> createScene(ProjectMeta meta, String name) async {
    final scene = Scene(name: validateName(name));
    await storage.writeScene(meta.id, scene);
    meta.sceneOrder.add(scene.id);
    await saveMeta(meta);
    return scene;
  }

  Future<void> deleteScene(ProjectMeta meta, String sceneId) async {
    if (meta.sceneOrder.length <= 1) {
      throw ValidationException(ValidationError.lastScene);
    }
    meta.sceneOrder.remove(sceneId);
    if (meta.startSceneId == sceneId) meta.startSceneId = meta.sceneOrder.first;
    await saveMeta(meta);
    await storage.deleteScene(meta.id, sceneId);
  }

  /// Name of each scene in [meta.sceneOrder] (unreadable scenes are skipped).
  Future<Map<String, String>> sceneNames(ProjectMeta meta) async {
    final names = <String, String>{};
    for (final id in meta.sceneOrder) {
      try {
        names[id] = (await storage.readScene(meta.id, id)).value.name;
      } catch (_) {
        // Skipped; integrity issues are reported when the scene is opened.
      }
    }
    return names;
  }

  // ---- import / export ----

  /// Packs the project into a `.gfproj` (zip) archive. Recovery snapshots
  /// and backup files are not included.
  Future<Uint8List> exportPackage(String id) async {
    await storage.readMeta(id); // validates the project
    final dir = storage.projectDir(id);
    final archive = Archive();
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final rel = p.relative(e.path, from: dir.path).replaceAll('\\', '/');
      if (rel.startsWith('.recovery/') || rel.endsWith('.bak') || rel.endsWith('.tmp')) {
        continue;
      }
      final bytes = await e.readAsBytes();
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw DataFormatException('Could not create archive');
    return Uint8List.fromList(encoded);
  }

  /// Imports a `.gfproj` archive as a new project (always with a new id, so
  /// importing the same file twice never overwrites anything).
  Future<ProjectMeta> importPackage(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw ValidationException(ValidationError.invalidPackage);
    }
    ArchiveFile? metaEntry;
    for (final f in archive.files) {
      if (f.isFile && f.name == ProjectStorage.projectFileName) metaEntry = f;
    }
    if (metaEntry == null) throw ValidationException(ValidationError.invalidPackage);

    final Map<String, dynamic> metaJson;
    try {
      final decoded = jsonDecode(utf8.decode(metaEntry.content as List<int>));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      metaJson = decoded;
      ProjectMeta.fromJson(metaJson); // validate before touching the disk
    } on ValidationException {
      rethrow;
    } catch (_) {
      throw ValidationException(ValidationError.invalidPackage);
    }

    final newProjectId = newId();
    final target = storage.projectDir(newProjectId);
    try {
      await storage.createLayout(newProjectId);
      for (final f in archive.files) {
        if (!f.isFile || f.name == ProjectStorage.projectFileName) continue;
        final rel = f.name.replaceAll('\\', '/');
        // Reject absolute paths and path traversal ("zip slip").
        final parts = rel.split('/');
        if (rel.startsWith('/') || parts.contains('..') || p.isAbsolute(rel)) {
          throw ValidationException(ValidationError.invalidPackage);
        }
        final out = File(p.joinAll([target.path, ...parts]));
        if (!p.isWithin(target.path, out.path)) {
          throw ValidationException(ValidationError.invalidPackage);
        }
        await out.parent.create(recursive: true);
        await out.writeAsBytes(f.content as List<int>, flush: true);
      }
      metaJson['id'] = newProjectId;
      metaJson['modifiedAt'] = DateTime.now().toUtc().toIso8601String();
      final meta = ProjectMeta.fromJson(metaJson);
      await storage.writeMeta(meta);
      // Validates scenes and fixes the scene list.
      final opened = await openProject(newProjectId);
      for (final s in opened.value.sceneOrder) {
        await storage.readScene(newProjectId, s);
      }
      return opened.value;
    } catch (e) {
      await storage.deleteProject(newProjectId);
      if (e is ValidationException) rethrow;
      throw ValidationException(ValidationError.invalidPackage);
    }
  }

  Future<void> _clearDir(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final e in dir.list()) {
      await e.delete(recursive: true);
    }
  }
}
