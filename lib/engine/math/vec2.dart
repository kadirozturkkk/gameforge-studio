import 'dart:math' as math;

/// Immutable 2D vector used by the engine data model.
///
/// The engine keeps its own vector type so the scene model stays independent
/// of any rendering library (Flutter, Flame or a future 3D renderer).
class Vec2 {
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);
  static const one = Vec2(1, 1);

  final double x;
  final double y;

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);

  Vec2 withX(double v) => Vec2(v, y);
  Vec2 withY(double v) => Vec2(x, v);

  /// Rounds both components to the nearest multiple of [step].
  Vec2 snapped(double step) {
    if (step <= 0) return this;
    return Vec2((x / step).roundToDouble() * step, (y / step).roundToDouble() * step);
  }

  List<double> toJson() => [x, y];

  static Vec2 fromJson(Object? json, [Vec2 fallback = Vec2.zero]) {
    if (json is List && json.length == 2 && json[0] is num && json[1] is num) {
      final x = (json[0] as num).toDouble();
      final y = (json[1] as num).toDouble();
      if (x.isFinite && y.isFinite) return Vec2(x, y);
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) => other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
