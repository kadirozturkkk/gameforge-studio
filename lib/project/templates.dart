import '../engine/components/sprite_renderer.dart';
import '../engine/math/vec2.dart';
import '../engine/scene/game_object.dart';
import '../engine/scene/presets.dart';
import '../engine/scene/scene.dart';
import 'project_meta.dart';

/// Builds the starting content of each project template.
///
/// Templates set up a meaningful scene layout. Gameplay behaviour (physics,
/// scripts) is attached to these objects in the phases that add those
/// systems; the objects themselves are ordinary, editable GameObjects.
class ProjectTemplates {
  ProjectTemplates._();

  static (ProjectSettings, List<Scene>) build(ProjectTemplate template) {
    switch (template) {
      case ProjectTemplate.platformer:
        return (ProjectSettings(), [_platformer()]);
      case ProjectTemplate.topDown:
        return (ProjectSettings(), [_topDown()]);
      case ProjectTemplate.rpg:
        return (ProjectSettings(), [_rpg()]);
      case ProjectTemplate.endlessRunner:
        return (ProjectSettings(), [_runner()]);
      case ProjectTemplate.puzzle:
        return (
          ProjectSettings(
              referenceWidth: 720,
              referenceHeight: 1280,
              orientation: ScreenOrientation.portrait),
          [_puzzle()]
        );
      case ProjectTemplate.empty:
        return (ProjectSettings(), [_empty()]);
    }
  }

  static GameObject _o(ObjectPreset p, String name, double x, double y,
      {Vec2? size, int? color, SpriteShape? shape}) {
    final o = ObjectPresets.create(p, name: name, position: Vec2(x, y));
    final r = o.getComponent<SpriteRenderer>();
    if (r != null) {
      if (size != null) r.size = size;
      if (color != null) r.color = color;
      if (shape != null) r.shape = shape;
    }
    return o;
  }

  static Scene _empty() => Scene(
      name: 'Main', objects: [_o(ObjectPreset.camera, 'Main Camera', 0, 0)]);

  static Scene _platformer() => Scene(name: 'Level 1', objects: [
        _o(ObjectPreset.camera, 'Main Camera', 0, 0),
        _o(ObjectPreset.background, 'Background', 0, 0),
        _o(ObjectPreset.platform, 'Ground', 0, 300, size: const Vec2(1280, 64)),
        _o(ObjectPreset.platform, 'Platform A', -300, 120),
        _o(ObjectPreset.platform, 'Platform B', 250, 0),
        _o(ObjectPreset.character, 'Player', -500, 236),
        _o(ObjectPreset.enemy, 'Enemy', 250, -40),
        _o(ObjectPreset.sprite, 'Coin', -300, 70,
            size: const Vec2(24, 24), color: 0xFFFFC53D, shape: SpriteShape.circle),
        _o(ObjectPreset.sprite, 'Goal Flag', 560, 220,
            size: const Vec2(32, 96), color: 0xFF46A758),
      ]);

  static Scene _topDown() {
    final s = Scene(name: 'Arena', backgroundColor: 0xFF2B3A2F, gravity: Vec2.zero, objects: [
      _o(ObjectPreset.camera, 'Main Camera', 0, 0),
      _o(ObjectPreset.wall, 'Wall Top', 0, -340, size: const Vec2(1280, 32)),
      _o(ObjectPreset.wall, 'Wall Bottom', 0, 340, size: const Vec2(1280, 32)),
      _o(ObjectPreset.wall, 'Wall Left', -620, 0, size: const Vec2(32, 720)),
      _o(ObjectPreset.wall, 'Wall Right', 620, 0, size: const Vec2(32, 720)),
      _o(ObjectPreset.character, 'Player', 0, 0,
          size: const Vec2(48, 48), shape: SpriteShape.circle),
      _o(ObjectPreset.enemy, 'Enemy 1', -400, -200, shape: SpriteShape.circle),
      _o(ObjectPreset.enemy, 'Enemy 2', 400, 200, shape: SpriteShape.circle),
    ]);
    return s;
  }

  static Scene _rpg() => Scene(name: 'Village', backgroundColor: 0xFF3B5D3A, gravity: Vec2.zero, objects: [
        _o(ObjectPreset.camera, 'Main Camera', 0, 0),
        _o(ObjectPreset.sprite, 'House', -350, -150,
            size: const Vec2(192, 160), color: 0xFF8B5E3C),
        _o(ObjectPreset.sprite, 'Tree 1', 300, -200,
            size: const Vec2(96, 96), color: 0xFF2F7D32, shape: SpriteShape.circle),
        _o(ObjectPreset.sprite, 'Tree 2', 420, 120,
            size: const Vec2(96, 96), color: 0xFF2F7D32, shape: SpriteShape.circle),
        _o(ObjectPreset.sprite, 'Path', 0, 100,
            size: const Vec2(900, 64), color: 0xFFB59B6A),
        _o(ObjectPreset.character, 'Hero', 0, 60),
        _o(ObjectPreset.sprite, 'Villager', -350, 0,
            size: const Vec2(48, 64), color: 0xFFE0A458),
        _o(ObjectPreset.enemy, 'Slime', 450, -40, shape: SpriteShape.circle),
      ]);

  static Scene _runner() => Scene(name: 'Run', objects: [
        _o(ObjectPreset.camera, 'Main Camera', 0, 0),
        _o(ObjectPreset.background, 'Sky', 0, 0, color: 0xFF4A6FA5),
        _o(ObjectPreset.platform, 'Ground', 0, 300, size: const Vec2(2560, 64)),
        _o(ObjectPreset.character, 'Runner', -450, 236),
        _o(ObjectPreset.enemy, 'Obstacle 1', 100, 244,
            size: const Vec2(40, 48), shape: SpriteShape.triangle),
        _o(ObjectPreset.enemy, 'Obstacle 2', 500, 244,
            size: const Vec2(40, 48), shape: SpriteShape.triangle),
      ]);

  static Scene _puzzle() {
    const colors = [0xFFE5484D, 0xFF4C8DFF, 0xFF46A758, 0xFFFFC53D];
    final objects = <GameObject>[
      _o(ObjectPreset.camera, 'Main Camera', 0, 0),
      _o(ObjectPreset.sprite, 'Board', 0, 0, size: const Vec2(560, 560), color: 0xFF2A2F3A),
    ];
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        objects.add(_o(ObjectPreset.sprite, 'Tile ${row * 4 + col + 1}',
            -210.0 + col * 140, -210.0 + row * 140,
            size: const Vec2(120, 120), color: colors[(row + col) % 4]));
      }
    }
    return Scene(name: 'Puzzle', backgroundColor: 0xFF1B1F27, gravity: Vec2.zero, objects: objects);
  }
}
