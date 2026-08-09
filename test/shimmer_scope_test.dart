// What ShimmerScope is for, asserted in pixels.
//
// Every test here samples rendered output rather than widget properties. The
// scope's whole claim is about where the highlight lands, and a claim about
// pixels that is checked by reading back a field is not checked at all.
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

const _base = Color(0xFFE0E0E0);
const _highlight = Color(0xFFF5F5F5);

/// Red channel of the two ends of the gradient, which is what the samplers
/// below compare against. The colors are gray, so red stands in for value.
const _baseRed = 0xE0;
const _highlightRed = 0xF5;

const _canvas = ValueKey('canvas');

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_canvas));
  late Uint8List out;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    out = Uint8List.fromList(data!.buffer.asUint8List());
    image.dispose();
  });
  return out;
}

int _red(Uint8List rgba, int rowWidth, int x, int y) =>
    rgba[(y * rowWidth + x) * 4];

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(child: RepaintBoundary(key: _canvas, child: child)),
      ),
    );

Widget _shimmer(
  Widget child, {
  ShimmerDirection direction = ShimmerDirection.ltr,
  bool enabled = true,
  Duration period = const Duration(milliseconds: 1500),
}) =>
    Shimmer.fromColors(
      baseColor: _base,
      highlightColor: _highlight,
      direction: direction,
      enabled: enabled,
      period: period,
      child: child,
    );

/// Optionally wraps [child] in a scope, so a test can render the same subject
/// both ways and compare.
Widget _maybeScoped(Widget child, {required bool scoped, Duration? period}) =>
    scoped
        ? ShimmerScope(
            period: period ?? const Duration(milliseconds: 1500),
            child: child,
          )
        : child;

