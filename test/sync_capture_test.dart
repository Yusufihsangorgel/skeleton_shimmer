// Regenerates doc/sync.png: a dashboard skeleton drawn twice at four points
// of one sweep, with a Shimmer per card on the left and one ShimmerScope over
// all of them on the right.
//
// The figure is the evidence for the README's opening claim, so the run
// asserts the claim before it writes the file. On the left every card has to
// peak at the same moment, because each one is sweeping its own width. On the
// right only the card the band is crossing may be lit. A figure that stopped
// proving that would be worse than no figure.
//
// Not part of the regular suite. Run it through the committed script, which
// points the output at doc/:
//
//   tool/build_media.sh
//
// or directly, which writes to the system temp dir instead:
//
//   flutter test --tags demo test/sync_capture_test.dart
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

/// Environment variable the build script uses to redirect the output into the
/// repository. Unset, the figure lands in the system temp dir: a test run
/// should not touch tracked files unless it was asked to.
const _outputVariable = 'SKELETON_SHIMMER_SYNC_OUT';

const _columnWidth = 340.0;
const _tileWidth = 100.0;
const _tileHeight = 64.0;
const _tileGap = 20.0;
const _rowGap = 12.0;
const _cardHeight = 78.0;
const _cardPadding = 10.0;
const _columnHeight = _tileHeight + _rowGap + _cardHeight;
const _gutter = 20.0;

/// Left edges of the three tiles, and so the x of their centres plus half a
/// tile. The middle one sits on the centre of the column on purpose: that is
/// where a sweep across the whole column has its highlight half way through.
const _tileLefts = [0.0, _tileWidth + _tileGap, 2 * (_tileWidth + _tileGap)];

const _period = Duration(milliseconds: 1500);
const _step = Duration(milliseconds: 375);
const _ratio = 2.0;

/// Slate 400 and slate 100, rather than the README's grey 300 and grey 100.
///
/// The band's position is what this figure is about, and a 21-step difference
/// between base and highlight is legible in motion and close to invisible in a
/// still. These two are 93 steps apart. The geometry is untouched; the caption
/// says as much.
const _baseRed = 0x94;
const _highlightRed = 0xF1;
const _base = Color(0xFF94A3B8);
const _highlight = Color(0xFFF1F5F9);
const _surface = Color(0xFFFFFFFF);
const _page = Color(0xFFE2E8F0);

/// A pixel counts as sitting under the band once it is within a tenth of the
/// way back from the highlight towards the base. Derived rather than picked,
/// so changing the palette cannot quietly turn the check into a formality.
const _lit = _highlightRed - (_highlightRed - _baseRed) ~/ 10;

/// How far off the band the outer tiles have to be for the figure to be worth
/// printing: a third of the distance between the two colors.
const _clearlyOffTheBand = (_highlightRed - _baseRed) ~/ 3;

const _captureKey = ValueKey('sync-pair');

