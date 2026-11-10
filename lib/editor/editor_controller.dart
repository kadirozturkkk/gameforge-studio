import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../engine/components/sprite_renderer.dart';
import '../engine/math/vec2.dart';
import '../engine/scene/game_object.dart';
import '../engine/scene/presets.dart';
import '../engine/scene/scene.dart';
import '../project/project_meta.dart';
import '../project/project_storage.dart';
import 'commands.dart';

enum EditorTool { select, move }

/// State and operations of the scene editor. UI widgets only call methods
/// here; every scene change becomes an [EditorCommand].
class EditorController extends ChangeNotifier {
  EditorController({
    required this.project,
    required Scene scene,
    required this.storage,
    this.recoveryDelay = const Duration(seconds: 2),
    this.enableRecoverySnapshots = true,
    bool startDirty = false,
  }) : _scene = scene {
    _forceDirty = startDirty;
  }

  final ProjectMeta project;
  final ProjectStorage storage;
  final Duration recoveryDelay;
  final bool enableRecoverySnapshots;

  Scene _scene;
  Scene get scene => _scene;

  // ---- view state ----
  Vec2 viewCenter = Vec2.zero;
  double zoom = 0.6;
  static const minZoom = 0.05;
  static const maxZoom = 8.0;
  bool showGrid = true;
  bool snapToGrid = false;
  double gridSize = 32;
  EditorTool tool = EditorTool.move;

  // ---- selection ----
  final Set<String> _selection = {};
  Set<String> get selection => Set.unmodifiable(_selection);
  GameObject? get primarySelection =>
      _selection.isEmpty ? null : _scene.find(_selection.last);

  // ---- history ----
  final List<EditorCommand> _undo = [];
  final List<EditorCommand> _redo = [];
  static const maxHistory = 200;
  // Dirty tracking: the command on top of the undo stack when last saved.
  EditorCommand? _savedTop;
  bool _forceDirty = false;

  EditorCommand? get _top => _undo.isEmpty ? null : _undo.last;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isDirty => _forceDirty || !identical(_top, _savedTop);

  // ---- clipboard (shared across editor sessions of this app run) ----
  static List<Map<String, dynamic>> _clipboard = [];
  bool get canPaste => _clipboard.isNotEmpty;

  Timer? _recoveryTimer;
  bool _disposed = false;
  Object? lastSaveError;

  // =================================================================
  // Commands & history
  // =================================================================

  void execute(EditorCommand command) {
    command.apply(_scene);
    _undo.add(command);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    _changed();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final c = _undo.removeLast();
    c.revert(_scene);
    _redo.add(c);
    _pruneSelection();
    _changed();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final c = _redo.removeLast();
    c.apply(_scene);
    _undo.add(c);
    _pruneSelection();
    _changed();
  }

  void _changed() {
    _scheduleRecovery();
    notifyListeners();
  }

  void _pruneSelection() {
    _selection.removeWhere((id) => _scene.find(id) == null);
  }

  // =================================================================
  // Selection
  // =================================================================

  void select(String? id, {bool additive = false}) {
    if (!additive) _selection.clear();
    if (id != null) {
      if (additive && _selection.contains(id)) {
        _selection.remove(id);
      } else {
        _selection.remove(id);
        _selection.add(id);
      }
    }
    notifyListeners();
  }

  void selectAll() {
    _selection
      ..clear()
      ..addAll(_scene.objects.map((o) => o.id));
    notifyListeners();
  }

  bool isSelected(String id) => _selection.contains(id);

  /// Selected objects without those whose ancestor is also selected
  /// (moving a parent already moves its children).
  List<GameObject> get selectionRoots {
    final result = <GameObject>[];
    for (final id in _selection) {
      final o = _scene.find(id);
      if (o == null) continue;
      var covered = false;
      var parent = o.parentId;
      while (parent != null) {
        if (_selection.contains(parent)) {
          covered = true;
          break;
        }
        parent = _scene.find(parent)?.parentId;
      }
      if (!covered) result.add(o);
    }
    return result;
  }

  // =================================================================
  // Object operations
  // =================================================================

