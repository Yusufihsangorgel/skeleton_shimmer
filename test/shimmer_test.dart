import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );

Widget _shimmer({
  int loop = 0,
  bool enabled = true,
  ShimmerDirection direction = ShimmerDirection.ltr,
  Duration period = const Duration(milliseconds: 1500),
}) =>
    Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      loop: loop,
      enabled: enabled,
      direction: direction,
      period: period,
      child: const SkeletonBox(width: 100, height: 20),
    );

void main() {
  testWidgets('masks the child with srcIn and animates', (tester) async {
    await tester.pumpWidget(_app(_shimmer()));
    expect(find.byType(SkeletonBox), findsOneWidget);
    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.srcIn);
    // An animation is running.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // Advancing time keeps it running (loop: 0 repeats forever).
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // Never settles; stop the test cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('band geometry matches the original shimmer package',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_app(
      Center(
        child: RepaintBoundary(
          key: key,
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFE0E0E0),
            highlightColor: const Color(0xFFF5F5F5),
            child: Container(
                width: 200, height: 40, color: const Color(0xFF000000)),
          ),
        ),
      ),
    ));

    Future<int> bandPixelsOnCenterline() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late final ByteData bytes;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        bytes = (await image.toByteData())!;
        image.dispose();
      });
      const width = 200;
      const y = 20;
      var count = 0;
      for (var x = 0; x < width; x++) {
        final red = bytes.getUint8((y * width + x) * 4);
        if ((red - 0xE0).abs() > 3) count++;
      }
      return count;
    }

    // t = 0: the highlight window is fully offscreen, centerline is base.
    expect(await bandPixelsOnCenterline(), 0);

    // t = 0.5: the band is centered and wide. The original's 3x-width
    // paint window yields a band spanning most of the child (measured
    // measured ~0.75 x width); the pre-fix 1x window gave ~0.28 x width.
    await tester.pump(const Duration(milliseconds: 750));
    expect(await bandPixelsOnCenterline(), greaterThan(120));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('enabled: false keeps the mask but stops the sweep',
      (tester) async {
    await tester.pumpWidget(_app(_shimmer(enabled: false)));
    // Parity with the shimmer package: the gradient still masks the
    // child; only the motion stops.
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('stops after the requested number of loops', (tester) async {
    await tester.pumpWidget(
        _app(_shimmer(loop: 2, period: const Duration(milliseconds: 100))));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('freezes when the platform disables animations', (tester) async {
    await tester.pumpWidget(_app(_shimmer(), disableAnimations: true));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a finished loop does not replay when motion settings change',
      (tester) async {
    // Regression: MediaQuery changes used to restart a completed loop.
    await tester.pumpWidget(
        _app(_shimmer(loop: 1, period: const Duration(milliseconds: 100))));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(
      _app(_shimmer(loop: 1, period: const Duration(milliseconds: 100)),
          disableAnimations: true),
    );
    await tester.pump();
    await tester.pumpWidget(
      _app(_shimmer(loop: 1, period: const Duration(milliseconds: 100))),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('toggling enabled stops and resumes the sweep', (tester) async {
    await tester.pumpWidget(_app(_shimmer(enabled: true)));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(_app(_shimmer(enabled: false)));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_app(_shimmer(enabled: true)));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('supports all four directions', (tester) async {
    for (final direction in ShimmerDirection.values) {
      await tester.pumpWidget(_app(_shimmer(direction: direction)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), findsOneWidget,
          reason: 'direction $direction');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('uses a custom gradient exactly as given', (tester) async {
    const gradient =
        LinearGradient(colors: [Color(0xFF111111), Color(0xFF999999)]);
    await tester.pumpWidget(_app(
      const Shimmer(
        gradient: gradient,
        child: SkeletonLine(width: 80),
      ),
    ));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(
      tester.widget<Shimmer>(find.byType(Shimmer)).gradient,
      same(gradient),
    );
    await tester.pumpWidget(const SizedBox());
  });

  group('skeleton primitives', () {
    testWidgets('render with requested geometry', (tester) async {
      await tester.pumpWidget(_app(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 120, height: 80),
            SkeletonCircle(size: 40),
            SkeletonLine(width: 200),
          ],
        ),
      ));
      expect(
          tester.getSize(find.byType(SkeletonBox).first), const Size(120, 80));
      expect(tester.getSize(find.byType(SkeletonCircle)), const Size(40, 40));
      expect(tester.getSize(find.byType(SkeletonLine)).height, 14);
    });
  });
}
