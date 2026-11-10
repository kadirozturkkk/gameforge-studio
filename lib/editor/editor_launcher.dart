import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../dashboard/dialogs.dart';
import '../project/project_meta.dart';
import '../project/project_service.dart';
import 'editor_controller.dart';
import 'editor_screen.dart';

/// Opens a project and shows its start scene in the editor.
Future<void> openProjectInEditor(BuildContext context, String projectId) async {
  final service = context.read<ProjectService>();
  final s = context.sRead;
  final loaded = await service.openProject(projectId);
  if (!context.mounted) return;
  if (loaded.recovered) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.projectRecovered)));
  }
  final meta = loaded.value;
  final controller = await loadSceneController(context, meta, meta.startSceneId);
  if (controller == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EditorScreen(initialController: controller),
  ));
}

/// Loads a scene into a new [EditorController]. If an unsaved recovery
/// snapshot exists, asks whether to restore it.
Future<EditorController?> loadSceneController(
    BuildContext context, ProjectMeta meta, String sceneId) async {
  final service = context.read<ProjectService>();
  final s = context.sRead;
  final storage = service.storage;
  final loaded = await storage.readScene(meta.id, sceneId);
  var scene = loaded.value;
  var restored = false;
  final recovery = await storage.readRecovery(meta.id, sceneId);
  if (recovery != null && context.mounted) {
    final restore = await showConfirmDialog(context,
        title: s.recoveryTitle, body: s.recoveryBody, confirm: s.restore);
    if (restore) {
      scene = recovery;
      restored = true;
    } else {
      await storage.clearRecovery(meta.id, sceneId);
    }
  }
  if (loaded.recovered && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.projectRecovered)));
  }
  return EditorController(
    project: meta,
    scene: scene,
    storage: storage,
    startDirty: restored,
  );
}