  GameObject addObject(ObjectPreset preset, String name) {
    var pos = viewCenter;
    if (snapToGrid) pos = pos.snapped(gridSize);
    final obj = ObjectPresets.create(preset, name: _uniqueName(name), position: pos);
    execute(AddObjectsCommand([(_scene.objects.length, obj)]));
    select(obj.id);
    return obj;
  }

  void deleteSelection() {
    if (_selection.isEmpty) return;
    final ids = <String>{};
    for (final id in _selection) {
      ids.addAll(_scene.subtree(id).map((o) => o.id));
    }
    final cmd = RemoveObjectsCommand(_scene, ids);
    if (cmd.isEmpty) return;
    _selection.clear();
    execute(cmd);
  }

  void copySelection() {
    final roots = selectionRoots;
    if (roots.isEmpty) return;
    final out = <Map<String, dynamic>>[];
    for (final r in roots) {
      out.addAll(_scene.subtree(r.id).map((o) => o.toJson()));
    }
    _clipboard = out;
    notifyListeners();
  }

  void paste() => _insertCopies(_clipboard, offset: Vec2(gridSize, gridSize));

  void duplicateSelection() {
    final roots = selectionRoots;
    if (roots.isEmpty) return;
    final data = <Map<String, dynamic>>[];
    for (final r in roots) {
      data.addAll(_scene.subtree(r.id).map((o) => o.toJson()));
    }
    _insertCopies(data, offset: Vec2(gridSize, gridSize));
  }

  /// Inserts copies of serialized objects with fresh ids, keeping their
  /// internal parent links. Roots keep their parent if it still exists.
  void _insertCopies(List<Map<String, dynamic>> data, {required Vec2 offset}) {
    if (data.isEmpty) return;
    final idMap = <String, String>{};
    final copies = <GameObject>[];
    for (final json in data) {
      final copy = GameObject.fromJson(json).clone(newIdentity: true);
      idMap[json['id'] as String] = copy.id;
      copies.add(copy);
    }
    final rootIds = <String>[];
    for (final c in copies) {
      final oldParent = c.parentId;
      if (oldParent != null && idMap.containsKey(oldParent)) {
        c.parentId = idMap[oldParent];
      } else {
        if (oldParent != null && _scene.find(oldParent) == null) c.parentId = null;
        c.transform.position = c.transform.position + offset;
        c.name = _uniqueName(c.name);
        rootIds.add(c.id);
      }
    }
    var index = _scene.objects.length;
    execute(AddObjectsCommand([for (final c in copies) (index++, c)]));
    _selection
      ..clear()
      ..addAll(rootIds);
    notifyListeners();
  }

