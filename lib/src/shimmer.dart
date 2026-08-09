import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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
/// On its own, each `Shimmer` runs its own clock and sweeps across its own
/// box, which is what makes a screen full of them look like a screen full of
/// separate animations. Wrap them in a [ShimmerScope] to put every one of them
/// on one clock and one band.
///
/// When the platform requests reduced motion
/// ([MediaQuery.disableAnimationsOf]), the sweep freezes instead of
/// animating.
final class Shimmer extends StatefulWidget {
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
  ///
  /// Under a [ShimmerScope] the scope's own `period` wins, since the point of
  /// a scope is that there is one clock.
  final Duration period;

  /// Number of sweeps before the animation stops. `0` (the default)
  /// repeats forever.
  ///
  /// Under a [ShimmerScope] the scope's own `loop` wins.
  final int loop;

  /// When false, the sweep pauses in place; the gradient keeps masking
  /// the child, matching the `shimmer` package.
  ///
  /// This stays per-widget under a [ShimmerScope]: one card can hold still on
  /// the band it happens to be showing while its neighbours keep sweeping.
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

/// Puts every [Shimmer] below it on one clock and one band.
///
/// A bare [Shimmer] owns its own [AnimationController] and sweeps the gradient
/// across its own box. Put three of them on a screen and you get three clocks,
/// each started when its widget mounted, each running a full highlight across
/// a box the size of an avatar or a line of text. Wrapping them changes both
/// halves of that: the scope holds the only controller, and each [Shimmer]
/// resolves its own position inside the scope's box and paints the slice of
/// the sweep that lands on it. One band crosses the screen.
///
/// ```dart
/// ShimmerScope(
///   child: Column(
///     children: [
///       for (final row in rows)
///         Shimmer.fromColors(
///           baseColor: Colors.grey.shade300,
///           highlightColor: Colors.grey.shade100,
///           child: row,
///         ),
///     ],
///   ),
/// )
/// ```
///
/// The scope owns [period] and [loop], because those describe the clock.
/// Everything else stays on the individual [Shimmer]: its colors, its
/// [Shimmer.direction], its [Shimmer.enabled] flag, its
/// [Shimmer.semanticsLabel]. A widget with `enabled: false` holds still on
/// whatever part of the band it was showing while its neighbours carry on.
///
/// The sweep is anchored to the scope's box rather than to the widgets inside
/// it. A [Shimmer] scrolling through a list therefore moves through the band
/// instead of carrying its own copy along, except while the band is held
/// still by `enabled: false` or by reduced motion, when nothing repaints it.
/// Reduced motion otherwise works as it does without a scope:
/// [MediaQuery.disableAnimationsOf] freezes the clock.
///
/// Adding a scope is the only thing that changes any of this. A [Shimmer] with
/// no scope above it runs exactly as it did before scopes existed.
final class ShimmerScope extends StatefulWidget {
  /// Creates a scope that drives every [Shimmer] in [child].
  const ShimmerScope({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1500),
    this.loop = 0,
    this.enabled = true,
  });

  /// The subtree whose shimmers share this scope's clock and band. The scope
  /// takes the size of this child, and that size is the distance the sweep
  /// travels.
  final Widget child;

  /// Duration of one sweep across the whole scope. Defaults to 1500 ms.
  final Duration period;

  /// Number of sweeps before the clock stops. `0` (the default) repeats
  /// forever.
  final int loop;

  /// When false, the shared clock pauses in place and every [Shimmer] below
  /// holds the band where it is.
  final bool enabled;

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Duration>('period', period))
      ..add(IntProperty('loop', loop, defaultValue: 0))
      ..add(FlagProperty('enabled',
          value: enabled, ifTrue: 'enabled', ifFalse: 'disabled'));
  }
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final _Sweep _sweep = _Sweep(
    vsync: this,
    period: widget.period,
    loop: widget.loop,
  );

  /// The clock every [Shimmer] below this scope reads.
  Animation<double> get clock => _sweep.controller;

  /// The box the sweep travels across, or null before the first layout.
  ///
  /// This is the render object of the [_ScopeFrame] in [build], reached by
  /// walking down from this element: the marker above it is an
  /// [InheritedWidget] and has none of its own.
  RenderBox? get frame {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ShimmerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final motionDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sweep.update(
      period: widget.period,
      loop: widget.loop,
      running: widget.enabled && !motionDisabled,
    );
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerScopeMarker(state: this, child: _ScopeFrame(child: widget.child));
}

/// Carries the scope's state down to the shimmers that depend on it.
class _ShimmerScopeMarker extends InheritedWidget {
  const _ShimmerScopeMarker({required this.state, required super.child});

  final _ShimmerScopeState state;

  @override
  bool updateShouldNotify(_ShimmerScopeMarker oldWidget) =>
      state != oldWidget.state;
}

