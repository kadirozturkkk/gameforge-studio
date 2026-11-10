import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gameforge_studio/core/errors.dart';
import 'package:gameforge_studio/engine/components/camera2d.dart';
import 'package:gameforge_studio/engine/components/component.dart';
import 'package:gameforge_studio/engine/components/sprite_renderer.dart';
import 'package:gameforge_studio/engine/math/affine2.dart';
import 'package:gameforge_studio/engine/math/vec2.dart';
import 'package:gameforge_studio/engine/scene/game_object.dart';
import 'package:gameforge_studio/engine/scene/presets.dart';
import 'package:gameforge_studio/engine/scene/scene.dart';

void main() {
  group('math', () {
    test('affine inverse undoes transform', () {
      final m = Affine2.fromTRS(const Vec2(10, -5), 30, const Vec2(2, 0.5));
      final p = const Vec2(3, 7);
      final back = m.inverse()!.transformPoint(m.transformPoint(p));
      expect(back.x, closeTo(p.x, 1e-9));
      expect(back.y, closeTo(p.y, 1e-9));
    });

    test('zero scale has no inverse', () {
      expect(Affine2.fromTRS(Vec2.zero, 0, const Vec2(0, 1)).inverse(), isNull);
    });

    test('90 degree rotation turns +x into +y (y-down, clockwise)', () {
      final p = Affine2.fromTRS(Vec2.zero, 90, Vec2.one).transformPoint(const Vec2(1, 0));
      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(1, 1e-9));
    });

    test('snapping', () {
      expect(const Vec2(17, -15).snapped(32), const Vec2(32, 0));
    });
  });

  group('scene serialization', () {
    Scene sample() {
      final parent = ObjectPresets.create(ObjectPreset.character,
          name: 'Player', position: const Vec2(100, 50));
      final child = ObjectPresets.create(ObjectPreset.sprite, name: 'Hat', position: const Vec2(0, -40))
        ..parentId = parent.id;
      final cam = ObjectPresets.create(ObjectPreset.camera, name: 'Cam');
      return Scene(name: 'Test', objects: [cam, parent, child]);
    }

    test('round trip keeps everything', () {
      final s = sample();
      s.objects[1].transform.rotation = 45;
      s.objects[1].getComponent<SpriteRenderer>()!.shape = SpriteShape.circle;
      final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      final back = Scene.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
      expect(back.objects[2].parentId, back.objects[1].id);
      expect(back.objects[0].getComponent<Camera2D>(), isNotNull);
    });

    test('unknown components are preserved', () {
      final s = sample();
      final json = s.toJson();
      final objects = json['objects'] as List;
      ((objects[1] as Map<String, dynamic>)['components'] as List)
          .add({'type': 'FutureLight3D', 'enabled': true, 'intensity': 4.5});
      final back = Scene.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      final unknown = back.objects[1].components.whereType<UnknownComponent>().single;
      expect(unknown.type, 'FutureLight3D');
      expect(unknown.toJson()['intensity'], 4.5);
    });

    test('object without transform gets one', () {
      final o = GameObject.fromJson({'id': 'a', 'name': 'A', 'components': []});
      expect(o.transform.position, Vec2.zero);
    });

    test('repairs duplicate ids, missing parents and cycles', () {
      final json = {
        'formatVersion': 1,
        'id': 's',
        'name': 'Broken',
        'objects': [
          {'id': 'a', 'name': 'A', 'parentId': 'b'},
          {'id': 'b', 'name': 'B', 'parentId': 'a'},
          {'id': 'a', 'name': 'Duplicate'},
          {'id': 'c', 'name': 'C', 'parentId': 'missing'},
          {'id': 'd', 'name': 'D', 'parentId': 'c'},
        ],
      };
      final s = Scene.fromJson(json);
      expect(s.objects.length, 4);
      expect(s.find('c')!.parentId, isNull);
      expect(s.find('d')!.parentId, 'c');
      // The a <-> b cycle must be broken.
      expect(s.find('a')!.parentId == null || s.find('b')!.parentId == null, isTrue);
    });

    test('rejects scenes from a newer format', () {
      expect(() => Scene.fromJson({'formatVersion': 999, 'id': 'x', 'name': 'x'}),
          throwsA(isA<ValidationException>()));
    });

    test('invalid numbers fall back to defaults', () {
      final o = GameObject.fromJson({
        'id': 'a',
        'name': 'A',
        'components': [
          {'type': 'Transform2D', 'position': ['x', 2], 'rotation': 'bad', 'scale': [1]},
        ],
      });
      expect(o.transform.position, Vec2.zero);
      expect(o.transform.rotation, 0);
      expect(o.transform.scale, Vec2.one);
    });
  });

  group('hierarchy', () {
    test('world matrix combines parent transforms', () {
      final parent = GameObject(name: 'P')..transform.position = const Vec2(100, 0);
      parent.transform.rotation = 90;
      final child = GameObject(name: 'C', parentId: parent.id)
        ..transform.position = const Vec2(10, 0);
      final s = Scene(name: 's', objects: [parent, child]);
      final world = s.worldMatrix(child).transformPoint(Vec2.zero);
      expect(world.x, closeTo(100, 1e-9));
      expect(world.y, closeTo(10, 1e-9));
    });

    test('setParent refuses cycles', () {
      final a = GameObject(name: 'A');
      final b = GameObject(name: 'B', parentId: a.id);
      final s = Scene(name: 's', objects: [a, b]);
      expect(s.setParent(a.id, b.id), isFalse);
      expect(s.setParent(b.id, null), isTrue);
      expect(s.subtree(a.id).length, 1);
    });

    test('inactive parent hides children', () {
      final a = GameObject(name: 'A', active: false);
      final b = GameObject(name: 'B', parentId: a.id);
      final s = Scene(name: 's', objects: [a, b]);
      expect(s.isActiveInHierarchy(b), isFalse);
    });

    test('every preset can be created and serialized', () {
      for (final p in ObjectPreset.values) {
        final o = ObjectPresets.create(p, name: p.name);
        final back = GameObject.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
        expect(back.kind, p.name);
        expect(ComponentRegistry.isKnown(back.components.first.type), isTrue);
      }
    });
  });
}
