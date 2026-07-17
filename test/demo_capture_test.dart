// Captures the frames for doc/demo.gif. Not part of the regular test
// suite; run explicitly with:
//
//   flutter test --tags demo test/demo_capture_test.dart
//
// Frames are written to /tmp/demo_skeleton_shimmer/frame_NNN.png and
// assembled with ffmpeg (see doc/demo.gif in the README).
@Tags(['demo'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

const _captureKey = ValueKey('demo-capture');
final _frameDir = Directory('/tmp/demo_skeleton_shimmer');
int _frameIndex = 0;

void main() {
  testWidgets('captures shimmer demo frames', (tester) async {
    if (_frameDir.existsSync()) _frameDir.deleteSync(recursive: true);
    _frameDir.createSync(recursive: true);

    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await _loadRealFonts(tester);

    final loaded = ValueNotifier(false);
    addTearDown(loaded.dispose);
    await tester.pumpWidget(_DemoApp(loaded: loaded));

    // One full 1.5 s sweep in 60 ms steps: 25 frames.
    await _capture(tester);
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      await _capture(tester);
    }

    // Content arrives: 5 frames across the 240 ms switcher fade.
    loaded.value = true;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      await _capture(tester);
    }
  });
}

/// The default test font renders every glyph as a box; load the SDK's
/// bundled Roboto and MaterialIcons so the captures look like a real app.
Future<void> _loadRealFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fonts = _materialFontsDir();
    Future<ByteData> read(String name) async =>
        ByteData.sublistView(await File('${fonts.path}/$name').readAsBytes());
    final roboto = FontLoader('Roboto')
      ..addFont(read('Roboto-Regular.ttf'))
      ..addFont(read('Roboto-Medium.ttf'))
      ..addFont(read('Roboto-Bold.ttf'));
    await roboto.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(read('MaterialIcons-Regular.otf'));
    await icons.load();
  });
}

Directory _materialFontsDir() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fonts = Directory('${dir.path}/bin/cache/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('material_fonts not found above $dir');
    }
    dir = parent;
  }
}

Future<void> _capture(WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  final name = 'frame_${'$_frameIndex'.padLeft(3, '0')}.png';
  _frameIndex++;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${_frameDir.path}/$name')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _DemoApp extends StatelessWidget {
  const _DemoApp({required this.loaded});

  final ValueNotifier<bool> loaded;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0EA5E9),
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Inbox'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.search),
              ),
            ],
          ),
          body: ValueListenableBuilder(
            valueListenable: loaded,
            builder: (context, isLoaded, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: isLoaded ? const _LoadedFeed() : const _SkeletonFeed(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonFeed extends StatelessWidget {
  const _SkeletonFeed();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SkeletonBox(height: 120),
          const SizedBox(height: 16),
          for (var i = 0; i < 5; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SkeletonCircle(size: 48),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 180, height: 16),
                        SizedBox(height: 8),
                        SkeletonLine(width: 320, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  SkeletonLine(width: 40, height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadedFeed extends StatelessWidget {
  const _LoadedFeed();

  static const _conversations = [
    (
      'ML',
      'Maya Lindqvist',
      'The onboarding flow is ready for review',
      '09:41'
    ),
    ('RP', 'Ravi Patel', 'Shipped the dark theme toggle to beta', '09:12'),
    ('BB', 'Build Bot', 'Pipeline #482 passed on main', '08:56'),
    ('ED', 'Elif Demir', 'Can we move standup to 10:30 tomorrow?', '08:47'),
    ('JW', 'Jonas Weber', 'Uploaded the Q3 usage report', '08:20'),
  ];

  static const _avatarColors = [
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF475569),
    Color(0xFFDB2777),
    Color(0xFFD97706),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 120,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF0369A1), Color(0xFF0EA5E9)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Team workspace',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '5 unread conversations',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _conversations.length; i++)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: _avatarColors[i],
              foregroundColor: Colors.white,
              child: Text(_conversations[i].$1),
            ),
            title: Text(
              _conversations[i].$2,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_conversations[i].$3),
            trailing: Text(
              _conversations[i].$4,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
