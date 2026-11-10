import '../../core/errors.dart';
import '../../core/ids.dart';
import '../../core/json_read.dart';
import '../components/component.dart';
import '../components/transform2d.dart';

/// An entity in a scene. Behaviour and appearance come from its components.
class GameObject {
  GameObject({
    String? id,
    required this.name,
    this.kind = 'empty',
    this.active = true,
    this.layer = 'Default',
    this.tag = 'Untagged',
    this.parentId,
    List<Component>? components,
  })  : id = id ?? newId(),
        components = components ?? [] {
    if (!this.components.any((c) => c is Transform2D)) {
      this.components.insert(0, Transform2D());
    }
  }

  final String id;
  String name;

  /// Preset the object was created from (sprite, character, camera...).
  /// Used for icons only; behaviour always comes from components.
  String kind;

  /// Visible and updated when true.
  bool active;
  String layer;
  String tag;
  String? parentId;
  final List<Component> components;

  Transform2D get transform => components.whereType<Transform2D>().first;

  T? getComponent<T extends Component>() {
    for (final c in components) {
      if (c is T) return c;
    }
    return null;
  }

  bool hasComponentType(String type) => components.any((c) => c.type == type);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'active': active,
        'layer': layer,
        'tag': tag,
        'parentId': parentId,
        'components': [for (final c in components) c.toJson()],
      };

  factory GameObject.fromJson(Map<String, dynamic> json) {
    final id = json.reqString('id');
    if (id.isEmpty) throw DataFormatException('GameObject id is empty');
    final components = <Component>[];
    for (final c in json.optList('components')) {
      if (c is Map<String, dynamic>) {
        final comp = ComponentRegistry.fromJson(c);
        final duplicate = !comp.allowMultiple &&
            components.any((existing) => existing.type == comp.type);
        if (!duplicate) components.add(comp);
      }
    }
    return GameObject(
      id: id,
      name: json.optString('name', 'GameObject'),
      kind: json.optString('kind', 'empty'),
      active: json.optBool('active', true),
      layer: json.optString('layer', 'Default'),
      tag: json.optString('tag', 'Untagged'),
      parentId: json.nullableString('parentId'),
      components: components,
    );
  }

  /// Deep copy. With [newIdentity] the copy receives a fresh id.
  GameObject clone({bool newIdentity = false}) {
    final json = toJson();
    if (newIdentity) json['id'] = newId();
    return GameObject.fromJson(json);
  }
}
