import 'package:flutter_test/flutter_test.dart';
import 'package:gameforge_studio/editor/editor_controller.dart';
import 'package:gameforge_studio/engine/math/vec2.dart';
import 'package:gameforge_studio/engine/scene/game_object.dart';
import 'package:gameforge_studio/engine/scene/presets.dart';
import 'package:gameforge_studio/project/project_meta.dart';

import 'test_helpers.dart';

void main() {
  late TestEnv env;
  late ProjectMeta meta;
  late EditorController c;

  setUp(() async {
    env = await TestEnv.create();
    meta = await env.service.createProject('Editor', ProjectTemplate.empty);
    final scene = (await env.service.storage.readScene(meta.id, meta.startSceneId)).value;
    c = EditorController(
      project: meta,
      scene: scene,
      storage: env.service.storage,
      enableRecoverySnapshots: false,
    );
  });

  tearDown(() async {
    c.dispose();
    await env.dispose();
  });

  int count() => c.scene.objects.length;

  test('add, undo, redo', () {
    final start = count();
    final o = c.addObject(ObjectPreset.character, 'Player');
    expect(count(), start + 1);
    expect(c.selection, {o.id});
    expect(c.isDirty, isTrue);
    c.undo();
    expect(count(), start);
    expect(c.selection, isEmpty);
    expect(c.isDirty, isFalse);
    c.redo();
    expect(count(), start + 1);
    expect(c.scene.find(o.id)!.name, 'Player');
  });

  test('names are made unique', () {
    c.addObject(ObjectPreset.enemy, 'Enemy');
    final second = c.addObject(ObjectPreset.enemy, 'Enemy');
    final third = c.addObject(ObjectPreset.enemy, 'Enemy');
    expect(second.name, 'Enemy (1)');
    expect(third.name, 'Enemy (2)');
  });

  test('delete removes children and undo restores order', () {
    final a = c.addObject(ObjectPreset.sprite, 'A');
    final b = c.addObject(ObjectPreset.sprite, 'B');
    final child = c.addObject(ObjectPreset.sprite, 'Child');
    c.setParent(child.id, a.id);
    final order = c.scene.objects.map((o) => o.id).toList();
    c.select(a.id);
    c.deleteSelection();
    expect(c.scene.find(a.id), isNull);
    expect(c.scene.find(child.id), isNull);
    expect(c.scene.find(b.id), isNotNull);
    c.undo();
    expect(c.scene.objects.map((o) => o.id).toList(), order);
    expect(c.scene.find(child.id)!.parentId, a.id);
  });

  test('copy & paste create new ids and keep internal parenting', () {
    final a = c.addObject(ObjectPreset.sprite, 'A');
    final child = c.addObject(ObjectPreset.sprite, 'Child');
    c.setParent(child.id, a.id);
    c.select(a.id);
    c.copySelection();
    final before = count();
    c.paste();
    expect(count(), before + 2);
    final pastedRoot = c.scene.find(c.selection.single)!;
    expect(pastedRoot.id, isNot(a.id));
    expect(pastedRoot.parentId, isNull);
    final pastedChild = c.scene.objects.firstWhere((o) => o.parentId == pastedRoot.id);
    expect(pastedChild.id, isNot(child.id));
    expect(pastedRoot.transform.position, a.transform.position + Vec2(c.gridSize, c.gridSize));
    c.undo();
    expect(count(), before);
  });

  test('duplicate', () {
    final a = c.addObject(ObjectPreset.platform, 'Ground');
    c.select(a.id);
    c.duplicateSelection();
    final copy = c.scene.find(c.selection.single)!;
    expect(copy.id, isNot(a.id));
    expect(copy.name, 'Ground (1)');
  });

  test('editObjects is one undo step and ignores no-op edits', () {
    final a = c.addObject(ObjectPreset.sprite, 'A');
    c.editObject(a.id, (o) => o.transform.rotation = 45);
    expect(c.scene.find(a.id)!.transform.rotation, 45);
    c.editObject(a.id, (o) => o.transform.rotation = 45); // no change
    c.undo();
    expect(c.scene.find(a.id)!.transform.rotation, 0);
    c.undo();
    expect(c.scene.find(a.id), isNull);
  });

  test('drag moves selection as a single undo step, with snapping', () {
    final a = c.addObject(ObjectPreset.sprite, 'A');
    c.select(a.id);
    c.beginDrag();
    c.updateDrag(const Vec2(10, 0));
    c.updateDrag(const Vec2(10, 5));
    c.endDrag();
    expect(c.scene.find(a.id)!.transform.position, const Vec2(20, 5));
    c.toggleSnap();
    c.beginDrag();
    c.updateDrag(const Vec2(20, 20));
    c.endDrag();
    expect(c.scene.find(a.id)!.transform.position, const Vec2(32, 32));
    c.undo();
    expect(c.scene.find(a.id)!.transform.position, const Vec2(20, 5));
    c.undo();
    expect(c.scene.find(a.id)!.transform.position, Vec2.zero);
  });

  test('dragging a child respects parent rotation', () {
    final parent = c.addObject(ObjectPreset.empty, 'P');
    c.editObject(parent.id, (o) => o.transform.rotation = 90);
    final child = c.addObject(ObjectPreset.sprite, 'C');
    c.setParent(child.id, parent.id);
    c.select(child.id);
    c.beginDrag();
    c.updateDrag(const Vec2(0, 10)); // down in world = +x in parent space
    c.endDrag();
    final local = c.scene.find(child.id)!.transform.position;
    expect(local.x, closeTo(10, 1e-6));
    expect(local.y, closeTo(0, 1e-6));
  });

  test('setParent keeps world position and refuses cycles', () {
    final a = c.addObject(ObjectPreset.empty, 'A');
    c.editObject(a.id, (o) => o.transform.position = const Vec2(100, 100));
    final b = c.addObject(ObjectPreset.sprite, 'B');
    c.editObject(b.id, (o) => o.transform.position = const Vec2(150, 100));
    c.setParent(b.id, a.id);
    final bo = c.scene.find(b.id)!;
    expect(bo.transform.position, const Vec2(50, 0));
    final world = c.scene.worldMatrix(bo).transformPoint(Vec2.zero);
    expect(world, const Vec2(150, 100));
    c.setParent(a.id, b.id); // cycle
    expect(c.scene.find(a.id)!.parentId, isNull);
  });

  test('hit testing picks the top-most object', () {
    final back = c.addObject(ObjectPreset.platform, 'Back');
    final front = c.addObject(ObjectPreset.character, 'Front'); // higher sorting order
    expect(c.hitTest(Vec2.zero)!.id, front.id);
    expect(c.hitTest(const Vec2(100, 0))!.id, back.id);
    expect(c.hitTest(const Vec2(1000, 1000)), isNull);
    c.editObject(front.id, (o) => o.active = false);
    expect(c.hitTest(Vec2.zero)!.id, back.id);
  });

  test('save writes to disk and clears dirty state', () async {
    final o = c.addObject(ObjectPreset.enemy, 'Saved Enemy');
    expect(c.isDirty, isTrue);
    expect(await c.save(), isTrue);
    expect(c.isDirty, isFalse);
    final reloaded = (await env.service.storage.readScene(meta.id, c.scene.id)).value;
    expect(reloaded.find(o.id)!.name, 'Saved Enemy');
    c.undo();
    expect(c.isDirty, isTrue);
    c.redo();
    expect(c.isDirty, isFalse);
  });

  test('recovery snapshot holds unsaved work', () async {
    final rc = EditorController(
      project: meta,
      scene: c.scene.clone(),
      storage: env.service.storage,
      recoveryDelay: const Duration(milliseconds: 1),
    );
    final o = rc.addObject(ObjectPreset.sprite, 'Unsaved');
    await rc.writeRecoveryNow();
    final snap = await env.service.storage.readRecovery(meta.id, rc.scene.id);
    expect(snap!.find(o.id), isNotNull);
    await rc.save();
    expect(await env.service.storage.readRecovery(meta.id, rc.scene.id), isNull);
    rc.dispose();
  });

  test('frame fits selection', () {
    final a = c.addObject(ObjectPreset.platform, 'Wide');
    c.editObject(a.id, (o) => o.transform.position = const Vec2(500, 300));
    c.select(a.id);
    c.frame(800, 600);
    expect(c.viewCenter, const Vec2(500, 300));
    expect(c.zoom, greaterThan(0));
  });

  test('cameras are only picked near their centre', () {
    final cam = c.scene.objects.firstWhere((GameObject o) => o.kind == 'camera');
    expect(c.hitTest(cam.transform.position)!.id, cam.id);
    expect(c.hitTest(cam.transform.position + const Vec2(300, 0)), isNull);
  });
}
