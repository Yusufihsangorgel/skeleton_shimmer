import 'package:flutter/widgets.dart';

/// Direction the highlight sweeps across the child.
enum ShimmerDirection {
  /// Left to right.
  ltr,

  /// Right to left.
  rtl,

  /// Top to bottom.
  ttb,

  /// Bottom to top.
  btt,
}

/// Paints an animated gradient sweep over its child's opaque pixels,
/// producing the shimmer loading effect.
///
/// The API is compatible with the `shimmer` package: [Shimmer.fromColors]
/// with `baseColor`/`highlightColor` covers the common case, and the
/// default constructor takes a full [gradient].
///
/// When the platform requests reduced motion
/// ([MediaQuery.disableAnimationsOf]), the sweep is frozen on the base
/// color instead of animating.
class Shimmer extends StatefulWidget {
  /// Creates a shimmer that paints [gradient] across [child].
  const Shimmer({
    super.key,
    required this.child,
    required this.gradient,
    this.direction = ShimmerDirection.ltr,
    this.period = const Duration(milliseconds: 1500),
    this.loop = 0,
    this.enabled = true,
  });

  /// The common two-color shimmer: [baseColor] with a [highlightColor]
  /// band sweeping across.
  Shimmer.fromColors({
    super.key,
    required this.child,
    required Color baseColor,
    required Color highlightColor,
    this.direction = ShimmerDirection.ltr,
    this.period = const Duration(milliseconds: 1500),
    this.loop = 0,
    this.enabled = true,
  }) : gradient = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            baseColor,
            baseColor,
            highlightColor,
            baseColor,
            baseColor,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        );

  /// The widget whose opaque pixels the shimmer paints over. Typically
  /// gray placeholder shapes; see `SkeletonBox` and friends.
  final Widget child;

  /// The gradient swept across the child.
  final Gradient gradient;

  /// Sweep direction. Defaults to [ShimmerDirection.ltr].
  final ShimmerDirection direction;

  /// Duration of one sweep. Defaults to 1500 ms.
  final Duration period;

  /// Number of sweeps before the animation stops. `0` (the default)
  /// repeats forever.
  final int loop;

  /// When false, the child is rendered as-is with no shimmer.
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);
  int _completedLoops = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.period;
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.period != widget.period ||
        oldWidget.loop != widget.loop) {
      _completedLoops = 0;
      _syncAnimation();
    }
  }

  bool get _motionDisabled =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _syncAnimation() {
    if (!widget.enabled || _motionDisabled) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _completedLoops++;
    if (widget.loop <= 0 || _completedLoops < widget.loop) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final gradient = _directedGradient();
          return gradient.createShader(
            bounds,
            textDirection: Directionality.maybeOf(context),
          );
        },
        child: child,
      ),
      child: widget.child,
    );
  }

  /// The gradient oriented for [Shimmer.direction], with a transform that
  /// slides it across the bounds as the animation progresses.
  Gradient _directedGradient() {
    final gradient = widget.gradient;
    // Sweep offset in [-1, 1] fractions of the paint bounds.
    final slide = 2.0 * _controller.value - 1.0;
    if (gradient is! LinearGradient) {
      // Custom gradient types are used as given; only linear gradients
      // are re-oriented and slid.
      return gradient;
    }
    return switch (widget.direction) {
      ShimmerDirection.ltr => LinearGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: _SlidingGradientTransform(x: slide),
        ),
      ShimmerDirection.rtl => LinearGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          transform: _SlidingGradientTransform(x: -slide),
        ),
      ShimmerDirection.ttb => LinearGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          transform: _SlidingGradientTransform(y: slide),
        ),
      ShimmerDirection.btt => LinearGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          transform: _SlidingGradientTransform(y: -slide),
        ),
    };
  }
}

/// Translates a gradient by a fraction of the paint bounds.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({this.x = 0, this.y = 0});

  final double x;
  final double y;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * x, bounds.height * y, 0);
}
