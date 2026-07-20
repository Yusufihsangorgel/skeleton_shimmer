import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _skeleton({String? semanticsLabel}) => Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      semanticsLabel: semanticsLabel,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonCircle(size: 40),
          SizedBox(height: 8),
          SkeletonLine(width: 200),
          SizedBox(height: 4),
          SkeletonBox(width: 120, height: 12),
        ],
      ),
    );

void main() {
  testWidgets('placeholders are not read as content', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_skeleton()));
    await tester.pump(const Duration(milliseconds: 16));

    // A skeleton screen is decoration standing in for content that has not
    // arrived. Without exclusion it is a row of empty containers a screen
    // reader user has to walk past.
    for (final entry in {
      'SkeletonBox': find.byType(SkeletonBox),
      'SkeletonCircle': find.byType(SkeletonCircle),
      'SkeletonLine': find.byType(SkeletonLine),
    }.entries) {
      expect(
        tester.getSemantics(entry.value.first).label,
        isEmpty,
        reason: '${entry.key} leaked into the semantics tree',
      );
    }
    handle.dispose();
  });

  testWidgets('a semanticsLabel announces the loading state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_skeleton(semanticsLabel: 'Yükleniyor')));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      tester.getSemantics(find.byType(Shimmer)),
      isSemantics(label: 'Yükleniyor', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('without a label nothing is announced', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_skeleton()));
    await tester.pump(const Duration(milliseconds: 16));

    // Silence is the honest default: the package cannot invent a localized
    // string, so it stays quiet rather than announcing English to everyone.
    expect(tester.getSemantics(find.byType(Shimmer)).label, isEmpty);
    handle.dispose();
  });

  testWidgets('the label survives the shimmer animating', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_skeleton(semanticsLabel: 'Loading posts')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      tester.getSemantics(find.byType(Shimmer)).label,
      'Loading posts',
    );
    handle.dispose();
  });

  testWidgets('the shapes still render', (tester) async {
    // Excluding semantics must not change what is drawn.
    await tester.pumpWidget(_host(_skeleton()));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(SkeletonCircle), findsOneWidget);
    expect(find.byType(SkeletonLine), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
  });
}