void main() {
  testWidgets('captures the shared-sweep figure', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await loadMaterialFonts(tester);

    await tester.pumpWidget(const _Pair());
    final frames = [await _capture(tester)];
    for (var i = 0; i < 3; i++) {
      await tester.pump(_step);
      frames.add(await _capture(tester));
    }

    // Frame 2 is t = 750 ms, half way through the sweep: the highlight is on
    // the centre of whatever box it is crossing. Sampled down the middle of
    // each tile's first line, which spans the tile.
    const lineY = 24;
    final mid = frames[2];
    final perWidget = [
      for (final x in _tileCentres) mid.redAt(x, lineY, mid.left)
    ];
    final scoped = [
      for (final x in _tileCentres) mid.redAt(x, lineY, mid.right)
    ];

    final spread =
        perWidget.reduce(_max) - perWidget.reduce((a, b) => a < b ? a : b);
    expect(spread, lessThanOrEqualTo(2),
        reason: 'a Shimmer per card should light every card at once, '
            'got $perWidget');
    expect(perWidget[1], greaterThan(_lit),
        reason: 'and each of them at full highlight');

    expect(scoped[1], greaterThan(_lit),
        reason: 'the scoped middle tile is under the band, got $scoped');
    for (final outer in [scoped[0], scoped[2]]) {
      expect(scoped[1] - outer, greaterThanOrEqualTo(_clearlyOffTheBand),
          reason: 'the outer tiles should be well off the band, got $scoped');
    }

    // Positive controls. Without these the checks above could be measuring two
    // copies of one frozen picture and reporting success.
    expect(listEquals(mid.left, mid.right), isFalse,
        reason: 'the two columns must differ half way through the sweep');
    for (var i = 1; i < frames.length; i++) {
      expect(listEquals(frames[i].left, frames[0].left), isFalse,
          reason: 'left column, frame $i: the sweep should have moved');
      expect(listEquals(frames[i].right, frames[0].right), isFalse,
          reason: 'right column, frame $i: the sweep should have moved');
    }

    // Composing and encoding are real async work in dart:ui, so they belong
    // inside runAsync. Awaiting them straight from the test body leaves real
    // futures pending in the fake-async zone, and the runner then hangs after
    // this test instead of moving on.
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

int _max(int a, int b) => a > b ? a : b;

List<int> get _tileCentres =>
    [for (final left in _tileLefts) (left + _tileWidth / 2).round()];

String _outputPath() {
  final override = Platform.environment[_outputVariable];
  if (override != null && override.isNotEmpty) return override;
  return '${Directory.systemTemp.path}/skeleton_shimmer_sync.png';
}

/// One captured frame: the image to draw, plus each column's pixels kept
/// separately so the run can compare them.
class _Frame {
  _Frame(this.image, this.left, this.right);

  final ui.Image image;
  final Uint8List left;
  final Uint8List right;

  /// Red channel at a logical point inside one of the columns. The palette is
  /// gray, so red stands in for how lit that pixel is.
  int redAt(int x, int y, Uint8List column) {
    final stride = (_columnWidth * _ratio).round();
    final px = (x * _ratio).round();
    final py = (y * _ratio).round();
    return column[(py * stride + px) * 4];
  }
}

Future<_Frame> _capture(WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  late final _Frame frame;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData();
    final rgba = data!.buffer.asUint8List();
    final columnWidth = (_columnWidth * _ratio).round();
    final rightStart = ((_columnWidth + _gutter) * _ratio).round();
    frame = _Frame(
      image,
      _slice(rgba, image.width, image.height, 0, columnWidth),
      _slice(rgba, image.width, image.height, rightStart, columnWidth),
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
  const labelWidth = 78.0;
  const headerHeight = 26.0;
  const gap = 10.0;
  const footerHeight = 26.0;
  const pairWidth = _columnWidth * 2 + _gutter;
  const width = pad + labelWidth + pairWidth + pad;
  const height =
      pad + headerHeight + _columnHeight * 4 + gap * 3 + footerHeight + pad;
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
  canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height), Paint()..color = _page);

  drawText(canvas, 'A Shimmer per card',
      style: header,
      x: pairX + _columnWidth / 2,
      centerY: pad + headerHeight / 2,
      anchor: TextAnchor.center);
  drawText(canvas, 'One ShimmerScope over all of them',
      style: header,
      x: pairX + _columnWidth * 1.5 + _gutter,
      centerY: pad + headerHeight / 2,
      anchor: TextAnchor.center);

  for (var i = 0; i < frames.length; i++) {
    final top = pad + headerHeight + i * (_columnHeight + gap);
    drawText(canvas, 't = ${(_step * i).inMilliseconds} ms',
        style: label,
        x: pad + labelWidth - 14,
        centerY: top + _columnHeight / 2,
        anchor: TextAnchor.right);
    final image = frames[i].image;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(pairX, top, pairWidth, _columnHeight),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  drawText(
      canvas,
      'One ${_period.inMilliseconds} ms sweep, sampled every '
      '${_step.inMilliseconds} ms. Same cards, same frame, same colors. '
      'Contrast raised for print; the geometry is the default.',
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

/// The captured subject: the same dashboard skeleton twice, once with a
/// [Shimmer] around each card and once with one [ShimmerScope] around the lot.
class _Pair extends StatelessWidget {
  const _Pair();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      // A full reset, deliberately: the figure must not inherit whatever
      // accessibility settings the machine running the capture happens to
      // have, or both columns could come out frozen.
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: RepaintBoundary(
            key: _captureKey,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dashboard(),
                SizedBox(width: _gutter),
                ShimmerScope(period: _period, child: _Dashboard()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three stat tiles over a chart card and a legend card, each its own
/// [Shimmer]. This is what a builder-per-card loading screen looks like, and
/// it is the layout the scope changes: five boxes of four different widths at
/// four different offsets.
class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _columnWidth,
      height: _columnHeight,
      child: Column(
        children: [
          SizedBox(
            height: _tileHeight,
            child: Row(
              children: [
                _Card(width: _tileWidth, height: _tileHeight, lines: 2),
                SizedBox(width: _tileGap),
                _Card(width: _tileWidth, height: _tileHeight, lines: 2),
                SizedBox(width: _tileGap),
                _Card(width: _tileWidth, height: _tileHeight, lines: 2),
              ],
            ),
          ),
          SizedBox(height: _rowGap),
          Row(
            children: [
              _Card(width: 200, height: _cardHeight, lines: 3),
              SizedBox(width: 10),
              _Card(width: 130, height: _cardHeight, lines: 3),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.height,
    required this.lines,
  });

  final double width;
  final double height;
  final int lines;

  @override
  Widget build(BuildContext context) {
    // The surface sits outside the Shimmer on purpose. Inside it, srcIn would
    // sweep the card itself and the placeholders would stop being readable as
    // separate shapes.
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Shimmer.fromColors(
        baseColor: _base,
        highlightColor: _highlight,
        period: _period,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              // The first line runs the full width of the card, which is what
              // the run samples: a point in the gutter between two lines is
              // transparent and would read as unlit whatever the sweep did.
              SkeletonLine(
                width: i == 0
                    ? null
                    : (width - 2 * _cardPadding) * (0.85 - 0.25 * i),
                height: i == 0 ? 12 : 8,
                color: _base,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