/// A proxy box that exists only to give [ShimmerScope] a render object.
///
/// Without one, a [Shimmer] would have nothing to measure its offset against:
/// the scope is otherwise a pair of [InheritedWidget]s, which do not lay
/// anything out. This adds a box the size of the child and no layer.
class _ScopeFrame extends SingleChildRenderObjectWidget {
  const _ScopeFrame({required Widget super.child});

  @override
  RenderProxyBox createRenderObject(BuildContext context) => RenderProxyBox();
}

/// A [Listenable] that never fires.
///
/// What a frozen [Shimmer] listens to instead of the clock: under a
/// [ShimmerScope] the shared controller keeps ticking for the other widgets,
/// and this one has to stop repainting without stopping them.
final Listenable _neverTicks = Listenable.merge(const <Listenable?>[]);

class _ShimmerState extends State<Shimmer> with TickerProviderStateMixin {
  /// The clock this widget owns, or null while a [ShimmerScope] drives it.
  _Sweep? _own;

  /// The scope driving this widget, or null when it is on its own.
  _ShimmerScopeState? _scope;

  /// Where the band was when this widget froze, used only under a scope: on
  /// its own, the widget's own controller stops and holds the value itself.
  double _frozenAt = 0;
  bool _frozen = false;

  Animation<double> get _clock => _scope?.clock ?? _own!.controller;

  double get _percent => _scope != null && _frozen ? _frozenAt : _clock.value;

  bool get _motionDisabled =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ShimmerScopeMarker>()
        ?.state;
    if (scope != _scope) {
      _scope = scope;
      _frozen = false;
      // Whichever clock is not driving must not be running.
      _own?.dispose();
      _own = null;
    }
    if (_scope == null) {
      _own ??= _Sweep(vsync: this, period: widget.period, loop: widget.loop);
    }
    _sync();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final frozen = !widget.enabled || _motionDisabled;
    // Capture on the edge: the scope's clock runs on regardless, so reading it
    // later would give the band's position now rather than when it stopped.
    if (frozen && !_frozen) _frozenAt = _clock.value;
    _frozen = frozen;
    _own?.update(
      period: widget.period,
      loop: widget.loop,
      running: !frozen,
    );
  }

  @override
  void dispose() {
    _own?.dispose();
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
        animation: _frozen ? _neverTicks : _clock,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => widget.gradient.createShader(
            _shaderRect(bounds, context),
            textDirection: Directionality.maybeOf(context),
          ),
          child: child,
        ),
        // Cache the static child's picture across animation frames.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }

  /// The rect handed to the gradient, in this widget's own coordinates.
  ///
  /// With no scope that is just [_paintRect] over this widget's box, which is
  /// what the `shimmer` package does and what this package did before scopes.
  /// Under a scope the window is computed over the scope's box instead and
  /// then translated back into local coordinates, so neighbouring widgets read
  /// neighbouring slices of one gradient.
  ///
  /// [ShaderMask] calls this during paint, which is where the offset has to be
  /// resolved: inside a scrolling list a row's position in the scope changes
  /// every frame without the row rebuilding.
  Rect _shaderRect(Rect bounds, BuildContext maskContext) {
    final frame = _scope?.frame;
    final self = maskContext.findRenderObject();
    if (frame == null ||
        !frame.attached ||
        self is! RenderBox ||
        !self.attached ||
        !self.hasSize) {
      return _paintRect(bounds, _percent);
    }
    final origin = self.localToGlobal(Offset.zero, ancestor: frame);
    return _paintRect(Offset.zero & frame.size, _percent).shift(-origin);
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

/// One repeating sweep, and the rules for starting and stopping it.
///
/// A lone [Shimmer] owns one of these; a [ShimmerScope] owns one on behalf of
/// every [Shimmer] under it. The loop accounting below is small and easy to
/// get subtly wrong, which is the argument for having it once rather than in
/// both places.
class _Sweep {
  _Sweep({
    required TickerProvider vsync,
    required Duration period,
    required this.loop,
  }) : controller = AnimationController(vsync: vsync, duration: period) {
    controller.addStatusListener(_onStatus);
  }

  final AnimationController controller;
  int loop;
  int _completedLoops = 0;

  bool get _finished => loop > 0 && _completedLoops >= loop;

  void update({
    required Duration period,
    required int loop,
    required bool running,
  }) {
    controller.duration = period;
    if (loop != this.loop) {
      this.loop = loop;
      _completedLoops = 0;
    }
    if (_finished) return;
    if (!running) {
      controller.stop();
    } else if (!controller.isAnimating) {
      // A finished finite loop parks the controller at the upper bound, where
      // forward() would be a no-op; restart from 0 so a raised loop count
      // sweeps again. Otherwise (e.g. re-enabled mid-sweep) resume in place.
      controller.forward(from: controller.isCompleted ? 0 : controller.value);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _completedLoops++;
    if (!_finished) controller.forward(from: 0);
  }

  void dispose() => controller.dispose();
}
