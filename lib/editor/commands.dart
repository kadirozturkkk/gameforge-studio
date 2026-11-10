import '../engine/scene/game_object.dart';
import '../engine/scene/scene.dart';

/// A reversible edit of a scene. All editor changes go through commands so
/// they can be undone and redone.
abstract class EditorCommand {
  void apply(Scene scene);
  void revert(Scene scene);
}

/// Inserts objects at given list positions. Its inverse is [RemoveObjectsCommand].
class AddObjectsCommand extends EditorCommand {
  /// Pairs of (index in scene list, object). Indices refer to the final list.
  AddObjectsCommand(List<(int, GameObject)> entries)
      : entries = [for (final e in entries) (e.$1, e.$2.toJson())];

  final List<(int, Map<String, dynamic>)> entries;

  List<String> get ids => [for (final e in entries) e.$2['id'] as String];

  @override
  void apply(Scene scene) {
    final sorted = [...entries]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (index, json) in sorted) {
      final obj = GameObject.fromJson(json);
      scene.objects.insert(index.clamp(0, scene.objects.length).toInt(), obj);
    }
  }

  @override
  void revert(Scene scene) {
    final remove = ids.toSet();
    scene.objects.removeWhere((o) => remove.contains(o.id));
  }
}

/// Removes objects (callers include descendants) and remembers their
/// positions so undo restores the exact same order.
class RemoveObjectsCommand extends EditorCommand {
  RemoveObjectsCommand(Scene scene, Iterable<String> ids) {
    final set = ids.toSet();
    for (var i = 0; i < scene.objects.length; i++) {
      final o = scene.objects[i];
      if (set.contains(o.id)) _removed.add((i, o.toJson()));
    }
  }

  final List<(int, Map<String, dynamic>)> _removed = [];

  bool get isEmpty => _removed.isEmpty;

  @override
  void apply(Scene scene) {
    final set = {for (final r in _removed) r.$2['id'] as String};
    scene.objects.removeWhere((o) => set.contains(o.id));
  }

  @override
  void revert(Scene scene) {
    for (final (index, json) in _removed) {
      scene.objects.insert(index.clamp(0, scene.objects.length).toInt(), GameObject.fromJson(json));
    }
  }
}

/// Replaces objects with new versions (used for every property edit:
/// moving, renaming, changing components...). Stores full before/after
/// snapshots, which keeps undo simple and always correct.
class ReplaceObjectsCommand extends EditorCommand {
  ReplaceObjectsCommand(this.before, this.after);

  final Map<String, Map<String, dynamic>> before;
  final Map<String, Map<String, dynamic>> after;

  void _write(Scene scene, Map<String, Map<String, dynamic>> data) {
    data.forEach((id, json) {
      final i = scene.indexOf(id);
      if (i >= 0) scene.objects[i] = GameObject.fromJson(json);
    });
  }

  @override
  void apply(Scene scene) => _write(scene, after);

  @override
  void revert(Scene scene) => _write(scene, before);
}

/// Scene-level settings (name, background colour).
class SceneSettingsCommand extends EditorCommand {
  SceneSettingsCommand(
      {required this.oldName,
      required this.newName,
      required this.oldColor,
      required this.newColor});

  final String oldName, newName;
  final int oldColor, newColor;

  @override
  void apply(Scene scene) {
    scene.name = newName;
    scene.backgroundColor = newColor;
  }

  @override
  void revert(Scene scene) {
    scene.name = oldName;
    scene.backgroundColor = oldColor;
  }
}
