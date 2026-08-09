// Shared helpers for the figure-capture tests (test/*_capture_test.dart).
// Not a test itself: `flutter test` only picks up files ending in _test.dart.
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the SDK's bundled Roboto and MaterialIcons into the test binding.
///
/// The default test font draws every glyph as a filled box, which is fine for
/// assertions and useless for a figure that ends up in the README.
Future<void> loadMaterialFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fonts = materialFontsDir();
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

/// Where [drawText] puts the string relative to the x it is given.
enum TextAnchor { left, center, right }

/// Draws one line of text, vertically centred on [centerY].
///
/// The figures are laid out from a handful of constants rather than a widget
/// tree, so this is the labelling primitive all of them share.
void drawText(
  Canvas canvas,
  String text, {
  required TextStyle style,
  required double x,
  required double centerY,
  TextAnchor anchor = TextAnchor.left,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (anchor) {
    TextAnchor.left => x,
    TextAnchor.center => x - painter.width / 2,
    TextAnchor.right => x - painter.width,
  };
  painter.paint(canvas, Offset(dx, centerY - painter.height / 2));
  painter.dispose();
}

/// Walks up from the running Dart executable to the SDK's font cache, so the
/// path does not have to be configured per machine.
Directory materialFontsDir() {
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
