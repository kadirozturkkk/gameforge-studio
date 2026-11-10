import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameforge_studio/app/app.dart';
import 'package:gameforge_studio/app/app_settings.dart';
import 'package:gameforge_studio/editor/editor_controller.dart';
import 'package:gameforge_studio/editor/editor_screen.dart';
import 'package:gameforge_studio/engine/scene/presets.dart';
import 'package:gameforge_studio/l10n/strings.dart';
import 'package:gameforge_studio/project/project_meta.dart';
import 'package:gameforge_studio/project/project_service.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

void main() {
  // Real file and database I/O must run outside the fake-async test zone.
  late TestEnv env;

  Future<void> setUpEnv(WidgetTester tester) async {
    // Temporary folders are left to the OS; CI machines are discarded.
    await tester.runAsync(() async => env = await TestEnv.create());
  }

  testWidgets('dashboard shows templates in Turkish and English', (tester) async {
    await setUpEnv(tester);
    final settings = AppSettings.memory(AppLanguage.tr);
    await tester.runAsync(() async {
      await tester.pumpWidget(GameForgeApp(service: env.service, settings: settings));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('GameForge Studio'), findsWidgets);
    expect(find.text('2D Platform'), findsOneWidget);
    expect(find.text('Yeni Proje'), findsOneWidget);

    await settings.setLanguage(AppLanguage.en);
    await tester.pump();
    expect(find.text('2D Platformer'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
  });

  testWidgets('dashboard lists existing projects', (tester) async {
    await setUpEnv(tester);
    await tester.runAsync(() async {
      await env.service.createProject('Listed Game', ProjectTemplate.puzzle);
      await tester.pumpWidget(
          GameForgeApp(service: env.service, settings: AppSettings.memory(AppLanguage.en)));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('Listed Game'), findsOneWidget);
  });

  Future<EditorController> openEditor(WidgetTester tester, {required Size size}) async {
    await setUpEnv(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late EditorController controller;
    await tester.runAsync(() async {
      final meta = await env.service.createProject('Edit Me', ProjectTemplate.empty);
      final scene = (await env.service.storage.readScene(meta.id, meta.startSceneId)).value;
      controller = EditorController(
        project: meta,
        scene: scene,
        storage: env.service.storage,
        enableRecoverySnapshots: false,
      );
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ProjectService>.value(value: env.service),
        ChangeNotifierProvider<AppSettings>.value(value: AppSettings.memory(AppLanguage.en)),
      ],
      child: MaterialApp(home: EditorScreen(initialController: controller)),
    ));
    await tester.pump();
    return controller;
  }

  testWidgets('editor: add object from menu, undo and redo (phone layout)', (tester) async {
    final c = await openEditor(tester, size: const Size(420, 860));
    final start = c.scene.objects.length;

    await tester.tap(find.byKey(const ValueKey('editor_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_character')));
    await tester.pumpAndSettle();
    expect(c.scene.objects.length, start + 1);
    expect(find.text('Player'), findsWidgets); // shown in hierarchy

    await tester.tap(find.byKey(const ValueKey('editor_undo')));
    await tester.pump();
    expect(c.scene.objects.length, start);

    await tester.tap(find.byKey(const ValueKey('editor_redo')));
    await tester.pump();
    expect(c.scene.objects.length, start + 1);
  });

  testWidgets('editor: tap selects in viewport, inspector edits position (tablet layout)',
      (tester) async {
    final c = await openEditor(tester, size: const Size(1280, 800));
    final o = c.addObject(ObjectPreset.platform, 'Ground');
    c.select(null);
    await tester.pump();

    // The object sits at the viewport centre.
    final viewport = find.byKey(const ValueKey('scene_viewport_paint'));
    await tester.tapAt(tester.getCenter(viewport));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.selection, {o.id});

    final xField = find.descendant(
        of: find.byKey(const ValueKey('inspector_pos_x')), matching: find.byType(TextField));
    await tester.enterText(xField, '128');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.scene.find(o.id)!.transform.position.x, 128);
  });

  testWidgets('editor: drag in viewport moves the selected object', (tester) async {
    final c = await openEditor(tester, size: const Size(1280, 800));
    final o = c.addObject(ObjectPreset.platform, 'Ground');
    await tester.pump();
    final viewport = find.byKey(const ValueKey('scene_viewport_paint'));
    await tester.dragFrom(tester.getCenter(viewport), const Offset(60, 0));
    await tester.pumpAndSettle();
    final x = c.scene.find(o.id)!.transform.position.x;
    expect(x, greaterThan(0));
    expect(c.canUndo, isTrue);
  });
}
