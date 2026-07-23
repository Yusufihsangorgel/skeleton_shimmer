import 'package:flutter/widgets.dart';

const Color _defaultBone = Color(0xFFE0E0E0);

/// A rounded rectangle placeholder to put under a `Shimmer`.
final class SkeletonBox extends StatelessWidget {
  /// Creates a [width] x [height] placeholder box.
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.color = _defaultBone,
  });

  /// Box width; null fills the available width.
  final double? width;

  /// Box height; null fills the available height.
  final double? height;

  /// Corner rounding. Defaults to 4.
  final BorderRadiusGeometry borderRadius;

  /// Fill color the shimmer paints over.
  final Color color;

  @override
  // A placeholder carries no information, so it must not reach a screen
  // reader as content: without this a skeleton screen is a run of empty
  // containers to walk through. Announce the loading state once, on the
  // `Shimmer` above these, with its semanticsLabel.
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        ),
      );
}

/// A circular placeholder, e.g. for an avatar.
final class SkeletonCircle extends StatelessWidget {
  /// Creates a circular placeholder with [size] diameter.
  const SkeletonCircle({
    super.key,
    required this.size,
    this.color = _defaultBone,
  });

  /// Diameter of the circle.
  final double size;

  /// Fill color the shimmer paints over.
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}

/// A single line of placeholder text.
final class SkeletonLine extends StatelessWidget {
  /// Creates a text-line placeholder.
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
    this.color = _defaultBone,
  });

  /// Line width; null fills the available width.
  final double? width;

  /// Line height. Defaults to a body-text-like 14.
  final double height;

  /// Fill color the shimmer paints over.
  final Color color;

  @override
  Widget build(BuildContext context) => SkeletonBox(
        width: width,
        height: height,
        borderRadius: const BorderRadius.all(Radius.circular(7)),
        color: color,
      );
}