void main() {
  group('one band instead of one band per widget', () {
    // Three 40 px squares pinned inside a 600 px row: at the far left, at the
    // centre, at the far right. Half way through a sweep the centre of the
    // scope carries the highlight, so under a scope only the middle square is
    // lit. Without one, each square runs its own sweep across its own 40 px
    // and all three peak at once.
    const width = 600.0;
    const height = 40.0;
    const squares = [0.0, 280.0, 560.0];

    Widget subject({required bool scoped}) => _host(
          _maybeScoped(
            scoped: scoped,
            SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  for (final left in squares)
                    Positioned(
                      left: left,
                      top: 0,
                      child: _shimmer(
                        const SkeletonBox(width: 40, height: height),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

    /// The centre pixel of each square, half way through one sweep.
    Future<List<int>> centresAtMidSweep(
      WidgetTester tester, {
      required bool scoped,
    }) async {
      await tester.pumpWidget(subject(scoped: scoped));
      await tester.pump(const Duration(milliseconds: 750));
      final rgba = await _pixels(tester);
      final reds = [
        for (final left in squares)
          _red(rgba, width.round(), (left + 20).round(), 20),
      ];
      await tester.pumpWidget(const SizedBox());
      return reds;
    }

    testWidgets('without a scope every widget peaks at the same moment',
        (tester) async {
      final reds = await centresAtMidSweep(tester, scoped: false);
      for (final red in reds) {
        expect(red, closeTo(_highlightRed, 2));
      }
    });

    testWidgets('with a scope only the widget under the band is lit',
        (tester) async {
      final reds = await centresAtMidSweep(tester, scoped: true);
      expect(reds[0], closeTo(_baseRed, 2),
          reason: 'left square, band is not here');
      expect(reds[1], closeTo(_highlightRed, 2), reason: 'centre square');
      expect(reds[2], closeTo(_baseRed, 2), reason: 'right square');
    });
  });

  group('the sweep is continuous across neighbouring widgets', () {
    // Two boxes meeting at x = 150 inside a 200 px scope. A quarter of the way
    // through a sweep the highlight sits on a box's left edge, so an unscoped
    // pair has base on one side of the seam and the peak on the other. One
    // gradient over both cannot do that.
    const width = 200.0;
    const height = 30.0;

    Widget subject({required bool scoped}) => _host(
          _maybeScoped(
            scoped: scoped,
            SizedBox(
              width: width,
              height: height,
              child: Row(
                children: [
                  _shimmer(const SkeletonBox(width: 150, height: height)),
                  _shimmer(const SkeletonBox(width: 50, height: height)),
                ],
              ),
            ),
          ),
        );

    Future<int> seamJump(WidgetTester tester, {required bool scoped}) async {
      await tester.pumpWidget(subject(scoped: scoped));
      await tester.pump(const Duration(milliseconds: 375)); // a quarter sweep
      final rgba = await _pixels(tester);
      final jump = (_red(rgba, width.round(), 150, 15) -
              _red(rgba, width.round(), 149, 15))
          .abs();
      await tester.pumpWidget(const SizedBox());
      return jump;
    }

    testWidgets('unscoped neighbours break at the seam', (tester) async {
      expect(await seamJump(tester, scoped: false), greaterThan(6));
    });

    testWidgets('a scope carries one gradient over both', (tester) async {
      expect(await seamJump(tester, scoped: true), lessThanOrEqualTo(2));
    });
  });

  group('the band is anchored to the scope, not to the widget', () {
    // A row parked so its centre sits on the highlight, then scrolled 135 px
    // up. Anchored to the scope, the row moves out of the band and goes back
    // to base. Anchored to itself, it carries the band along and nothing
    // changes. The period is long enough that the frame spent scrolling moves
    // the clock by 0.016%, so the difference is the scroll and not the time.
    const viewport = 300.0;
    const rowHeight = 24.0;
    const period = Duration(seconds: 100);
    const scrollBy = 135.0;

    Future<(int before, int after)> rowRedAcrossScroll(
      WidgetTester tester, {
      required bool scoped,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        _maybeScoped(
          scoped: scoped,
          period: period,
          SizedBox(
            width: 200,
            height: viewport,
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 150 - rowHeight / 2),
                  _shimmer(
                    const SkeletonBox(width: 200, height: rowHeight),
                    direction: ShimmerDirection.ttb,
                    // Set on both, since only one of them is read: under a
                    // scope the scope's period wins, and the unscoped arm of
                    // this comparison has to run on the same clock to be a
                    // comparison at all.
                    period: period,
                  ),
                  const SizedBox(height: 600),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump(period ~/ 2);
      final before = _red(await _pixels(tester), 200, 100, 150);

      controller.jumpTo(scrollBy);
      await tester.pump(const Duration(milliseconds: 16));
      final after =
          _red(await _pixels(tester), 200, 100, (150 - scrollBy).round());

      await tester.pumpWidget(const SizedBox());
      return (before, after);
    }

    testWidgets('unscoped, the band travels with the row', (tester) async {
      final (before, after) = await rowRedAcrossScroll(tester, scoped: false);
      expect(before, closeTo(_highlightRed, 2));
      expect(after, closeTo(before, 2), reason: 'the row carries its own band');
    });

    testWidgets('scoped, the row moves through a band that stays put',
        (tester) async {
      final (before, after) = await rowRedAcrossScroll(tester, scoped: true);
      expect(before, closeTo(_highlightRed, 2), reason: 'parked on the band');
      expect(after, closeTo(_baseRed, 3), reason: 'scrolled out of the band');
    });
  });

  group('enabled: false under a running scope', () {
    // Freezing one widget out of a shared clock takes two things, and each
    // one hides the other's absence: the widget stops listening, so it stops
    // repainting, and it also remembers where the band was, so a repaint it
    // did not ask for paints the same frame. Testing them together passes
    // with either one removed, so they get a test each.
    const width = 400.0;
    const left = ValueKey('left');
    const right = ValueKey('right');

    Widget subject({required bool leftEnabled}) => _host(
          ShimmerScope(
            child: SizedBox(
              width: width,
              height: 40,
              child: Row(
                children: [
                  KeyedSubtree(
                    key: left,
                    child: _shimmer(const SkeletonBox(width: 200, height: 40),
                        enabled: leftEnabled),
                  ),
                  KeyedSubtree(
                    key: right,
                    child: _shimmer(const SkeletonBox(width: 200, height: 40)),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('it holds its band even when something else repaints it',
        (tester) async {
      // Both start running, so the one that stops has a band on it to hold
      // rather than the blank frame it would have kept from t = 0.
      await tester.pumpWidget(subject(leftEnabled: true));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(subject(leftEnabled: false));
      await tester.pump();
      final atFreeze = await _pixels(tester);

      await tester.pump(const Duration(milliseconds: 400));
      // Rebuild the tree while the widget is frozen. A parent rebuilding for
      // its own reasons is the case where holding the band takes more than
      // just declining to repaint.
      await tester.pumpWidget(subject(leftEnabled: false));
      await tester.pump();
      final later = await _pixels(tester);

      int sample(Uint8List rgba, int x) => _red(rgba, width.round(), x, 20);
      expect(sample(later, 100), sample(atFreeze, 100),
          reason: 'the disabled widget should still show the band it froze on');
      expect(sample(later, 300), isNot(sample(atFreeze, 300)),
          reason: 'its neighbour should have kept sweeping');
      // A frozen frame of flat base would satisfy the first check on its own.
      expect(sample(atFreeze, 100), isNot(closeTo(_baseRed, 1)),
          reason: 'the frozen frame should be mid-band, not blank');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it stops rebuilding while its neighbour keeps going',
        (tester) async {
      await tester.pumpWidget(subject(leftEnabled: false));
      await tester.pump(const Duration(milliseconds: 100));

      ShaderMask maskUnder(Key key) => tester.widget<ShaderMask>(
            find.descendant(
                of: find.byKey(key), matching: find.byType(ShaderMask)),
          );
      final frozenBefore = maskUnder(left);
      final runningBefore = maskUnder(right);

      await tester.pump(const Duration(milliseconds: 100));

      // An element that did not rebuild is still holding the widget it built
      // last time, so identity is the question here rather than equality.
      expect(identical(maskUnder(left), frozenBefore), isTrue,
          reason: 'a frozen widget has nothing to redraw once per frame');
      expect(identical(maskUnder(right), runningBefore), isFalse,
          reason: 'a running one is rebuilt by the clock it listens to');

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('the shared clock stops when the platform disables animations',
      (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ShimmerScope(
            child: _shimmer(const SkeletonBox(width: 100, height: 20)),
          ),
        ),
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('the shared clock stops after the requested number of loops',
      (tester) async {
    await tester.pumpWidget(_host(
      ShimmerScope(
        loop: 2,
        period: const Duration(milliseconds: 100),
        child: _shimmer(const SkeletonBox(width: 100, height: 20)),
      ),
    ));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('enabled: false on the scope holds every widget under it',
      (tester) async {
    await tester.pumpWidget(_host(
      ShimmerScope(
        enabled: false,
        child: _shimmer(const SkeletonBox(width: 100, height: 20)),
      ),
    ));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_host(
      ShimmerScope(
        child: _shimmer(const SkeletonBox(width: 100, height: 20)),
      ),
    ));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a widget taken out of a scope gets its own clock back',
      (tester) async {
    final shimmer = _shimmer(const SkeletonBox(width: 100, height: 20));

    await tester.pumpWidget(_host(ShimmerScope(child: shimmer)));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(_host(shimmer));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'it should be running on a clock of its own now');

    await tester.pumpWidget(_host(ShimmerScope(child: shimmer)));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the same widget carried in and out of a scope keeps sweeping',
      (tester) async {
    // The case above rebuilds the widget, which quietly hands the problem to a
    // fresh State. A GlobalKey does not: the same State is reparented, so it
    // has to give its ticker up to the scope and build another one afterwards.
    // That is what a single-ticker mixin would refuse to do, and getting it
    // wrong leaves a widget with no clock at all rather than a broken-looking
    // one.
    final key = GlobalKey();
    Widget subject({required bool scoped}) => _host(
          _maybeScoped(
            scoped: scoped,
            SizedBox(
              width: 100,
              height: 20,
              child: Shimmer.fromColors(
                key: key,
                baseColor: _base,
                highlightColor: _highlight,
                child: const SkeletonBox(width: 100, height: 20),
              ),
            ),
          ),
        );

    Future<void> expectSweeping(String where) async {
      final before = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(await _pixels(tester), isNot(before), reason: 'sweeping $where');
    }

    await tester.pumpWidget(subject(scoped: true));
    final state = key.currentState;
    await expectSweeping('inside the scope');

    await tester.pumpWidget(subject(scoped: false));
    await tester.pump();
    expect(key.currentState, same(state),
        reason: 'the point of this test is that the State survived the move');
    await expectSweeping('after being moved out');

    await tester.pumpWidget(subject(scoped: true));
    await tester.pump();
    expect(key.currentState, same(state));
    await expectSweeping('after being moved back in');

    await tester.pumpWidget(const SizedBox());
  });

  group('a Shimmer with no scope above it', () {
    // The whole feature rests on this: adding scopes to the package must not
    // move a single pixel for anybody who does not use one. _LegacyShimmer
    // below is a transcription of the implementation from before scopes
    // existed, and it renders in the same tree on the same clock, so the two
    // can be compared frame by frame rather than against a stored image.
    const mine = ValueKey('mine');
    const legacy = ValueKey('legacy');
    const period = Duration(milliseconds: 1600);

    Future<Uint8List> capture(WidgetTester tester, Key key) async {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      late Uint8List out;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        out = Uint8List.fromList(data!.buffer.asUint8List());
        image.dispose();
      });
      return out;
    }

    for (final direction in ShimmerDirection.values) {
      testWidgets('renders what it rendered before scopes: ${direction.name}',
          (tester) async {
        Widget subject(Key key, Widget Function(Widget) wrap) =>
            RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 240,
                height: 72,
                child: wrap(const _Subject()),
              ),
            );

        await tester.pumpWidget(_host(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            subject(
                mine,
                (child) => Shimmer.fromColors(
                      baseColor: _base,
                      highlightColor: _highlight,
                      direction: direction,
                      period: period,
                      child: child,
                    )),
            subject(
                legacy,
                (child) => _LegacyShimmer(
                      direction: direction,
                      period: period,
                      child: child,
                    )),
          ],
        )));

        for (var i = 0; i < 8; i++) {
          if (i > 0) await tester.pump(period ~/ 8);
          expect(await capture(tester, mine), await capture(tester, legacy),
              reason: 'frame $i of a ${direction.name} sweep');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  testWidgets('a scope the size of the widget changes nothing', (tester) async {
    // The scoped path resolves an offset and translates the sweep window by
    // it. Where that offset is zero and the boxes match, the translation has
    // to come out as the identity, and the two renders have to be the same
    // pixels.
    Future<Uint8List> render({required bool scoped}) async {
      await tester.pumpWidget(_host(
        _maybeScoped(
          scoped: scoped,
          SizedBox(
            width: 200,
            height: 40,
            child: _shimmer(const SkeletonBox(width: 200, height: 40)),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      final rgba = await _pixels(tester);
      await tester.pumpWidget(const SizedBox());
      return rgba;
    }

    expect(await render(scoped: true), await render(scoped: false));
  });
}

/// The placeholder layout both implementations are asked to paint.
class _Subject extends StatelessWidget {
  const _Subject();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SkeletonCircle(size: 48),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 110, height: 14),
                  SizedBox(height: 10),
                  SkeletonLine(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
}

/// skeleton_shimmer 1.0.1's `Shimmer`, transcribed.
///
/// Deliberately a copy rather than a call into the package: its job is to keep
/// saying what the old code said after the real one changes. Only the parts
/// that reach the screen are here, since the comparison is on pixels.
class _LegacyShimmer extends StatefulWidget {
  const _LegacyShimmer({
    required this.child,
    required this.direction,
    required this.period,
  });

  final Widget child;
  final ShimmerDirection direction;
  final Duration period;

  @override
  State<_LegacyShimmer> createState() => _LegacyShimmerState();
}

class _LegacyShimmerState extends State<_LegacyShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);

  late final Gradient _gradient = LinearGradient(
    begin: switch (widget.direction) {
      ShimmerDirection.ltr || ShimmerDirection.rtl => Alignment.centerLeft,
      ShimmerDirection.ttb || ShimmerDirection.btt => Alignment.topCenter,
    },
    end: switch (widget.direction) {
      ShimmerDirection.ltr || ShimmerDirection.rtl => Alignment.centerRight,
      ShimmerDirection.ttb || ShimmerDirection.btt => Alignment.bottomCenter,
    },
    colors: const [_base, _base, _highlight, _base, _base],
    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isAnimating) _controller.forward(from: _controller.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => _gradient.createShader(
              _paintRect(bounds, _controller.value),
              textDirection: Directionality.maybeOf(context),
            ),
            child: child,
          ),
          child: RepaintBoundary(child: widget.child),
        ),
      );

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
