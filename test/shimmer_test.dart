import 'package:flutter/material.dart';
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
  testWidgets('paints a shader mask over the child and animates',
      (tester) async {
    await tester.pumpWidget(_app(_shimmer()));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(SkeletonBox), findsOneWidget);
    // An animation is running.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // Advancing time keeps it running (loop: 0 repeats forever).
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // Never settles; stop the test cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('enabled: false renders the child without a shader',
      (tester) async {
    await tester.pumpWidget(_app(_shimmer(enabled: false)));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonBox), findsOneWidget);
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
    // Still masked (colors match the skeleton) but not animating.
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('toggling enabled restarts and stops the sweep', (tester) async {
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

  testWidgets('custom gradient constructor works', (tester) async {
    await tester.pumpWidget(_app(
      const Shimmer(
        gradient:
            LinearGradient(colors: [Color(0xFF111111), Color(0xFF999999)]),
        child: SkeletonLine(width: 80),
      ),
    ));
    expect(find.byType(ShaderMask), findsOneWidget);
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
