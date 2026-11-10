import 'dart:math' as math;
import 'dart:typed_data';

import 'vec2.dart';

/// 2D affine transform:
///   x' = a*x + c*y + tx
///   y' = b*x + d*y + ty
class Affine2 {
  const Affine2(this.a, this.b, this.c, this.d, this.tx, this.ty);

  static const identity = Affine2(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, tx, ty;

  /// Scale, then rotate (degrees, clockwise in a y-down world), then translate.
  factory Affine2.fromTRS(Vec2 position, double rotationDegrees, Vec2 scale) {
    final r = rotationDegrees * math.pi / 180.0;
    final cos = math.cos(r);
    final sin = math.sin(r);
    return Affine2(cos * scale.x, sin * scale.x, -sin * scale.y, cos * scale.y,
        position.x, position.y);
  }

  /// Returns `this * other` (apply [other] first, then this).
  Affine2 multiply(Affine2 o) => Affine2(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.tx + c * o.ty + tx,
        b * o.tx + d * o.ty + ty,
      );

  double get determinant => a * d - b * c;

  /// Inverse transform, or null if the transform is degenerate (scale 0).
  Affine2? inverse() {
    final det = determinant;
    if (det.abs() < 1e-12) return null;
    final ia = d / det;
    final ib = -b / det;
    final ic = -c / det;
    final id = a / det;
    return Affine2(ia, ib, ic, id, -(ia * tx + ic * ty), -(ib * tx + id * ty));
  }

  Vec2 transformPoint(Vec2 p) => Vec2(a * p.x + c * p.y + tx, b * p.x + d * p.y + ty);

  /// Transforms a direction (ignores translation).
  Vec2 transformVector(Vec2 v) => Vec2(a * v.x + c * v.y, b * v.x + d * v.y);

  /// Column-major 4x4 matrix for `Canvas.transform`.
  Float64List toMatrix4Storage() => Float64List.fromList(
      [a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]);
}
