// Regenerates doc/reduced-motion.png: the same skeleton card at four points
// of one sweep, under the ambient MediaQuery on the left and under
// `disableAnimations: true` on the right.
//
// The figure is the evidence for a claim the README makes, so the run asserts
// the claim before it writes the file: the left column must change between
// frames and the right column must not. A figure that quietly stopped proving
// anything would be worse than no figure.
//
// Not part of the regular suite. Run it through the committed script, which
// points the output at doc/:
//
//   tool/capture_reduced_motion.sh
//
// or directly, which writes to the system temp dir instead:
//
//   flutter test --tags demo test/reduced_motion_capture_test.dart
@Tags(['demo'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

import 'doc_capture_support.dart';

/// Environment variable the capture script uses to redirect the output into
/// the repository. Unset, the figure lands in the system temp dir: a test run
/// should not touch tracked files unless it was asked to.
const _outputVariable = 'SKELETON_SHIMMER_DOC_OUT';

const _cardWidth = 250.0;
const _cardHeight = 88.0;
const _gutter = 16.0;

/// One sweep, sampled at four evenly spaced points.
const _period = Duration(milliseconds: 1500);
const _step = Duration(milliseconds: 375);

/// Rasterisation factor for both the captures and the composed figure.
const _ratio = 2.0;

const _captureKey = ValueKey('reduced-motion-pair');

void main() {
  testWidgets('captures the reduced-motion figure', (tester) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await loadMaterialFonts(tester);

    await tester.pumpWidget(const _Pair());
    final frames = [await _capture(tester)];
    for (var i = 0; i < 3; i++) {
      await tester.pump(_step);
      frames.add(await _capture(tester));
    }

    // At t = 0 the highlight window is still fully offscreen, so both columns
    // start out identical. That is exactly why the figure needs four rows: a
    // single frame could not tell a frozen sweep from a sweep between bands.
    expect(listEquals(frames[0].left, frames[0].right), isTrue,
        reason: 'both columns should be plain base color at t = 0');
    // Mid-sweep they must differ, or the equality checks below would be
    // measuring two frozen cards and reporting success.
    expect(listEquals(frames[2].left, frames[2].right), isFalse,
        reason: 'the animating column should carry a band at t = 750 ms');

    for (var i = 1; i < frames.length; i++) {
      expect(listEquals(frames[i].left, frames[0].left), isFalse,
          reason: 'left column, frame $i: the sweep should have moved');
      expect(listEquals(frames[i].right, frames[0].right), isTrue,
          reason: 'right column, frame $i: the sweep should be frozen');
    }

    // Composing and encoding are real async work in dart:ui, so they belong
    // inside runAsync. Awaiting them straight from the test body leaves real
    // futures pending in the fake-async zone, and the runner then hangs after
    // this test instead of moving on to the next file.
    await tester.runAsync(() async {
      final png = await _compose(frames);
      final file = File(_outputPath());
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(png);
      debugPrint('wrote ${file.path} (${png.length} bytes)');
    });
    for (final frame in frames) {
      frame.image.dispose();
    }
  });
}

String _outputPath() {
  final override = Platform.environment[_outputVariable];
  if (override != null && override.isNotEmpty) return override;
  return '${Directory.systemTemp.path}/skeleton_shimmer_reduced_motion.png';
}

/// One captured frame: the image to draw, plus the two card regions kept
/// separately so the run can compare them.
class _Frame {
  _Frame(this.image, this.left, this.right);

  final ui.Image image;
  final Uint8List left;
  final Uint8List right;
}

Future<_Frame> _capture(WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  late final _Frame frame;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData();
    final rgba = data!.buffer.asUint8List();
    final cardWidth = (_cardWidth * _ratio).round();
    final rightStart = ((_cardWidth + _gutter) * _ratio).round();
    frame = _Frame(
      image,
      _slice(rgba, image.width, image.height, 0, cardWidth),
      _slice(rgba, image.width, image.height, rightStart, cardWidth),
    );
  });
  return frame;
}

/// Copies the `width` pixel columns starting at `x0` out of a raw RGBA buffer.
Uint8List _slice(
    Uint8List rgba, int imageWidth, int imageHeight, int x0, int width) {
  final out = Uint8List(width * imageHeight * 4);
  for (var y = 0; y < imageHeight; y++) {
    out.setRange(
        y * width * 4, (y + 1) * width * 4, rgba, (y * imageWidth + x0) * 4);
  }
  return out;
}

/// Stacks the frames into one labelled figure and encodes it as PNG.
///
/// The whole canvas is drawn in logical pixels and scaled once, so the layout
/// numbers below can be read against the widths above.
Future<Uint8List> _compose(List<_Frame> frames) async {
  const pad = 20.0;
  const labelWidth = 84.0;
  const headerHeight = 26.0;
  const rowGap = 10.0;
  const footerHeight = 26.0;
  const pairWidth = _cardWidth * 2 + _gutter;
  const width = pad + labelWidth + pairWidth + pad;
  const height =
      pad + headerHeight + _cardHeight * 4 + rowGap * 3 + footerHeight + pad;
  const pairX = pad + labelWidth;

  const header = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF0F172A),
  );
  const label = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    color: Color(0xFF64748B),
  );
  const footer = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 11,
    color: Color(0xFF94A3B8),
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(_ratio);
  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFF8FAFC));

  drawText(canvas, 'Default',
      style: header,
      x: pairX + _cardWidth / 2,
      centerY: pad + headerHeight / 2,
      anchor: TextAnchor.center);
  drawText(canvas, 'disableAnimations: true',
      style: header,
      x: pairX + _cardWidth * 1.5 + _gutter,
      centerY: pad + headerHeight / 2,
      anchor: TextAnchor.center);

  for (var i = 0; i < frames.length; i++) {
    final top = pad + headerHeight + i * (_cardHeight + rowGap);
    drawText(canvas, 't = ${(_step * i).inMilliseconds} ms',
        style: label,
        x: pad + labelWidth - 14,
        centerY: top + _cardHeight / 2,
        anchor: TextAnchor.right);
    final image = frames[i].image;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(pairX, top, pairWidth, _cardHeight),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  drawText(
      canvas,
      'One ${_period.inMilliseconds} ms sweep, sampled every '
      '${_step.inMilliseconds} ms. Same widget, same frame, same colors.',
      style: footer,
      x: pairX,
      centerY: height - pad - footerHeight / 2);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (width * _ratio).round(), (height * _ratio).round());
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

/// The captured subject: two identical cards, one told the platform wants no
/// animation.
class _Pair extends StatelessWidget {
  const _Pair();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      // A full reset, deliberately: the figure must not inherit whatever
      // accessibility settings the machine running the capture happens to
      // have, or the left card could come out frozen too. In app code this
      // would be the bug the figure is about; see example/lib/main.dart.
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: RepaintBoundary(
            key: _captureKey,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Card(),
                const SizedBox(width: _gutter),
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: const _Card(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Shimmer.fromColors(
        // Colors.grey.shade300 and .shade100, as in the README snippet,
        // spelled out so the figure does not depend on Material.
        baseColor: const Color(0xFFE0E0E0),
        highlightColor: const Color(0xFFF5F5F5),
        period: _period,
        child: const Row(
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
      ),
    );
  }
}
