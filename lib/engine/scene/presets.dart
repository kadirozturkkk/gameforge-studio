import '../components/camera2d.dart';
import '../components/sprite_renderer.dart';
import '../components/transform2d.dart';
import '../math/vec2.dart';
import 'game_object.dart';

/// Object types the user can create from the editor's "Add" menu.
///
/// Phase 1 offers object types that are fully supported by the current
/// component set. Lights, audio sources, particle emitters and UI elements
/// are added in the phases that implement their components.
enum ObjectPreset {
  empty,
  sprite,
  character,
  enemy,
  platform,
  wall,
  background,
  camera,
}

class ObjectPresets {
  ObjectPresets._();

  /// Creates a new object of [preset] at [position] with the given [name].
  static GameObject create(ObjectPreset preset,
      {required String name, Vec2 position = Vec2.zero}) {
    Transform2D t() => Transform2D(position: position);
    switch (preset) {
      case ObjectPreset.empty:
        return GameObject(name: name, kind: preset.name, components: [t()]);
      case ObjectPreset.sprite:
        return GameObject(name: name, kind: preset.name, components: [
          t(),
          SpriteRenderer(size: const Vec2(64, 64), color: 0xFFFFFFFF),
        ]);
      case ObjectPreset.character:
        return GameObject(name: name, kind: preset.name, tag: 'Player', components: [
          t(),
          SpriteRenderer(size: const Vec2(48, 64), color: 0xFF4C8DFF, sortingOrder: 10),
        ]);
      case ObjectPreset.enemy:
        return GameObject(name: name, kind: preset.name, tag: 'Enemy', components: [
          t(),
          SpriteRenderer(size: const Vec2(48, 48), color: 0xFFE5484D, sortingOrder: 10),
        ]);
      case ObjectPreset.platform:
        return GameObject(name: name, kind: preset.name, layer: 'Ground', components: [
          t(),
          SpriteRenderer(size: const Vec2(256, 32), color: 0xFF6B7A8F),
        ]);
      case ObjectPreset.wall:
        return GameObject(name: name, kind: preset.name, layer: 'Ground', components: [
          t(),
          SpriteRenderer(size: const Vec2(32, 256), color: 0xFF56606E),
        ]);
      case ObjectPreset.background:
        return GameObject(name: name, kind: preset.name, layer: 'Background', components: [
          t(),
          SpriteRenderer(
              size: const Vec2(1280, 720), color: 0xFF2E4A62, sortingOrder: -100),
        ]);
      case ObjectPreset.camera:
        return GameObject(
            name: name, kind: preset.name, tag: 'MainCamera', components: [t(), Camera2D()]);
    }
  }
}
