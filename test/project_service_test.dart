import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameforge_studio/core/errors.dart';
import 'package:gameforge_studio/project/project_index.dart';
import 'package:gameforge_studio/project/project_meta.dart';
import 'package:gameforge_studio/project/project_storage.dart';

import 'test_helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() async => env.dispose());

  group('project creation', () {
    for (final template in ProjectTemplate.values) {
      test('creates and reopens ${template.name} template', () async {
        final meta = await env.service.createProject('Game ${template.name}', template);
        final dir = env.service.storage.projectDir(meta.id);
        for (final sub in ProjectStorage.subfolders) {
          expect(await Directory('${dir.path}/$sub').exists(), isTrue, reason: sub);
        }
        final opened = await env.service.openProject(meta.id);
        expect(opened.value.name, 'Game ${template.name}');
        expect(opened.value.template, template);
        final scene =
            await env.service.storage.readScene(meta.id, opened.value.startSceneId);
        expect(scene.value.objects, isNotEmpty);
      });
    }

    test('rejects invalid names', () async {
      for (final bad in ['   ', 'a/b', 'x' * 65]) {
        await expectLater(env.service.createProject(bad, ProjectTemplate.empty),
            throwsA(isA<ValidationException>()), reason: bad);
      }
      expect(await env.service.listProjects(), isEmpty);
    });

    test('projects are independent folders', () async {
      final a = await env.service.createProject('A', ProjectTemplate.empty);
      final b = await env.service.createProject('B', ProjectTemplate.empty);
      expect(a.id, isNot(b.id));
      await env.service.delete(a.id);
      expect(await env.service.storage.exists(b.id), isTrue);
    });
  });

  group('project management', () {
    test('rename, search, sort and recent', () async {
      final a = await env.service.createProject('Alpha', ProjectTemplate.empty);
      await env.service.createProject('Beta', ProjectTemplate.puzzle);
      await env.service.rename(a.id, 'Zeta');
      final byName = await env.service.listProjects(sort: ProjectSort.name);
      expect(byName.map((p) => p.name), ['Beta', 'Zeta']);
      final found = await env.service.listProjects(query: 'ze');
      expect(found.single.name, 'Zeta');
      expect(await env.service.listProjects(query: '%'), isEmpty);
      expect(await env.service.recentProjects(), isEmpty);
      await env.service.openProject(a.id);
      expect((await env.service.recentProjects()).single.id, a.id);
    });

    test('duplicate creates an independent copy', () async {
      final a = await env.service.createProject('Original', ProjectTemplate.platformer);
      final copy = await env.service.duplicate(a.id, 'Copy');
      expect(copy.id, isNot(a.id));
      expect(copy.sceneOrder, a.sceneOrder);
      final scene = (await env.service.storage.readScene(copy.id, copy.startSceneId)).value;
      scene.objects.clear();
      await env.service.storage.writeScene(copy.id, scene);
      final original = (await env.service.storage.readScene(a.id, a.startSceneId)).value;
      expect(original.objects, isNotEmpty);
      expect((await env.service.listProjects()).length, 2);
    });

    test('delete removes folder and index entry', () async {
      final a = await env.service.createProject('Gone', ProjectTemplate.empty);
      await env.service.delete(a.id);
      expect(await env.service.storage.exists(a.id), isFalse);
      expect(await env.service.listProjects(), isEmpty);
    });

    test('index is rebuilt from disk', () async {
      final a = await env.service.createProject('Disk', ProjectTemplate.empty);
      await env.index.remove(a.id);
      expect(await env.service.listProjects(), isEmpty);
      await env.service.syncIndexWithDisk();
      expect((await env.service.listProjects()).single.id, a.id);
      await env.service.storage.deleteProject(a.id);
      await env.service.syncIndexWithDisk();
      expect(await env.service.listProjects(), isEmpty);
    });

    test('settings are persisted', () async {
      final a = await env.service.createProject('Settings', ProjectTemplate.empty);
      final meta = (await env.service.openProject(a.id)).value;
      meta.settings.referenceWidth = 1920;
      meta.settings.orientation = ScreenOrientation.portrait;
      await env.service.saveMeta(meta);
      final again = (await env.service.openProject(a.id)).value;
      expect(again.settings.referenceWidth, 1920);
      expect(again.settings.orientation, ScreenOrientation.portrait);
    });
  });

  group('scenes', () {
    test('create and delete scenes, last scene protected', () async {
      final meta = await env.service.createProject('Scenes', ProjectTemplate.empty);
      final second = await env.service.createScene(meta, 'Level 2');
      expect(meta.sceneOrder.length, 2);
      final names = await env.service.sceneNames(meta);
      expect(names[second.id], 'Level 2');
      await env.service.deleteScene(meta, meta.startSceneId);
      expect(meta.startSceneId, second.id);
      await expectLater(env.service.deleteScene(meta, second.id),
          throwsA(isA<ValidationException>()));
    });

    test('scene list is repaired against disk on open', () async {
      final meta = await env.service.createProject('Repair', ProjectTemplate.empty);
      final orphan = await env.service.createScene(meta, 'Orphan');
      meta.sceneOrder.remove(orphan.id);
      meta.sceneOrder.add('does-not-exist');
      await env.service.storage.writeMeta(meta);
      final opened = (await env.service.openProject(meta.id)).value;
      expect(opened.sceneOrder, contains(orphan.id));
      expect(opened.sceneOrder, isNot(contains('does-not-exist')));
    });
  });

  group('recovery and integrity', () {
    test('corrupt project.json is restored from backup', () async {
      final meta = await env.service.createProject('Safe', ProjectTemplate.empty);
      await env.service.rename(meta.id, 'Safe 2'); // creates project.json.bak
      final file = env.service.storage.metaFile(meta.id);
      await file.writeAsString('{ this is not json');
      final opened = await env.service.openProject(meta.id);
      expect(opened.recovered, isTrue);
      expect(opened.value.id, meta.id);
      // The main file was repaired.
      expect(jsonDecode(await file.readAsString()), isA<Map>());
    });

    test('corrupt scene is restored from backup', () async {
      final meta = await env.service.createProject('SafeScene', ProjectTemplate.platformer);
      final storage = env.service.storage;
      final scene = (await storage.readScene(meta.id, meta.startSceneId)).value;
      await storage.writeScene(meta.id, scene); // creates .bak
      await storage.sceneFile(meta.id, scene.id).writeAsString('garbage');
      final loaded = await storage.readScene(meta.id, scene.id);
      expect(loaded.recovered, isTrue);
      expect(loaded.value.objects.length, scene.objects.length);
    });

    test('unreadable file without backup reports an error', () async {
      final meta = await env.service.createProject('Broken', ProjectTemplate.empty);
      final file = env.service.storage.metaFile(meta.id);
      await file.writeAsString('[]');
      await expectLater(env.service.openProject(meta.id), throwsA(isA<DataFormatException>()));
      final broken = await env.service.syncIndexWithDisk();
      expect(broken, contains(meta.id));
    });

    test('newer format version is refused, not overwritten', () async {
      final meta = await env.service.createProject('Future', ProjectTemplate.empty);
      final file = env.service.storage.metaFile(meta.id);
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json['formatVersion'] = 99;
      await file.writeAsString(jsonEncode(json));
      await expectLater(
          env.service.openProject(meta.id), throwsA(isA<ValidationException>()));
      final after = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(after['formatVersion'], 99);
    });

    test('recovery snapshots are written and cleared', () async {
      final meta = await env.service.createProject('Snap', ProjectTemplate.empty);
      final storage = env.service.storage;
      final scene = (await storage.readScene(meta.id, meta.startSceneId)).value;
      scene.name = 'Unsaved';
      await storage.writeRecovery(meta.id, scene);
      expect((await storage.readRecovery(meta.id, scene.id))!.name, 'Unsaved');
      await storage.clearRecovery(meta.id, scene.id);
      expect(await storage.readRecovery(meta.id, scene.id), isNull);
    });
  });

  group('import / export', () {
    test('export then import gives an equal, independent project', () async {
      final meta = await env.service.createProject('Packed', ProjectTemplate.rpg);
      final bytes = await env.service.exportPackage(meta.id);
      final imported = await env.service.importPackage(bytes);
      expect(imported.id, isNot(meta.id));
      expect(imported.name, 'Packed');
      expect(imported.sceneOrder, meta.sceneOrder);
      final a = (await env.service.storage.readScene(meta.id, meta.startSceneId)).value;
      final b = (await env.service.storage.readScene(imported.id, imported.startSceneId)).value;
      expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
      expect((await env.service.listProjects()).length, 2);
    });

    test('rejects files that are not projects', () async {
      await expectLater(env.service.importPackage(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<ValidationException>()));
      final archive = Archive()..addFile(ArchiveFile('readme.txt', 2, utf8.encode('hi')));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive)!);
      await expectLater(env.service.importPackage(zip), throwsA(isA<ValidationException>()));
    });

    test('rejects path traversal (zip slip) and leaves nothing behind', () async {
      final meta = await env.service.createProject('Evil', ProjectTemplate.empty);
      final good = await env.service.exportPackage(meta.id);
      final archive = ZipDecoder().decodeBytes(good);
      final evil = Archive();
      for (final f in archive.files) {
        evil.addFile(f);
      }
      evil.addFile(ArchiveFile('../../escaped.txt', 4, utf8.encode('evil')));
      final zip = Uint8List.fromList(ZipEncoder().encode(evil)!);
      final before = await env.service.storage.listProjectIds();
      await expectLater(env.service.importPackage(zip), throwsA(isA<ValidationException>()));
      expect(await env.service.storage.listProjectIds(), before);
      expect(await File('${env.dir.path}/escaped.txt').exists(), isFalse);
    });
  });
}
