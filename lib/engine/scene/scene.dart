import '../../core/errors.dart';
import '../../core/ids.dart';
import '../../core/json_read.dart';
import '../math/affine2.dart';
import '../math/vec2.dart';
import 'game_object.dart';

/// A scene: an ordered list of GameObjects plus scene settings.
///
/// The hierarchy is stored flat; each object points to its parent with
/// [GameObject.parentId]. List order defines sibling order and default
/// draw order.
class Scene {
  Scene({
    String? id,
    required this.name,
    this.backgroundColor = 0xFF22313F,
    this.gravity = const Vec2(0, 9.8),
    List<GameObject>? objects,
  })  : id = id ?? newId(),
        objects = objects ?? [];

  static const formatVersion = 1;

  final String id;
  String name;
  int backgroundColor;

  /// Gravity in world units per second squared (y points down). Used by the
  /// physics runtime in Phase 3.
  Vec2 gravity;
  final List<GameObject> objects;

  GameObject? find(String id) {
    for (final o in objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  int indexOf(String id) => objects.indexWhere((o) => o.id == id);

  List<GameObject> get roots => objects.where((o) => o.parentId == null).toList();

  List<GameObject> childrenOf(String? parentId) =>
      objects.where((o) => o.parentId == parentId).toList();

  /// [id] followed by all of its descendants, in list order.
  List<GameObject> subtree(String id) {
    final ids = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final o in objects) {
        if (o.parentId != null && ids.contains(o.parentId) && ids.add(o.id)) {
          grew = true;
        }
      }
    }
    return objects.where((o) => ids.contains(o.id)).toList();
  }

  /// True if [candidate] is [ancestorId] or lies below it.
  bool isInSubtree(String candidate, String ancestorId) {
    String? current = candidate;
    var guard = 0;
    while (current != null && guard++ <= objects.length) {
      if (current == ancestorId) return true;
      current = find(current)?.parentId;
    }
    return false;
  }

  /// Changes the parent of [childId]. Returns false for invalid requests
  /// (unknown objects or a move that would create a cycle).
  bool setParent(String childId, String? newParentId) {
    final child = find(childId);
    if (child == null) return false;
    if (newParentId != null) {
      if (find(newParentId) == null) return false;
      if (isInSubtree(newParentId, childId)) return false;
    }
    child.parentId = newParentId;
    return true;
  }

  /// Local-to-world transform including all parents.
  Affine2 worldMatrix(GameObject object) {
    var m = object.transform.localMatrix;
    var parentId = object.parentId;
    var guard = 0;
    while (parentId != null && guard++ <= objects.length) {
      final parent = find(parentId);
      if (parent == null) break;
      m = parent.transform.localMatrix.multiply(m);
      parentId = parent.parentId;
    }
    return m;
  }

  /// World transform of the parent (identity for root objects).
  Affine2 parentWorldMatrix(GameObject object) {
    final parent = object.parentId == null ? null : find(object.parentId!);
    return parent == null ? Affine2.identity : worldMatrix(parent);
  }

  /// Object and all ancestors active?
  bool isActiveInHierarchy(GameObject object) {
    GameObject? current = object;
    var guard = 0;
    while (current != null && guard++ <= objects.length) {
      if (!current.active) return false;
      current = current.parentId == null ? null : find(current.parentId!);
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'id': id,
        'name': name,
        'backgroundColor': backgroundColor,
        'gravity': gravity.toJson(),
        'objects': [for (final o in objects) o.toJson()],
      };

  /// Parses and validates a scene. Repairs what can be repaired safely:
  /// duplicate ids are dropped, missing parents and cycles become roots.
  factory Scene.fromJson(Map<String, dynamic> json) {
    final version = json.optInt('formatVersion', 1);
    if (version > formatVersion) {
      throw ValidationException(ValidationError.unsupportedFormatVersion);
    }
    final id = json.reqString('id');
    final objects = <GameObject>[];
    final seen = <String>{};
    for (final raw in json.optList('objects')) {
      if (raw is! Map<String, dynamic>) continue;
      final obj = GameObject.fromJson(raw);
      if (seen.add(obj.id)) objects.add(obj);
    }
    final scene = Scene(
      id: id,
      name: json.optString('name', 'Scene'),
      backgroundColor: json.optInt('backgroundColor', 0xFF22313F) & 0xFFFFFFFF,
      gravity: Vec2.fromJson(json['gravity'], const Vec2(0, 9.8)),
      objects: objects,
    );
    for (final o in scene.objects) {
      final pid = o.parentId;
      if (pid == null) continue;
      if (pid == o.id || !seen.contains(pid)) {
        o.parentId = null;
      }
    }
    // Break cycles: an object whose parent chain leads back to itself
    // becomes a root. Chains that enter a cycle elsewhere are left alone;
    // that cycle is broken when one of its own members is processed.
    for (final o in scene.objects) {
      final visited = <String>{o.id};
      var current = o.parentId;
      while (current != null) {
        if (current == o.id) {
          o.parentId = null;
          break;
        }
        if (!visited.add(current)) break;
        current = scene.find(current)?.parentId;
      }
    }
    return scene;
  }

  Scene clone() => Scene.fromJson(toJson());
}
