import '../../core/json_read.dart';
import '../math/vec2.dart';
import 'component.dart';

enum SpriteShape { rectangle, circle, triangle }

/// Draws the object. Until image assets arrive (Phase 2) a sprite is a
/// coloured shape; [assetId] is already part of the format.
class SpriteRenderer extends Component {
  SpriteRenderer({
    this.size = const Vec2(64, 64),
    this.color = 0xFFFFFFFF,
    this.shape = SpriteShape.rectangle,
    this.assetId,
    this.flipX = false,
    this.flipY = false,
    this.sortingOrder = 0,
  });

  static const typeName = 'SpriteRenderer';

  /// Size in world units before the transform scale is applied.
  Vec2 size;

  /// ARGB colour (tint when an image asset is set).
  int color;
  SpriteShape shape;
  String? assetId;
  bool flipX;
  bool flipY;

  /// Higher values are drawn on top.
  int sortingOrder;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> dataToJson() => {
        'size': size.toJson(),
        'color': color,
        'shape': shape.name,
        'assetId': assetId,
        'flipX': flipX,
        'flipY': flipY,
        'sortingOrder': sortingOrder,
      };

  factory SpriteRenderer.fromJson(Map<String, dynamic> json) {
    final shapeName = json.optString('shape', SpriteShape.rectangle.name);
    return SpriteRenderer(
      size: Vec2.fromJson(json['size'], const Vec2(64, 64)),
      color: json.optInt('color', 0xFFFFFFFF) & 0xFFFFFFFF,
      shape: SpriteShape.values.firstWhere((s) => s.name == shapeName,
          orElse: () => SpriteShape.rectangle),
      assetId: json.nullableString('assetId'),
      flipX: json.optBool('flipX', false),
      flipY: json.optBool('flipY', false),
      sortingOrder: json.optInt('sortingOrder', 0),
    );
  }
}
