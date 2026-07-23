import 'package:flutter/foundation.dart';
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
/// The API and the sweep geometry match the `shimmer` package:
/// [Shimmer.fromColors] with `baseColor`/`highlightColor` covers the
/// common case, and the default constructor takes a full [gradient] that
/// is used exactly as given while the paint window slides across.
///
/// When the platform requests reduced motion
/// ([MediaQuery.disableAnimationsOf]), the sweep freezes instead of
/// animating.
class Shimmer extends StatefulWidget {
  /// Creates a shimmer that sweeps [gradient] across [child].
  const Shimmer({
    super.key,
    required this.child,
    required this.gradient,
    this.direction = ShimmerDirection.ltr,
    this.period = const Duration(milliseconds: 1500),
    this.loop = 0,
    this.enabled = true,
    this.semanticsLabel,
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
    this.semanticsLabel,
  }) : gradient = LinearGradient(
          begin: switch (direction) {
            ShimmerDirection.ltr ||
            ShimmerDirection.rtl =>
              Alignment.centerLeft,
            ShimmerDirection.ttb || ShimmerDirection.btt => Alignment.topCenter,
          },
          end: switch (direction) {
            ShimmerDirection.ltr ||
            ShimmerDirection.rtl =>
              Alignment.centerRight,
            ShimmerDirection.ttb ||
            ShimmerDirection.btt =>
              Alignment.bottomCenter,
          },
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

  /// The gradient swept across the child, used exactly as given.
  final Gradient gradient;

  /// Sweep direction. Defaults to [ShimmerDirection.ltr].
  final ShimmerDirection direction;

  /// Duration of one sweep. Defaults to 1500 ms.
  final Duration period;

  /// Number of sweeps before the animation stops. `0` (the default)
  /// repeats forever.
  final int loop;

  /// When false, the sweep pauses in place; the gradient keeps masking
  /// the child, matching the `shimmer` package.
  final bool enabled;

  /// Announced to a screen reader while this is on screen, as
  /// `CircularProgressIndicator.semanticsLabel` is.
  ///
  /// The placeholders underneath carry no text, so without a label a skeleton
  /// screen is silence: a user hears nothing and cannot tell whether content
  /// is loading or the screen is simply empty. Pass a localized string, which
  /// is why there is no English default here.
  ///
  /// ```dart
  /// Shimmer.fromColors(
  ///   baseColor: base,
  ///   highlightColor: highlight,
  ///   semanticsLabel: AppLocalizations.of(context).loading,
  ///   child: const SkeletonLine(),
  /// )
  /// ```
  final String? semanticsLabel;

  @override
  State<Shimmer> createState() => _ShimmerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Gradient>('gradient', gradient))
      ..add(EnumProperty<ShimmerDirection>('direction', direction))
      ..add(DiagnosticsProperty<Duration>('period', period))
      ..add(IntProperty('loop', loop, defaultValue: 0))
      ..add(FlagProperty('enabled',
          value: enabled, ifTrue: 'enabled', ifFalse: 'disabled'));
  }
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
      if (oldWidget.loop != widget.loop) _completedLoops = 0;
      _syncAnimation();
    }
  }

  bool get _motionDisabled =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _syncAnimation() {
    if (widget.loop > 0 && _completedLoops >= widget.loop) return;
    if (!widget.enabled || _motionDisabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.forward();
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
    final label = widget.semanticsLabel;
    if (label != null) {
      // liveRegion so it is announced when the skeleton appears, not only when
      // focus happens to land on it.
      return Semantics(
        label: label,
        liveRegion: true,
        container: true,
        child: _buildShimmer(),
      );
    }
    return _buildShimmer();
  }

  Widget _buildShimmer() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => widget.gradient.createShader(
            _paintRect(bounds, _controller.value),
            textDirection: Directionality.maybeOf(context),
          ),
          child: child,
        ),
        // Cache the static child's picture across animation frames.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }

  /// The window the gradient is painted into: three times the child size
  /// along the sweep axis, sliding across as [percent] advances. This is
  /// the `shimmer` package's geometry, so the band width and travel look
  /// identical.
  Rect _paintRect(Rect bounds, double percent) {
    final width = bounds.width;
    final height = bounds.height;
    double lerp(double from, double to) => from + (to - from) * percent;
    return switch (widget.direction) {
      ShimmerDirection.ltr =>
        Rect.fromLTWH(lerp(-width, width) - width, 0, 3 * width, height),
      ShimmerDirection.rtl =>
        Rect.fromLTWH(lerp(width, -width) - width, 0, 3 * width, height),
      ShimmerDirection.ttb =>
        Rect.fromLTWH(0, lerp(-height, height) - height, width, 3 * height),
      ShimmerDirection.btt =>
        Rect.fromLTWH(0, lerp(height, -height) - height, width, 3 * height),
    };
  }
}
