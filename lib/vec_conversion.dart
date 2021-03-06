import 'package:vector_math/vector_math_64.dart';
import 'dart:ui' show Offset, Size;

extension OffsetE on Offset {
  Size toSize() => Size(dx, dy);
  Vector2 toVector2() => Vector2(dx, dy);
  Vector4 toVector4Point() => Vector4(dx, dy, 0, 1);
  Vector4 toVector4Distance() => Vector4(dx, dy, 0, 0);
}

extension SizeE on Size {
  Offset toOffset() => Offset(width, height);
  Vector2 toVector2() => Vector2(width, height);
  Vector4 toVector4Point() => Vector4(width, height, 0, 1);
  Vector4 toVector4Distance() => Vector4(width, height, 0, 0);
}

extension Vector2E on Vector2 {
  Offset toOffset() => Offset(x, y);
  Size toSize() => Size(x, y);
  Vector4 toVector4Point() => Vector4(x, y, 0, 1);
  Vector4 toVector4Distance() => Vector4(x, y, 0, 0);
}

extension Vector4E on Vector4 {
  Offset toOffset() => Offset(x, y);
  Vector2 toVector2() => Vector2(x, y);
  static Vector4 pointZero() => Vector4(0, 0, 0, 1);
  static Vector4 zero() => Vector4.zero();
}
