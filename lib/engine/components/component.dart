import '../../core/json_read.dart';
import 'camera2d.dart';
import 'sprite_renderer.dart';
import 'transform2d.dart';

/// Base class of every component attached to a GameObject.
///
/// Components are plain data. Editors read and write them; runtimes
/// (Flame in Phase 3, a possible 3D runtime later) interpret them.
abstract class Component {
  Component({this.enabled = true});

  bool enabled;

  /// Stable type name used for serialization (for example "Transform2D").
  String get type;

  /// Whether a GameObject may hold more than one component of this type.
  bool get allowMultiple => false;

  /// Whether the component may be removed by the user.
  bool get removable => true;

  /// Component specific fields.
  Map<String, dynamic> dataToJson();

  Map<String, dynamic> toJson() =>
      {'type': type, 'enabled': enabled, ...dataToJson()};

  Component clone() => ComponentRegistry.fromJson(toJson());
}

typedef ComponentFactory = Component Function(Map<String, dynamic> json);

/// Maps type names to factories so new component types (including future 3D
/// ones) can be added without touching the serializer.
class ComponentRegistry {
  ComponentRegistry._();

  static final Map<String, ComponentFactory> _factories = {
    Transform2D.typeName: Transform2D.fromJson,
    SpriteRenderer.typeName: SpriteRenderer.fromJson,
    Camera2D.typeName: Camera2D.fromJson,
  };

  static void register(String type, ComponentFactory factory) {
    _factories[type] = factory;
  }

  static bool isKnown(String type) => _factories.containsKey(type);

  static Component fromJson(Map<String, dynamic> json) {
    final type = json.optString('type', '');
    final factory = _factories[type];
    if (factory == null) return UnknownComponent(json);
    final c = factory(json);
    c.enabled = json.optBool('enabled', true);
    return c;
  }
}

/// Keeps data of component types this version does not understand, so
/// opening a project made with a newer version never destroys data.
class UnknownComponent extends Component {
  UnknownComponent(Map<String, dynamic> raw)
      : raw = Map<String, dynamic>.from(raw);

  final Map<String, dynamic> raw;

  @override
  String get type => raw.optString('type', 'Unknown');

  @override
  bool get allowMultiple => true;

  @override
  Map<String, dynamic> dataToJson() {
    final copy = Map<String, dynamic>.from(raw)
      ..remove('type')
      ..remove('enabled');
    return copy;
  }
}
