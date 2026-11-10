import '../../core/json_read.dart';
import '../math/affine2.dart';
import '../math/vec2.dart';
import 'component.dart';

/// Position, rotation (degrees) and scale relative to the parent object.
/// Every GameObject has exactly one Transform2D.
class Transform2D extends Component {
  Transform2D({
    this.position = Vec2.zero,
    this.rotation = 0,
    this.scale = Vec2.one,
  });

  static const typeName = 'Transform2D';

  Vec2 position;
  double rotation;
  Vec2 scale;

  @override
  String get type => typeName;

  @override
  bool get removable => false;

  Affine2 get localMatrix => Affine2.fromTRS(position, rotation, scale);

  @override
  Map<String, dynamic> dataToJson() => {
        'position': position.toJson(),
        'rotation': rotation,
        'scale': scale.toJson(),
      };

  factory Transform2D.fromJson(Map<String, dynamic> json) => Transform2D(
        position: Vec2.fromJson(json['position']),
        rotation: json.optDouble('rotation', 0),
        scale: Vec2.fromJson(json['scale'], Vec2.one),
      );
}