  /// Applies [mutate] to copies of the given objects and records the change
  /// as one undoable step. No-op if nothing actually changed.
  void editObjects(Iterable<String> ids, void Function(GameObject o) mutate) {
    final before = <String, Map<String, dynamic>>{};
    final after = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      final o = _scene.find(id);
      if (o == null) continue;
      final b = o.toJson();
      final copy = GameObject.fromJson(b);
      mutate(copy);
      final a = copy.toJson();
      if (jsonEncode(b) != jsonEncode(a)) {
        before[id] = b;
        after[id] = a;
      }
    }
    if (after.isEmpty) return;
    execute(ReplaceObjectsCommand(before, after));
  }

  void editObject(String id, void Function(GameObject o) mutate) =>
      editObjects([id], mutate);

  void setParent(String childId, String? parentId) {
    final child = _scene.find(childId);
    if (child == null) return;
    if (parentId != null && _scene.isInSubtree(parentId, childId)) return;
    // Keep the world position unchanged when re-parenting.
    final world = _scene.worldMatrix(child).transformPoint(Vec2.zero);
    final newParent = parentId == null ? null : _scene.find(parentId);
    final parentWorld =
        newParent == null ? null : _scene.worldMatrix(newParent).inverse();
    editObject(childId, (o) {
      o.parentId = parentId;
      o.transform.position =
          parentWorld == null ? world : parentWorld.transformPoint(world);
    });
  }

  void updateSceneSettings({String? name, int? backgroundColor}) {
    final newName = name?.trim().isNotEmpty == true ? name!.trim() : _scene.name;
    final newColor = backgroundColor ?? _scene.backgroundColor;
    if (newName == _scene.name && newColor == _scene.backgroundColor) return;
    execute(SceneSettingsCommand(
        oldName: _scene.name,
        newName: newName,
        oldColor: _scene.backgroundColor,
        newColor: newColor));
  }

  // =================================================================
  // Dragging (live preview, single undo step on release)
  // =================================================================

  Map<String, Map<String, dynamic>>? _dragBefore;
  Map<String, Vec2>? _dragStartLocal;
  Vec2 _dragTotal = Vec2.zero;

  bool get isDragging => _dragBefore != null;

  void beginDrag() {
    final roots = selectionRoots;
    if (roots.isEmpty) return;
    _dragBefore = {for (final o in roots) o.id: o.toJson()};
    _dragStartLocal = {for (final o in roots) o.id: o.transform.position};
    _dragTotal = Vec2.zero;
  }

  /// [worldDelta] is the pointer movement since the last update, in world units.
  void updateDrag(Vec2 worldDelta) {
    final start = _dragStartLocal;
    if (start == null) return;
    _dragTotal = _dragTotal + worldDelta;
    start.forEach((id, startPos) {
      final o = _scene.find(id);
      if (o == null) return;
      final parentInv = _scene.parentWorldMatrix(o).inverse();
      final localDelta =
          parentInv == null ? _dragTotal : parentInv.transformVector(_dragTotal);
      var p = startPos + localDelta;
      if (snapToGrid) p = p.snapped(gridSize);
      o.transform.position = p;
    });
    notifyListeners();
  }

  void endDrag() {
    final before = _dragBefore;
    _dragBefore = null;
    _dragStartLocal = null;
    if (before == null) return;
    final after = <String, Map<String, dynamic>>{};
    before.forEach((id, _) {
      final o = _scene.find(id);
      if (o != null) after[id] = o.toJson();
    });
    final moved = after.entries
        .any((e) => jsonEncode(e.value) != jsonEncode(before[e.key]));
    if (!moved) return;
    // The live drag already changed the scene; record without re-applying.
    final cmd = ReplaceObjectsCommand(before, after);
    _undo.add(cmd);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    _changed();
  }

  // =================================================================
  // View
  // =================================================================

  void setView({Vec2? center, double? zoom}) {
    if (center != null) viewCenter = center;
    if (zoom != null) this.zoom = zoom.clamp(minZoom, maxZoom).toDouble();
    notifyListeners();
  }

  void zoomBy(double factor) => setView(zoom: zoom * factor);

  void toggleGrid() {
    showGrid = !showGrid;
    notifyListeners();
  }

  void toggleSnap() {
    snapToGrid = !snapToGrid;
    notifyListeners();
  }

  void setTool(EditorTool t) {
    tool = t;
    notifyListeners();
  }

  /// Centres the view on the selection (or the whole scene) and picks a
  /// zoom that fits it into [viewportSize].
  void frame(double viewportWidth, double viewportHeight) {
    final targets = _selection.isNotEmpty
        ? _selection.map(_scene.find).whereType<GameObject>().toList()
        : _scene.objects;
    if (targets.isEmpty) {
      setView(center: Vec2.zero, zoom: 0.6);
      return;
    }
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final o in targets) {
      for (final c in worldCorners(o)) {
        if (c.x < minX) minX = c.x;
        if (c.y < minY) minY = c.y;
        if (c.x > maxX) maxX = c.x;
        if (c.y > maxY) maxY = c.y;
      }
    }
    final w = (maxX - minX).clamp(64.0, double.infinity).toDouble();
    final h = (maxY - minY).clamp(64.0, double.infinity).toDouble();
    final z = (viewportWidth / (w * 1.2)).clamp(minZoom, maxZoom).toDouble();
    final z2 = (viewportHeight / (h * 1.2)).clamp(minZoom, maxZoom).toDouble();
    setView(center: Vec2((minX + maxX) / 2, (minY + maxY) / 2), zoom: z < z2 ? z : z2);
  }

  // =================================================================
  // Geometry helpers (shared by painter and hit testing)
  // =================================================================

  /// Local-space size used for drawing and picking.
  Vec2 localSize(GameObject o) {
    final r = o.getComponent<SpriteRenderer>();
    if (r != null) return r.size;
    if (o.kind == ObjectPreset.camera.name) {
      return Vec2(project.settings.referenceWidth.toDouble(),
          project.settings.referenceHeight.toDouble());
    }
    return const Vec2(32, 32);
  }

  List<Vec2> worldCorners(GameObject o) {
    final m = _scene.worldMatrix(o);
    final s = localSize(o);
    final hx = s.x / 2, hy = s.y / 2;
    return [
      m.transformPoint(Vec2(-hx, -hy)),
      m.transformPoint(Vec2(hx, -hy)),
      m.transformPoint(Vec2(hx, hy)),
      m.transformPoint(Vec2(-hx, hy)),
    ];
  }

  /// Objects in the order they are drawn (back to front).
  List<GameObject> get drawOrder {
    final indexed = <(int, GameObject)>[];
    for (var i = 0; i < _scene.objects.length; i++) {
      final o = _scene.objects[i];
      if (_scene.isActiveInHierarchy(o)) indexed.add((i, o));
    }
    int order(GameObject o) => o.getComponent<SpriteRenderer>()?.sortingOrder ?? 1000;
    indexed.sort((a, b) {
      final c = order(a.$2).compareTo(order(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Top-most visible object under [world], or null. Cameras are only
  /// picked near their centre so they do not block everything behind them.
  GameObject? hitTest(Vec2 world) {
    final ordered = drawOrder.reversed.toList();
    // Regular objects first, cameras only if nothing else was hit.
    for (final camerasPass in [false, true]) {
      for (final o in ordered) {
        final isCamera = o.kind == ObjectPreset.camera.name;
        if (isCamera != camerasPass) continue;
        final inv = _scene.worldMatrix(o).inverse();
        if (inv == null) continue;
        final local = inv.transformPoint(world);
        final s = isCamera ? const Vec2(48, 48) : localSize(o);
        if (local.x.abs() <= s.x / 2 && local.y.abs() <= s.y / 2) return o;
      }
    }
    return null;
  }

  // =================================================================
  // Saving & recovery
  // =================================================================

  Future<bool> save() async {
    try {
      final snapshot = _scene.clone();
      final topAtSave = _top;
      await storage.writeScene(project.id, snapshot);
      project.modifiedAt = DateTime.now();
      await storage.writeMeta(project);
      await storage.clearRecovery(project.id, snapshot.id);
      _savedTop = topAtSave;
      _forceDirty = false;
      lastSaveError = null;
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      lastSaveError = e;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  void _scheduleRecovery() {
    if (!enableRecoverySnapshots) return;
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(recoveryDelay, writeRecoveryNow);
  }

  /// Writes an unsaved-changes snapshot used after a crash or forced close.
  Future<void> writeRecoveryNow() async {
    _recoveryTimer?.cancel();
    if (!isDirty || !enableRecoverySnapshots) return;
    try {
      await storage.writeRecovery(project.id, _scene.clone());
    } catch (_) {
      // Snapshots are best effort; real saves report errors.
    }
  }

  /// Throws away unsaved changes (also their recovery snapshot).
  Future<void> discardChanges() async {
    _recoveryTimer?.cancel();
    await storage.clearRecovery(project.id, _scene.id);
    _savedTop = _top;
    _forceDirty = false;
  }

  // =================================================================

  String _uniqueName(String base) {
    final names = _scene.objects.map((o) => o.name).toSet();
    if (!names.contains(base)) return base;
    final stem = base.replaceFirst(RegExp(r' \(\d+\)$'), '');
    var i = 1;
    while (names.contains('$stem ($i)')) {
      i++;
    }
    return '$stem ($i)';
  }

  @override
  void dispose() {
    _disposed = true;
    _recoveryTimer?.cancel();
    super.dispose();
  }
}
