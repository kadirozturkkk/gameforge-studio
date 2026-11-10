import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../engine/components/sprite_renderer.dart';
import '../../engine/math/vec2.dart';
import '../../engine/scene/game_object.dart';
import '../../engine/scene/presets.dart';
import '../editor_controller.dart';

/// The central scene view: pan/zoom with gestures, tap to select,
/// drag to move objects (Move tool).
///
/// Touch: one finger drags objects (Move tool) or pans the view; two
/// fingers pan and pinch-zoom. Mouse: wheel zooms.
class SceneViewport extends StatefulWidget {
  const SceneViewport({super.key, required this.controller});

  final EditorController controller;

  @override
  State<SceneViewport> createState() => SceneViewportState();
}

class SceneViewportState extends State<SceneViewport> {
  Size _size = Size.zero;
  Offset _startFocal = Offset.zero;
  Offset _lastFocal = Offset.zero;
  double _startZoom = 1;
  Vec2 _startCenter = Vec2.zero;
  bool _draggingObject = false;

  EditorController get c => widget.controller;

  Size get size => _size;

  Vec2 screenToWorld(Offset p) => Vec2(
        (p.dx - _size.width / 2) / c.zoom + c.viewCenter.x,
        (p.dy - _size.height / 2) / c.zoom + c.viewCenter.y,
      );

  void _onTapUp(TapUpDetails d) {
    final hit = c.hitTest(screenToWorld(d.localPosition));
    if (c.tool == EditorTool.select) {
      if (hit != null) c.select(hit.id, additive: true);
    } else {
      c.select(hit?.id);
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startFocal = d.localFocalPoint;
    _lastFocal = d.localFocalPoint;
    _startZoom = c.zoom;
    _startCenter = c.viewCenter;
    _draggingObject = false;
    if (d.pointerCount == 1 && c.tool == EditorTool.move) {
      final hit = c.hitTest(screenToWorld(d.localFocalPoint));
      if (hit != null) {
        if (!c.isSelected(hit.id)) c.select(hit.id);
        c.beginDrag();
        _draggingObject = c.isDragging;
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_draggingObject) {
      final delta = d.localFocalPoint - _lastFocal;
      _lastFocal = d.localFocalPoint;
      c.updateDrag(Vec2(delta.dx / c.zoom, delta.dy / c.zoom));
      return;
    }
    final newZoom = (_startZoom * d.scale).clamp(EditorController.minZoom, EditorController.maxZoom).toDouble();
    final anchor = Vec2(
      _startCenter.x + (_startFocal.dx - _size.width / 2) / _startZoom,
      _startCenter.y + (_startFocal.dy - _size.height / 2) / _startZoom,
    );
    final center = Vec2(
      anchor.x - (d.localFocalPoint.dx - _size.width / 2) / newZoom,
      anchor.y - (d.localFocalPoint.dy - _size.height / 2) / newZoom,
    );
    c.setView(center: center, zoom: newZoom);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_draggingObject) c.endDrag();
    _draggingObject = false;
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final before = screenToWorld(e.localPosition);
      final factor = e.scrollDelta.dy > 0 ? 1 / 1.15 : 1.15;
      final newZoom = (c.zoom * factor).clamp(EditorController.minZoom, EditorController.maxZoom).toDouble();
      final center = Vec2(
        before.x - (e.localPosition.dx - _size.width / 2) / newZoom,
        before.y - (e.localPosition.dy - _size.height / 2) / newZoom,
      );
      c.setView(center: center, zoom: newZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.biggest;
      return Listener(
        onPointerSignal: _onPointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: ClipRect(
            child: CustomPaint(
              key: const ValueKey('scene_viewport_paint'),
              painter: ScenePainter(c),
              size: Size.infinite,
            ),
          ),
        ),
      );
    });
  }
}

/// Draws grid, objects and selection. Repaints when the controller changes.
class ScenePainter extends CustomPainter {
  ScenePainter(this.c) : super(repaint: c);

