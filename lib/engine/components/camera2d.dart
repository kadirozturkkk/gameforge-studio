import '../../core/json_read.dart';
import 'component.dart';

/// Defines what the player sees. The visible area is the project's reference
/// resolution divided by [zoom].
class Camera2D extends Component {
  Camera2D({this.zoom = 1, this.isMain = true});

  static const typeName = 'Camera2D';

  double zoom;
  bool isMain;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> dataToJson() => {'zoom': zoom, 'isMain': isMain};

  factory Camera2D.fromJson(Map<String, dynamic> json) {
    final zoom = json.optDouble('zoom', 1);
    return Camera2D(
      zoom: zoom > 0 ? zoom : 1,
      isMain: json.optBool('isMain', true),
    );
  }
}
