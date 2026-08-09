# skeleton_shimmer

Two shimmers on a screen are two animations. Each one owns a clock and sweeps
its highlight across its own box. Five cards give you five highlights peaking
at the same instant rather than one band crossing the screen. `ShimmerScope`
puts every shimmer under it on one clock and one band, and changes nothing
else.

```dart
ShimmerScope(
  child: Column(
    children: [
      for (final card in cards)
        Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: card,
        ),
    ],
  ),
)
```

![The same five-card dashboard skeleton rendered twice at four points of one sweep. On the left each card has its own Shimmer and every card carries the highlight at the same moment. On the right one ShimmerScope covers all of them and a single band travels across the row, lighting the left card, then the middle, then the right](https://raw.githubusercontent.com/Yusufihsangorgel/skeleton_shimmer/main/doc/sync.png)

Each row is one frame of the same 1500 ms sweep. `tool/build_media.sh`
regenerates the figure, and the run behind it asserts the difference before it
writes the file: on the left the three tiles have to be equally lit, on the
right the two outer ones have to be well off the band.

## Install

```console
$ flutter pub add skeleton_shimmer
```

## The widget on its own

`Shimmer` wraps anything and sweeps a gradient over its opaque pixels.
`SkeletonBox`, `SkeletonCircle` and `SkeletonLine` are the shapes you put
under it.

```dart
Shimmer.fromColors(
  baseColor: Colors.grey.shade300,
  highlightColor: Colors.grey.shade100,
  child: const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonCircle(size: 48),
      SizedBox(height: 12),
      SkeletonLine(width: 220),
      SizedBox(height: 8),
      SkeletonLine(width: 160),
      SizedBox(height: 16),
      SkeletonBox(height: 120),
    ],
  ),
)
```

![A skeleton inbox: a header block and five rows of avatar and text placeholders with the highlight sweeping across, then the real conversations fading in](https://raw.githubusercontent.com/Yusufihsangorgel/skeleton_shimmer/main/doc/demo.webp)

## What a scope does and does not take over

The scope owns the clock: `period` and `loop` belong to it. Everything else
stays on each widget: its colors, its `direction`, its `enabled` flag, its
`semanticsLabel`. Turning one card off holds it on the band it was showing
while its neighbours keep going.

```dart
ShimmerScope(
  period: const Duration(milliseconds: 1200),
  child: ListView.builder(
    itemBuilder: (context, index) => Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      enabled: index != pinnedRow,
      child: SkeletonRow(index),
    ),
  ),
)
```

A row scrolling through a scope moves through the band rather than carrying a
copy of it along, because the offset is resolved during paint rather than at
build time.

## Migrating from `shimmer`

The widget API is the same; change the import and the class works as before:

```dart
// import 'package:shimmer/shimmer.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';
```

`Shimmer`, `Shimmer.fromColors`, `ShimmerDirection` (`ltr`, `rtl`, `ttb`,
`btt`), `period`, `loop`, and `enabled` all behave the way you expect.

Adding `ShimmerScope` is opt-in, and staying out of it costs nothing: with no
scope above it a `Shimmer` renders the pixels it rendered before scopes
existed. `test/shimmer_scope_test.dart` keeps a transcription of the 1.0.1
implementation and renders the two side by side on one clock, comparing every
pixel at eight points of a sweep in all four directions.

## Reduced motion

![Four frames of one sweep side by side: on the left the highlight band advances across the placeholder card, on the right the same card stays flat base gray because the platform asked for reduced motion](https://raw.githubusercontent.com/Yusufihsangorgel/skeleton_shimmer/main/doc/reduced-motion.png)

Each row is one frame. The left card sits under the ambient `MediaQuery` and
the right one under `disableAnimations: true`: the sweep stops, the gradient
mask stays, and the placeholders still preview the layout that is coming.

Your app wires nothing up for this. `MediaQueryData.fromView` fills the flag in
from `AccessibilityFeatures.disableAnimations` and `Shimmer` reads it. Two
things are worth knowing anyway:

- Ignoring the flag is worse than it sounds. While it is set,
  `AnimationController.forward()` runs its duration at 5% by default
  (`AnimationBehavior.normal`), so a shimmer that kept sweeping would restart
  every 75 ms instead of every 1500 ms. Measured on Flutter 3.41.
- Override `MediaQuery` with `copyWith`. A fresh `MediaQueryData(...)` anywhere
  above a `Shimmer` resets `disableAnimations` to false, and then the sweep
  runs for someone who asked it not to.

`example/lib/main.dart` has a switch that turns the flag on for the feed below
it. Both states are then visible on a machine that has the setting turned off.

## Screen readers

The placeholder shapes stay out of the semantics tree. A skeleton is decoration
standing in for content that has not arrived, and a run of empty containers is
nothing but an obstacle to walk past. Pass `semanticsLabel` to announce the
loading state instead:

```dart
Shimmer.fromColors(
  baseColor: base,
  highlightColor: highlight,
  semanticsLabel: AppLocalizations.of(context).loading,
  child: const SkeletonLine(width: 200),
)
```

It works like `CircularProgressIndicator.semanticsLabel`, including having no
default: the package cannot invent a localized string, so it stays quiet rather
than announcing English into every app. The label is a live region, which means
it is read when the skeleton appears rather than only when focus reaches it.

## Skeleton primitives

| Widget | Shape |
|---|---|
| `SkeletonBox(width, height, borderRadius)` | Rounded rectangle |
| `SkeletonCircle(size)` | Circle, e.g. avatar |
| `SkeletonLine(width, height)` | Pill-shaped text line |

All take a `color` (default: a light gray for the shimmer to paint over). Null
`width`/`height` fills the available space when the incoming constraints are
bounded.

## Where a scope is the wrong tool

- One `Shimmer` already wraps the whole list. If every row is the same width
  and they all sit under a single widget, that widget is already the frame the
  sweep travels across, and a scope has nothing left to change.
- Two widgets need different speeds. One clock means one `period`; a widget
  that wants its own pace has to sit outside the scope.
- The sweep is frozen over scrolling content. While the band is held still, by
  `enabled: false` or by reduced motion, nothing repaints it: it stays with its
  widget until something else triggers a repaint.
- Scopes are nested. A `Shimmer` binds to the nearest one above it, which is
  usually what you want and does mean an inner scope quietly wins.

## Notes

- A custom `Gradient` passed to the default constructor is used exactly as
  given; the sweep comes from sliding the paint window across the child, which
  is why it applies to any gradient type.
- `loop: 0` (default) repeats until the widget is disposed or `enabled: false`.

## Credits

The API design and sweep geometry follow the
[shimmer](https://pub.dev/packages/shimmer) package by HungHD (hnvn); this is
an independent implementation.

## License

MIT