  final EditorController c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = GfColors.viewport);
    final zoom = c.zoom;
    final halfW = size.width / 2 / zoom;
    final halfH = size.height / 2 / zoom;
    final left = c.viewCenter.x - halfW;
    final right = c.viewCenter.x + halfW;
    final top = c.viewCenter.y - halfH;
    final bottom = c.viewCenter.y + halfH;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-c.viewCenter.x, -c.viewCenter.y);

    // Scene background.
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom),
        Paint()..color = Color(c.scene.backgroundColor));

    if (c.showGrid) _drawGrid(canvas, left, top, right, bottom, zoom);

    for (final o in c.drawOrder) {
      _drawObject(canvas, o, zoom);
    }
    for (final id in c.selection) {
      final o = c.scene.find(id);
      if (o != null) _drawSelection(canvas, o, zoom);
    }
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, double left, double top, double right, double bottom, double zoom) {
    var step = c.gridSize;
    while (step * zoom < 10) {
      step *= 4;
    }
    final minor = Paint()
      ..color = GfColors.gridMinor
      ..strokeWidth = 1 / zoom;
    final major = Paint()
      ..color = GfColors.gridMajor
      ..strokeWidth = 1 / zoom;
    final startX = (left / step).floor();
    final endX = (right / step).ceil();
    for (var i = startX; i <= endX; i++) {
      final x = i * step;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), i % 5 == 0 ? major : minor);
    }
    final startY = (top / step).floor();
    final endY = (bottom / step).ceil();
    for (var i = startY; i <= endY; i++) {
      final y = i * step;
      canvas.drawLine(Offset(left, y), Offset(right, y), i % 5 == 0 ? major : minor);
    }
    // World axes.
    canvas.drawLine(Offset(left, 0), Offset(right, 0),
        Paint()
          ..color = const Color(0x88E5484D)
          ..strokeWidth = 1.5 / zoom);
    canvas.drawLine(Offset(0, top), Offset(0, bottom),
        Paint()
          ..color = const Color(0x8846A758)
          ..strokeWidth = 1.5 / zoom);
  }

  void _drawObject(Canvas canvas, GameObject o, double zoom) {
    final m = c.scene.worldMatrix(o);
    final scaleFactor = math.sqrt(m.determinant.abs()).clamp(1e-6, double.infinity).toDouble();
    final px = 1 / (zoom * scaleFactor); // one screen pixel in local units
    canvas.save();
    canvas.transform(m.toMatrix4Storage());
    final r = o.getComponent<SpriteRenderer>();
    if (r != null && r.enabled) {
      if (r.flipX || r.flipY) canvas.scale(r.flipX ? -1 : 1, r.flipY ? -1 : 1);
      final rect = Rect.fromCenter(center: Offset.zero, width: r.size.x, height: r.size.y);
      final paint = Paint()..color = Color(r.color);
      switch (r.shape) {
        case SpriteShape.rectangle:
          canvas.drawRect(rect, paint);
        case SpriteShape.circle:
          canvas.drawOval(rect, paint);
        case SpriteShape.triangle:
          final path = Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.bottom)
            ..lineTo(rect.left, rect.bottom)
            ..close();
          canvas.drawPath(path, paint);
      }
    } else if (o.kind == ObjectPreset.camera.name) {
      final s = c.localSize(o);
      final frame = Rect.fromCenter(center: Offset.zero, width: s.x, height: s.y);
      canvas.drawRect(
          frame,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * px
            ..color = const Color(0xAAFFFFFF));
      // Small camera glyph.
      final g = 14 * px;
      final body = Paint()..color = const Color(0xDDFFFFFF);
      canvas.drawRect(Rect.fromCenter(center: Offset(-g * 0.3, 0), width: g * 1.4, height: g), body);
      canvas.drawPath(
          Path()
            ..moveTo(g * 0.4, 0)
            ..lineTo(g * 1.1, -g * 0.5)
            ..lineTo(g * 1.1, g * 0.5)
            ..close(),
          body);
    } else {
      // Empty object: cross gizmo.
      final g = 10 * px;
      final p = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 1.5 * px;
      canvas.drawLine(Offset(-g, 0), Offset(g, 0), p);
      canvas.drawLine(Offset(0, -g), Offset(0, g), p);
    }
    canvas.restore();
  }

  void _drawSelection(Canvas canvas, GameObject o, double zoom) {
    final corners = c.worldCorners(o);
    final path = Path()..moveTo(corners[0].x, corners[0].y);
    for (final p in corners.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / zoom
          ..color = GfColors.accentOrange);
    final center = c.scene.worldMatrix(o).transformPoint(Vec2.zero);
    canvas.drawCircle(Offset(center.x, center.y), 5 / zoom, Paint()..color = GfColors.accentOrange);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) => oldDelegate.c != c;
}
